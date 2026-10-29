import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Auth } from "./auth.js";
import { exec, rows, transaction, parseJson, type DB } from "./db.js";
import { packId, publicPack } from "./catalog.js";
import { fail, hash, encrypt, decrypt, id, ApiError } from "./security.js";
export const coinProducts: Record<string, number> = {
  betterseed_coin_120: 120,
  betterseed_coin_300: 300,
  betterseed_coin_650: 650,
  betterseed_coin_1400: 1400,
};
export class Billing {
  constructor(public a: Auth) {}
  async wallet(db: DB, uid: string) {
    const [wallet] = await rows(
      db,
      `SELECT balance,revision,
      (SELECT JSON_ARRAYAGG(pack_id) FROM entitlements WHERE user_id=wallets.user_id) AS packs
      FROM wallets WHERE user_id=?`,
      [uid],
    );
    return {
      balance: Number(wallet?.balance ?? 0),
      revision: wallet?.revision ?? 0,
      packs: parseJson(wallet?.packs ?? []) ?? [],
    };
  }
  async verify(
    uid: string,
    billingId: string,
    product: string,
    purchaseToken: string,
  ) {
    const { pool, c, p } = this.a;
    const coins = coinProducts[product];
    if (!coins) return fail(400, "unknown_product");
    const tokenHash = hash(c, "purchase", purchaseToken);
    const [previous] = await rows(
      pool,
      "SELECT * FROM purchases WHERE token_hash=?",
      [tokenHash],
    );
    if (previous && previous.user_id !== uid)
      return fail(409, "purchase_unavailable");
    if (previous?.state === "voided") return fail(409, "purchase_voided");
    let purchase;
    try {
      purchase = await p.playPurchase(product, purchaseToken);
    } catch {
      return fail(503, "play_verification_unavailable");
    }
    if (purchase.purchaseState !== 0)
      return fail(
        409,
        purchase.purchaseState === 2
          ? "purchase_pending"
          : "purchase_not_completed",
      );
    if (purchase.obfuscatedExternalAccountId !== billingId)
      return fail(403, "purchase_account_mismatch");
    if ((purchase.quantity ?? 1) !== 1)
      return fail(400, "unsupported_purchase_quantity");
    if (purchase.consumptionState !== 0 && !previous)
      return fail(409, "purchase_already_consumed");
    await transaction(pool, async (db) => {
      const [owner] = await rows(
        db,
        "SELECT id FROM users WHERE id=? FOR UPDATE",
        [uid],
      );
      if (!owner) return fail(401, "unauthorized");
      const [existing] = await rows(
        db,
        "SELECT * FROM purchases WHERE token_hash=? FOR UPDATE",
        [tokenHash],
      );
      if (existing) {
        if (existing.user_id !== uid || existing.product_id !== product)
          return fail(409, "purchase_unavailable");
        if (existing.state === "voided") return fail(409, "purchase_voided");
        return;
      }
      await exec(
        db,
        `INSERT INTO purchases(token_hash,user_id,product_id,token_cipher,coins,state) VALUES(?,?,?,?,?,'credited')`,
        [tokenHash, uid, product, encrypt(c, purchaseToken), coins],
      );
      await exec(
        db,
        `INSERT INTO wallets(user_id,balance,revision) VALUES(?,?,1) ON DUPLICATE KEY UPDATE balance=balance+?,revision=revision+1`,
        [uid, coins, coins],
      );
      await exec(
        db,
        "INSERT INTO coin_ledger(user_id,entry_key,delta) VALUES(?,?,?)",
        [uid, "grant:" + tokenHash, coins],
      );
    });
    // Consume only AFTER the durable credit commits. A worker repairs interruptions.
    const consumed = await this.finishConsumption(tokenHash);
    return { ...(await this.wallet(pool, uid)), verified: true, consumed };
  }
  async finishConsumption(tokenHash: string) {
    const { pool, c, p } = this.a;
    const [row] = await rows(
      pool,
      "SELECT * FROM purchases WHERE token_hash=?",
      [tokenHash],
    );
    if (!row || row.state === "voided") return false;
    if (row.state === "consumed") return true;
    if (!row.token_cipher || !row.user_id) return false;
    try {
      const purchaseToken = decrypt(c, row.token_cipher);
      let purchase = await p.playPurchase(row.product_id, purchaseToken);
      if (purchase.purchaseState !== 0) {
        if (purchase.purchaseState === 1) await this.void(tokenHash);
        return false;
      }
      if (purchase.consumptionState !== 1) {
        try {
          await p.consume(row.product_id, purchaseToken);
        } catch {
          // A timeout may mean Google completed consumption. Verify before retry.
          purchase = await p.playPurchase(row.product_id, purchaseToken);
          if (purchase.consumptionState !== 1) return false;
        }
      }
      const result = await exec(
        pool,
        "UPDATE purchases SET state='consumed',checked_at=NOW(3) WHERE token_hash=? AND state='credited'",
        [tokenHash],
      );
      if (result.affectedRows === 0) {
        const [fresh] = await rows(
          pool,
          "SELECT state FROM purchases WHERE token_hash=?",
          [tokenHash],
        );
        return fresh?.state === "consumed";
      }
      return true;
    } catch {
      return false;
    }
  }
  async void(tokenHash: string) {
    const { pool } = this.a;
    await transaction(pool, async (db) => {
      // Keep lock order user -> purchase, consistent with grants and deletion.
      const [hint] = await rows(
        db,
        "SELECT user_id FROM purchases WHERE token_hash=?",
        [tokenHash],
      );
      if (hint?.user_id)
        await rows(db, "SELECT id FROM users WHERE id=? FOR UPDATE", [
          hint.user_id,
        ]);
      const [row] = await rows(
        db,
        "SELECT * FROM purchases WHERE token_hash=? FOR UPDATE",
        [tokenHash],
      );
      if (!row || row.state === "voided") return;
      if (row.user_id) {
        await exec(
          db,
          "UPDATE wallets SET balance=balance-?,revision=revision+1 WHERE user_id=?",
          [row.coins, row.user_id],
        );
        await exec(
          db,
          "INSERT INTO coin_ledger(user_id,entry_key,delta) VALUES(?,?,?)",
          [row.user_id, "void:" + tokenHash, -row.coins],
        );
      }
      await exec(
        db,
        "UPDATE purchases SET state='voided',token_cipher=NULL,checked_at=NOW(3) WHERE token_hash=?",
        [tokenHash],
      );
    });
  }
  async reconcile() {
    const { pool, c, p } = this.a;
    const pending = await rows(
      pool,
      "SELECT token_hash FROM purchases WHERE state='credited' AND user_id IS NOT NULL ORDER BY created_at LIMIT 100",
    );
    for (const row of pending) await this.finishConsumption(row.token_hash);
    let page: string | undefined;
    do {
      const result = await p.voided(page);
      for (const t of result.tokens) await this.void(hash(c, "purchase", t));
      page = result.next;
    } while (page);
  }
}
export function billingRoutes(app: FastifyInstance, billing: Billing) {
  const a = billing.a;
  app.get("/v1/wallet", async (r) => {
    const u = await a.current(r);
    return {
      ...(await billing.wallet(a.pool, u.id)),
      billingAvailable: !!a.c.GOOGLE_APPLICATION_CREDENTIALS,
    };
  });
  app.post("/v1/billing/verify", async (r) => {
    const u = await a.current(r);
    const b = z
      .object({
        productId: z.string().max(80),
        purchaseToken: z.string().min(1).max(4096),
      })
      .strict()
      .parse(r.body);
    if (!a.c.GOOGLE_APPLICATION_CREDENTIALS)
      return fail(503, "billing_unavailable");
    return billing.verify(u.id, u.billing_id, b.productId, b.purchaseToken);
  });
  app.post("/v1/shop/unlock", async (r) => {
    const u = await a.current(r);
    const b = z
      .object({
        packId,
        expectedPrice: z.number().int().min(0).max(1000000).optional(),
        catalogRevision: z.number().int().positive().optional(),
        appBuild: z.number().int().positive().optional(),
      })
      .strict()
      .parse(r.body);
    return transaction(a.pool, async (db) => {
      const [owner] = await rows(
        db,
        "SELECT id FROM users WHERE id=? FOR UPDATE",
        [u.id],
      );
      if (!owner) return fail(401, "unauthorized");
      const [existing] = await rows(
        db,
        "SELECT pack_id FROM entitlements WHERE user_id=? AND pack_id=?",
        [u.id, b.packId],
      );
      if (existing) return billing.wallet(db, u.id);
      const [pack] = await rows(
        db,
        "SELECT * FROM garden_packs WHERE pack_id=? FOR UPDATE",
        [b.packId],
      );
      if (!pack || pack.status !== "active")
        return fail(409, "pack_unavailable");
      const modern =
        b.expectedPrice !== undefined &&
        b.catalogRevision !== undefined &&
        b.appBuild !== undefined;
      if (!modern) {
        if (
          b.expectedPrice !== undefined ||
          b.catalogRevision !== undefined ||
          b.appBuild !== undefined ||
          pack.legacy_price === null ||
          pack.access_type !== "premium" ||
          Number(pack.price_coins) !== Number(pack.legacy_price) ||
          pack.minimum_app_build > 56
        )
          return fail(409, "app_update_required");
      } else {
        if (b.appBuild! < pack.minimum_app_build)
          return fail(409, "app_update_required");
        if (
          b.expectedPrice !== Number(pack.price_coins) ||
          b.catalogRevision !== pack.revision
        )
          throw new ApiError(409, "catalog_changed", {
            pack: publicPack(pack),
          });
      }
      if (b.packId === "default") return billing.wallet(db, u.id);
      const cost = Number(pack.price_coins);
      await exec(db, "INSERT IGNORE INTO wallets(user_id) VALUES(?)", [u.id]);
      const result = await exec(
        db,
        "UPDATE wallets SET balance=balance-?,revision=revision+1 WHERE user_id=? AND (balance>=? OR ?=0)",
        [cost, u.id, cost, cost],
      );
      if (result.affectedRows !== 1) return fail(409, "insufficient_coins");
      await exec(
        db,
        "INSERT INTO entitlements(user_id,pack_id,cost) VALUES(?,?,?)",
        [u.id, b.packId, cost],
      );
      const acquisition = id();
      await exec(
        db,
        "INSERT INTO pack_acquisitions(id,user_id,pack_id,price_coins,catalog_revision,access_type) VALUES(?,?,?,?,?,?)",
        [acquisition, u.id, b.packId, cost, pack.revision, pack.access_type],
      );
      await exec(
        db,
        "INSERT INTO coin_ledger(user_id,entry_key,delta) VALUES(?,?,?)",
        [u.id, "pack-acquisition:" + acquisition, -cost],
      );
      return billing.wallet(db, u.id);
    });
  });
  app.post("/v1/billing/notifications", async (r) => {
    const jwt = r.headers.authorization?.match(/^Bearer (.+)$/)?.[1];
    if (!jwt) return fail(401, "unauthorized");
    await a.p.verifyNotification(jwt);
    const envelope = z
      .object({
        message: z.object({ data: z.string().max(100000) }).passthrough(),
      })
      .passthrough()
      .parse(r.body);
    let payload: any;
    try {
      payload = JSON.parse(
        Buffer.from(envelope.message.data, "base64").toString("utf8"),
      );
    } catch {
      return fail(400, "invalid_notification");
    }
    if (payload.packageName !== a.c.GOOGLE_PLAY_PACKAGE_NAME)
      return fail(400, "wrong_package");
    if (payload.voidedPurchaseNotification?.purchaseToken) {
      await billing.void(
        hash(a.c, "purchase", payload.voidedPurchaseNotification.purchaseToken),
      );
    } else if (payload.oneTimeProductNotification?.purchaseToken) {
      const t = payload.oneTimeProductNotification.purchaseToken;
      const h = hash(a.c, "purchase", t);
      const [existing] = await rows(
        a.pool,
        "SELECT * FROM purchases WHERE token_hash=?",
        [h],
      );
      if (existing?.user_id && existing.state !== "voided") {
        const state = await a.p.playPurchase(existing.product_id, t);
        if (state.purchaseState === 1) await billing.void(h);
        else await billing.finishConsumption(h);
      }
      // Unknown tokens are never credited by push alone; the app must bind an account.
    }
    return { ok: true };
  });
}

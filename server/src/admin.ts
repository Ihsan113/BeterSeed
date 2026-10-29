import type { FastifyInstance, FastifyRequest, FastifyReply } from "fastify";
import { readFile } from "node:fs/promises";
import { z } from "zod";
import type { Auth } from "./auth.js";
import { rows, exec, transaction, type DB } from "./db.js";
import {
  fail,
  id,
  token,
  hash,
  decrypt,
  matchingStep,
  passwordMatches,
  passwordHash,
  rateLimit,
} from "./security.js";
import {
  packId,
  packInput,
  validOffer,
  catalog,
  publicPack,
} from "./catalog.js";
import { email, password } from "./schema.js";
const cookieName = "__Host-betterseed_admin";
const reason = z.string().trim().min(5).max(500);
const packs = packId;
const fields = `u.id,u.email,u.provider,u.verified,u.created_at,(u.totp_secret IS NOT NULL) AS twoFactorEnabled,
 COALESCE(ac.suspended,0) AS suspended,COALESCE(w.balance,0) AS balance,COALESCE(g.revision,0) AS gardenRevision,g.updated_at AS lastSync`;
const joins = `FROM users u LEFT JOIN account_controls ac ON ac.user_id=u.id LEFT JOIN wallets w ON w.user_id=u.id LEFT JOIN gardens g ON g.user_id=u.id`;
export function adminRoutes(app: FastifyInstance, a: Auth) {
  const { pool, c } = a;
  function sameOrigin(r: FastifyRequest) {
    if (r.headers.origin !== new URL(c.PUBLIC_BASE_URL).origin)
      fail(403, "admin_origin_required");
    if (!r.headers["content-type"]?.startsWith("application/json"))
      fail(415, "invalid_request");
  }
  function rawSession(r: FastifyRequest) {
    const raw = r.headers.cookie
      ?.split(";")
      .map((x) => x.trim())
      .find((x) => x.startsWith(cookieName + "="))
      ?.slice(cookieName.length + 1);
    return raw && /^[A-Za-z0-9_-]{43}$/.test(raw) ? raw : "";
  }
  const csrf = (raw: string) => hash(c, "admin-csrf", raw);
  function setCookie(reply: FastifyReply, raw: string, age: number) {
    reply.header(
      "Set-Cookie",
      `${cookieName}=${raw}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${age}`,
    );
  }
  async function current(r: FastifyRequest, mutate = false) {
    const raw = rawSession(r);
    if (!raw) return fail(401, "admin_unauthorized");
    const [u] = await rows(
      pool,
      `SELECT au.id,au.email,s.csrf_hash FROM admin_sessions s JOIN admin_users au ON au.id=s.admin_id WHERE s.token_hash=? AND s.expires_at>NOW(3)`,
      [hash(c, "admin-session", raw)],
    );
    if (!u) return fail(401, "admin_unauthorized");
    if (mutate) {
      sameOrigin(r);
      const proof = r.headers["x-csrf-token"];
      if (
        typeof proof !== "string" ||
        hash(c, "admin-csrf-proof", proof) !== u.csrf_hash
      )
        fail(403, "admin_csrf_required");
    }
    return u;
  }
  async function audit(
    db: DB,
    actor: string,
    target: string | null,
    action: string,
    why: string,
    details: object = {},
  ) {
    await exec(
      db,
      "INSERT INTO admin_audit(admin_id,target_id,action,reason,details) VALUES(?,?,?,?,?)",
      [actor, target, action, why, JSON.stringify(details)],
    );
  }
  async function lockUser(db: DB, uid: string) {
    const [u] = await rows(db, "SELECT * FROM users WHERE id=? FOR UPDATE", [
      uid,
    ]);
    return u ?? fail(404, "user_not_found");
  }
  const uid = (r: FastifyRequest) =>
    z.object({ id: z.uuid() }).parse(r.params).id;
  app.addHook("onRequest", async (r) => {
    if (r.url.startsWith("/admin/api/"))
      await rateLimit(pool, c, "admin-ip:" + r.ip, 90, 60);
  });
  for (const [url, name, type] of [
    ["/admin", "index.html", "text/html"],
    ["/admin/", "index.html", "text/html"],
    ["/admin/app.js", "app.js", "application/javascript"],
    ["/admin/style.css", "style.css", "text/css"],
  ])
    app.get(url!, async (_r, reply) =>
      reply
        .type(type! + "; charset=utf-8")
        .send(
          await readFile(
            new URL(`../public/admin/${name}`, import.meta.url),
            "utf8",
          ),
        ),
    );
  const dummy = passwordHash(token());
  app.post("/admin/api/login", async (r, reply) => {
    sameOrigin(r);
    const b = z
      .object({
        email,
        password: z.string().min(1).max(128),
        code: z.string().regex(/^\d{6}$/),
      })
      .strict()
      .parse(r.body);
    await rateLimit(pool, c, "admin-login-ip:" + r.ip, 10, 900);
    await rateLimit(pool, c, "admin-login:" + b.email, 5, 900);
    const [candidate] = await rows(
      pool,
      "SELECT id,password_hash FROM admin_users WHERE email=?",
      [b.email],
    );
    const valid = await passwordMatches(
      candidate?.password_hash ?? (await dummy),
      b.password,
    );
    if (!valid || !candidate) return fail(401, "admin_invalid_credentials");
    const result = await transaction(pool, async (db) => {
      const [u] = await rows(
        db,
        "SELECT * FROM admin_users WHERE id=? FOR UPDATE",
        [candidate.id],
      );
      if (!u || u.password_hash !== candidate.password_hash) return null;
      const step = matchingStep(
        decrypt(c, u.totp_secret),
        b.code,
        Number(u.totp_last_step),
      );
      if (step < 0) return null;
      await exec(db, "UPDATE admin_users SET totp_last_step=? WHERE id=?", [
        step,
        u.id,
      ]);
      const raw = token();
      await exec(
        db,
        `INSERT INTO admin_sessions(token_hash,admin_id,csrf_hash,expires_at) VALUES(?,?,?,DATE_ADD(NOW(3),INTERVAL 8 HOUR))`,
        [
          hash(c, "admin-session", raw),
          u.id,
          hash(c, "admin-csrf-proof", csrf(raw)),
        ],
      );
      await audit(db, u.id, null, "admin.login", "Authenticator verified");
      return { raw, email: u.email };
    });
    if (!result) return fail(401, "admin_invalid_credentials");
    setCookie(reply, result.raw, 28800);
    return { email: result.email, csrf: csrf(result.raw) };
  });
  app.get("/admin/api/me", async (r) => {
    const u = await current(r);
    return { email: u.email, csrf: csrf(rawSession(r)) };
  });
  app.post("/admin/api/logout", async (r, reply) => {
    await current(r, true);
    await exec(pool, "DELETE FROM admin_sessions WHERE token_hash=?", [
      hash(c, "admin-session", rawSession(r)),
    ]);
    setCookie(reply, "", 0);
    return { ok: true };
  });
  app.get("/admin/api/overview", async (r) => {
    await current(r);
    const [stats] = await rows(
      pool,
      `SELECT (SELECT COUNT(*) FROM users) AS users,(SELECT COUNT(*) FROM users WHERE verified=1) AS verified,
   (SELECT COUNT(*) FROM account_controls WHERE suspended=1) AS suspended,(SELECT COUNT(*) FROM sessions WHERE access_until>NOW(3)) AS activeSessions,
   (SELECT COUNT(*) FROM purchases WHERE state='credited') AS pendingPurchases,(SELECT COUNT(*) FROM email_outbox WHERE expires_at>NOW(3)) AS pendingEmails`,
    );
    return stats;
  });
  app.get("/admin/api/users", async (r) => {
    await current(r);
    const q = z
      .object({
        search: z.string().trim().max(254).default(""),
        page: z.coerce.number().int().min(1).max(100000).default(1),
      })
      .strict()
      .parse(r.query);
    const search = `%${q.search.replace(/[!%_]/g, (m) => "!" + m)}%`,
      filter = "WHERE u.email LIKE ? ESCAPE '!'";
    const [count] = await rows(
      pool,
      `SELECT COUNT(*) AS total FROM users u ${filter}`,
      [search],
    );
    return {
      users: await rows(
        pool,
        `SELECT ${fields} ${joins} ${filter} ORDER BY u.created_at DESC,u.id LIMIT 25 OFFSET ?`,
        [search, (q.page - 1) * 25],
      ),
      total: Number(count!.total),
      page: q.page,
      pageSize: 25,
    };
  });
  app.get("/admin/api/users/:id", async (r) => {
    await current(r);
    const target = uid(r);
    const [user] = await rows(pool, `SELECT ${fields} ${joins} WHERE u.id=?`, [
      target,
    ]);
    if (!user) return fail(404, "user_not_found");
    const [garden] = await rows(
      pool,
      "SELECT snapshot FROM gardens WHERE user_id=?",
      [target],
    );
    const s = garden?.snapshot;
    return {
      user,
      garden: { habitCount: s?.habits?.length ?? 0, xp: s?.progress?.xp ?? 0 },
      packs: await rows(
        pool,
        "SELECT pack_id,cost,created_at FROM entitlements WHERE user_id=?",
        [target],
      ),
      ledger: await rows(
        pool,
        "SELECT delta,created_at FROM coin_ledger WHERE user_id=? ORDER BY id DESC LIMIT 30",
        [target],
      ),
      purchases: await rows(
        pool,
        "SELECT product_id,coins,state,created_at FROM purchases WHERE user_id=? ORDER BY created_at DESC LIMIT 30",
        [target],
      ),
      audit: await rows(
        pool,
        "SELECT action,reason,details,created_at FROM admin_audit WHERE target_id=? ORDER BY id DESC LIMIT 30",
        [target],
      ),
    };
  });
  app.post("/admin/api/users", async (r) => {
    const actor = await current(r, true);
    const b = z.object({ email, password, reason }).strict().parse(r.body);
    const pw = await passwordHash(b.password);
    return transaction(pool, async (db) => {
      const target = id();
      await exec(
        db,
        `INSERT INTO users(id,email,provider,password_hash,billing_id,legal_version) VALUES(?,?,'email',?,?,'pending')`,
        [target, b.email, pw, token().slice(0, 43) + token().slice(0, 21)],
      );
      await a.emailChallenge(db, { id: target, email: b.email }, "verify");
      await audit(db, actor.id, target, "user.create", b.reason);
      return { id: target };
    });
  });
  app.patch("/admin/api/users/:id", async (r) => {
    const actor = await current(r, true),
      target = uid(r);
    const b = z
      .object({
        email: email.optional(),
        suspended: z.boolean().optional(),
        reason,
      })
      .strict()
      .refine((b) => b.email !== undefined || b.suspended !== undefined)
      .parse(r.body);
    return transaction(pool, async (db) => {
      const u = await lockUser(db, target);
      if (b.email !== undefined && b.email !== u.email) {
        if (u.provider !== "email") fail(400, "google_managed_email");
        // Re-verification must not make an established account eligible for
        // the abandoned-signup cleanup job, especially after years of use.
        await exec(
          db,
          `INSERT IGNORE INTO pending_email_changes(user_id)
          SELECT id FROM users WHERE id=? AND verified=1`,
          [target],
        );
        await exec(db, "UPDATE users SET email=?,verified=0 WHERE id=?", [
          b.email,
          target,
        ]);
        await exec(db, "DELETE FROM challenges WHERE user_id=?", [target]);
        await exec(db, "DELETE FROM email_outbox WHERE user_id=?", [target]);
        await a.emailChallenge(db, { id: target, email: b.email }, "verify");
      }
      if (b.suspended !== undefined)
        await exec(
          db,
          "INSERT INTO account_controls(user_id,suspended) VALUES(?,?) ON DUPLICATE KEY UPDATE suspended=?",
          [target, b.suspended, b.suspended],
        );
      await exec(db, "DELETE FROM sessions WHERE user_id=?", [target]);
      if (b.suspended)
        await exec(
          db,
          "DELETE FROM challenges WHERE user_id=? AND purpose='login'",
          [target],
        );
      await audit(db, actor.id, target, "user.update", b.reason, {
        emailChanged: b.email !== undefined && b.email !== u.email,
        suspended: b.suspended,
      });
      return { ok: true };
    });
  });
  app.post("/admin/api/users/:id/revoke-sessions", async (r) => {
    const actor = await current(r, true),
      target = uid(r),
      b = z.object({ reason }).strict().parse(r.body);
    return transaction(pool, async (db) => {
      await lockUser(db, target);
      await exec(db, "DELETE FROM sessions WHERE user_id=?", [target]);
      await exec(
        db,
        "DELETE FROM challenges WHERE user_id=? AND purpose='login'",
        [target],
      );
      await audit(db, actor.id, target, "user.revoke_sessions", b.reason);
      return { ok: true };
    });
  });
  app.post("/admin/api/users/:id/coins", async (r) => {
    const actor = await current(r, true),
      target = uid(r),
      b = z
        .object({
          delta: z
            .number()
            .int()
            .min(-100000)
            .max(100000)
            .refine((n) => n !== 0),
          mutationId: z.uuid(),
          reason,
        })
        .strict()
        .parse(r.body);
    return transaction(pool, async (db) => {
      await lockUser(db, target);
      const key = `admin:${b.mutationId}`;
      const [prior] = await rows(
        db,
        "SELECT user_id,delta FROM coin_ledger WHERE entry_key=?",
        [key],
      );
      if (prior) {
        if (prior.user_id !== target || Number(prior.delta) !== b.delta)
          fail(409, "mutation_conflict");
        return { ok: true, repeated: true };
      }
      await exec(db, "INSERT IGNORE INTO wallets(user_id) VALUES(?)", [target]);
      const [wallet] = await rows(
        db,
        "SELECT balance FROM wallets WHERE user_id=? FOR UPDATE",
        [target],
      );
      const next = Number(wallet!.balance) + b.delta;
      if (!Number.isSafeInteger(next) || Math.abs(next) > 1000000000)
        fail(400, "balance_limit");
      await exec(
        db,
        "UPDATE wallets SET balance=?,revision=revision+1 WHERE user_id=?",
        [next, target],
      );
      await exec(
        db,
        "INSERT INTO coin_ledger(user_id,entry_key,delta) VALUES(?,?,?)",
        [target, key, b.delta],
      );
      await audit(db, actor.id, target, "wallet.adjust", b.reason, {
        delta: b.delta,
        mutationId: b.mutationId,
      });
      return { ok: true };
    });
  });
  app.post("/admin/api/users/:id/packs", async (r) => {
    const actor = await current(r, true),
      target = uid(r),
      b = z
        .object({ pack: packs, granted: z.boolean(), reason })
        .strict()
        .parse(r.body);
    return transaction(pool, async (db) => {
      await lockUser(db, target);
      const [registered] = await rows(
        db,
        "SELECT pack_id FROM garden_packs WHERE pack_id=? FOR SHARE",
        [b.pack],
      );
      if (!registered || b.pack === "default") fail(400, "invalid_pack");
      if (b.granted)
        await exec(
          db,
          "INSERT IGNORE INTO entitlements(user_id,pack_id,cost) VALUES(?,?,0)",
          [target, b.pack],
        );
      else
        await exec(
          db,
          "DELETE FROM entitlements WHERE user_id=? AND pack_id=?",
          [target, b.pack],
        );
      await exec(
        db,
        "INSERT INTO wallets(user_id,revision) VALUES(?,1) ON DUPLICATE KEY UPDATE revision=revision+1",
        [target],
      );
      await audit(
        db,
        actor.id,
        target,
        b.granted ? "pack.grant" : "pack.revoke",
        b.reason,
        { pack: b.pack },
      );
      return { ok: true };
    });
  });
  app.delete("/admin/api/users/:id", async (r) => {
    const actor = await current(r, true),
      target = uid(r),
      b = z.object({ confirmation: email, reason }).strict().parse(r.body);
    return transaction(pool, async (db) => {
      const u = await lockUser(db, target);
      if (b.confirmation !== u.email) fail(400, "confirmation_mismatch");
      await exec(db, "UPDATE purchases SET token_cipher=NULL WHERE user_id=?", [
        target,
      ]);
      await exec(db, "DELETE FROM users WHERE id=?", [target]);
      await exec(
        db,
        "UPDATE admin_audit SET target_id=NULL,reason='Account deleted',details=NULL WHERE target_id=?",
        [target],
      );
      await audit(
        db,
        actor.id,
        null,
        "user.delete",
        "Account permanently deleted",
      );
      return { ok: true };
    });
  });
  app.get("/admin/api/packs", async (r) => {
    await current(r);
    return { packs: await catalog(pool, true) };
  });
  app.post("/admin/api/packs", async (r) => {
    const actor = await current(r, true);
    const b = packInput.extend({ packId, reason }).strict().parse(r.body);
    if (!validOffer(b) || b.packId === "default") fail(400, "invalid_pack");
    return transaction(pool, async (db) => {
      await exec(
        db,
        `INSERT INTO garden_packs(pack_id,name,description,access_type,price_coins,status,minimum_app_build,display_order) VALUES(?,?,?,?,?,?,?,?)`,
        [
          b.packId,
          b.name,
          b.description,
          b.accessType,
          b.priceCoins,
          b.status,
          b.minimumAppBuild,
          b.displayOrder,
        ],
      );
      await audit(db, actor.id, null, "catalog.create", b.reason, {
        pack: b.packId,
        offer: b,
      });
      return { packs: await catalog(db, true) };
    });
  });
  app.patch("/admin/api/packs/:packId", async (r) => {
    const actor = await current(r, true),
      key = z.object({ packId }).parse(r.params).packId;
    const b = packInput
      .extend({ expectedRevision: z.number().int().positive(), reason })
      .strict()
      .parse(r.body);
    if (
      !validOffer(b) ||
      (key === "default" &&
        (b.accessType !== "free" ||
          b.status !== "active" ||
          b.minimumAppBuild !== 1))
    )
      fail(400, "invalid_pack");
    return transaction(pool, async (db) => {
      const [previous] = await rows(
        db,
        "SELECT * FROM garden_packs WHERE pack_id=? FOR UPDATE",
        [key],
      );
      if (!previous) fail(404, "pack_not_found");
      if (previous!.revision !== b.expectedRevision)
        fail(409, "catalog_changed");
      await exec(
        db,
        `UPDATE garden_packs SET name=?,description=?,access_type=?,price_coins=?,status=?,minimum_app_build=?,display_order=?,revision=revision+1,updated_at=NOW(3) WHERE pack_id=?`,
        [
          b.name,
          b.description,
          b.accessType,
          b.priceCoins,
          b.status,
          b.minimumAppBuild,
          b.displayOrder,
          key,
        ],
      );
      await audit(db, actor.id, null, "catalog.update", b.reason, {
        pack: key,
        before: publicPack(previous),
        after: b,
      });
      return { packs: await catalog(db, true) };
    });
  });
  app.get("/admin/api/audit", async (r) => {
    await current(r);
    const q = z
      .object({ page: z.coerce.number().int().min(1).max(100000).default(1) })
      .strict()
      .parse(r.query);
    return {
      entries: await rows(
        pool,
        "SELECT id,admin_id,target_id,action,reason,details,created_at FROM admin_audit ORDER BY id DESC LIMIT 50 OFFSET ?",
        [(q.page - 1) * 50],
      ),
    };
  });
}

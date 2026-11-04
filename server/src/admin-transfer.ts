import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import type { Auth } from "./auth.js";
import { rows, exec, transaction, type DB } from "./db.js";
import { fail, hash, decrypt, matchingStep, passwordMatches, rateLimit } from "./security.js";
import { catalog, publicPack } from "./catalog.js";
import { packDocument, planPackImport, applyPackImport } from "./pack-transfer.js";
import { backupPassword, encryptedBackup, makeSnapshot, sealSnapshot, openSnapshot, inspectSnapshot, snapshotDigest, restoreSnapshot } from "./database-backup.js";
import type { DatabaseGate } from "./database-gate.js";

export function adminTransferRoutes(app: FastifyInstance, a: Auth, gate: DatabaseGate,
  current: (r: FastifyRequest, mutate?: boolean) => Promise<Record<string, any>>,
  audit: (db: DB, actor: string, target: string | null, action: string, why: string, details?: object) => Promise<void>) {
  const { pool, c } = a;
  const reason = z.string().trim().min(5).max(500);
  const previewProof = z.object({ expires: z.number().int(), signature: z.string().length(64) }).strict();
  function signPreview(actor: string, purpose: string, digest: string) {
    const expires = Date.now() + 10 * 60 * 1000;
    return { expires, signature: hash(c, "admin-preview", `${actor}:${purpose}:${digest}:${expires}`) };
  }
  function verifyPreview(actor: string, purpose: string, digest: string, proof: z.infer<typeof previewProof>) {
    if (proof.expires < Date.now() || proof.expires > Date.now() + 10 * 60 * 1000 ||
        proof.signature !== hash(c, "admin-preview", `${actor}:${purpose}:${digest}:${proof.expires}`)) fail(409, "preview_expired");
  }
  app.get("/admin/api/packs/export", async (r, reply) => {
    const actor = await current(r);
    const result = { format: "betterseed-garden-packs", version: 1,
      packs: (await rows(pool, "SELECT * FROM garden_packs ORDER BY display_order,pack_id")).map(publicPack) };
    await audit(pool, actor.id, null, "catalog.export", "Garden pack JSON exported");
    return reply.header("Content-Disposition", 'attachment; filename="BetterSeed-garden-packs.json"').send(result);
  });
  app.post("/admin/api/packs/import/preview", async r => {
    const actor = await current(r, true);
    const document = packDocument.parse(r.body);
    const changes = await planPackImport(pool, document);
    return { changes, proof: signPreview(actor.id, "packs", JSON.stringify(document)) };
  });
  app.post("/admin/api/packs/import", async r => {
    const actor = await current(r, true);
    const b = z.object({ document: packDocument, proof: previewProof, reason }).strict().parse(r.body);
    verifyPreview(actor.id, "packs", JSON.stringify(b.document), b.proof);
    return transaction(pool, async db => {
      const changes = await applyPackImport(db, b.document);
      await audit(db, actor.id, null, "catalog.import", b.reason, { changes });
      return { packs: await catalog(db, true), changed: changes.filter(p => p.action !== "unchanged").length };
    });
  });
  const credentials = z.object({ password: z.string().min(1).max(128), code: z.string().regex(/^\d{6}$/) }).strict();
  async function verifyAdmin(actor: string, proof: z.infer<typeof credentials>) {
    await rateLimit(pool, c, "admin-backup-auth:" + actor, 5, 900);
    return transaction(pool, async db => {
      const [u] = await rows(db, "SELECT * FROM admin_users WHERE id=? FOR UPDATE", [actor]);
      if (!u || !await passwordMatches(u.password_hash, proof.password)) fail(403, "admin_invalid_credentials");
      const step = matchingStep(decrypt(c, u!.totp_secret), proof.code, Number(u!.totp_last_step));
      if (step < 0) fail(403, "admin_invalid_credentials");
      await exec(db, "UPDATE admin_users SET totp_last_step=? WHERE id=?", [step,actor]);
    });
  }
  app.post("/admin/api/database/export", async (r, reply) => {
    const actor = await current(r, true);
    const b = z.object({ passphrase: backupPassword, credentials, reason }).strict().parse(r.body);
    await verifyAdmin(actor.id, b.credentials);
    await rateLimit(pool, c, "database-export:" + actor.id, 6, 600);
    const snapshot = await makeSnapshot(pool, c);
    const result = await sealSnapshot(snapshot, b.passphrase);
    await audit(pool, actor.id, null, "database.export", b.reason);
    return reply.header("Content-Disposition", 'attachment; filename="BetterSeed-database.encrypted.json"').send(result);
  });
  app.post("/admin/api/database/preview", { bodyLimit: 48 * 1024 * 1024 }, async r => {
    const actor = await current(r, true);
    const b = z.object({ backup: encryptedBackup, passphrase: backupPassword }).strict().parse(r.body);
    await rateLimit(pool, c, "database-preview:" + actor.id, 6, 600);
    const snapshot = await openSnapshot(b.backup, b.passphrase);
    const summary = await inspectSnapshot(pool, c, snapshot);
    return { ...summary, proof: signPreview(actor.id, "database", snapshotDigest(snapshot)) };
  });
  app.post("/admin/api/database/restore", { bodyLimit: 48 * 1024 * 1024 }, async r => {
    const actor = await current(r, true);
    const b = z.object({ backup: encryptedBackup, passphrase: backupPassword, credentials,
      proof: previewProof, confirmation: z.literal("RESTORE"), safetyBackupSaved: z.literal(true), reason }).strict().parse(r.body);
    await verifyAdmin(actor.id, b.credentials);
    const snapshot = await openSnapshot(b.backup, b.passphrase);
    verifyPreview(actor.id, "database", snapshotDigest(snapshot), b.proof);
    return gate.run(async () => {
      await current(r, true);
      return { ok: true, summary: await restoreSnapshot(pool, c, snapshot, actor.id, b.reason) };
    }, true);
  });
}

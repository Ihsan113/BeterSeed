import { createCipheriv, createDecipheriv, createHash, randomBytes, scrypt } from "node:crypto";
import { z } from "zod";
import type { Pool } from "mysql2/promise";
import type { Config } from "./config.js";
import { rows, exec, transaction, type DB } from "./db.js";
import { fail, hash } from "./security.js";

// Parent-first dependency order. No identifiers or SQL are taken from an upload.
export const backupTables = ["users", "admin_users", "garden_packs", "recovery_codes",
  "gardens", "sync_mutations", "wallets", "entitlements", "purchases", "coin_ledger",
  "account_controls", "admin_audit", "pending_email_changes", "pack_acquisitions"] as const;
const transientTables = ["refresh_receipts", "sessions", "used_refresh", "challenges", "email_outbox", "admin_sessions"];
const limit = 32 * 1024 * 1024;
export const backupPassword = z.string().min(16).max(256);
const base64 = (bytes: number) => z.string().max(Math.ceil(bytes / 3) * 4).refine(value => value.length % 4 === 0 && /^[A-Za-z0-9+/]*={0,2}$/.test(value));
export const encryptedBackup = z.object({
  format: z.literal("betterseed-encrypted-database"), version: z.literal(1),
  algorithm: z.literal("scrypt-aes-256-gcm"), salt: base64(16), iv: base64(12),
  tag: base64(16), data: base64(limit),
}).strict();
const cell = z.union([z.string().max(limit), z.number().finite(), z.boolean(), z.null(), z.record(z.string(), z.unknown()), z.array(z.unknown())]);
const snapshotSchema = z.object({
  format: z.literal("betterseed-database"), version: z.literal(1),
  createdAt: z.iso.datetime(), keyId: z.string().length(64), schema: z.string().length(64),
  tables: z.record(z.string(), z.object({ columns: z.array(z.string()).max(64), rows: z.array(z.array(cell).max(64)).max(100000) }).strict()),
}).strict();
type Snapshot = z.infer<typeof snapshotSchema>;
async function key(password: string, salt: Buffer) {
  return new Promise<Buffer>((resolve, reject) => scrypt(password, salt, 32, { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 }, (error, derived) => error ? reject(error) : resolve(derived)));
}
const aad = Buffer.from("betterseed-encrypted-database:v1:scrypt-aes-256-gcm");
export async function sealSnapshot(snapshot: Snapshot, passphrase: string) {
  const plain = Buffer.from(JSON.stringify(snapshot));
  if (plain.length > limit) fail(413, "backup_too_large");
  const salt = randomBytes(16), iv = randomBytes(12), derived = await key(passphrase, salt);
  try {
    const cipher = createCipheriv("aes-256-gcm", derived, iv); cipher.setAAD(aad);
    const data = Buffer.concat([cipher.update(plain), cipher.final()]);
    return { format: "betterseed-encrypted-database" as const, version: 1 as const,
      algorithm: "scrypt-aes-256-gcm" as const, salt: salt.toString("base64"), iv: iv.toString("base64"),
      tag: cipher.getAuthTag().toString("base64"), data: data.toString("base64") };
  } finally { derived.fill(0); plain.fill(0); }
}
export async function openSnapshot(input: z.infer<typeof encryptedBackup>, passphrase: string): Promise<Snapshot> {
  const salt = Buffer.from(input.salt, "base64"), iv = Buffer.from(input.iv, "base64"), tag = Buffer.from(input.tag, "base64");
  if (salt.length !== 16 || iv.length !== 12 || tag.length !== 16) return fail(400, "invalid_backup");
  const derived = await key(passphrase, salt);
  let plain: Buffer | undefined;
  try {
    const decipher = createDecipheriv("aes-256-gcm", derived, iv); decipher.setAAD(aad); decipher.setAuthTag(tag);
    plain = Buffer.concat([decipher.update(Buffer.from(input.data, "base64")), decipher.final()]);
    if (plain.length > limit) return fail(413, "backup_too_large");
    return snapshotSchema.parse(JSON.parse(plain.toString("utf8")));
  } catch { return fail(400, "invalid_backup"); }
  finally { derived.fill(0); plain?.fill(0); }
}
async function schema(db: DB) {
  const columns = await rows(db, `SELECT TABLE_NAME AS t,COLUMN_NAME AS c,COLUMN_TYPE AS type,
    IS_NULLABLE AS nullable,EXTRA AS extra,DATA_TYPE AS dataType,
    COLUMN_DEFAULT AS defaultValue,CHARACTER_SET_NAME AS charset,COLLATION_NAME AS collation FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA=DATABASE() ORDER BY TABLE_NAME,ORDINAL_POSITION`);
  const selected = columns.filter(c => (backupTables as readonly string[]).includes(c.t));
  return { columns: selected, fingerprint: createHash("sha256").update(JSON.stringify(selected)).digest("hex") };
}
const keyId = (c: Config) => hash(c, "database-backup-keys-v1", c.DATA_ENCRYPTION_KEY);
export async function makeSnapshot(pool: Pool, c: Config): Promise<Snapshot> {
  return transaction(pool, async db => {
    // InnoDB REPEATABLE READ gives one consistent snapshot across all tables.
    const shape = await schema(db);
    const tables: Snapshot["tables"] = {};
    let size = 0;
    for (const table of backupTables) {
      const columns = shape.columns.filter(c => c.t === table).map(c => c.c as string);
      if (!columns.length) fail(409, "backup_schema_mismatch");
      const [data] = await db.query<any[]>({ sql: `SELECT * FROM \`${table}\` LIMIT 100001`, dateStrings: true, supportBigNumbers: true, bigNumberStrings: true });
      if (data.length > 100000) fail(413, "backup_too_large");
      if (table === "users") for (const row of data) { row.totp_pending = null; row.totp_pending_until = null; }
      const saved = { columns, rows: data.map(row => columns.map(k => row[k])) };
      size += Buffer.byteLength(JSON.stringify(saved));
      if (size > limit) fail(413, "backup_too_large");
      tables[table] = saved;
    }
    return { format: "betterseed-database", version: 1, createdAt: new Date().toISOString(), keyId: keyId(c), schema: shape.fingerprint, tables };
  }, "REPEATABLE READ");
}
export async function inspectSnapshot(db: DB, c: Config, snapshot: Snapshot) {
  if (snapshot.keyId !== keyId(c)) fail(409, "backup_key_mismatch");
  const shape = await schema(db);
  if (snapshot.schema !== shape.fingerprint ||
      Object.keys(snapshot.tables).sort().join() !== [...backupTables].sort().join()) fail(409, "backup_schema_mismatch");
  for (const table of backupTables) {
    const cols = shape.columns.filter(c => c.t === table);
    const data = snapshot.tables[table]!;
    if (data.columns.join() !== cols.map(c => c.c).join()) fail(400, "invalid_backup");
    for (const row of data.rows) {
      if (row.length !== cols.length || row.some((v, i) => v !== null && typeof v === "object" && cols[i]!.dataType !== "json")) fail(400, "invalid_backup");
    }
  }
  if (!snapshot.tables.admin_users!.rows.length) fail(400, "backup_missing_admin");
  const packs = snapshot.tables.garden_packs!;
  const defaultPack = packs.rows.find(r => r[packs.columns.indexOf("pack_id")] === "default");
  if (!defaultPack || defaultPack[packs.columns.indexOf("access_type")] !== "free" ||
      Number(defaultPack[packs.columns.indexOf("price_coins")]) !== 0 ||
      defaultPack[packs.columns.indexOf("status")] !== "active") fail(400, "invalid_backup");
  return { createdAt: snapshot.createdAt, tables: backupTables.map(name => ({ name, rows: snapshot.tables[name]!.rows.length })),
    sessionsRevoked: true, bytes: Buffer.byteLength(JSON.stringify(snapshot)) };
}
export function snapshotDigest(snapshot: Snapshot) {
  return createHash("sha256").update(JSON.stringify(snapshot)).digest("hex");
}
export async function restoreSnapshot(pool: Pool, c: Config, snapshot: Snapshot, actor: string, reason: string) {
  // Caller must hold DatabaseGate exclusively. Never disable foreign keys or use
  // TRUNCATE/DDL: any invalid row rolls back the entire restore, including deletes.
  return transaction(pool, async db => {
    const summary = await inspectSnapshot(db, c, snapshot);
    for (const table of transientTables) await exec(db, `DELETE FROM \`${table}\``);
    for (const table of [...backupTables].reverse()) await exec(db, `DELETE FROM \`${table}\``);
    const shape = await schema(db);
    for (const table of backupTables) {
      const data = snapshot.tables[table]!;
      const jsonColumns = new Set(shape.columns.filter(c => c.t === table && c.dataType === "json").map(c => c.c));
      const sql = `INSERT INTO \`${table}\` (${data.columns.map(c => `\`${c}\``).join(",")}) VALUES (${data.columns.map(() => "?").join(",")})`;
      for (const row of data.rows) await exec(db, sql, row.map((value, i) => value !== null && jsonColumns.has(data.columns[i]!) ? JSON.stringify(value) : value));
    }
    await exec(db, "UPDATE users SET totp_pending=NULL,totp_pending_until=NULL,totp_last_step=GREATEST(totp_last_step,?) WHERE totp_secret IS NOT NULL", [Math.floor(Date.now()/30000)]);
    await exec(db, "UPDATE admin_users SET totp_last_step=GREATEST(totp_last_step,?)", [Math.floor(Date.now()/30000)]);
    const [restoredActor] = await rows(db, "SELECT id FROM admin_users WHERE id=?", [actor]);
    await exec(db, "INSERT INTO admin_audit(admin_id,action,reason,details) VALUES(?,'database.restore',?,?)",
      [restoredActor?.id ?? null, reason, JSON.stringify({ createdAt: snapshot.createdAt, tables: summary.tables })]);
    return summary;
  });
}

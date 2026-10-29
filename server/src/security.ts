import {
  createHmac,
  randomBytes,
  randomUUID,
  randomInt,
  createCipheriv,
  createDecipheriv,
  timingSafeEqual,
} from "node:crypto";
import argon2 from "argon2";
import type { Config } from "./config.js";
import { exec, rows, type DB } from "./db.js";
export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    public details?: Record<string, unknown>,
  ) {
    super(code);
  }
}
export const fail = (status: number, code: string): never => {
  throw new ApiError(status, code);
};
export const id = randomUUID;
export const token = () => randomBytes(32).toString("base64url");
export const otp = () => randomInt(0, 1_000_000).toString().padStart(6, "0");
export function hash(c: Config, purpose: string, value: string) {
  return createHmac("sha256", Buffer.from(c.TOKEN_PEPPER, "hex"))
    .update(purpose + "\0" + value)
    .digest("hex");
}
export function encrypt(c: Config, value: string) {
  const iv = randomBytes(12);
  const cipher = createCipheriv(
    "aes-256-gcm",
    Buffer.from(c.DATA_ENCRYPTION_KEY, "hex"),
    iv,
  );
  const bytes = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), bytes]).toString("base64");
}
export function decrypt(c: Config, value: string) {
  const bytes = Buffer.from(value, "base64");
  const decipher = createDecipheriv(
    "aes-256-gcm",
    Buffer.from(c.DATA_ENCRYPTION_KEY, "hex"),
    bytes.subarray(0, 12),
  );
  decipher.setAuthTag(bytes.subarray(12, 28));
  return Buffer.concat([
    decipher.update(bytes.subarray(28)),
    decipher.final(),
  ]).toString("utf8");
}
export const passwordHash = (password: string) =>
  argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost: 65536,
    timeCost: 3,
    parallelism: 1,
  });
export async function passwordMatches(
  encoded: string | null,
  password: string,
) {
  if (!encoded) return false;
  try {
    return await argon2.verify(encoded, password);
  } catch {
    return false;
  }
}
const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
export function newTotpSecret() {
  let bits = "";
  for (const n of randomBytes(20)) bits += n.toString(2).padStart(8, "0");
  return bits
    .match(/.{5}/g)!
    .map((x) => alphabet[parseInt(x, 2)])
    .join("");
}
function secretBytes(secret: string) {
  const bits = [...secret]
    .map((c) => alphabet.indexOf(c).toString(2).padStart(5, "0"))
    .join("");
  return Buffer.from(bits.match(/.{8}/g)!.map((x) => parseInt(x, 2)));
}
export function totpAt(secret: string, step: number) {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(step));
  const digest = createHmac("sha1", secretBytes(secret))
    .update(counter)
    .digest();
  const offset = digest[19]! & 15;
  return ((digest.readUInt32BE(offset) & 0x7fffffff) % 1_000_000)
    .toString()
    .padStart(6, "0");
}
export function matchingStep(
  secret: string,
  code: string,
  lastStep = -1,
  now = Date.now(),
) {
  if (!/^\d{6}$/.test(code)) return -1;
  const step = Math.floor(now / 30000);
  for (const n of [step, step - 1, step + 1]) {
    if (
      n > lastStep &&
      timingSafeEqual(Buffer.from(totpAt(secret, n)), Buffer.from(code))
    )
      return n;
  }
  return -1;
}
export async function secondFactor(db: DB, c: Config, user: any, code: string) {
  if (!user.totp_secret) return true;
  const step = matchingStep(
    decrypt(c, user.totp_secret),
    code,
    Number(user.totp_last_step),
  );
  if (step >= 0) {
    await exec(db, "UPDATE users SET totp_last_step=? WHERE id=?", [
      step,
      user.id,
    ]);
    return true;
  }
  const result = await exec(
    db,
    "DELETE FROM recovery_codes WHERE user_id=? AND code_hash=?",
    [user.id, hash(c, "recovery", code.toUpperCase().replace(/\s/g, ""))],
  );
  return result.affectedRows === 1;
}
export async function rateLimit(
  db: DB,
  c: Config,
  key: string,
  limit: number,
  seconds: number,
) {
  const bucket = hash(c, "rate", key);
  // Atomic counter shared by all API instances; no trust in client forwarding headers.
  await exec(
    db,
    `INSERT INTO rate_limits(bucket,hits,expires_at) VALUES(?,1,DATE_ADD(NOW(3), INTERVAL ? SECOND))
    ON DUPLICATE KEY UPDATE hits=IF(expires_at<NOW(3),1,hits+1),
    expires_at=IF(expires_at<NOW(3),DATE_ADD(NOW(3), INTERVAL ? SECOND),expires_at)`,
    [bucket, seconds, seconds],
  );
  const [row] = await rows(db, "SELECT hits FROM rate_limits WHERE bucket=?", [
    bucket,
  ]);
  if (row!.hits > limit) fail(429, "rate_limited");
}

import { createInterface } from "node:readline/promises";
import { Writable } from "node:stream";
import { configFromEnv } from "./config.js";
import { createPool, exec, rows, transaction } from "./db.js";
import { email, password } from "./schema.js";
import {
  id,
  encrypt,
  newTotpSecret,
  passwordHash,
  matchingStep,
} from "./security.js";
// Run locally over SSH / docker compose exec -it. No password in argv or env.
if (!process.stdin.isTTY || !process.stdout.isTTY)
  throw Error("Use an interactive terminal to provision an administrator.");
const address = email.parse(process.argv[2]);
const reset = process.argv[3] === "--reset";
const c = configFromEnv(),
  pool = createPool(c);
let muted = false;
const output = new Writable({
  write(chunk, _encoding, done) {
    if (!muted) process.stdout.write(chunk);
    done();
  },
});
const input = createInterface({ input: process.stdin, output, terminal: true });
try {
  const [existing] = await rows(
    pool,
    "SELECT id FROM admin_users WHERE email=?",
    [address],
  );
  if (!!existing !== reset)
    throw Error(
      existing
        ? "Administrator exists. Use --reset to replace credentials and revoke sessions."
        : "Administrator does not exist. Omit --reset to create it.",
    );
  process.stdout.write("New admin password (12–128 characters, hidden): ");
  muted = true;
  const raw = await input.question("");
  muted = false;
  process.stdout.write("\n");
  const pw = password.parse(raw);
  process.stdout.write("Repeat password (hidden): ");
  muted = true;
  const repeat = await input.question("");
  muted = false;
  process.stdout.write("\n");
  if (pw !== repeat) throw Error("Passwords do not match.");
  const secret = newTotpSecret();
  console.log(
    "Add this NEW secret to your authenticator (keep it private):",
    secret,
  );
  console.log(
    `otpauth://totp/BetterSeed%20Admin:${encodeURIComponent(address)}?secret=${secret}&issuer=BetterSeed%20Admin&algorithm=SHA1&digits=6&period=30`,
  );
  const code = await input.question(
    "Enter the 6-digit code to confirm setup: ",
  );
  const step = matchingStep(secret, code.trim());
  if (step < 0) throw Error("Invalid authenticator code. Nothing was changed.");
  const encoded = await passwordHash(pw);
  await transaction(pool, async (db) => {
    if (existing) {
      await exec(
        db,
        "UPDATE admin_users SET password_hash=?,totp_secret=?,totp_last_step=? WHERE id=?",
        [encoded, encrypt(c, secret), step, existing.id],
      );
      await exec(db, "DELETE FROM admin_sessions WHERE admin_id=?", [
        existing.id,
      ]);
    } else
      await exec(
        db,
        "INSERT INTO admin_users(id,email,password_hash,totp_secret,totp_last_step) VALUES(?,?,?,?,?)",
        [id(), address, encoded, encrypt(c, secret), step],
      );
  });
  console.log(
    "Administrator ready. Wait for the next authenticator code, then open",
    new URL("/admin", c.PUBLIC_BASE_URL).href,
  );
} finally {
  input.close();
  await pool.end();
}

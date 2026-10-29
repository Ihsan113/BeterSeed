import type { FastifyInstance, FastifyRequest } from "fastify";
import type { Pool } from "mysql2/promise";
import { z } from "zod";
import type { Config } from "./config.js";
import type { Providers } from "./providers.js";
import { exec, rows, transaction, type DB } from "./db.js";
import {
  ApiError,
  fail,
  id,
  token,
  otp,
  hash,
  encrypt,
  decrypt,
  passwordHash,
  passwordMatches,
  newTotpSecret,
  matchingStep,
  secondFactor,
  rateLimit,
} from "./security.js";
import { email, password, proof } from "./schema.js";
export function publicUser(u: any) {
  return {
    id: u.id,
    email: u.email,
    provider: u.provider,
    twoFactorEnabled: !!u.totp_secret,
    billingAccountId: u.billing_id,
  };
}
export class Auth {
  constructor(
    public pool: Pool,
    public c: Config,
    public p: Providers,
  ) {}
  async current(r: FastifyRequest) {
    const access = r.headers.authorization?.match(
      /^Bearer ([A-Za-z0-9_-]{43})$/,
    )?.[1];
    if (!access) return fail(401, "unauthorized");
    const [user] = await rows(
      this.pool,
      `SELECT u.*,s.id AS session_id FROM sessions s JOIN users u ON u.id=s.user_id
      WHERE s.access_hash=? AND s.access_until>NOW(3) AND u.verified=1 AND NOT EXISTS (SELECT 1 FROM account_controls ac WHERE ac.user_id=u.id AND ac.suspended=1)`,
      [hash(this.c, "access", access)],
    );
    return user ?? fail(401, "unauthorized");
  }
  async session(db: DB, user: any) {
    await this.ensureActive(db, user.id);
    const accessToken = token(),
      refreshToken = token();
    await exec(
      db,
      `INSERT INTO sessions(id,user_id,access_hash,refresh_hash,access_until,refresh_until)
      VALUES(?,?,?,?,DATE_ADD(NOW(3),INTERVAL 15 MINUTE),DATE_ADD(NOW(3),INTERVAL 30 DAY))`,
      [
        id(),
        user.id,
        hash(this.c, "access", accessToken),
        hash(this.c, "refresh", refreshToken),
      ],
    );
    return {
      user: publicUser(user),
      accessToken,
      refreshToken,
      expiresIn: 900,
    };
  }
  async ensureActive(db: DB, uid: string) {
    const [blocked] = await rows(
      db,
      "SELECT user_id FROM account_controls WHERE user_id=? AND suspended=1",
      [uid],
    );
    if (blocked) fail(403, "account_suspended");
  }
  async completeLogin(db: DB, user: any) {
    await this.ensureActive(db, user.id);
    if (!user.totp_secret) return this.session(db, user);
    const challengeId = id(),
      challengeToken = token();
    await exec(
      db,
      `INSERT INTO challenges(id,user_id,purpose,proof_hash,expires_at) VALUES(?,?,'login',?,DATE_ADD(NOW(3),INTERVAL 5 MINUTE))`,
      [challengeId, user.id, hash(this.c, "challenge", challengeToken)],
    );
    return { twoFactorRequired: true, challengeId, challengeToken };
  }
  async emailChallenge(db: DB, user: any, purpose: "verify" | "reset") {
    const challengeId = id(),
      code = otp();
    await exec(db, "DELETE FROM challenges WHERE user_id=? AND purpose=?", [
      user.id,
      purpose,
    ]);
    await exec(
      db,
      `INSERT INTO challenges(id,user_id,purpose,proof_hash,expires_at) VALUES(?,?,?,?,DATE_ADD(NOW(3),INTERVAL 10 MINUTE))`,
      [
        challengeId,
        user.id,
        purpose,
        hash(this.c, "email-code", challengeId + ":" + code),
      ],
    );
    const payload = {
      to: user.email,
      subject:
        purpose === "verify"
          ? "Verify your BetterSeed email"
          : "Reset your BetterSeed password",
      html: `<p>Your BetterSeed code is <strong>${code}</strong>.</p><p>It expires in 10 minutes. Never share this code. If you did not request it, ignore this message.</p>`,
    };
    await exec(
      db,
      `INSERT INTO email_outbox(id,user_id,payload_cipher,expires_at) VALUES(?,?,?,DATE_ADD(NOW(3),INTERVAL 10 MINUTE))`,
      [id(), user.id, encrypt(this.c, JSON.stringify(payload))],
    );
    return challengeId;
  }
  async consumeEmailChallenge(
    challengeId: string,
    code: string,
    purpose: "verify" | "reset",
    work: (db: DB, u: any) => Promise<any>,
  ) {
    // Failed attempts must commit, rather than roll back with an HTTP error.
    const result = await transaction(this.pool, async (db) => {
      const [ch] = await rows(
        db,
        "SELECT * FROM challenges WHERE id=? AND purpose=? FOR UPDATE",
        [challengeId, purpose],
      );
      if (
        !ch ||
        ch.attempts >= 5 ||
        new Date(ch.expires_at).getTime() <= Date.now()
      )
        return null;
      await exec(db, "UPDATE challenges SET attempts=attempts+1 WHERE id=?", [
        challengeId,
      ]);
      if (
        ch.proof_hash !== hash(this.c, "email-code", challengeId + ":" + code)
      )
        return null;
      const [u] = await rows(db, "SELECT * FROM users WHERE id=? FOR UPDATE", [
        ch.user_id,
      ]);
      if (!u || u.provider !== "email") return null;
      const outcome = await work(db, u);
      if (outcome === null) return null;
      await exec(db, "DELETE FROM challenges WHERE id=?", [challengeId]);
      return outcome;
    });
    if (result === null) return fail(400, "invalid_or_expired_code");
    return result;
  }
  async reauthenticate(db: DB, u: any, input: z.infer<typeof proof>) {
    let valid = false;
    if (u.provider === "email")
      valid = await passwordMatches(u.password_hash, input.password ?? "");
    else if (input.idToken)
      valid = (await this.p.googleIdentity(input.idToken)).sub === u.google_sub;
    if (!valid) return false;
    return secondFactor(db, this.c, u, input.factor);
  }
}
export function authRoutes(app: FastifyInstance, a: Auth) {
  const { pool, c, p } = a;
  async function emailLimit(address: string) {
    await rateLimit(pool, c, "email:" + address, 5, 900);
  }
  app.post("/v1/auth/register", async (r) => {
    const b = z
      .object({
        email,
        password,
        legalVersion: z.literal(c.LEGAL_VERSION),
        acceptTerms: z.literal(true),
      })
      .strict()
      .parse(r.body);
    await emailLimit(b.email);
    const pw = await passwordHash(b.password);
    const challengeId = await transaction(pool, async (db) => {
      const [existing] = await rows(
        db,
        "SELECT id FROM users WHERE email=? FOR UPDATE",
        [b.email],
      );
      if (existing) return id(); // Same response for registered addresses.
      const uid = id();
      await exec(
        db,
        `INSERT INTO users(id,email,provider,password_hash,billing_id,legal_version) VALUES(?,?,'email',?,?,?)`,
        [
          uid,
          b.email,
          pw,
          token().slice(0, 43) + token().slice(0, 21),
          b.legalVersion,
        ],
      );
      return a.emailChallenge(db, { id: uid, email: b.email }, "verify");
    });
    return {
      challengeId,
      message: "If eligible, a verification code will arrive shortly.",
    };
  });
  app.post("/v1/auth/resend-verification", async (r) => {
    const b = z.object({ email }).strict().parse(r.body);
    await emailLimit(b.email);
    const challengeId = await transaction(pool, async (db) => {
      const [u] = await rows(
        db,
        "SELECT * FROM users WHERE email=? AND provider='email' AND verified=0 FOR UPDATE",
        [b.email],
      );
      return u ? a.emailChallenge(db, u, "verify") : id();
    });
    return { challengeId };
  });
  app.post("/v1/auth/verify-email", async (r) => {
    const b = z
      .object({
        challengeId: z.uuid(),
        code: z.string().regex(/^\d{6}$/),
        acceptTerms: z.boolean().optional(),
        legalVersion: z.string().optional(),
      })
      .strict()
      .parse(r.body);
    return a.consumeEmailChallenge(
      b.challengeId,
      b.code,
      "verify",
      async (db, u) => {
        if (u.verified) return null;
        if (u.legal_version === "pending") {
          if (b.acceptTerms !== true || b.legalVersion !== c.LEGAL_VERSION)
            return fail(400, "terms_required");
          await exec(db, "UPDATE users SET legal_version=? WHERE id=?", [
            c.LEGAL_VERSION,
            u.id,
          ]);
        }
        await exec(db, "UPDATE users SET verified=1 WHERE id=?", [u.id]);
        await exec(db, "DELETE FROM pending_email_changes WHERE user_id=?", [
          u.id,
        ]);
        return a.completeLogin(db, u);
      },
    );
  });
  // Constant-cost password verification for unknown/email-vs-Google addresses.
  const dummyHash = passwordHash(token());
  app.post("/v1/auth/login", async (r) => {
    const b = z
      .object({ email, password: z.string().max(128) })
      .strict()
      .parse(r.body);
    await rateLimit(pool, c, "login:" + b.email, 10, 900);
    const [u] = await rows(pool, "SELECT * FROM users WHERE email=?", [
      b.email,
    ]);
    const valid = await passwordMatches(
      u?.password_hash ?? (await dummyHash),
      b.password,
    );
    if (!valid || !u || !u.verified || u.provider !== "email")
      return fail(401, "invalid_credentials");
    return transaction(pool, async (db) => {
      const [locked] = await rows(
        db,
        "SELECT * FROM users WHERE id=? FOR UPDATE",
        [u.id],
      );
      if (!locked || locked.password_hash !== u.password_hash)
        return fail(401, "invalid_credentials");
      return a.completeLogin(db, locked);
    });
  });
  app.post("/v1/auth/google", async (r) => {
    const b = z
      .object({
        idToken: z.string().min(1).max(10000),
        legalVersion: z.literal(c.LEGAL_VERSION),
        acceptTerms: z.literal(true),
      })
      .strict()
      .parse(r.body);
    const identity = await p.googleIdentity(b.idToken);
    await rateLimit(pool, c, "google-login:" + identity.sub, 10, 900);
    return transaction(pool, async (db) => {
      let [u] = await rows(
        db,
        "SELECT * FROM users WHERE google_sub=? FOR UPDATE",
        [identity.sub],
      );
      if (!u) {
        const [sameEmail] = await rows(
          db,
          "SELECT id FROM users WHERE email=? FOR UPDATE",
          [identity.email],
        );
        if (sameEmail) return fail(409, "use_original_sign_in");
        const uid = id();
        await exec(
          db,
          `INSERT INTO users(id,email,provider,google_sub,verified,billing_id,legal_version) VALUES(?,?,'google',?,1,?,?)`,
          [
            uid,
            identity.email,
            identity.sub,
            token().slice(0, 43) + token().slice(0, 21),
            b.legalVersion,
          ],
        );
        [u] = await rows(db, "SELECT * FROM users WHERE id=?", [uid]);
      }
      return a.completeLogin(db, u);
    });
  });
  app.post("/v1/auth/two-factor", async (r) => {
    const b = z
      .object({
        challengeId: z.uuid(),
        challengeToken: z.string().max(100),
        factor: z.string().max(64),
      })
      .strict()
      .parse(r.body);
    const result = await transaction(pool, async (db) => {
      const [ch] = await rows(
        db,
        "SELECT * FROM challenges WHERE id=? AND purpose='login' FOR UPDATE",
        [b.challengeId],
      );
      if (
        !ch ||
        ch.attempts >= 5 ||
        new Date(ch.expires_at).getTime() <= Date.now()
      )
        return null;
      await exec(db, "UPDATE challenges SET attempts=attempts+1 WHERE id=?", [
        ch.id,
      ]);
      if (ch.proof_hash !== hash(c, "challenge", b.challengeToken)) return null;
      const [u] = await rows(db, "SELECT * FROM users WHERE id=? FOR UPDATE", [
        ch.user_id,
      ]);
      if (!u || !(await secondFactor(db, c, u, b.factor))) return null;
      await exec(db, "DELETE FROM challenges WHERE id=?", [ch.id]);
      return a.session(db, u);
    });
    return result ?? fail(401, "invalid_factor");
  });
  app.post("/v1/auth/forgot-password", async (r) => {
    const b = z.object({ email }).strict().parse(r.body);
    await emailLimit(b.email);
    const challengeId = await transaction(pool, async (db) => {
      const [u] = await rows(
        db,
        "SELECT * FROM users WHERE email=? AND provider='email' AND verified=1 FOR UPDATE",
        [b.email],
      );
      return u ? a.emailChallenge(db, u, "reset") : id();
    });
    return {
      challengeId,
      message: "If eligible, a reset code will arrive shortly.",
    };
  });
  app.post("/v1/auth/reset-password", async (r) => {
    const b = z
      .object({
        challengeId: z.uuid(),
        code: z.string().regex(/^\d{6}$/),
        password,
        factor: z.string().max(64).default(""),
      })
      .strict()
      .parse(r.body);
    const pw = await passwordHash(b.password);
    return a.consumeEmailChallenge(
      b.challengeId,
      b.code,
      "reset",
      async (db, u) => {
        if (!u.verified || !(await secondFactor(db, c, u, b.factor)))
          return null;
        await exec(db, "UPDATE users SET password_hash=? WHERE id=?", [
          pw,
          u.id,
        ]);
        await exec(db, "DELETE FROM sessions WHERE user_id=?", [u.id]);
        await exec(db, "DELETE FROM challenges WHERE user_id=?", [u.id]);
        return { ok: true };
      },
    );
  });
  app.post("/v1/auth/refresh", async (r) => {
    const b = z
      .object({
        refreshToken: z.string().min(40).max(100),
        requestId: z.uuid().optional(),
      })
      .strict()
      .parse(r.body);
    const h = hash(c, "refresh", b.refreshToken);
    const result = await transaction(pool, async (db) => {
      const [s] = await rows(
        db,
        "SELECT * FROM sessions WHERE refresh_hash=? FOR UPDATE",
        [h],
      );
      if (!s) {
        if (b.requestId) {
          const [receipt] = await rows(
            db,
            `SELECT rr.response_cipher FROM refresh_receipts rr
            JOIN sessions s ON s.id=rr.session_id WHERE rr.token_hash=? AND rr.request_hash=?
            AND rr.expires_at>NOW(3) AND s.refresh_until>NOW(3)`,
            [h, hash(c, "refresh-request", b.requestId)],
          );
          if (receipt) return JSON.parse(decrypt(c, receipt.response_cipher));
        }
        const [used] = await rows(
          db,
          "SELECT user_id FROM used_refresh WHERE token_hash=? AND expires_at>NOW(3)",
          [h],
        );
        if (used)
          await exec(db, "DELETE FROM sessions WHERE user_id=?", [
            used.user_id,
          ]);
        return null;
      }
      if (new Date(s.refresh_until).getTime() <= Date.now()) return null;
      const [u] = await rows(db, "SELECT * FROM users WHERE id=? FOR UPDATE", [
        s.user_id,
      ]);
      await exec(
        db,
        "INSERT INTO used_refresh(token_hash,user_id,expires_at) VALUES(?,?,?)",
        [h, s.user_id, s.refresh_until],
      );
      await exec(db, "DELETE FROM sessions WHERE id=?", [s.id]);
      const next = await a.session(db, u);
      if (b.requestId) {
        const [created] = await rows(
          db,
          "SELECT id FROM sessions WHERE access_hash=?",
          [hash(c, "access", next.accessToken)],
        );
        await exec(
          db,
          `INSERT INTO refresh_receipts(token_hash,request_hash,session_id,response_cipher,expires_at)
          VALUES(?,?,?,?,DATE_ADD(NOW(3),INTERVAL 30 DAY))`,
          [
            h,
            hash(c, "refresh-request", b.requestId),
            created!.id,
            encrypt(c, JSON.stringify(next)),
          ],
        );
      }
      return next;
    });
    return result ?? fail(401, "session_expired");
  });
  app.get("/v1/account", async (r) => ({
    user: publicUser(await a.current(r)),
  }));
  app.post("/v1/auth/logout", async (r) => {
    const u = await a.current(r);
    await exec(pool, "DELETE FROM sessions WHERE id=?", [u.session_id]);
    return { ok: true };
  });
  app.post("/v1/account/password", async (r) => {
    const u = await a.current(r);
    const b = proof.extend({ newPassword: password }).strict().parse(r.body);
    if (u.provider !== "email") return fail(400, "google_managed_password");
    await rateLimit(pool, c, "sensitive:" + u.id, 10, 900);
    const pw = await passwordHash(b.newPassword);
    return transaction(pool, async (db) => {
      const [locked] = await rows(
        db,
        "SELECT * FROM users WHERE id=? FOR UPDATE",
        [u.id],
      );
      if (!locked || !(await a.reauthenticate(db, locked, b)))
        return fail(401, "reauthentication_failed");
      await exec(db, "UPDATE users SET password_hash=? WHERE id=?", [pw, u.id]);
      await exec(db, "DELETE FROM sessions WHERE user_id=?", [u.id]);
      await exec(db, "DELETE FROM challenges WHERE user_id=?", [u.id]);
      return { ok: true };
    });
  });
  app.post("/v1/account/two-factor/setup", async (r) => {
    const u = await a.current(r);
    const b = proof.strict().parse(r.body);
    await rateLimit(pool, c, "sensitive:" + u.id, 10, 900);
    return transaction(pool, async (db) => {
      const [locked] = await rows(
        db,
        "SELECT * FROM users WHERE id=? FOR UPDATE",
        [u.id],
      );
      if (!locked || !(await a.reauthenticate(db, locked, b)))
        return fail(401, "reauthentication_failed");
      if (locked.totp_secret) return fail(409, "two_factor_already_enabled");
      const secret = newTotpSecret();
      await exec(
        db,
        "UPDATE users SET totp_pending=?,totp_pending_until=DATE_ADD(NOW(3),INTERVAL 10 MINUTE) WHERE id=?",
        [encrypt(c, secret), u.id],
      );
      return {
        secret,
        uri: `otpauth://totp/BetterSeed:${encodeURIComponent(u.email)}?secret=${secret}&issuer=BetterSeed&algorithm=SHA1&digits=6&period=30`,
      };
    });
  });
  app.post("/v1/account/two-factor/confirm", async (r) => {
    const u = await a.current(r);
    const b = z
      .object({ factor: z.string().regex(/^\d{6}$/) })
      .strict()
      .parse(r.body);
    await rateLimit(pool, c, "sensitive:" + u.id, 10, 900);
    return transaction(pool, async (db) => {
      const [locked] = await rows(
        db,
        "SELECT * FROM users WHERE id=? FOR UPDATE",
        [u.id],
      );
      if (
        !locked?.totp_pending ||
        new Date(locked.totp_pending_until).getTime() <= Date.now()
      )
        return fail(400, "setup_expired");
      const step = matchingStep(decrypt(c, locked.totp_pending), b.factor);
      if (step < 0) return fail(400, "invalid_factor");
      await exec(
        db,
        "UPDATE users SET totp_secret=totp_pending,totp_pending=NULL,totp_pending_until=NULL,totp_last_step=? WHERE id=?",
        [step, u.id],
      );
      const recoveryCodes = Array.from({ length: 10 }, () =>
        token().slice(0, 16).toUpperCase(),
      );
      await exec(db, "DELETE FROM recovery_codes WHERE user_id=?", [u.id]);
      for (const code of recoveryCodes)
        await exec(
          db,
          "INSERT INTO recovery_codes(user_id,code_hash) VALUES(?,?)",
          [u.id, hash(c, "recovery", code)],
        );
      await exec(db, "DELETE FROM sessions WHERE user_id=? AND id<>?", [
        u.id,
        u.session_id,
      ]);
      await exec(db, "DELETE FROM challenges WHERE user_id=?", [u.id]);
      return { recoveryCodes };
    });
  });
  app.post("/v1/account/two-factor/disable", async (r) => {
    const u = await a.current(r);
    const b = proof.strict().parse(r.body);
    await rateLimit(pool, c, "sensitive:" + u.id, 10, 900);
    return transaction(pool, async (db) => {
      const [locked] = await rows(
        db,
        "SELECT * FROM users WHERE id=? FOR UPDATE",
        [u.id],
      );
      if (!locked || !(await a.reauthenticate(db, locked, b)))
        return fail(401, "reauthentication_failed");
      await exec(
        db,
        "UPDATE users SET totp_secret=NULL,totp_pending=NULL,totp_pending_until=NULL,totp_last_step=-1 WHERE id=?",
        [u.id],
      );
      await exec(db, "DELETE FROM recovery_codes WHERE user_id=?", [u.id]);
      await exec(db, "DELETE FROM sessions WHERE user_id=? AND id<>?", [
        u.id,
        u.session_id,
      ]);
      await exec(db, "DELETE FROM challenges WHERE user_id=?", [u.id]);
      return { ok: true };
    });
  });
  app.delete("/v1/account", async (r) => {
    const u = await a.current(r);
    const b = proof
      .extend({ confirmation: z.literal("DELETE") })
      .strict()
      .parse(r.body);
    await rateLimit(pool, c, "sensitive:" + u.id, 10, 900);
    return transaction(pool, async (db) => {
      const [locked] = await rows(
        db,
        "SELECT * FROM users WHERE id=? FOR UPDATE",
        [u.id],
      );
      if (!locked || !(await a.reauthenticate(db, locked, b)))
        return fail(401, "reauthentication_failed");
      // Keep only anonymous anti-replay fingerprints and financial deltas.
      await exec(db, "UPDATE purchases SET token_cipher=NULL WHERE user_id=?", [
        u.id,
      ]);
      await exec(
        db,
        "UPDATE admin_audit SET target_id=NULL,reason='Account deleted',details=NULL WHERE target_id=?",
        [u.id],
      );
      await exec(db, "DELETE FROM users WHERE id=?", [u.id]);
      return { ok: true };
    });
  });
}

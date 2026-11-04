import { test, before, after, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../src/app.js";
import { configFromEnv } from "../src/config.js";
import { createPool, exec, rows } from "../src/db.js";
import { migrate } from "../src/migrate.js";
import { deliverMail, cleanup } from "../src/maintenance.js";
import {
  decrypt,
  encrypt,
  id,
  passwordHash,
  hash,
  totpAt,
  matchingStep,
  newTotpSecret,
} from "../src/security.js";
import type { Providers, PlayPurchase } from "../src/providers.js";
const c = configFromEnv({
  ...process.env,
  NODE_ENV: "test",
  MYSQL_HOST: process.env.TEST_MYSQL_HOST ?? "127.0.0.1",
  MYSQL_PORT: process.env.TEST_MYSQL_PORT ?? "33067",
  MYSQL_USER: "root",
  MYSQL_PASSWORD: "betterseed_local_test_only",
  MYSQL_DATABASE: "betterseed_test",
  TOKEN_PEPPER: "11".repeat(32),
  DATA_ENCRYPTION_KEY: "22".repeat(32),
  GOOGLE_APPLICATION_CREDENTIALS: "test-only",
  GOOGLE_WEB_CLIENT_ID: "test-client",
  LEGAL_OPERATOR_NAME: "Test operator",
  SUPPORT_EMAIL: "support@example.com",
});
const pool = createPool(c);
const mails: { to: string; html: string }[] = [];
const purchases = new Map<string, PlayPurchase>();
let consumeFails = false,
  consumeCalls = 0,
  googleCalls = 0,
  voided: string[] = [];
const p: Providers = {
  async googleIdentity(t) {
    googleCalls++;
    if (t !== "valid-google") throw Error("invalid signature");
    return { sub: "google-user", email: "google@example.com" };
  },
  async playPurchase(product, t) {
    const found = purchases.get(t);
    if (!found) throw Error("not found");
    return { ...found };
  },
  async consume(product, t) {
    consumeCalls++;
    if (consumeFails) throw Error("timeout");
    purchases.get(t)!.consumptionState = 1;
  },
  async voided() {
    return { tokens: voided };
  },
  async verifyNotification(t) {
    if (t !== "valid-pubsub") throw Error("bad push identity");
  },
  async sendMail(m) {
    mails.push(m);
  },
};
let system: Awaited<ReturnType<typeof buildApp>>;
before(async () => {
  await migrate(pool);
  system = await buildApp(c, pool, p);
  await system.app.ready();
});
after(async () => {
  await system.app.close();
  await pool.end();
});
beforeEach(async () => {
  await exec(pool, "DELETE FROM admin_users");
  await exec(pool, "DELETE FROM admin_audit");
  await exec(pool, "DELETE FROM users");
  for (const table of ["purchases", "coin_ledger", "rate_limits"])
    await exec(pool, `DELETE FROM ${table}`);
  // Reset catalog only in the isolated test database, never during migrations.
  await exec(pool, "DELETE FROM pack_acquisitions");
  await exec(pool, "DELETE FROM garden_packs");
  await migrate(pool);
  mails.length = 0;
  purchases.clear();
  consumeFails = false;
  consumeCalls = 0;
  voided = [];
});
async function request(method: any, url: string, body?: any, access?: string) {
  const response = await system.app.inject({
    method,
    url,
    ...(body ? { payload: body } : {}),
    ...(access ? { headers: { authorization: "Bearer " + access } } : {}),
  });
  return { status: response.statusCode, body: response.json() };
}
const pw = "long-password-for-test";
async function account(email = "a@example.com") {
  const r = await request("POST", "/v1/auth/register", {
    email,
    password: pw,
    legalVersion: c.LEGAL_VERSION,
    acceptTerms: true,
  });
  assert.equal(r.status, 200);
  await deliverMail(system.auth);
  const code = mails.at(-1)!.html.match(/<strong>(\d{6})/)![1];
  const verified = await request("POST", "/v1/auth/verify-email", {
    challengeId: r.body.challengeId,
    code,
  });
  assert.equal(verified.status, 200);
  return verified.body;
}
const garden = {
  version: 1,
  habits: [
    {
      id: "drink",
      title: "Drink water",
      completed: true,
      iconKey: "water",
      reminderEnabled: false,
      reminderHour: 20,
      reminderMinute: 0,
    },
  ],
  progress: {
    version: 3,
    earned: 1,
    spent: 0,
    xp: 0,
    credited: { "2026-10-27": ["drink"] },
  },
  day: "2026-10-27",
  cosmetics: {
    treeSkinId: "default",
    backgroundId: "default",
    butterflyId: "default",
    wateringCanId: "default",
    fireflyId: "default",
  },
  treePlacements: { default: { dx: 0.1, dy: 0, scale: 1 } },
  preferences: {
    music: true,
    effects: true,
    motion: false,
    motionOverride: false,
  },
};
const mutation = (n: number, snapshot = garden, baseRevision = 0) => ({
  mutationId: `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`,
  baseRevision,
  snapshot,
});
test("email registration requires verification; OTP is single use and secrets are protected", async () => {
  const r = await request("POST", "/v1/auth/register", {
    email: "a@example.com",
    password: pw,
    legalVersion: c.LEGAL_VERSION,
    acceptTerms: true,
  });
  assert.equal(
    (
      await request("POST", "/v1/auth/login", {
        email: "a@example.com",
        password: pw,
      })
    ).status,
    401,
  );
  const [u] = await rows(pool, "SELECT * FROM users");
  assert.match(u!.password_hash, /^\$argon2id\$/);
  const [out] = await rows(pool, "SELECT * FROM email_outbox");
  assert.ok(!out!.payload_cipher.includes("example.com"));
  await deliverMail(system.auth);
  const code = mails[0]!.html.match(/<strong>(\d{6})/)![1];
  const first = await request("POST", "/v1/auth/verify-email", {
    challengeId: r.body.challengeId,
    code,
  });
  assert.equal(first.status, 200);
  assert.equal(
    (
      await request("POST", "/v1/auth/verify-email", {
        challengeId: r.body.challengeId,
        code,
      })
    ).status,
    400,
  );
  assert.equal(
    (await request("GET", "/v1/account", undefined, first.body.accessToken))
      .status,
    200,
  );
});
test("verification request reveals status only after password proof and issues a single-use OTP", async () => {
  const email = "pending@example.com";
  await request("POST", "/v1/auth/register", {
    email, password: pw, legalVersion: c.LEGAL_VERSION, acceptTerms: true,
  });
  const wrong = await request("POST", "/v1/auth/verification/start", { email, password: "wrong" });
  const unknown = await request("POST", "/v1/auth/verification/start", { email: "unknown@example.com", password: pw });
  assert.deepEqual(wrong, unknown);
  assert.equal(wrong.status, 401);
  assert.equal(wrong.body.error, "invalid_credentials");
  assert.equal((await rows(pool, "SELECT id FROM email_outbox")).length, 1);
  const login = await request("POST", "/v1/auth/login", { email, password: pw });
  assert.equal(login.status, 401);
  assert.equal(login.body.error, "email_not_verified");
  const loginWrong = await request("POST", "/v1/auth/login", { email, password: "wrong" });
  assert.equal(loginWrong.body.error, "invalid_credentials");
  const started = await request("POST", "/v1/auth/verification/start", { email, password: pw });
  assert.equal(started.status, 200);
  assert.equal(started.body.status, "verification_sent");
  assert.equal((await rows(pool, "SELECT id FROM challenges WHERE purpose='verify'")).length, 1);
  await deliverMail(system.auth);
  const code = mails.at(-1)!.html.match(/<strong>(\d{6})/)![1];
  const proof = { challengeId: started.body.challengeId, code, acceptTerms: true, legalVersion: c.LEGAL_VERSION };
  assert.equal((await request("POST", "/v1/auth/verify-email", proof)).status, 200);
  assert.equal((await request("POST", "/v1/auth/verify-email", proof)).status, 400);
});

test("verified registration status requires correct credentials and never sends another verification email", async () => {
  await account();
  const start = await request("POST", "/v1/auth/verification/start", { email: "a@example.com", password: pw });
  assert.deepEqual(start.body, { status: "already_verified" });
  const duplicate = await request("POST", "/v1/auth/register", {
    email: "a@example.com", password: pw, legalVersion: c.LEGAL_VERSION, acceptTerms: true,
  });
  assert.equal(duplicate.body.status, "already_verified");
  const wrong = await request("POST", "/v1/auth/register", {
    email: "a@example.com", password: "another-long-password", legalVersion: c.LEGAL_VERSION, acceptTerms: true,
  });
  assert.equal(wrong.status, 200);
  assert.equal(wrong.body.status, undefined);
  assert.equal(typeof wrong.body.challengeId, "string");
  await deliverMail(system.auth);
  assert.equal(mails.length, 1);
  assert.equal((await request("POST", "/v1/auth/login", { email: "a@example.com", password: pw })).status, 200);
});

test("verification requests share the per-email rate limit and cannot bypass suspension", async () => {
  const user = await account();
  await exec(pool, "INSERT INTO account_controls(user_id,suspended) VALUES(?,1)", [user.user.id]);
  assert.equal((await request("POST", "/v1/auth/verification/start", { email: "a@example.com", password: pw })).status, 403);
  for (let i = 0; i < 5; i++) {
    const r = await request("POST", "/v1/auth/verification/start", { email: "absent@example.com", password: pw });
    assert.equal(r.status, 401);
  }
  assert.equal((await request("POST", "/v1/auth/verification/start", { email: "absent@example.com", password: pw })).status, 429);
});

test("verification limits attempts even if attacker later knows correct code", async () => {
  const r = await request("POST", "/v1/auth/register", {
    email: "a@example.com",
    password: pw,
    legalVersion: c.LEGAL_VERSION,
    acceptTerms: true,
  });
  await deliverMail(system.auth);
  const code = mails[0]!.html.match(/<strong>(\d{6})/)![1];
  for (let i = 0; i < 5; i++)
    assert.equal(
      (
        await request("POST", "/v1/auth/verify-email", {
          challengeId: r.body.challengeId,
          code: code === "000000" ? "000001" : "000000",
        })
      ).status,
      400,
    );
  assert.equal(
    (
      await request("POST", "/v1/auth/verify-email", {
        challengeId: r.body.challengeId,
        code,
      })
    ).status,
    400,
  );
});
test("refresh rotates, replay revokes sessions; reset invalidates login", async () => {
  const s = await account();
  const next = await request("POST", "/v1/auth/refresh", {
    refreshToken: s.refreshToken,
  });
  assert.equal(next.status, 200);
  assert.equal(
    (await request("GET", "/v1/account", undefined, s.accessToken)).status,
    401,
  );
  assert.equal(
    (
      await request("POST", "/v1/auth/refresh", {
        refreshToken: s.refreshToken,
      })
    ).status,
    401,
  );
  assert.equal(
    (await request("GET", "/v1/account", undefined, next.body.accessToken))
      .status,
    401,
  );
  const login = await request("POST", "/v1/auth/login", {
    email: s.user.email,
    password: pw,
  });
  const reset = await request("POST", "/v1/auth/forgot-password", {
    email: s.user.email,
  });
  await deliverMail(system.auth);
  const code = mails.at(-1)!.html.match(/<strong>(\d{6})/)![1];
  assert.equal(
    (
      await request("POST", "/v1/auth/reset-password", {
        challengeId: reset.body.challengeId,
        code,
        password: "new-password-12345",
      })
    ).status,
    200,
  );
  assert.equal(
    (await request("GET", "/v1/account", undefined, login.body.accessToken))
      .status,
    401,
  );
  assert.equal(
    (
      await request("POST", "/v1/auth/login", {
        email: s.user.email,
        password: pw,
      })
    ).status,
    401,
  );
});
test("Google uses server identity, never auto-links email, hides password API", async () => {
  const session = await request("POST", "/v1/auth/google", {
    idToken: "valid-google",
    legalVersion: c.LEGAL_VERSION,
    acceptTerms: true,
  });
  assert.equal(session.status, 200);
  assert.equal(session.body.user.provider, "google");
  assert.equal(
    (
      await request(
        "POST",
        "/v1/account/password",
        { password: pw, newPassword: "something-very-long" },
        session.body.accessToken,
      )
    ).status,
    400,
  );
  const reset = await request("POST", "/v1/auth/forgot-password", {
    email: "google@example.com",
  });
  assert.equal(reset.status, 200);
  await deliverMail(system.auth);
  assert.equal(mails.length, 0);
  assert.ok(googleCalls > 0);
});
test("TOTP setup, replay prevention and one-use recovery; email reset cannot bypass 2FA", async () => {
  const s = await account();
  const setup = await request(
    "POST",
    "/v1/account/two-factor/setup",
    { password: pw },
    s.accessToken,
  );
  assert.equal(setup.status, 200);
  const code = totpAt(setup.body.secret, Math.floor(Date.now() / 30000));
  const confirmed = await request(
    "POST",
    "/v1/account/two-factor/confirm",
    { factor: code },
    s.accessToken,
  );
  assert.equal(confirmed.status, 200);
  assert.equal(confirmed.body.recoveryCodes.length, 10);
  const login = await request("POST", "/v1/auth/login", {
    email: s.user.email,
    password: pw,
  });
  assert.equal(login.body.twoFactorRequired, true);
  const payload = {
    challengeId: login.body.challengeId,
    challengeToken: login.body.challengeToken,
  };
  assert.equal(
    (await request("POST", "/v1/auth/two-factor", { ...payload, factor: code }))
      .status,
    401,
  );
  const recovery = confirmed.body.recoveryCodes[0];
  assert.equal(
    (
      await request("POST", "/v1/auth/two-factor", {
        ...payload,
        factor: recovery,
      })
    ).status,
    200,
  );
  const again = await request("POST", "/v1/auth/login", {
    email: s.user.email,
    password: pw,
  });
  assert.equal(
    (
      await request("POST", "/v1/auth/two-factor", {
        challengeId: again.body.challengeId,
        challengeToken: again.body.challengeToken,
        factor: recovery,
      })
    ).status,
    401,
  );
  const reset = await request("POST", "/v1/auth/forgot-password", {
    email: s.user.email,
  });
  await deliverMail(system.auth);
  const emailCode = mails.at(-1)!.html.match(/<strong>(\d{6})/)![1];
  assert.equal(
    (
      await request("POST", "/v1/auth/reset-password", {
        challengeId: reset.body.challengeId,
        code: emailCode,
        password: "new-password-12345",
      })
    ).status,
    400,
  );
});
test("sync detects concurrent revisions, preserves both and retries are idempotent", async () => {
  const s = await account();
  const first = await request("PUT", "/v1/garden", mutation(1), s.accessToken);
  assert.equal(first.status, 200);
  assert.equal(first.body.revision, 1);
  const replay = await request("PUT", "/v1/garden", mutation(1), s.accessToken);
  assert.equal(replay.body.duplicate, true);
  const parallel = await Promise.all([
    request("PUT", "/v1/garden", mutation(2, garden, 1), s.accessToken),
    request("PUT", "/v1/garden", mutation(3, garden, 1), s.accessToken),
  ]);
  assert.deepEqual(parallel.map((x) => x.status).sort(), [200, 409]);
  assert.equal(
    parallel.find((x) => x.status === 409)!.body.details.revision,
    2,
  );
  const hijack = await request(
    "PUT",
    "/v1/garden",
    mutation(1, { ...garden, day: "2026-10-28" }),
    s.accessToken,
  );
  assert.equal(hijack.body.error, "mutation_reused");
  const other = await account("b@example.com");
  assert.equal(
    (await request("GET", "/v1/garden", undefined, other.accessToken)).body
      .snapshot,
    null,
  );
});
test("garden payload cannot write coin balances or entitlements; invalid geometry rejected", async () => {
  const s = await account();
  assert.equal(
    (
      await request(
        "PUT",
        "/v1/garden",
        mutation(1, { ...garden, coins: 50000 } as any),
        s.accessToken,
      )
    ).status,
    400,
  );
  assert.equal(
    (
      await request(
        "PUT",
        "/v1/garden",
        mutation(2, {
          ...garden,
          treePlacements: { default: { scale: 999, dx: 0, dy: 0 } },
        }),
        s.accessToken,
      )
    ).status,
    400,
  );
  assert.equal(
    (await request("GET", "/v1/wallet", undefined, s.accessToken)).body.balance,
    0,
  );
});
test("billing verifies purchase state and binding; concurrent delivery only credits once", async () => {
  const s = await account();
  const purchaseToken = "purchase-1";
  purchases.set(purchaseToken, {
    purchaseState: 2,
    consumptionState: 0,
    obfuscatedExternalAccountId: s.user.billingAccountId,
  });
  const body = { productId: "betterseed_coin_300", purchaseToken };
  assert.equal(
    (await request("POST", "/v1/billing/verify", body, s.accessToken)).body
      .error,
    "purchase_pending",
  );
  purchases.get(purchaseToken)!.purchaseState = 0;
  purchases.get(purchaseToken)!.obfuscatedExternalAccountId = "someone-else";
  assert.equal(
    (await request("POST", "/v1/billing/verify", body, s.accessToken)).status,
    403,
  );
  purchases.get(purchaseToken)!.obfuscatedExternalAccountId =
    s.user.billingAccountId;
  const results = await Promise.all([
    request("POST", "/v1/billing/verify", body, s.accessToken),
    request("POST", "/v1/billing/verify", body, s.accessToken),
  ]);
  assert.ok(results.every((x) => x.status === 200));
  assert.equal(
    (await request("GET", "/v1/wallet", undefined, s.accessToken)).body.balance,
    300,
  );
  assert.equal((await rows(pool, "SELECT * FROM coin_ledger")).length, 1);
  assert.ok(consumeCalls >= 1);
  const other = await account("b@example.com");
  assert.equal(
    (await request("POST", "/v1/billing/verify", body, other.accessToken))
      .status,
    409,
  );
});
test("durable credit precedes consume and worker repairs failures; unlock and refunds are idempotent", async () => {
  const s = await account();
  purchases.set("repair", {
    purchaseState: 0,
    consumptionState: 0,
    obfuscatedExternalAccountId: s.user.billingAccountId,
  });
  consumeFails = true;
  const grant = await request(
    "POST",
    "/v1/billing/verify",
    { productId: "betterseed_coin_300", purchaseToken: "repair" },
    s.accessToken,
  );
  assert.equal(grant.body.balance, 300);
  assert.equal(grant.body.consumed, false);
  consumeFails = false;
  await system.billing.reconcile();
  assert.equal(
    (await rows(pool, "SELECT state FROM purchases"))[0]!.state,
    "consumed",
  );
  const unlocks = await Promise.all([
    request("POST", "/v1/shop/unlock", { packId: "sakura" }, s.accessToken),
    request("POST", "/v1/shop/unlock", { packId: "sakura" }, s.accessToken),
  ]);
  assert.ok(unlocks.every((x) => x.status === 200));
  assert.equal(unlocks[0]!.body.balance, 20);
  voided = ["repair"];
  await system.billing.reconcile();
  await system.billing.reconcile();
  assert.equal(
    (await request("GET", "/v1/wallet", undefined, s.accessToken)).body.balance,
    -280,
  );
  assert.equal(
    (
      await request(
        "POST",
        "/v1/shop/unlock",
        { packId: "moonlight" },
        s.accessToken,
      )
    ).body.error,
    "insufficient_coins",
  );
});
test("permanent deletion reauthenticates, cascades private data and keeps only anti-replay purchase record", async () => {
  const s = await account();
  purchases.set("delete", {
    purchaseState: 0,
    consumptionState: 0,
    obfuscatedExternalAccountId: s.user.billingAccountId,
  });
  await request(
    "POST",
    "/v1/billing/verify",
    { productId: "betterseed_coin_120", purchaseToken: "delete" },
    s.accessToken,
  );
  await request("PUT", "/v1/garden", mutation(1), s.accessToken);
  assert.equal(
    (
      await request(
        "DELETE",
        "/v1/account",
        { password: "incorrect", confirmation: "DELETE" },
        s.accessToken,
      )
    ).status,
    401,
  );
  assert.equal(
    (
      await request(
        "DELETE",
        "/v1/account",
        { password: pw, confirmation: "DELETE" },
        s.accessToken,
      )
    ).status,
    200,
  );
  for (const table of [
    "users",
    "gardens",
    "sessions",
    "challenges",
    "email_outbox",
    "wallets",
    "entitlements",
  ])
    assert.equal((await rows(pool, `SELECT * FROM ${table}`)).length, 0);
  const [tombstone] = await rows(pool, "SELECT * FROM purchases");
  assert.equal(tombstone!.user_id, null);
  assert.equal(tombstone!.token_cipher, null);
  assert.equal(
    (await request("GET", "/v1/account", undefined, s.accessToken)).status,
    401,
  );
});
test("untrusted RTDN cannot void a payment; policy documents are publicly served", async () => {
  assert.equal(
    (
      await request("POST", "/v1/billing/notifications", {
        message: { data: "e30=" },
      })
    ).status,
    401,
  );
  const policies = await request("GET", "/v1/legal");
  assert.ok(policies.body.documents.privacy.body.includes("Gmail Relay"));
  for (const path of [
    "/privacy",
    "/terms",
    "/licenses",
    "/faq",
    "/about",
    "/delete-account",
  ])
    assert.equal((await system.app.inject(path)).statusCode, 200);
});
test("TOTP follows RFC 6238 SHA1 six-digit truncation", () => {
  const secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ";
  assert.equal(totpAt(secret, 1), "287082");
  assert.equal(matchingStep(secret, "287082", -1, 59000), 1);
  assert.equal(matchingStep(secret, "287082", 1, 59000), -1);
});

test("refresh retry after a lost response returns the same session; logout invalidates the retry receipt", async () => {
  const u = await account(),
    requestId = id();
  const first = await request("POST", "/v1/auth/refresh", {
    refreshToken: u.refreshToken,
    requestId,
  });
  assert.equal(first.status, 200);
  const retry = await request("POST", "/v1/auth/refresh", {
    refreshToken: u.refreshToken,
    requestId,
  });
  assert.equal(retry.status, 200);
  assert.deepEqual(retry.body, first.body);
  const [receipt] = await rows(pool, "SELECT * FROM refresh_receipts");
  assert.ok(!receipt!.response_cipher.includes(first.body.refreshToken));
  assert.equal(
    (await request("GET", "/v1/account", undefined, retry.body.accessToken))
      .status,
    200,
  );
  await request("POST", "/v1/auth/logout", {}, retry.body.accessToken);
  assert.equal(
    (
      await request("POST", "/v1/auth/refresh", {
        refreshToken: u.refreshToken,
        requestId,
      })
    ).status,
    401,
  );
});
test("a different refresh retry key is replay and revokes the rotated session", async () => {
  const u = await account();
  const first = await request("POST", "/v1/auth/refresh", {
    refreshToken: u.refreshToken,
    requestId: id(),
  });
  assert.equal(
    (
      await request("POST", "/v1/auth/refresh", {
        refreshToken: u.refreshToken,
        requestId: id(),
      })
    ).status,
    401,
  );
  assert.equal(
    (await request("GET", "/v1/account", undefined, first.body.accessToken))
      .status,
    401,
  );
});
async function adminLogin() {
  const secret = newTotpSecret(),
    adminId = id();
  await exec(
    pool,
    "INSERT INTO admin_users(id,email,password_hash,totp_secret) VALUES(?,?,?,?)",
    [adminId, "admin@example.test", await passwordHash(pw), encrypt(c, secret)],
  );
  const code = totpAt(secret, Math.floor(Date.now() / 30000));
  const response = await system.app.inject({
    method: "POST",
    url: "/admin/api/login",
    headers: { origin: new URL(c.PUBLIC_BASE_URL).origin },
    payload: { email: "admin@example.test", password: pw, code },
  });
  assert.equal(response.statusCode, 200, response.body);
  const cookie = String(response.headers["set-cookie"]).split(";")[0]!;
  assert.match(
    String(response.headers["set-cookie"]),
    /HttpOnly; Secure; SameSite=Strict/,
  );
  return { cookie, csrf: response.json().csrf, secret, code };
}
async function adminRequest(
  admin: { cookie: string; csrf: string },
  method: any,
  url: string,
  payload?: any,
  headers: Record<string, string> = {},
) {
  const r = await system.app.inject({
    method,
    url: "/admin/api" + url,
    headers: {
      cookie: admin.cookie,
      origin: new URL(c.PUBLIC_BASE_URL).origin,
      "x-csrf-token": admin.csrf,
      ...headers,
    },
    ...(payload ? { payload } : {}),
  });
  return { status: r.statusCode, body: r.json() };
}
test("admin requires separate password + TOTP, secure cookie, exact origin and CSRF", async () => {
  const u = await account();
  assert.equal(
    (await request("GET", "/admin/api/users", undefined, u.accessToken)).status,
    401,
  );
  const admin = await adminLogin();
  assert.equal((await adminRequest(admin, "GET", "/users")).status, 200);
  assert.equal(
    (
      await adminRequest(
        admin,
        "POST",
        "/users/" + u.user.id + "/revoke-sessions",
        { reason: "Support request" },
        { origin: "https://evil.example" },
      )
    ).status,
    403,
  );
  assert.equal(
    (
      await adminRequest(
        admin,
        "POST",
        "/users/" + u.user.id + "/revoke-sessions",
        { reason: "Support request" },
        { "x-csrf-token": "" },
      )
    ).status,
    403,
  );
  const replay = await system.app.inject({
    method: "POST",
    url: "/admin/api/login",
    headers: { origin: new URL(c.PUBLIC_BASE_URL).origin },
    payload: { email: "admin@example.test", password: pw, code: admin.code },
  });
  assert.equal(replay.statusCode, 401);
  await exec(
    pool,
    "UPDATE admin_sessions SET expires_at=DATE_SUB(NOW(3),INTERVAL 1 SECOND)",
  );
  assert.equal((await adminRequest(admin, "GET", "/users")).status, 401);
});
test("admin CRUD keeps verification and MFA, suspends login and sync, and removes private data on deletion", async () => {
  const admin = await adminLogin();
  const made = await adminRequest(admin, "POST", "/users", {
    email: "invited@example.test",
    password: pw,
    reason: "Requested help creating an account",
  });
  assert.equal(made.status, 200);
  const target = made.body.id;
  assert.equal(
    (
      await request("POST", "/v1/auth/login", {
        email: "invited@example.test",
        password: pw,
      })
    ).status,
    401,
  );
  await deliverMail(system.auth);
  const code = mails.at(-1)!.html.match(/<strong>(\d{6})/)![1];
  const [challenge] = await rows(
    pool,
    "SELECT id FROM challenges WHERE user_id=? AND purpose='verify'",
    [target],
  );
  assert.equal(
    (
      await request("POST", "/v1/auth/verify-email", {
        challengeId: challenge!.id,
        code,
      })
    ).status,
    400,
  );
  const verified = await request("POST", "/v1/auth/verify-email", {
    challengeId: challenge!.id,
    code,
    acceptTerms: true,
    legalVersion: c.LEGAL_VERSION,
  });
  assert.equal(verified.status, 200);
  assert.equal(
    (
      await adminRequest(admin, "PATCH", "/users/" + target, {
        suspended: true,
        reason: "Investigating a support report",
      })
    ).status,
    200,
  );
  assert.equal(
    (await request("GET", "/v1/garden", undefined, verified.body.accessToken))
      .status,
    401,
  );
  assert.equal(
    (
      await request("POST", "/v1/auth/login", {
        email: "invited@example.test",
        password: pw,
      })
    ).status,
    403,
  );
  await adminRequest(admin, "PATCH", "/users/" + target, {
    suspended: false,
    reason: "Support report resolved",
  });
  assert.equal(
    (
      await request("POST", "/v1/auth/login", {
        email: "invited@example.test",
        password: pw,
      })
    ).status,
    200,
  );
  const secret = newTotpSecret();
  await exec(pool, "UPDATE users SET totp_secret=? WHERE id=?", [
    encrypt(c, secret),
    target,
  ]);
  assert.equal(
    (
      await adminRequest(admin, "PATCH", "/users/" + target, {
        email: "updated@example.test",
        reason: "User requested an email correction",
      })
    ).status,
    200,
  );
  // A changed email on an old account must not trigger abandoned-signup cleanup.
  await exec(
    pool,
    "UPDATE users SET created_at=DATE_SUB(NOW(3),INTERVAL 90 DAY) WHERE id=?",
    [target],
  );
  // The marker is written while the old address is still verified. Verify its presence.
  assert.equal(
    (
      await rows(
        pool,
        "SELECT user_id FROM pending_email_changes WHERE user_id=?",
        [target],
      )
    ).length,
    1,
  );
  await cleanup(system.auth);
  assert.equal(
    (await rows(pool, "SELECT id FROM users WHERE id=?", [target])).length,
    1,
  );
  await deliverMail(system.auth);
  const emailCode = mails.at(-1)!.html.match(/<strong>(\d{6})/)![1];
  const [ch] = await rows(
    pool,
    "SELECT id FROM challenges WHERE user_id=? AND purpose='verify'",
    [target],
  );
  const result = await request("POST", "/v1/auth/verify-email", {
    challengeId: ch!.id,
    code: emailCode,
  });
  assert.equal(result.body.twoFactorRequired, true);
  assert.equal(result.body.accessToken, undefined);
  const detail = await adminRequest(admin, "GET", "/users/" + target);
  assert.equal(detail.status, 200);
  assert.ok(!JSON.stringify(detail.body).includes(secret));
  assert.ok(!JSON.stringify(detail.body).includes("password_hash"));
  assert.equal(
    (
      await adminRequest(admin, "DELETE", "/users/" + target, {
        confirmation: "wrong@example.test",
        reason: "User requested deletion",
      })
    ).status,
    400,
  );
  assert.equal(
    (
      await adminRequest(admin, "DELETE", "/users/" + target, {
        confirmation: "updated@example.test",
        reason: "User requested deletion",
      })
    ).status,
    200,
  );
  assert.equal(
    (await rows(pool, "SELECT id FROM users WHERE id=?", [target])).length,
    0,
  );
  assert.equal(
    (await rows(pool, "SELECT id FROM admin_audit WHERE target_id=?", [target]))
      .length,
    0,
  );
});
test("admin coin adjustment retries are idempotent, pack controls update wallet, and payment proof cannot be edited", async () => {
  const u = await account(),
    admin = await adminLogin(),
    path = "/users/" + u.user.id;
  const adjustment = {
    delta: 300,
    mutationId: id(),
    reason: "Goodwill credit for a support case",
  };
  const responses = await Promise.all([
    adminRequest(admin, "POST", path + "/coins", adjustment),
    adminRequest(admin, "POST", path + "/coins", adjustment),
  ]);
  assert.ok(responses.every((r) => r.status === 200));
  let wallet = await request("GET", "/v1/wallet", undefined, u.accessToken);
  assert.equal(wallet.body.balance, 300);
  assert.equal(
    (
      await adminRequest(admin, "POST", path + "/coins", {
        ...adjustment,
        delta: 600,
      })
    ).status,
    409,
  );
  assert.equal(
    (
      await adminRequest(admin, "PATCH", path, {
        verified: true,
        reason: "Attempt verification bypass",
      })
    ).status,
    400,
  );
  await adminRequest(admin, "POST", path + "/packs", {
    pack: "sakura",
    granted: true,
    reason: "Verified migration support case",
  });
  wallet = await request("GET", "/v1/wallet", undefined, u.accessToken);
  assert.deepEqual(wallet.body.packs, ["sakura"]);
  assert.equal(wallet.body.balance, 300);
  await adminRequest(admin, "POST", path + "/packs", {
    pack: "sakura",
    granted: false,
    reason: "Correcting a mistaken entitlement",
  });
  wallet = await request("GET", "/v1/wallet", undefined, u.accessToken);
  assert.deepEqual(wallet.body.packs, []);
  assert.equal((await rows(pool, "SELECT * FROM purchases")).length, 0);
  const events = await rows(
    pool,
    "SELECT * FROM admin_audit WHERE action='wallet.adjust'",
  );
  assert.equal(events.length, 1);
  const result = await adminRequest(
    admin,
    "GET",
    "/users?search=" + encodeURIComponent("%' OR 1=1 --"),
  );
  assert.equal(result.body.total, 0);
  await adminRequest(admin, "POST", path + "/revoke-sessions", {
    reason: "Lost device reported by owner",
  });
  assert.equal(
    (await request("GET", "/v1/account", undefined, u.accessToken)).status,
    401,
  );
});
test("admin assets use self-hosted scripts and security headers; migrations preserve existing accounts", async () => {
  const u = await account();
  await migrate(pool);
  assert.equal(
    (await request("GET", "/v1/account", undefined, u.accessToken)).status,
    200,
  );
  for (const path of [
    "/admin",
    "/admin/",
    "/admin/app.js",
    "/admin/style.css",
  ]) {
    const response = await system.app.inject({ method: "GET", url: path });
    assert.equal(response.statusCode, 200);
    assert.equal(response.headers["cache-control"], "no-store");
    assert.ok(response.headers["content-security-policy"]);
  }
});

const newPack = {
  packId: "crystal_forest",
  name: "Crystal Forest",
  description: "Locally bundled garden",
  accessType: "premium",
  priceCoins: 90,
  status: "active",
  minimumAppBuild: 57,
  displayOrder: 40,
};
async function offer(pack = "crystal_forest") {
  return (await request("GET", "/v1/shop/catalog")).body.packs.find(
    (p: any) => p.packId === pack,
  );
}
function consent(p: any) {
  return {
    packId: p.packId,
    expectedPrice: p.priceCoins,
    catalogRevision: p.revision,
    appBuild: 57,
  };
}
async function changePack(admin: any, p: any, changes: any = {}) {
  const { packId, revision, ...metadata } = p;
  return adminRequest(admin, "PATCH", "/packs/" + packId, {
    ...metadata,
    ...changes,
    expectedRevision: revision,
    reason: "Test catalog change",
  });
}
async function fundedAccount() {
  const u = await account();
  await exec(
    pool,
    "INSERT INTO wallets(user_id,balance) VALUES(?,1000) ON DUPLICATE KEY UPDATE balance=1000",
    [u.user.id],
  );
  return u;
}
test("catalog seeds are idempotent and preserve old purchases and edited prices", async () => {
  const u = await fundedAccount();
  await request(
    "POST",
    "/v1/shop/unlock",
    { packId: "moonlight" },
    u.accessToken,
  );
  const admin = await adminLogin();
  assert.equal(
    (await changePack(admin, await offer("moonlight"), { priceCoins: 222 }))
      .status,
    200,
  );
  await migrate(pool);
  await migrate(pool);
  assert.equal((await offer("moonlight")).priceCoins, 222);
  assert.deepEqual(
    (await request("GET", "/v1/wallet", undefined, u.accessToken)).body.packs,
    ["moonlight"],
  );
  assert.equal(
    (
      await rows(pool, "SELECT cost FROM entitlements WHERE user_id=?", [
        u.user.id,
      ])
    )[0]!.cost,
    180,
  );
  assert.equal((await request("GET", "/v1/shop/catalog")).body.packs.length, 4);
});
test("new IDs need no whitelist; concurrent acquisition deducts once and persists the agreed price", async () => {
  const admin = await adminLogin(),
    u = await fundedAccount();
  assert.equal(
    (
      await adminRequest(admin, "POST", "/packs", {
        ...newPack,
        reason: "Register bundled assets",
      })
    ).status,
    200,
  );
  const p = await offer();
  const results = await Promise.all(
    Array.from({ length: 8 }, () =>
      request("POST", "/v1/shop/unlock", consent(p), u.accessToken),
    ),
  );
  assert.ok(
    results.every((r) => r.status === 200),
    JSON.stringify(results),
  );
  assert.ok(results.every((r) => r.body.balance === 910));
  const acquisition = await rows(
    pool,
    "SELECT * FROM pack_acquisitions WHERE user_id=?",
    [u.user.id],
  );
  assert.equal(acquisition.length, 1);
  assert.equal(acquisition[0]!.price_coins, 90);
  assert.equal(
    (await rows(pool, "SELECT * FROM coin_ledger WHERE user_id=?", [u.user.id]))
      .length,
    1,
  );
  const all = (await adminRequest(admin, "GET", "/packs")).body.packs;
  assert.equal(all.find((p: any) => p.packId === "crystal_forest").owners, 1);
  assert.equal(
    (
      await adminRequest(admin, "POST", "/users/" + u.user.id + "/packs", {
        pack: "crystal_forest",
        granted: false,
        reason: "Correct support grant",
      })
    ).status,
    200,
  );
  assert.equal(
    (await request("POST", "/v1/shop/unlock", consent(p), u.accessToken)).body
      .balance,
    820,
  );
  assert.equal(
    (
      await rows(pool, "SELECT * FROM pack_acquisitions WHERE user_id=?", [
        u.user.id,
      ])
    ).length,
    2,
  );
});
test("premium/free conversions keep old owners; free claims work with refund debt; retired and hidden block newcomers", async () => {
  const admin = await adminLogin(),
    u = await fundedAccount();
  await adminRequest(admin, "POST", "/packs", {
    ...newPack,
    reason: "Register a garden",
  });
  await request(
    "POST",
    "/v1/shop/unlock",
    consent(await offer()),
    u.accessToken,
  );
  assert.equal(
    (
      await changePack(admin, await offer(), {
        accessType: "free",
        priceCoins: 0,
      })
    ).status,
    200,
  );
  const freeUser = await account("free@example.com");
  await exec(
    pool,
    "INSERT INTO wallets(user_id,balance) VALUES(?,-10) ON DUPLICATE KEY UPDATE balance=-10",
    [freeUser.user.id],
  );
  const free = await request(
    "POST",
    "/v1/shop/unlock",
    consent(await offer()),
    freeUser.accessToken,
  );
  assert.equal(free.status, 200);
  assert.equal(free.body.balance, -10);
  assert.equal(
    (
      await changePack(admin, await offer(), {
        accessType: "premium",
        priceCoins: 500,
      })
    ).status,
    200,
  );
  assert.equal(
    (
      await request(
        "POST",
        "/v1/shop/unlock",
        consent(await offer()),
        freeUser.accessToken,
      )
    ).body.balance,
    -10,
  );
  const newcomer = await account("new@example.com");
  for (const status of ["hidden", "retired"]) {
    await changePack(admin, await offer(), { status });
    assert.equal(
      (
        await request(
          "POST",
          "/v1/shop/unlock",
          consent(await offer()),
          newcomer.accessToken,
        )
      ).body.error,
      "pack_unavailable",
    );
    assert.deepEqual(
      (
        await request(
          "POST",
          "/v1/shop/unlock",
          consent(await offer()),
          u.accessToken,
        )
      ).body.packs,
      ["crystal_forest"],
    );
  }
  const records = await rows(
    pool,
    "SELECT price_coins FROM pack_acquisitions ORDER BY price_coins",
  );
  assert.deepEqual(
    records.map((r) => r.price_coins),
    [0, 90],
  );
});
test("stale price/revision and old APKs fail safely without spending coins", async () => {
  const admin = await adminLogin(),
    u = await fundedAccount(),
    before = await offer("sakura");
  await changePack(admin, before, { priceCoins: 281 });
  for (const body of [
    { packId: "sakura" },
    consent(before),
    { ...consent(before), expectedPrice: 281 },
  ]) {
    const result = await request(
      "POST",
      "/v1/shop/unlock",
      body,
      u.accessToken,
    );
    assert.equal(result.status, 409);
  }
  assert.equal(
    (await request("GET", "/v1/wallet", undefined, u.accessToken)).body.balance,
    1000,
  );
  const latest = await offer("sakura");
  assert.equal(
    (await request("POST", "/v1/shop/unlock", consent(latest), u.accessToken))
      .body.balance,
    719,
  );
  await adminRequest(admin, "POST", "/packs", {
    ...newPack,
    reason: "New client only",
  });
  assert.equal(
    (
      await request(
        "POST",
        "/v1/shop/unlock",
        { packId: "crystal_forest" },
        u.accessToken,
      )
    ).body.error,
    "app_update_required",
  );
  assert.equal(
    (
      await request(
        "POST",
        "/v1/shop/unlock",
        { ...consent(await offer()), appBuild: 56 },
        u.accessToken,
      )
    ).body.error,
    "app_update_required",
  );
  await changePack(admin, await offer("moonlight"), { minimumAppBuild: 58 });
  assert.equal(
    (
      await request(
        "POST",
        "/v1/shop/unlock",
        consent(await offer("moonlight")),
        u.accessToken,
      )
    ).body.error,
    "app_update_required",
  );
});
test("admin edit racing a purchase either honors the old quote or rejects it, never silently reprices", async () => {
  const admin = await adminLogin(),
    u = await fundedAccount();
  const quoted = await offer("moonlight");
  const [purchase, edit] = await Promise.all([
    request("POST", "/v1/shop/unlock", consent(quoted), u.accessToken),
    changePack(admin, quoted, { priceCoins: 900 }),
  ]);
  assert.equal(edit.status, 200);
  assert.ok([200, 409].includes(purchase.status));
  const balance = (await request("GET", "/v1/wallet", undefined, u.accessToken))
    .body.balance;
  assert.equal(balance, purchase.status === 200 ? 820 : 1000);
  assert.equal(
    (await changePack(admin, quoted, { priceCoins: 999 })).body.error,
    "catalog_changed",
  );
});
test("catalog admin requires auth/CSRF, validates inputs and default invariants, records audit and excludes draft offers", async () => {
  assert.equal((await request("GET", "/admin/api/packs")).status, 401);
  assert.equal(
    (await request("POST", "/admin/api/packs", newPack)).status,
    401,
  );
  const admin = await adminLogin();
  const body = { ...newPack, reason: "Register new garden" };
  assert.equal(
    (await adminRequest(admin, "POST", "/packs", body, { "x-csrf-token": "" }))
      .status,
    403,
  );
  assert.equal(
    (
      await adminRequest(admin, "POST", "/packs", body, {
        origin: "https://evil.test",
      })
    ).status,
    403,
  );
  for (const bad of [
    { packId: "../secret" },
    { packId: "x' OR 1=1" },
    { priceCoins: -1 },
    { priceCoins: 1.5 },
    { accessType: "free" },
    { status: "published" },
    { minimumAppBuild: 0 },
    { packId: "default" },
  ])
    assert.equal(
      (await adminRequest(admin, "POST", "/packs", { ...body, ...bad })).status,
      400,
    );
  assert.equal(
    (
      await adminRequest(admin, "POST", "/packs", {
        ...body,
        status: "draft",
        name: "<img src=x onerror=alert(1)>",
      })
    ).status,
    200,
  );
  assert.equal(await offer(), undefined);
  const draft = (await adminRequest(admin, "GET", "/packs")).body.packs.find(
    (p: any) => p.packId === "crystal_forest",
  );
  assert.equal(
    (
      await request(
        "POST",
        "/v1/shop/unlock",
        consent(draft),
        (await account()).accessToken,
      )
    ).body.error,
    "pack_unavailable",
  );
  assert.equal(
    (
      await changePack(admin, await offer("default"), {
        accessType: "premium",
        priceCoins: 10,
      })
    ).status,
    400,
  );
  assert.equal(
    (await changePack(admin, await offer("default"), { status: "hidden" }))
      .status,
    400,
  );
  assert.equal(
    (
      await rows(
        pool,
        "SELECT * FROM admin_audit WHERE action='catalog.create'",
      )
    ).length,
    1,
  );
});
test("sync accepts future valid cosmetic and placement IDs without granting ownership, rejects paths", async () => {
  const u = await account();
  const snapshot = {
    ...garden,
    cosmetics: { ...garden.cosmetics, treeSkinId: "crystal_tree" },
    treePlacements: { crystal_garden: { dx: 0, dy: 0, scale: 1 } },
  };
  assert.equal(
    (await request("PUT", "/v1/garden", mutation(1, snapshot), u.accessToken))
      .status,
    200,
  );
  assert.deepEqual(
    (await request("GET", "/v1/wallet", undefined, u.accessToken)).body.packs,
    [],
  );
  assert.equal(
    (
      await request(
        "PUT",
        "/v1/garden",
        mutation(
          2,
          {
            ...snapshot,
            treePlacements: { "../escape": { dx: 0, dy: 0, scale: 1 } },
          },
          1,
        ),
        u.accessToken,
      )
    ).status,
    400,
  );
});

test("pack JSON import validates, previews, applies atomically and rejects stale edits", async () => {
  const admin = await adminLogin();
  const document = (await adminRequest(admin,"GET","/packs/export")).body;
  document.packs.find((p:any)=>p.packId==="sakura").priceCoins=320;
  document.packs.push({packId:"test_new",name:"New garden",description:"Test",accessType:"free",priceCoins:0,status:"draft",minimumAppBuild:58,displayOrder:90,revision:null});
  const preview=await adminRequest(admin,"POST","/packs/import/preview",document);
  assert.equal(preview.status,200,JSON.stringify(preview.body));
  const result=await adminRequest(admin,"POST","/packs/import",{document,proof:preview.body.proof,reason:"Bulk catalog update"});
  assert.equal(result.status,200); assert.equal(result.body.changed,2);
  assert.equal((await adminRequest(admin,"POST","/packs/import",{document,proof:preview.body.proof,reason:"Repeated import"})).status,409);
  const invalid=structuredClone(document);invalid.packs.push(invalid.packs[0]);
  assert.equal((await adminRequest(admin,"POST","/packs/import/preview",invalid)).status,400);
  const fresh=(await adminRequest(admin,"GET","/packs/export")).body;
  const next=await adminRequest(admin,"POST","/packs/import/preview",fresh);
  fresh.packs[0].name="Changed after preview";
  assert.equal((await adminRequest(admin,"POST","/packs/import",{document:fresh,proof:next.body.proof,reason:"Tampered preview"})).status,409);
  fresh.packs.find((p:any)=>p.packId==="default").status="hidden";
  assert.equal((await adminRequest(admin,"POST","/packs/import/preview",fresh)).status,400);
  assert.equal((await adminRequest(admin,"POST","/packs/import/preview",document,{"x-csrf-token":""})).status,403);
});

test("encrypted database backup restores balances and purchase proofs and revokes sessions", async () => {
  const {openSnapshot,sealSnapshot}=await import("../src/database-backup.js");
  const admin=await adminLogin(), user=await account();
  await exec(pool,"INSERT INTO wallets(user_id,balance,revision) VALUES(?,321,7)",[user.user.id]);
  await exec(pool,"INSERT INTO purchases(token_hash,user_id,product_id,coins,state) VALUES(?,?,?,100,'consumed')",["ab".repeat(32),user.user.id,"leaf_coins_100"]);
  const credentials=async()=>{await exec(pool,"UPDATE admin_users SET totp_last_step=-1");return {password:pw,code:totpAt(admin.secret,Math.floor(Date.now()/30000))};};
  const passphrase="my-test-backup-passphrase-123";
  const exported=await adminRequest(admin,"POST","/database/export",{passphrase,credentials:await credentials(),reason:"Backup round trip"});
  assert.equal(exported.status,200,JSON.stringify(exported.body));
  assert.ok(!JSON.stringify(exported.body).includes("a@example.com"));
  const snapshot=await openSnapshot(exported.body,passphrase);
  assert.equal(snapshot.tables.wallets!.rows.length,1);assert.ok(!snapshot.tables.sessions);
  assert.equal((await adminRequest(admin,"POST","/database/preview",{backup:exported.body,passphrase:"wrong-password-long-enough"})).status,400);
  const tampered={...exported.body,data:"AAAA"+exported.body.data.slice(4)};
  assert.equal((await adminRequest(admin,"POST","/database/preview",{backup:tampered,passphrase})).status,400);
  const wrongKey=structuredClone(snapshot);wrongKey.keyId="00".repeat(32);
  assert.equal((await adminRequest(admin,"POST","/database/preview",{backup:await sealSnapshot(wrongKey,passphrase),passphrase})).body.error,"backup_key_mismatch");
  const preview=await adminRequest(admin,"POST","/database/preview",{backup:exported.body,passphrase});assert.equal(preview.status,200);
  await exec(pool,"UPDATE wallets SET balance=1");
  const restored=await adminRequest(admin,"POST","/database/restore",{backup:exported.body,passphrase,proof:preview.body.proof,credentials:await credentials(),reason:"Restore backup test",confirmation:"RESTORE",safetyBackupSaved:true});
  assert.equal(restored.status,200,JSON.stringify(restored.body));
  assert.equal(Number((await rows(pool,"SELECT balance FROM wallets"))[0]!.balance),321);
  assert.equal((await rows(pool,"SELECT * FROM purchases"))[0]!.token_hash,"ab".repeat(32));
  assert.equal((await rows(pool,"SELECT * FROM sessions")).length,0);
  assert.equal((await adminRequest(admin,"GET","/me")).status,401);
  assert.equal((await rows(pool,"SELECT * FROM admin_audit WHERE action='database.restore'")).length,1);
});

test("invalid restore rolls back and database gate waits for in-flight work", async () => {
  const {makeSnapshot,restoreSnapshot}=await import("../src/database-backup.js");
  const {DatabaseGate}=await import("../src/database-gate.js");
  await adminLogin();const user=await account();const snapshot=await makeSnapshot(pool,c);
  const bad:Record<string,unknown>={user_id:id(),balance:12,revision:1};
  snapshot.tables.wallets!.rows.push(snapshot.tables.wallets!.columns.map(k=>bad[k] as string));
  await assert.rejects(restoreSnapshot(pool,c,snapshot,id(),"Invalid foreign key"));
  assert.equal((await rows(pool,"SELECT id FROM users WHERE id=?",[user.user.id])).length,1);
  assert.ok((await rows(pool,"SELECT * FROM admin_sessions")).length);
  const first=new DatabaseGate(c),second=new DatabaseGate(c);const release=await first.acquire();let entered=false;
  const pending=second.run(async()=>{entered=true;},true);
  await new Promise(r=>setTimeout(r,50));assert.equal(entered,false);await release();await pending;assert.equal(entered,true);
  await first.close();await second.close();
});

test("database tools require admin, CSRF, fresh TOTP and explicit restore confirmation", async () => {
  assert.equal((await request("POST","/admin/api/database/export",{})).status,401);
  assert.equal((await request("POST","/admin/api/database/restore",{})).status,401);
  const admin=await adminLogin();
  const body={passphrase:"long-backup-passphrase",reason:"Permission test",credentials:{password:pw,code:admin.code}};
  assert.equal((await adminRequest(admin,"POST","/database/export",body,{"x-csrf-token":""})).status,403);
  assert.equal((await adminRequest(admin,"POST","/database/export",body,{origin:"https://untrusted.example"})).status,403);
  // A TOTP already consumed during login cannot authorize an export.
  assert.equal((await adminRequest(admin,"POST","/database/export",body)).status,403);
  assert.equal((await adminRequest(admin,"POST","/database/restore",{confirmation:"YES"})).status,400);
  assert.equal((await rows(pool,"SELECT * FROM admin_sessions")).length,1);
});

test("bulk import never partially writes when another admin changes a revision", async () => {
  const admin=await adminLogin();
  const doc=(await adminRequest(admin,"GET","/packs/export")).body;
  doc.packs.find((p:any)=>p.packId==="moonlight").priceCoins=999;
  const preview=await adminRequest(admin,"POST","/packs/import/preview",doc);
  await exec(pool,"UPDATE garden_packs SET revision=revision+1 WHERE pack_id='sakura'");
  const result=await adminRequest(admin,"POST","/packs/import",{document:doc,proof:preview.body.proof,reason:"Concurrent catalog edit"});
  assert.equal(result.status,409);
  assert.equal(Number((await rows(pool,"SELECT price_coins FROM garden_packs WHERE pack_id='moonlight'"))[0]!.price_coins),180);
});

test("database backup preserves JSON, UTC dates, large IDs and encrypted credentials", async () => {
  const {makeSnapshot,sealSnapshot,openSnapshot,restoreSnapshot,inspectSnapshot}=await import("../src/database-backup.js");
  await adminLogin();const user=await account();
  const snapshotData={version:1,progress:{xp:25},habits:[{id:"a",title:"日本語 🌱"}]};
  await exec(pool,"INSERT INTO gardens(user_id,revision,snapshot,updated_at) VALUES(?,4,?,'2026-10-28 12:34:56.123')",[user.user.id,JSON.stringify(snapshotData)]);
  await exec(pool,"INSERT INTO coin_ledger(id,user_id,entry_key,delta) VALUES('9007199254740993',?,'backup-test',10)",[user.user.id]);
  const snapshot=await makeSnapshot(pool,c),passphrase="test-passphrase-for-round-trip";
  const decoded=await openSnapshot(await sealSnapshot(snapshot,passphrase),passphrase);
  const ledger=decoded.tables.coin_ledger!;
  assert.equal(ledger.rows[0]![ledger.columns.indexOf('id')],'9007199254740993');
  const invalid=structuredClone(decoded);invalid.schema="00".repeat(32);
  await assert.rejects(inspectSnapshot(pool,c,invalid),/backup_schema_mismatch/);
  const columns=structuredClone(decoded);columns.tables.users!.columns[0]="id`); DROP TABLE users; --";
  await assert.rejects(inspectSnapshot(pool,c,columns),/invalid_backup/);
  const savedHash=(await rows(pool,"SELECT password_hash FROM users WHERE id=?",[user.user.id]))[0]!.password_hash;
  await restoreSnapshot(pool,c,decoded,id(),"Round-trip restore test");
  const [garden]=await rows(pool,"SELECT snapshot,DATE_FORMAT(updated_at,'%Y-%m-%d %H:%i:%s.%f') AS date FROM gardens");
  assert.deepEqual(garden!.snapshot,snapshotData);assert.equal(garden!.date,'2026-10-28 12:34:56.123000');
  assert.equal((await rows(pool,"SELECT password_hash FROM users WHERE id=?",[user.user.id]))[0]!.password_hash,savedHash);
});

test("staged password reset reveals MFA only after email proof, revokes sessions and rejects replay", async () => {
  const s = await account();
  const start = await request("POST", "/v1/auth/forgot-password", { email: s.user.email });
  assert.equal(start.body.twoFactorRequired, undefined);
  const unknown = await request("POST", "/v1/auth/forgot-password", { email: "unknown@example.test" });
  assert.deepEqual(Object.keys(unknown.body).sort(), Object.keys(start.body).sort());
  await deliverMail(system.auth);
  const code = mails.at(-1)!.html.match(/<strong>(\d{6})/)![1];
  const proof = { challengeId: start.body.challengeId, code };
  assert.equal((await request("POST", "/v1/auth/password-reset/verify-email", { ...proof, code: "xxxxxx" })).status, 400);
  const verified = await request("POST", "/v1/auth/password-reset/verify-email", proof);
  assert.equal(verified.status, 200); assert.equal(verified.body.twoFactorRequired, false);
  const grant = { challengeId: verified.body.challengeId, resetToken: verified.body.resetToken };
  assert.equal((await request("POST", "/v1/auth/password-reset/verify-email", proof)).status, 400);
  const body = { ...grant, password: "new-long-password-123" };
  assert.equal((await request("POST", "/v1/auth/password-reset/complete", body)).status, 200);
  assert.equal((await request("POST", "/v1/auth/password-reset/complete", body)).status, 400);
  assert.equal((await request("GET", "/v1/account", undefined, s.accessToken)).status, 401);
  assert.equal((await request("POST", "/v1/auth/login", { email: s.user.email, password: body.password })).status, 200);
});

test("staged reset requires the enrolled factor and preserves MFA for future sign-in", async () => {
  const s = await account();
  const setup = await request("POST", "/v1/account/two-factor/setup", { password: pw }, s.accessToken);
  const code = totpAt(setup.body.secret, Math.floor(Date.now()/30000));
  const enabled = await request("POST", "/v1/account/two-factor/confirm", { factor: code }, s.accessToken);
  assert.equal(enabled.status, 200);
  const begin = await request("POST", "/v1/auth/forgot-password", { email: s.user.email });
  await deliverMail(system.auth);
  const emailCode = mails.at(-1)!.html.match(/<strong>(\d{6})/)![1];
  const verified = await request("POST", "/v1/auth/password-reset/verify-email", { challengeId: begin.body.challengeId, code: emailCode });
  assert.equal(verified.body.twoFactorRequired, true);
  const grant = { challengeId: verified.body.challengeId, resetToken: verified.body.resetToken };
  assert.equal((await request("POST", "/v1/auth/password-reset/complete", { ...grant, password: "new-long-password-123" })).status, 400);
  assert.equal((await request("POST", "/v1/auth/password-reset/verify-factor", { ...grant, factor: code })).status, 400); // already-used TOTP
  const factor = await request("POST", "/v1/auth/password-reset/verify-factor", { ...grant, factor: enabled.body.recoveryCodes[0] });
  assert.equal(factor.status, 200);
  assert.equal((await request("POST", "/v1/auth/password-reset/verify-factor", { ...grant, factor: enabled.body.recoveryCodes[1] })).status, 400);
  assert.equal((await request("POST", "/v1/auth/password-reset/complete", { ...factor.body, password: "new-long-password-123" })).status, 200);
  const login = await request("POST", "/v1/auth/login", { email: s.user.email, password: "new-long-password-123" });
  assert.equal(login.body.twoFactorRequired, true);
  assert.equal((await request("POST", "/v1/auth/two-factor", { challengeId: login.body.challengeId, challengeToken: login.body.challengeToken, factor: enabled.body.recoveryCodes[0] })).status, 401);
});

test("recovery grants expire, limit failed attempts, and cannot be swapped between users", async () => {
  async function grant(email: string) {
    const s = await account(email);
    const reset = await request("POST", "/v1/auth/forgot-password", { email: s.user.email });
    await deliverMail(system.auth);
    const code = mails.at(-1)!.html.match(/<strong>(\d{6})/)![1];
    const verified = await request("POST", "/v1/auth/password-reset/verify-email", { challengeId: reset.body.challengeId, code });
    return { challengeId: verified.body.challengeId, resetToken: verified.body.resetToken };
  }
  const a = await grant("reset-a@example.test"), b = await grant("reset-b@example.test");
  const url = "/v1/auth/password-reset/complete";
  assert.equal((await request("POST", url, { challengeId: a.challengeId, resetToken: b.resetToken, password: pw })).status, 400);
  for (let i=0;i<4;i++) assert.equal((await request("POST", url, { ...a, resetToken: "x".repeat(43), password: pw })).status, 400);
  assert.equal((await request("POST", url, { ...a, password: pw })).status, 400);
  await exec(pool, "UPDATE challenges SET expires_at=DATE_SUB(NOW(3),INTERVAL 1 SECOND) WHERE id=?", [b.challengeId]);
  assert.equal((await request("POST", url, { ...b, password: pw })).status, 400);
});

test("fresh authenticator code authorizes exactly one password reset", async () => {
  const s = await account();
  const secret = newTotpSecret();
  await exec(pool, "UPDATE users SET totp_secret=?,totp_last_step=-1 WHERE id=?", [encrypt(c, secret), s.user.id]);
  const begin = await request("POST", "/v1/auth/forgot-password", { email: s.user.email });
  await deliverMail(system.auth);
  const code = mails.at(-1)!.html.match(/<strong>(\d{6})/)![1];
  const email = await request("POST", "/v1/auth/password-reset/verify-email", { challengeId: begin.body.challengeId, code });
  const verified = await request("POST", "/v1/auth/password-reset/verify-factor", {
    challengeId: email.body.challengeId, resetToken: email.body.resetToken,
    factor: totpAt(secret, Math.floor(Date.now()/30000)),
  });
  assert.equal(verified.status, 200);
  const results = await Promise.all([1,2].map(() => request("POST", "/v1/auth/password-reset/complete", {
    ...verified.body, password: "new-long-password-123",
  })));
  assert.deepEqual(results.map(r => r.status).sort(), [200,400]);
});

test("checklist v2 advertises support and prevents legacy overwrite", async () => {
  const s = await account();
  const plan = {type:"count",target:8,unit:"glasses",weekdays:[1,2,3,4,5,6,7]};
  const snapshot = {...garden, version:2, habits: [{...garden.habits[0], checklist:{
    start:"2026-10-27",plan,category:"Morning",order:0,archived:false,
    pending:null,effective:null,records:{"2026-10-27":{plan,scheduled:true,value:4,rest:false}},carriedStreak:0,bestStreak:0
  }}]};
  assert.deepEqual((await request("GET","/v1/garden",undefined,s.accessToken)).body.supportedSnapshotVersions,[1,2]);
  assert.equal((await request("PUT","/v1/garden",mutation(1,snapshot),s.accessToken)).status,200);
  assert.equal((await request("PUT","/v1/garden",mutation(2,garden,1),s.accessToken)).body.error,"app_update_required");
  const remote = (await request("GET","/v1/garden",undefined,s.accessToken)).body;
  assert.equal(remote.revision,1);
  assert.equal(remote.snapshot.habits[0].checklist.records["2026-10-27"].value,4);
  assert.equal((await request("PUT","/v1/garden",mutation(3,{...snapshot,version:1},1),s.accessToken)).status,400);
});

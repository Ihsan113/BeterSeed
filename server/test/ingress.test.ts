import { test } from "node:test";
import { get } from "node:http";
import { once } from "node:events";
import assert from "node:assert/strict";
import Fastify from "fastify";
import { installIngress, notificationPath } from "../src/ingress.js";
import { buildApp } from "../src/app.js";
import { configFromEnv } from "../src/config.js";
import { createPool } from "../src/db.js";
import type { Providers } from "../src/providers.js";

function fixture() {
  const app = Fastify({ bodyLimit: 64 });
  installIngress(app);
  let entered = 0;
  app.addHook("preHandler", async () => { entered++; });
  app.all("/v1/auth/login", async () => ({ ok: true }));
  app.all("/v1/garden", async () => ({ ok: true }));
  app.all(notificationPath, async () => ({ ok: true }));
  app.get("/health", async () => ({ ok: true }));
  return { app, entered: () => entered };
}

test("auth admission blocks before downstream work; spoofed forwarded IP cannot reset it", async (t) => {
  const f = fixture(); t.after(() => f.app.close());
  for (let i = 0; i < 40; i++) {
    assert.equal((await f.app.inject("/v1/auth/login")).statusCode, 200);
  }
  const denied = await f.app.inject({ url: "/v1/auth/login?attempt=41", headers: { "x-forwarded-for": "192.0.2.7" } });
  assert.equal(denied.statusCode, 429);
  assert.ok(Number(denied.headers["retry-after"]) > 0);
  assert.equal(denied.headers["cache-control"], "no-store");
  assert.equal(f.entered(), 40);
  assert.equal((await f.app.inject("/health")).statusCode, 200);
  assert.equal((await f.app.inject("/v1/garden")).statusCode, 200);
});

test("RTDN has a dedicated budget including query strings, without consuming the app budget", async (t) => {
  const f = fixture(); t.after(() => f.app.close());
  for (let i = 0; i < 600; i++) {
    assert.equal((await f.app.inject(notificationPath + "?delivery=1")).statusCode, 200);
  }
  assert.equal((await f.app.inject(notificationPath)).statusCode, 429);
  assert.equal(f.entered(), 600);
  assert.equal((await f.app.inject("/v1/garden")).statusCode, 200);
});

test("admission storage is bounded; rotating IPs cannot evict existing counters", async (t) => {
  const f = fixture(); t.after(() => f.app.close());
  for (let i = 0; i < 4096; i++) {
    assert.equal((await f.app.inject({ url: "/v1/garden", remoteAddress: `198.18.${i >> 8}.${i & 255}` })).statusCode, 200);
  }
  const denied = await f.app.inject({ url: "/v1/garden", remoteAddress: "192.0.2.1" });
  assert.equal(denied.statusCode, 503);
  assert.equal(denied.headers["retry-after"], "1");
  assert.equal(f.entered(), 4096);
  assert.equal((await f.app.inject({ url: "/v1/garden", remoteAddress: "198.18.0.0" })).statusCode, 200);
});

test("expired windows recover both counters and admission storage using a monotonic clock", async (t) => {
  // performance.now is monotonic: system clock changes cannot prolong a ban.
  t.mock.method(performance, "now", () => 0);
  const f = fixture(); t.after(() => f.app.close());
  for (let i = 0; i < 40; i++) await f.app.inject("/v1/auth/login");
  assert.equal((await f.app.inject("/v1/auth/login")).statusCode, 429);
  t.mock.method(performance, "now", () => 60001);
  assert.equal((await f.app.inject("/v1/auth/login")).statusCode, 200);
});

for (const lane of ["api", "notification"] as const) {
  test(`${lane} concurrent work is bounded, isolated from the other lane, and released`, async (t) => {
    const app = Fastify(); t.after(() => app.close());
    installIngress(app);
    const url = lane === "api" ? "/v1/garden" : notificationPath;
    const other = lane === "api" ? notificationPath : "/v1/garden";
    const limit = lane === "api" ? 12 : 4;
    let finish!: () => void;
    let filled!: () => void;
    const barrier = new Promise<void>((resolve) => { finish = resolve; });
    const ready = new Promise<void>((resolve) => { filled = resolve; });
    let started = 0;
    app.get(url, async () => { if (++started === limit) filled(); await barrier; return { ok: true }; });
    app.get(other, async () => ({ ok: true }));
    await app.ready();
    const pending = Array.from({ length: limit }, () => app.inject(url).then((r) => r));
    t.after(finish);
    await ready;
    const denied = await app.inject(url);
    assert.equal(denied.statusCode, 503);
    assert.equal(denied.headers["retry-after"], "1");
    assert.equal(started, limit);
    assert.equal((await app.inject(other)).statusCode, 200);
    finish();
    assert.ok((await Promise.all(pending)).every((r) => r.statusCode === 200));
    assert.equal((await app.inject(url)).statusCode, 200);
  });
}

test("failed handlers release admission once, without leaking slots", async (t) => {
  const app = Fastify(); t.after(() => app.close());
  installIngress(app);
  app.get(notificationPath, async () => { throw Error("fixture failure"); });
  for (let i = 0; i < 12; i++) {
    assert.equal((await app.inject(notificationPath)).statusCode, 500);
  }
});

test("disconnects retain capacity until work ends, then release it even without a response finish", { timeout: 10000 }, async (t) => {
  const app = Fastify(); t.after(() => app.close());
  installIngress(app);
  const finishes: Array<() => void> = [];
  const started: Array<() => void> = [];
  let sent = 0;
  let drained!: () => void;
  const done = new Promise<void>((resolve) => { drained = resolve; });
  app.addHook("onSend", async (_request, reply, payload) => {
    if (reply.statusCode === 200 && ++sent === 4) drained();
    return payload;
  });
  app.get(notificationPath, async () => {
    const work = new Promise<void>((resolve) => { finishes.push(resolve); });
    started.shift()!();
    await work;
    return { ok: true };
  });
  t.after(() => finishes.forEach((finish) => finish()));
  const address = await app.listen({ host: "127.0.0.1", port: 0 });
  for (let i = 0; i < 4; i++) {
    const ready = new Promise<void>((resolve) => { started.push(resolve); });
    const client = get(address + notificationPath);
    client.on("error", () => {});
    await ready;
    const closed = once(client, "close").catch(() => {});
    client.destroy();
    await closed;
  }
  assert.equal((await app.inject(notificationPath)).statusCode, 503);
  // Observe serialization after handlers finish, even though clients are gone.
  finishes.forEach((finish) => finish());
  await done;
  await new Promise<void>((resolve) => setImmediate(resolve));
  started.push(() => { finishes.at(-1)!(); });
  assert.equal((await app.inject(notificationPath)).statusCode, 200);
});

test("real app rejects malformed/oversized bodies before acquiring any database connection", async (t) => {
  const c = configFromEnv({ NODE_ENV: "test", MYSQL_PASSWORD: "test-only", TOKEN_PEPPER: "11".repeat(32), DATA_ENCRYPTION_KEY: "22".repeat(32) });
  const pool = createPool(c);
  // No database exists in this offline test. A premature gate returns 503.
  const { app } = await buildApp(c, pool, {} as Providers);
  t.after(async () => { await app.close(); await pool.end(); });
  assert.equal((await app.inject({ method: "POST", url: "/v1/auth/login", headers: { "content-type": "application/json" }, payload: "{" })).statusCode, 400);
  assert.equal((await app.inject({ method: "POST", url: "/v1/auth/login", headers: { "content-type": "application/json" }, payload: "x".repeat(4 * 1024 * 1024 + 1) })).statusCode, 413);
});

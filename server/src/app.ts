import Fastify, { type FastifyRequest } from "fastify";
import { DatabaseGate } from "./database-gate.js";
import helmet from "@fastify/helmet";
import { ZodError } from "zod";
import type { Pool } from "mysql2/promise";
import type { Config } from "./config.js";
import type { Providers } from "./providers.js";
import { catalogRoutes } from "./catalog.js";
import { adminRoutes } from "./admin.js";
import { Auth, authRoutes } from "./auth.js";
import { Billing, billingRoutes } from "./billing.js";
import { syncRoutes } from "./sync.js";
import { legalRoutes } from "./legal.js";
import { ApiError, rateLimit } from "./security.js";
import { rows } from "./db.js";
import { apiPath, installIngress, notificationPath } from "./ingress.js";
export async function buildApp(c: Config, pool: Pool, p: Providers) {
  const app = Fastify({
    bodyLimit: 4 * 1024 * 1024,
    trustProxy: c.TRUST_PROXY
      ? c.TRUST_PROXY.split(",").map((s) => s.trim())
      : false,
    logger: {
      level: c.NODE_ENV === "test" ? "silent" : "info",
      redact: [
        "req.headers.authorization",
        "req.headers.cookie",
        "req.body",
        "res.headers.set-cookie",
      ],
    },
    disableRequestLogging: true,
    requestTimeout: 30000,
  });
  await app.register(helmet);
  installIngress(app);
  const gate = new DatabaseGate(c);
  const held = new WeakMap<FastifyRequest, () => Promise<void>>();
  app.addHook("preHandler", async (r) => {
    // Restore authenticates first, then obtains its exclusive gate in the handler.
    const path = apiPath(r);
    if ((path?.startsWith("/v1/") || path?.startsWith("/admin/api/")) &&
        path !== "/admin/api/database/restore") held.set(r, await gate.acquire());
  });
  const release = async (r: FastifyRequest) => {
    const unlock = held.get(r); held.delete(r); if (unlock) await unlock();
  };
  app.addHook("onResponse", release);
  app.addHook("onError", async (r) => { await release(r); });
  app.addHook("onClose", () => gate.close());
  const auth = new Auth(pool, c, p),
    billing = new Billing(auth);
  app.addHook("preHandler", async (r) => {
    // DB-backed limits stay inside the shared maintenance gate. In-memory
    // admission above protects the gate without writing during a restore.
    const path = apiPath(r);
    if (path.startsWith("/v1/") && path !== notificationPath) {
      await rateLimit(
        pool,
        c,
        "ip:" + r.ip,
        path.startsWith("/v1/auth/") ? 40 : 180,
        60,
      );
    }
  });
  app.setErrorHandler((e, r, reply) => {
    if (e instanceof ApiError)
      return reply
        .code(e.status)
        .send({ error: e.code, ...(e.details ? { details: e.details } : {}) });
    if (e instanceof ZodError)
      return reply.code(400).send({ error: "invalid_request" });
    const error = e as any;
    if (error.code === "ER_DUP_ENTRY")
      return reply.code(409).send({ error: "request_conflict" });
    if (error.statusCode >= 400 && error.statusCode < 500)
      return reply.code(error.statusCode).send({ error: "invalid_request" });
    // Do not log provider errors: upstream request configs may contain purchase tokens.
    app.log.error(
      { requestId: r.id, code: "internal_error" },
      "Request failed",
    );
    return reply.code(500).send({ error: "internal_error" });
  });
  app.get("/health", async () => ({ ok: true }));
  app.get("/ready", async () => {
    await rows(pool, "SELECT 1");
    return { ok: true };
  });
  app.get("/v1/config", async () => ({
    legalVersion: c.LEGAL_VERSION,
    googleEnabled: !!c.GOOGLE_WEB_CLIENT_ID,
    billingEnabled: !!c.GOOGLE_APPLICATION_CREDENTIALS,
  }));
  authRoutes(app, auth);
  adminRoutes(app, auth, gate);
  syncRoutes(app, auth);
  billingRoutes(app, billing);
  catalogRoutes(app, auth);
  legalRoutes(app, c);
  return { app, auth, billing };
}

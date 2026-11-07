import { performance } from "node:perf_hooks";
import type { FastifyInstance, FastifyRequest } from "fastify";

export const notificationPath = "/v1/billing/notifications";
export function apiPath(request: FastifyRequest): string {
  return request.url.split("?", 1)[0]!;
}

type Lane = "api" | "notification";
type Bucket = { hits: number; expires: number };

/** Cheap, bounded per-process admission before body parsing or database access.
 * The persistent limiter remains authoritative across API replicas. */
export function installIngress(app: FastifyInstance) {
  const buckets = new Map<string, Bucket>();
  const active: Record<Lane, number> = { api: 0, notification: 0 };
  const leases = new WeakMap<FastifyRequest, Lane>();
  let nextSweep = 0;

  app.addHook("onRequest", async (request, reply) => {
    reply.header("Cache-Control", "no-store");
    const path = apiPath(request);
    if (!path.startsWith("/v1/") && !path.startsWith("/admin/api/")) return;
    const notification = path === notificationPath;
    const auth = path.startsWith("/v1/auth/") || path === "/admin/api/login";
    const group = notification ? "notification" : auth ? "auth" : "api";
    const limit = notification ? 600 : auth ? 40 : 180;
    // request.ip honors only the explicitly configured TRUST_PROXY addresses.
    const key = group + ":" + request.ip;
    const now = performance.now();
    if (now >= nextSweep) {
      for (const [key, bucket] of buckets) {
        if (bucket.expires <= now) buckets.delete(key);
      }
      nextSweep = now + 1000;
    }
    let bucket = buckets.get(key);
    if (bucket && bucket.expires <= now) {
      buckets.delete(key);
      bucket = undefined;
    }
    if (!bucket) {
      // Never evict active counters: rotating IPs must not reset other limits.
      if (buckets.size >= 4096) {
        return reply.header("Retry-After", "1").code(503).send({ error: "server_busy" });
      }
      bucket = { hits: 0, expires: now + 60000 };
      buckets.set(key, bucket);
    }
    if (bucket.hits >= limit) {
      return reply.header("Retry-After", String(Math.max(1, Math.ceil((bucket.expires - now) / 1000))))
        .code(429).send({ error: "rate_limited" });
    }
    bucket.hits++;
  });

  // Parsing slow/invalid/oversized bodies never holds a database gate slot.
  app.addHook("preHandler", async (request, reply) => {
    const path = apiPath(request);
    if (!path.startsWith("/v1/") && !path.startsWith("/admin/api/")) return;
    const lane: Lane = path === notificationPath ? "notification" : "api";
    if (active[lane] >= (lane === "notification" ? 4 : 12)) {
      // Pub/Sub retries non-2xx responses. Never acknowledge dropped work.
      return reply.header("Retry-After", "1").code(503).send({ error: "server_busy" });
    }
    active[lane]++;
    leases.set(request, lane);
  });
  const release = async (request: FastifyRequest) => {
    const lane = leases.get(request);
    if (lane) { leases.delete(request); active[lane]--; }
  };
  app.addHook("onResponse", release);
  app.addHook("onError", async (request) => { await release(request); });
  // Do not release on a disconnected socket while its handler is still working.
}

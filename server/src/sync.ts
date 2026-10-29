import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { exec, rows, transaction, parseJson } from "./db.js";
import { ApiError, hash } from "./security.js";
import { snapshotSchema } from "./schema.js";
import type { Auth } from "./auth.js";
export function syncRoutes(app: FastifyInstance, a: Auth) {
  app.get("/v1/garden", async (r) => {
    const u = await a.current(r);
    const [g] = await rows(
      a.pool,
      "SELECT revision,snapshot,updated_at FROM gardens WHERE user_id=?",
      [u.id],
    );
    return {
      revision: g?.revision ?? 0,
      snapshot: g?.snapshot ? parseJson(g.snapshot) : null,
      updatedAt: g?.updated_at ?? null,
    };
  });
  app.put("/v1/garden", async (r) => {
    const u = await a.current(r);
    const b = z
      .object({
        baseRevision: z.number().int().min(0).max(4294967294),
        mutationId: z.uuid(),
        snapshot: snapshotSchema,
      })
      .strict()
      .parse(r.body);
    const encoded = JSON.stringify(b.snapshot);
    const digest = hash(
      a.c,
      "snapshot",
      JSON.stringify([b.baseRevision, b.snapshot]),
    );
    return transaction(a.pool, async (db) => {
      // Serialize all writers for this account, including initial creation.
      const [owner] = await rows(
        db,
        "SELECT id FROM users WHERE id=? FOR UPDATE",
        [u.id],
      );
      if (!owner) throw new ApiError(401, "unauthorized");
      const [previous] = await rows(
        db,
        "SELECT * FROM sync_mutations WHERE user_id=? AND mutation_id=?",
        [u.id, b.mutationId],
      );
      if (previous) {
        if (previous.payload_hash !== digest)
          throw new ApiError(409, "mutation_reused");
        return { revision: previous.revision, duplicate: true };
      }
      const [current] = await rows(
        db,
        "SELECT * FROM gardens WHERE user_id=?",
        [u.id],
      );
      const revision = current?.revision ?? 0;
      if (revision !== b.baseRevision)
        throw new ApiError(409, "sync_conflict", {
          revision,
          snapshot: current?.snapshot ? parseJson(current.snapshot) : null,
          updatedAt: current?.updated_at ?? null,
        });
      const next = revision + 1;
      await exec(
        db,
        `INSERT INTO gardens(user_id,revision,snapshot) VALUES(?,?,?)
        ON DUPLICATE KEY UPDATE revision=?,snapshot=?,updated_at=NOW(3)`,
        [u.id, next, encoded, next, encoded],
      );
      await exec(
        db,
        "INSERT INTO sync_mutations(user_id,mutation_id,payload_hash,revision) VALUES(?,?,?,?)",
        [u.id, b.mutationId, digest, next],
      );
      return { revision: next, duplicate: false };
    });
  });
}

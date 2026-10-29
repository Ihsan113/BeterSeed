import { z } from "zod";
import type { FastifyInstance } from "fastify";
import type { Auth } from "./auth.js";
import { rows, type DB } from "./db.js";
export const packId = z.string().regex(/^[a-z][a-z0-9_]{0,39}$/);
export const packInput = z
  .object({
    name: z.string().trim().min(1).max(120),
    description: z.string().trim().max(2000),
    accessType: z.enum(["free", "premium"]),
    priceCoins: z.number().int().min(0).max(1000000),
    status: z.enum(["draft", "active", "hidden", "retired"]),
    minimumAppBuild: z.number().int().min(1).max(1000000000),
    displayOrder: z.number().int().min(-100000).max(100000),
  })
  .strict();
export function validOffer(b: z.infer<typeof packInput>) {
  return b.accessType === "free" ? b.priceCoins === 0 : b.priceCoins > 0;
}
export function publicPack(p: any) {
  return {
    packId: p.pack_id,
    name: p.name,
    description: p.description,
    accessType: p.access_type,
    priceCoins: Number(p.price_coins),
    status: p.status,
    minimumAppBuild: p.minimum_app_build,
    displayOrder: p.display_order,
    revision: p.revision,
  };
}
export async function catalog(db: DB, admin = false) {
  return (
    await rows(
      db,
      `SELECT p.*${admin ? ",COALESCE(o.owners,0) AS owners" : ""} FROM garden_packs p ${admin ? "LEFT JOIN (SELECT pack_id, COUNT(*) AS owners FROM entitlements GROUP BY pack_id) o ON o.pack_id=p.pack_id" : ""} ${admin ? "" : "WHERE status<>'draft'"} ORDER BY display_order,pack_id`,
    )
  ).map((p) => ({
    ...publicPack(p),
    ...(admin
      ? {
          owners: Number(p.owners),
          createdAt: p.created_at,
          updatedAt: p.updated_at,
        }
      : {}),
  }));
}
export function catalogRoutes(app: FastifyInstance, a: Auth) {
  app.get("/v1/shop/catalog", async () => ({
    version: 1,
    packs: await catalog(a.pool),
  }));
}

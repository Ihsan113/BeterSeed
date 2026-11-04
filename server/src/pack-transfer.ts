import { z } from "zod";
import { packId, packInput, publicPack, validOffer } from "./catalog.js";
import { rows, exec, type DB } from "./db.js";
import { fail } from "./security.js";

export const packDocument = z.object({
  format: z.literal("betterseed-garden-packs"), version: z.literal(1),
  packs: z.array(packInput.extend({ packId,
    // null means create. Existing revisions prevent overwriting another admin's work.
    revision: z.number().int().positive().nullable(),
  }).strict()).min(1).max(500),
}).strict().superRefine((doc, ctx) => {
  const ids = new Set<string>();
  for (const [i, p] of doc.packs.entries()) {
    if (ids.has(p.packId) || !validOffer(p) ||
        (p.packId === "default" && (p.accessType !== "free" || p.status !== "active" || p.minimumAppBuild !== 1)))
      ctx.addIssue({ code: "custom", message: "Invalid or duplicate pack", path: ["packs", i] });
    ids.add(p.packId);
  }
});
export type PackDocument = z.infer<typeof packDocument>;
export async function planPackImport(db: DB, document: PackDocument, lock = false) {
  const existing = await rows(db, `SELECT * FROM garden_packs ORDER BY pack_id${lock ? " FOR UPDATE" : ""}`);
  const byId = new Map(existing.map(p => [p.pack_id, publicPack(p)]));
  return document.packs.map(p => {
    const before = byId.get(p.packId) ?? null;
    if ((before?.revision ?? null) !== p.revision) fail(409, "catalog_changed");
    const changed = !before || Object.keys(packInput.shape).some(k =>
      before[k as keyof typeof before] !== p[k as keyof typeof p]);
    return { packId: p.packId, action: before ? (changed ? "update" : "unchanged") : "create", before, after: p };
  });
}
export async function applyPackImport(db: DB, document: PackDocument) {
  const plan = await planPackImport(db, document, true);
  for (const item of plan) {
    const p = item.after;
    const values = [p.name,p.description,p.accessType,p.priceCoins,p.status,p.minimumAppBuild,p.displayOrder];
    if (item.action === "create") await exec(db,
      "INSERT INTO garden_packs(name,description,access_type,price_coins,status,minimum_app_build,display_order,pack_id) VALUES(?,?,?,?,?,?,?,?)", [...values,p.packId]);
    if (item.action === "update") await exec(db,
      "UPDATE garden_packs SET name=?,description=?,access_type=?,price_coins=?,status=?,minimum_app_build=?,display_order=?,revision=revision+1,updated_at=NOW(3) WHERE pack_id=?", [...values,p.packId]);
  }
  return plan;
}

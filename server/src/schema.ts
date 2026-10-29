import { z } from "zod";
export const email = z
  .email()
  .max(254)
  .transform((x) => x.trim().toLowerCase());
export const password = z.string().min(12).max(128);
export const proof = z.object({
  password: z.string().max(128).optional(),
  idToken: z.string().max(10000).optional(),
  factor: z.string().max(64).default(""),
});
const count = z.number().int().min(0).max(1_000_000_000);
const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const asset = z.string().regex(/^[a-z][a-z0-9_]{0,79}$/);
export const snapshotSchema = z
  .object({
    version: z.literal(1),
    habits: z
      .array(
        z
          .object({
            id: z.string().min(1).max(128),
            title: z.string().trim().min(1).max(300),
            completed: z.boolean(),
            iconKey: z.string().max(32),
            reminderEnabled: z.boolean(),
            reminderHour: z.number().int().min(0).max(23),
            reminderMinute: z.number().int().min(0).max(59),
          })
          .strict(),
      )
      .max(2000),
    progress: z
      .object({
        version: z.literal(3),
        earned: count,
        spent: count,
        xp: count,
        credited: z.record(day, z.array(z.string().max(128)).max(2000)),
      })
      .strict(),
    day,
    cosmetics: z
      .object({
        treeSkinId: asset,
        backgroundId: asset,
        butterflyId: asset,
        wateringCanId: asset,
        fireflyId: asset,
      })
      .strict(),
    treePlacements: z.record(
      asset,
      z
        .object({
          scale: z.number().min(0.65).max(1.35),
          dx: z.number().min(-0.35).max(0.35),
          dy: z.number().min(-0.35).max(0.35),
        })
        .strict(),
    ),
    preferences: z
      .object({
        music: z.boolean(),
        effects: z.boolean(),
        motion: z.boolean(),
        motionOverride: z.boolean(),
      })
      .strict(),
  })
  .strict()
  .superRefine((v, ctx) => {
    if (Object.keys(v.treePlacements).length > 200)
      ctx.addIssue({ code: "custom", message: "Too many placements" });
    if (new Set(v.habits.map((h) => h.id)).size !== v.habits.length)
      ctx.addIssue({ code: "custom", message: "Duplicate habit ID" });
    if (v.progress.spent > v.progress.earned)
      ctx.addIssue({ code: "custom", message: "Invalid water balance" });
    if (Object.keys(v.progress.credited).length > 40000)
      ctx.addIssue({ code: "custom", message: "Too many days" });
  });
export type Snapshot = z.infer<typeof snapshotSchema>;

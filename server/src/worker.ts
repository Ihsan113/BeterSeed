import { setTimeout } from "node:timers/promises";
import { configFromEnv } from "./config.js";
import { createPool } from "./db.js";
import { providers } from "./providers.js";
import { Auth } from "./auth.js";
import { Billing } from "./billing.js";
import { deliverMail, cleanup } from "./maintenance.js";
const c = configFromEnv(),
  pool = createPool(c),
  a = new Auth(pool, c, providers(c)),
  b = new Billing(a);
let stopping = false;
for (const signal of ["SIGTERM", "SIGINT"])
  process.on(signal, () => {
    stopping = true;
  });
async function loop(name: string, interval: number, work: () => Promise<void>) {
  while (!stopping) {
    try {
      await work();
    } catch {
      console.error(
        `${name} incomplete; retry scheduled. Check service health and credentials.`,
      );
    }
    // Short waits let SIGTERM finish promptly without starving email delivery
    // behind a slow Google Play outage or a large refund reconciliation.
    for (let elapsed = 0; !stopping && elapsed < interval; elapsed += 1000)
      await setTimeout(1000);
  }
}
await Promise.all([
  loop("Email delivery", 5000, () => deliverMail(a)),
  loop("Retention cleanup", 60000, () => cleanup(a)),
  loop("Payment reconciliation", 60000, async () => {
    if (c.GOOGLE_APPLICATION_CREDENTIALS) await b.reconcile();
  }),
]);
await pool.end();

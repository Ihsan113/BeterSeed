import { configFromEnv } from "./config.js";
import { createPool } from "./db.js";
import { providers } from "./providers.js";
import { buildApp } from "./app.js";
const c = configFromEnv(),
  pool = createPool(c);
const { app } = await buildApp(c, pool, providers(c));
await app.listen({ host: c.HOST, port: c.PORT });
for (const signal of ["SIGTERM", "SIGINT"])
  process.on(signal, async () => {
    await app.close();
    await pool.end();
    process.exit(0);
  });

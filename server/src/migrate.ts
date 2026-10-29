import { readFile, readdir } from "node:fs/promises";
import { configFromEnv } from "./config.js";
import { createPool } from "./db.js";
export async function migrate(pool: ReturnType<typeof createPool>) {
  const db = await pool.getConnection();
  try {
    await db.query("SELECT GET_LOCK('betterseed_migrations', 30)");
    const [lock] = await db.query<any[]>(
      "SELECT IS_USED_LOCK('betterseed_migrations') = CONNECTION_ID() AS owned",
    );
    if (!lock[0]?.owned) throw Error("Migration lock unavailable");
    const directory = new URL("../migrations/", import.meta.url);
    for (const name of (await readdir(directory))
      .filter((n) => /^\d+_.*\.sql$/.test(n))
      .sort()) {
      const sql = await readFile(new URL(name, directory), "utf8");
      for (const statement of sql.split(";"))
        if (statement.trim()) await db.query(statement);
    }
  } finally {
    await db.query("SELECT RELEASE_LOCK('betterseed_migrations')");
    db.release();
  }
}
if (/migrate\.(ts|js)$/.test(process.argv[1] ?? "")) {
  const pool = createPool(configFromEnv());
  await migrate(pool);
  await pool.end();
  console.log("Database schema ready.");
}

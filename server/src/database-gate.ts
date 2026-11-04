import type { Pool, PoolConnection } from "mysql2/promise";
import { createPool, rows } from "./db.js";
import type { Config } from "./config.js";
import { fail } from "./security.js";

/** Cross-process reader/writer gate. A separate pool avoids holding all data
 * connections while requests wait for maintenance to finish. Every API request
 * and worker job holds a shared lock; restore holds the exclusive lock. */
export class DatabaseGate {
  private pool: Pool;
  constructor(c: Config) {
    this.pool = createPool(c, { connectionLimit: 16, waitForConnections: false });
  }
  async acquire(exclusive = false): Promise<() => Promise<void>> {
    let db: PoolConnection | undefined;
    try {
      db = await this.pool.getConnection();
      await db.query("SET SESSION innodb_lock_wait_timeout=5");
      await db.beginTransaction();
      const locked = await rows(db,
        `SELECT id FROM database_gate WHERE id=1 ${exclusive ? "FOR UPDATE" : "FOR SHARE"}`);
      if (locked.length !== 1) throw Error("Database gate missing");
    } catch {
      if (db) { await db.rollback().catch(() => {}); db.release(); }
      return fail(503, "database_busy");
    }
    const held = db;
    let released = false;
    return async () => {
      if (released) return;
      released = true;
      try { await held.rollback(); } finally { held.release(); }
    };
  }
  async run<T>(work: () => Promise<T>, exclusive = false): Promise<T> {
    const release = await this.acquire(exclusive);
    try { return await work(); } finally { await release(); }
  }
  close() { return this.pool.end(); }
}

import mysql, {
  type Pool,
  type PoolConnection,
  type RowDataPacket,
  type ResultSetHeader,
} from "mysql2/promise";
import type { Config } from "./config.js";
export type DB = Pool | PoolConnection;
export function createPool(c: Config) {
  const pool = mysql.createPool({
    host: c.MYSQL_HOST,
    port: c.MYSQL_PORT,
    user: c.MYSQL_USER,
    password: c.MYSQL_PASSWORD,
    database: c.MYSQL_DATABASE,
    connectionLimit: 12,
    timezone: "Z",
    charset: "utf8mb4",
    supportBigNumbers: true,
    bigNumberStrings: false,
    multipleStatements: false,
    enableKeepAlive: true,
  });
  // SQL NOW() and JavaScript dates must agree even on a non-UTC VPS.
  pool.on("connection", (connection) => {
    connection.query("SET time_zone = '+00:00'");
  });
  return pool;
}
export async function rows<T = Record<string, any>>(
  db: DB,
  sql: string,
  values: any[] = [],
): Promise<T[]> {
  return (await db.execute<RowDataPacket[]>(sql, values))[0] as T[];
}
export async function exec(db: DB, sql: string, values: any[] = []) {
  return (await db.execute<ResultSetHeader>(sql, values))[0];
}
export async function transaction<T>(
  pool: Pool,
  work: (db: PoolConnection) => Promise<T>,
): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    const db = await pool.getConnection();
    try {
      await db.beginTransaction();
      const result = await work(db);
      await db.commit();
      return result;
    } catch (error) {
      await db.rollback();
      if ((error as any).code !== "ER_LOCK_DEADLOCK" || attempt >= 2)
        throw error;
    } finally {
      db.release();
    }
    await new Promise((resolve) => setTimeout(resolve, 20 * (attempt + 1)));
  }
}
export function parseJson(value: any): any {
  return typeof value === "string" ? JSON.parse(value) : value;
}

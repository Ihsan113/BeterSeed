import type { Auth } from "./auth.js";
import { exec, rows, transaction } from "./db.js";
import { decrypt } from "./security.js";
export async function deliverMail(a: Auth) {
  for (let i = 0; i < 20; i++) {
    const item = await transaction(a.pool, async (db) => {
      const [row] = await rows(
        db,
        `SELECT * FROM email_outbox WHERE next_attempt<=NOW(3) AND expires_at>NOW(3)
        AND (lease_until IS NULL OR lease_until<NOW(3)) ORDER BY next_attempt LIMIT 1 FOR UPDATE SKIP LOCKED`,
      );
      if (row)
        await exec(
          db,
          "UPDATE email_outbox SET lease_until=DATE_ADD(NOW(3),INTERVAL 1 MINUTE) WHERE id=?",
          [row.id],
        );
      return row;
    });
    if (!item) break;
    try {
      await a.p.sendMail(JSON.parse(decrypt(a.c, item.payload_cipher)));
      await exec(a.pool, "DELETE FROM email_outbox WHERE id=?", [item.id]);
    } catch {
      await exec(
        a.pool,
        `UPDATE email_outbox SET attempts=attempts+1,lease_until=NULL,
        next_attempt=DATE_ADD(NOW(3),INTERVAL ? SECOND) WHERE id=?`,
        [Math.min(120, 10 * 2 ** item.attempts), item.id],
      );
    }
  }
}
export async function cleanup(a: Auth) {
  for (const table of [
    "refresh_receipts",
    "admin_sessions",
    "challenges",
    "used_refresh",
    "rate_limits",
    "email_outbox",
  ]) {
    await exec(a.pool, `DELETE FROM ${table} WHERE expires_at<NOW(3)`);
  }
  await exec(
    a.pool,
    "DELETE FROM admin_audit WHERE created_at<DATE_SUB(NOW(3),INTERVAL 180 DAY)",
  );
  await exec(a.pool, "DELETE FROM sessions WHERE refresh_until<NOW(3)");
  await exec(
    a.pool,
    `UPDATE admin_audit aa JOIN users u ON u.id=aa.target_id
    SET aa.target_id=NULL,aa.reason='Account expired',aa.details=NULL
    WHERE u.verified=0 AND u.created_at<DATE_SUB(NOW(3),INTERVAL 7 DAY)
    AND NOT EXISTS (SELECT 1 FROM pending_email_changes ec WHERE ec.user_id=u.id)`,
  );
  await exec(
    a.pool,
    "DELETE FROM users WHERE verified=0 AND created_at<DATE_SUB(NOW(3),INTERVAL 7 DAY) AND NOT EXISTS (SELECT 1 FROM pending_email_changes ec WHERE ec.user_id=users.id)",
  );
  await exec(
    a.pool,
    "UPDATE users SET totp_pending=NULL,totp_pending_until=NULL WHERE totp_pending_until<NOW(3)",
  );
}

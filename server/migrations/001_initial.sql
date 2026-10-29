CREATE TABLE IF NOT EXISTS users (
 id CHAR(36) PRIMARY KEY,
 email VARCHAR(254) NOT NULL UNIQUE,
 provider ENUM('email','google') NOT NULL,
 google_sub VARCHAR(255) UNIQUE,
 password_hash VARCHAR(255),
 verified BOOLEAN NOT NULL DEFAULT FALSE,
 totp_secret TEXT,
 totp_pending TEXT,
 totp_pending_until DATETIME(3),
 totp_last_step BIGINT NOT NULL DEFAULT -1,
 billing_id CHAR(64) NOT NULL UNIQUE,
 legal_version VARCHAR(32) NOT NULL,
 created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
);
CREATE TABLE IF NOT EXISTS sessions (
 id CHAR(36) PRIMARY KEY, user_id CHAR(36) NOT NULL,
 access_hash CHAR(64) NOT NULL UNIQUE, refresh_hash CHAR(64) NOT NULL UNIQUE,
 access_until DATETIME(3) NOT NULL, refresh_until DATETIME(3) NOT NULL,
 created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS used_refresh (
 token_hash CHAR(64) PRIMARY KEY, user_id CHAR(36) NOT NULL, expires_at DATETIME(3) NOT NULL,
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS challenges (
 id CHAR(36) PRIMARY KEY, user_id CHAR(36) NOT NULL,
 purpose ENUM('verify','reset','login') NOT NULL,
 proof_hash CHAR(64) NOT NULL, attempts INT NOT NULL DEFAULT 0,
 expires_at DATETIME(3) NOT NULL,
 INDEX(user_id, purpose),
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS recovery_codes (
 user_id CHAR(36) NOT NULL, code_hash CHAR(64) NOT NULL, PRIMARY KEY(user_id, code_hash),
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS rate_limits (
 bucket CHAR(64) PRIMARY KEY, hits INT NOT NULL, expires_at DATETIME(3) NOT NULL,
 INDEX(expires_at)
);
CREATE TABLE IF NOT EXISTS gardens (
 user_id CHAR(36) PRIMARY KEY, revision INT UNSIGNED NOT NULL DEFAULT 0,
 snapshot JSON, updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS sync_mutations (
 user_id CHAR(36) NOT NULL, mutation_id CHAR(36) NOT NULL, payload_hash CHAR(64) NOT NULL,
 revision INT UNSIGNED NOT NULL, created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 PRIMARY KEY(user_id, mutation_id),
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS wallets (
 user_id CHAR(36) PRIMARY KEY, balance BIGINT NOT NULL DEFAULT 0, revision INT UNSIGNED NOT NULL DEFAULT 0,
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS entitlements (
 user_id CHAR(36) NOT NULL, pack_id VARCHAR(40) NOT NULL, cost INT NOT NULL,
 created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3), PRIMARY KEY(user_id, pack_id),
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
-- Keep a keyed, anonymous token fingerprint after deletion to prevent re-grant.
CREATE TABLE IF NOT EXISTS purchases (
 token_hash CHAR(64) PRIMARY KEY, user_id CHAR(36), product_id VARCHAR(80) NOT NULL,
 token_cipher TEXT, coins INT NOT NULL, state ENUM('credited','consumed','voided') NOT NULL,
 created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3), checked_at DATETIME(3),
 INDEX(user_id), INDEX(state,checked_at),
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE TABLE IF NOT EXISTS coin_ledger (
 id BIGINT AUTO_INCREMENT PRIMARY KEY, user_id CHAR(36),
 entry_key VARCHAR(120) NOT NULL UNIQUE, delta INT NOT NULL,
 created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE TABLE IF NOT EXISTS email_outbox (
 id CHAR(36) PRIMARY KEY, user_id CHAR(36) NOT NULL, payload_cipher TEXT NOT NULL,
 attempts INT NOT NULL DEFAULT 0, next_attempt DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 lease_until DATETIME(3), expires_at DATETIME(3) NOT NULL,
 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

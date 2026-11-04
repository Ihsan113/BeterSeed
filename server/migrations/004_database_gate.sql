-- Operational coordination only, deliberately excluded from portable backups.
CREATE TABLE IF NOT EXISTS database_gate (
 id TINYINT PRIMARY KEY
);
INSERT IGNORE INTO database_gate(id) VALUES(1);

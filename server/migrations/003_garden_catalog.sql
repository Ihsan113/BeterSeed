CREATE TABLE IF NOT EXISTS garden_packs (
 pack_id VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
 name VARCHAR(120) NOT NULL, description VARCHAR(2000) NOT NULL,
 access_type ENUM('free','premium') NOT NULL,
 price_coins INT UNSIGNED NOT NULL DEFAULT 0,
 status ENUM('draft','active','hidden','retired') NOT NULL DEFAULT 'draft',
 minimum_app_build INT UNSIGNED NOT NULL DEFAULT 57,
 display_order INT NOT NULL DEFAULT 0, revision INT UNSIGNED NOT NULL DEFAULT 1,
 legacy_price INT UNSIGNED NULL,
 created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 CHECK (price_coins<=1000000),
 CHECK ((access_type='free' AND price_coins=0) OR (access_type='premium' AND price_coins>0))
);
INSERT IGNORE INTO garden_packs(pack_id,name,description,access_type,price_coins,status,minimum_app_build,display_order,legacy_price) VALUES
 ('default','Original Garden','Your original garden. Always yours.','free',0,'active',1,0,NULL),
 ('moonlight','Moonlight Night Pack','A moonlit garden with glowing fireflies.','premium',180,'active',1,10,180),
 ('sakura','Sakura Blossom Garden','A flowering garden with a soft animated sky.','premium',280,'active',1,20,280),
 ('golden_autumn','Golden Autumn Garden','A warm maple garden with amber butterflies.','premium',420,'active',1,30,420);
CREATE TABLE IF NOT EXISTS pack_acquisitions (
 id CHAR(36) PRIMARY KEY,user_id CHAR(36),pack_id VARCHAR(40) NOT NULL,
 price_coins INT UNSIGNED NOT NULL,catalog_revision INT UNSIGNED NOT NULL,
 access_type ENUM('free','premium') NOT NULL,
 created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE SET NULL,
 INDEX(user_id,pack_id)
);

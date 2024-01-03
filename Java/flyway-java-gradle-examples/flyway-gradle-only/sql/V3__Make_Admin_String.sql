ALTER TABLE user ADD admin_tmp int NOT NULL DEFAULT 'false';

UPDATE user SET admin_tmp = 'true' where admin = 1;

ALTER TABLE user DROP admin;
ALTER TABLE user rename admin_tmp to admin;
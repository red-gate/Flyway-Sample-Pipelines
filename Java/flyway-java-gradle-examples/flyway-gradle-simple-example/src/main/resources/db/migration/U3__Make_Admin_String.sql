ALTER TABLE user ADD admin_tmp int NOT NULL DEFAULT 0;

UPDATE user SET admin_tmp = 1 where admin = 'true';

ALTER TABLE user DROP admin;
ALTER TABLE user rename admin_tmp to admin;
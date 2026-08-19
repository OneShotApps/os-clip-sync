CREATE TABLE IF NOT EXISTS clip_sync_core.device (
  id INTEGER GENERATED ALWAYS AS IDENTITY,
  uid CHAR(32) NOT NULL,
  account_id INTEGER NOT NULL,
  platform VARCHAR(20) NOT NULL,
  reported_name VARCHAR(100) NOT NULL,
  custom_name VARCHAR(100),
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  deleted_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT pk_device PRIMARY KEY (id),
  CONSTRAINT uk_device_uid UNIQUE (uid),
  CONSTRAINT fk_device_account FOREIGN KEY (account_id)
    REFERENCES clip_sync_core.account (id),
  CONSTRAINT ck_device_platform
    CHECK (platform IN ('windows', 'macos', 'ios', 'android'))
);

CREATE INDEX IF NOT EXISTS idx_device_account_id_deleted_at
  ON clip_sync_core.device (account_id, deleted_at);

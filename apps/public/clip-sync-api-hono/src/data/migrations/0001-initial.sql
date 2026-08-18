CREATE SCHEMA IF NOT EXISTS clip_sync_core;
CREATE SCHEMA IF NOT EXISTS clip_sync_auth_event;
CREATE SCHEMA IF NOT EXISTS clip_sync_delivery_event;

CREATE TABLE IF NOT EXISTS clip_sync_core.authentication_provider (
  id CHAR(1) NOT NULL,
  name VARCHAR(50) NOT NULL,
  enum_name VARCHAR(50) NOT NULL,
  CONSTRAINT pk_authentication_provider PRIMARY KEY (id),
  CONSTRAINT uk_authentication_provider_name UNIQUE (name),
  CONSTRAINT uk_authentication_provider_enum_name UNIQUE (enum_name)
);

CREATE TABLE IF NOT EXISTS clip_sync_core.account (
  id INTEGER GENERATED ALWAYS AS IDENTITY,
  uid CHAR(32) NOT NULL,
  primary_email VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  deleted_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT pk_account PRIMARY KEY (id),
  CONSTRAINT uk_account_uid UNIQUE (uid),
  CONSTRAINT uk_account_primary_email_deleted_at UNIQUE (primary_email, deleted_at)
);

CREATE TABLE IF NOT EXISTS clip_sync_core.account_identifier (
  id INTEGER GENERATED ALWAYS AS IDENTITY,
  account_id INTEGER NOT NULL,
  authentication_provider_id CHAR(1) NOT NULL,
  provider_identifier VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  deleted_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT pk_account_identifier PRIMARY KEY (id),
  CONSTRAINT fk_account_identifier_account FOREIGN KEY (account_id)
    REFERENCES clip_sync_core.account (id),
  CONSTRAINT fk_account_identifier_authentication_provider
    FOREIGN KEY (authentication_provider_id)
    REFERENCES clip_sync_core.authentication_provider (id),
  CONSTRAINT uk_account_identifier_provider_value_deleted_at
    UNIQUE (authentication_provider_id, provider_identifier, deleted_at)
);

CREATE INDEX IF NOT EXISTS idx_account_identifier_account_id_deleted_at
  ON clip_sync_core.account_identifier (account_id, deleted_at);

CREATE TABLE IF NOT EXISTS clip_sync_core.clipboard (
  id INTEGER GENERATED ALWAYS AS IDENTITY,
  uid CHAR(32) NOT NULL,
  account_id INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  deleted_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT pk_clipboard PRIMARY KEY (id),
  CONSTRAINT uk_clipboard_uid UNIQUE (uid),
  CONSTRAINT uk_clipboard_account_id_deleted_at UNIQUE (account_id, deleted_at),
  CONSTRAINT fk_clipboard_account FOREIGN KEY (account_id)
    REFERENCES clip_sync_core.account (id)
);

CREATE INDEX IF NOT EXISTS idx_clipboard_account_id_deleted_at
  ON clip_sync_core.clipboard (account_id, deleted_at);

CREATE TABLE IF NOT EXISTS clip_sync_auth_event.login_code (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  uid CHAR(32) NOT NULL,
  email VARCHAR(255) NOT NULL,
  code_hash CHAR(64) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ NOT NULL,
  attempts SMALLINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT pk_login_code PRIMARY KEY (id),
  CONSTRAINT uk_login_code_uid UNIQUE (uid),
  CONSTRAINT ck_login_code_attempts CHECK (attempts >= 0 AND attempts <= 5)
);

CREATE INDEX IF NOT EXISTS idx_login_code_email_created_at
  ON clip_sync_auth_event.login_code (email, created_at);

CREATE TABLE IF NOT EXISTS clip_sync_delivery_event.delivery_event (
  id BIGINT GENERATED ALWAYS AS IDENTITY,
  uid CHAR(32) NOT NULL,
  account_uid CHAR(32) NOT NULL,
  clipboard_uid CHAR(32) NOT NULL,
  item_uid CHAR(32) NOT NULL,
  source_client_uid CHAR(32) NOT NULL,
  content_kind VARCHAR(20) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT pk_delivery_event PRIMARY KEY (id),
  CONSTRAINT uk_delivery_event_uid UNIQUE (uid),
  CONSTRAINT ck_delivery_event_content_kind CHECK (content_kind IN ('text', 'image'))
);

CREATE INDEX IF NOT EXISTS idx_delivery_event_account_uid_created_at
  ON clip_sync_delivery_event.delivery_event (account_uid, created_at);
CREATE INDEX IF NOT EXISTS idx_delivery_event_clipboard_uid_created_at
  ON clip_sync_delivery_event.delivery_event (clipboard_uid, created_at);

INSERT INTO clip_sync_core.authentication_provider (id, name, enum_name)
VALUES
  ('E', 'Email code', 'EMAIL_CODE'),
  ('G', 'Google OpenID Connect', 'GOOGLE_OIDC')
ON CONFLICT (id) DO NOTHING;

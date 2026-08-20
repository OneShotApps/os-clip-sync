import {
  bigint,
  char,
  check,
  index,
  integer,
  pgSchema,
  smallint,
  timestamp,
  unique,
  varchar,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';

const core = pgSchema('clip_sync_core');
const authEvent = pgSchema('clip_sync_auth_event');
const deliveryEventSchema = pgSchema('clip_sync_delivery_event');

export const authenticationProvider = core.table(
  'authentication_provider',
  {
    id: char('id', { length: 1 }).primaryKey(),
    name: varchar('name', { length: 50 }).notNull(),
    enumName: varchar('enum_name', { length: 50 }).notNull(),
  },
  (table) => [
    unique('uk_authentication_provider_name').on(table.name),
    unique('uk_authentication_provider_enum_name').on(table.enumName),
  ],
);

export const account = core.table(
  'account',
  {
    id: integer('id').primaryKey().generatedAlwaysAsIdentity(),
    uid: char('uid', { length: 32 }).notNull(),
    primaryEmail: varchar('primary_email', { length: 255 }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    unique('uk_account_uid').on(table.uid),
    unique('uk_account_primary_email_deleted_at').on(table.primaryEmail, table.deletedAt),
  ],
);

export const accountIdentifier = core.table(
  'account_identifier',
  {
    id: integer('id').primaryKey().generatedAlwaysAsIdentity(),
    accountId: integer('account_id')
      .notNull()
      .references(() => account.id),
    authenticationProviderId: char('authentication_provider_id', { length: 1 })
      .notNull()
      .references(() => authenticationProvider.id),
    providerIdentifier: varchar('provider_identifier', { length: 255 }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    index('idx_account_identifier_account_id_deleted_at').on(table.accountId, table.deletedAt),
    unique('uk_account_identifier_provider_value_deleted_at').on(
      table.authenticationProviderId,
      table.providerIdentifier,
      table.deletedAt,
    ),
  ],
);

export const clipboard = core.table(
  'clipboard',
  {
    id: integer('id').primaryKey().generatedAlwaysAsIdentity(),
    uid: char('uid', { length: 32 }).notNull(),
    accountId: integer('account_id')
      .notNull()
      .references(() => account.id),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    unique('uk_clipboard_uid').on(table.uid),
    unique('uk_clipboard_account_id_deleted_at').on(table.accountId, table.deletedAt),
    index('idx_clipboard_account_id_deleted_at').on(table.accountId, table.deletedAt),
  ],
);

export const device = core.table(
  'device',
  {
    id: integer('id').primaryKey().generatedAlwaysAsIdentity(),
    uid: char('uid', { length: 32 }).notNull(),
    accountId: integer('account_id')
      .notNull()
      .references(() => account.id),
    platform: varchar('platform', { length: 20 }).notNull(),
    reportedName: varchar('reported_name', { length: 100 }).notNull(),
    customName: varchar('custom_name', { length: 100 }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    unique('uk_device_account_id_uid_deleted_at').on(table.accountId, table.uid, table.deletedAt),
    index('idx_device_account_id_deleted_at').on(table.accountId, table.deletedAt),
    check('ck_device_platform', sql`${table.platform} IN ('windows', 'macos', 'ios', 'android')`),
  ],
);

export const loginCode = authEvent.table(
  'login_code',
  {
    id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
    uid: char('uid', { length: 32 }).notNull(),
    email: varchar('email', { length: 255 }).notNull(),
    codeHash: char('code_hash', { length: 64 }).notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    usedAt: timestamp('used_at', { withTimezone: true }).notNull(),
    attempts: smallint('attempts').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    unique('uk_login_code_uid').on(table.uid),
    index('idx_login_code_email_created_at').on(table.email, table.createdAt),
    check('ck_login_code_attempts', sql`${table.attempts} >= 0 AND ${table.attempts} <= 5`),
  ],
);

export const deliveryEvent = deliveryEventSchema.table(
  'delivery_event',
  {
    id: bigint('id', { mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
    uid: char('uid', { length: 32 }).notNull(),
    accountUid: char('account_uid', { length: 32 }).notNull(),
    clipboardUid: char('clipboard_uid', { length: 32 }).notNull(),
    itemUid: char('item_uid', { length: 32 }).notNull(),
    sourceClientUid: char('source_client_uid', { length: 32 }).notNull(),
    contentKind: varchar('content_kind', { length: 20 }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    unique('uk_delivery_event_uid').on(table.uid),
    index('idx_delivery_event_account_uid_created_at').on(table.accountUid, table.createdAt),
    index('idx_delivery_event_clipboard_uid_created_at').on(table.clipboardUid, table.createdAt),
    check('ck_delivery_event_content_kind', sql`${table.contentKind} IN ('text', 'image')`),
  ],
);

export const postgresTables = Object.freeze({
  account,
  accountIdentifier,
  authenticationProvider,
  clipboard,
  device,
  deliveryEvent,
  loginCode,
});

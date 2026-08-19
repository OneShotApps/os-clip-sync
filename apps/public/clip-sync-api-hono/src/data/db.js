import { and, desc, eq, inArray } from 'drizzle-orm';
import { drizzle } from 'drizzle-orm/postgres-js';
import mongoose from 'mongoose';
import postgres from 'postgres';

import { ZERO_DATE, ZERO_EPOCH } from '../constants.js';
import { ClipboardItem } from './models/clipboard-item.js';
import { postgresTables } from './models/postgres-schema.js';

let postgresClient;
let database;

/**
 * Opens PostgreSQL and MongoDB connections for the API process.
 *
 * @param {{postgresUrl: string, mongoUrl: string}} config - Database connection values.
 * @returns {Promise<void>}
 */
export async function connectDatabases(config) {
  postgresClient = postgres(config.postgresUrl, { max: 10 });
  database = drizzle(postgresClient);
  await mongoose.connect(config.mongoUrl, { autoIndex: true });
  await Promise.all([postgresClient`SELECT 1`, ClipboardItem.init()]);
}

/** Closes both database connections during graceful shutdown. */
export async function closeDatabases() {
  await Promise.all([postgresClient?.end({ timeout: 5 }), mongoose.disconnect()]);
}

function getPostgresTable(tableName) {
  const table = postgresTables[tableName];
  if (!table) {
    throw new Error(`Unknown PostgreSQL table: ${tableName}`);
  }
  return table;
}

function makeConditions(table, data, includeDeleted) {
  const conditions = Object.entries(data).map(([key, value]) => {
    if (!table[key]) {
      throw new Error(`Unknown field ${key} for repository query.`);
    }
    return eq(table[key], value);
  });

  if (!includeDeleted && table.deletedAt) {
    conditions.push(eq(table.deletedAt, ZERO_DATE));
  }
  return conditions;
}

/**
 * Finds one active PostgreSQL record using repository-owned criteria.
 *
 * @param {object} payload - Generic repository query.
 * @returns {Promise<object|null>} Matching record or null.
 */
export async function findOneByData({
  table: tableName,
  data,
  includeDeleted = false,
  executor = database,
}) {
  const table = getPostgresTable(tableName);
  const conditions = makeConditions(table, data, includeDeleted);
  const rows = await executor
    .select()
    .from(table)
    .where(conditions.length === 1 ? conditions[0] : and(...conditions))
    .limit(1);
  return rows[0] ?? null;
}

/**
 * Finds active PostgreSQL records using repository-owned criteria.
 *
 * @param {object} payload - Generic repository query.
 * @returns {Promise<object[]>} Matching records.
 */
export async function findManyByData({
  table: tableName,
  data,
  includeDeleted = false,
  executor = database,
}) {
  const table = getPostgresTable(tableName);
  const conditions = makeConditions(table, data, includeDeleted);
  return executor
    .select()
    .from(table)
    .where(conditions.length === 1 ? conditions[0] : and(...conditions));
}

/**
 * Creates one PostgreSQL record and returns it.
 *
 * @param {object} payload - Generic repository create payload.
 * @returns {Promise<object>} Created record.
 */
export async function createOne({ table: tableName, data, executor = database }) {
  const table = getPostgresTable(tableName);
  const rows = await executor.insert(table).values(data).returning();
  return rows[0];
}

/**
 * Updates one PostgreSQL record selected by repository-owned criteria.
 *
 * @param {object} payload - Generic repository update payload.
 * @returns {Promise<object|null>} Updated record or null.
 */
export async function updateOneByData({
  table: tableName,
  criteria,
  updates,
  executor = database,
}) {
  const table = getPostgresTable(tableName);
  const conditions = makeConditions(table, criteria, true);
  const rows = await executor
    .update(table)
    .set(updates)
    .where(conditions.length === 1 ? conditions[0] : and(...conditions))
    .returning();
  return rows[0] ?? null;
}

/**
 * Runs a repository-owned unit of work in one PostgreSQL transaction.
 *
 * @template T
 * @param {(executor: object) => Promise<T>} callback - Repository work to run atomically.
 * @returns {Promise<T>} Callback result.
 */
export async function runPostgresTransaction(callback) {
  return database.transaction(callback);
}

/**
 * Creates one MongoDB clipboard item.
 *
 * @param {object} data - Validated document values.
 * @returns {Promise<object>} Plain persisted document.
 */
export async function createClipboardItemDocument(data) {
  const document = await ClipboardItem.create(data);
  return document.toObject();
}

/**
 * Lists active clipboard items for one owner, newest first.
 *
 * @param {object} payload - Owner and pagination criteria.
 * @returns {Promise<{items: object[], total: number}>} Page and active count.
 */
export async function findClipboardItemDocuments({ accountUid, page, pageSize }) {
  const filter = { accountUid, deletedAt: ZERO_EPOCH };
  const [items, total] = await Promise.all([
    ClipboardItem.find(filter)
      .select('-imageData')
      .sort({ createdAt: -1 })
      .skip((page - 1) * pageSize)
      .limit(pageSize)
      .lean(),
    ClipboardItem.countDocuments(filter),
  ]);
  return { items, total };
}

/**
 * Finds one active clipboard item by its public UID and owner.
 *
 * @param {{accountUid: string, itemUid: string}} payload - Isolation-safe lookup keys.
 * @returns {Promise<object|null>} Plain document or null.
 */
export async function findClipboardItemDocument({ accountUid, itemUid }) {
  return ClipboardItem.findOne({ uid: itemUid, accountUid, deletedAt: ZERO_EPOCH }).lean();
}

/**
 * Soft deletes one clipboard item using both public UID and account ownership.
 *
 * @param {{accountUid: string, itemUid: string, deletedAt: number}} payload - Delete values.
 * @returns {Promise<object|null>} Deleted document or null.
 */
export async function softDeleteClipboardItemDocument({ accountUid, itemUid, deletedAt }) {
  return ClipboardItem.findOneAndUpdate(
    { uid: itemUid, accountUid, deletedAt: ZERO_EPOCH },
    { deletedAt },
    { new: true, lean: true },
  );
}

/**
 * Permanently removes a just-created item as compensation when event persistence fails.
 * This is not exposed as product deletion behavior.
 *
 * @param {{accountUid: string, itemUid: string}} payload - Exact item keys.
 * @returns {Promise<void>}
 */
export async function compensateClipboardItemCreate({ accountUid, itemUid }) {
  await ClipboardItem.deleteOne({ uid: itemUid, accountUid });
}

/**
 * Returns event rows for diagnostics and tests, newest first.
 *
 * @param {{accountUid: string, limit: number}} payload - Owner and row limit.
 * @returns {Promise<object[]>} Matching event rows.
 */
export async function findDeliveryEvents({ accountUid, limit }) {
  const table = postgresTables.deliveryEvent;
  return database
    .select()
    .from(table)
    .where(eq(table.accountUid, accountUid))
    .orderBy(desc(table.createdAt))
    .limit(limit);
}

/**
 * Finds source-client metadata for a known set of owner-scoped clipboard items.
 *
 * @param {{accountUid: string, itemUids: string[]}} payload - Owner and item UIDs.
 * @returns {Promise<object[]>} Matching delivery event rows.
 */
export async function findDeliveryEventsByItemUids({ accountUid, itemUids }) {
  if (itemUids.length === 0) return [];
  const table = postgresTables.deliveryEvent;
  return database
    .select()
    .from(table)
    .where(and(eq(table.accountUid, accountUid), inArray(table.itemUid, itemUids)));
}

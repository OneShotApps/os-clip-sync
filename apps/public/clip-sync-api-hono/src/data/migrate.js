import { readFile } from 'node:fs/promises';

import postgres from 'postgres';

import { loadConfig } from '../config.js';

const config = loadConfig();
const sql = postgres(config.postgresUrl, { max: 1 });

try {
  const migrationUrl = new URL('./migrations/0001-initial.sql', import.meta.url);
  const migration = await readFile(migrationUrl, 'utf8');
  await sql.unsafe(migration);
  console.log('Clip Sync database migration completed.');
} finally {
  await sql.end({ timeout: 5 });
}

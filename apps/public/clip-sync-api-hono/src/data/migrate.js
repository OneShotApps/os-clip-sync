import { readdir, readFile } from 'node:fs/promises';

import postgres from 'postgres';

import { loadConfig } from '../config.js';

const config = loadConfig();
const sql = postgres(config.postgresUrl, { max: 1 });

try {
  const migrationsUrl = new URL('./migrations/', import.meta.url);
  const migrationFiles = (await readdir(migrationsUrl))
    .filter((fileName) => fileName.endsWith('.sql'))
    .sort();
  for (const fileName of migrationFiles) {
    const migration = await readFile(new URL(fileName, migrationsUrl), 'utf8');
    await sql.unsafe(migration);
    console.log(`Applied Clip Sync database migration ${fileName}.`);
  }
} finally {
  await sql.end({ timeout: 5 });
}

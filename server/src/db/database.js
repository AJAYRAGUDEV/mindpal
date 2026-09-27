import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

import { MIGRATIONS } from './migrations.js';

/**
 * The caregiver database.
 *
 * SQLite through node:sqlite, which is built into Node 22+ — no native module
 * to compile, nothing to install, and nothing that can fail on a Render
 * build. That matters more than it sounds: this project already lost an
 * afternoon to a native build hook, and the whole backend still has exactly
 * two dependencies.
 *
 * WHERE THE FILE LIVES, AND THE WARNING THAT GOES WITH IT. CAREGIVER_DB_PATH,
 * or ./data/caregiver.db. On Render's free tier the filesystem is EPHEMERAL:
 * the file is wiped on every deploy and every restart, taking accounts and
 * reminders with it. That is survivable for a demo — the fictional accounts
 * are re-seeded on boot — but it is not storage, and nothing here pretends
 * otherwise. A real deployment needs a Render persistent disk or a hosted
 * Postgres.
 */

let db = null;

export function openDatabase(path = process.env.CAREGIVER_DB_PATH ?? './data/caregiver.db') {
  if (db) return db;

  if (path !== ':memory:') {
    mkdirSync(dirname(path), { recursive: true });
  }

  db = new DatabaseSync(path);

  // Foreign keys are OFF by default in SQLite, which would make every
  // ON DELETE CASCADE above decorative.
  db.exec('PRAGMA foreign_keys = ON');
  // WAL survives a crash mid-write better than the default journal.
  if (path !== ':memory:') db.exec('PRAGMA journal_mode = WAL');

  migrate(db);
  return db;
}

/** For tests: a fresh in-memory database, migrated, with no shared state. */
export function openTestDatabase() {
  const fresh = new DatabaseSync(':memory:');
  fresh.exec('PRAGMA foreign_keys = ON');
  migrate(fresh);
  return fresh;
}

export function getDatabase() {
  if (!db) throw new Error('openDatabase() has not been called.');
  return db;
}

export function closeDatabase() {
  if (db) {
    db.close();
    db = null;
  }
}

/**
 * Applies every migration that has not run yet, each in its own transaction.
 *
 * A migration that throws rolls back and stops the process: a half-applied
 * schema is worse than a refusal to start, because the app would then run
 * against a shape nobody has ever tested.
 */
function migrate(database) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id          INTEGER PRIMARY KEY,
      name        TEXT NOT NULL,
      applied_at  TEXT NOT NULL
    )
  `);

  const applied = new Set(
    database.prepare('SELECT id FROM schema_migrations').all().map((row) => row.id),
  );

  for (const migration of MIGRATIONS) {
    if (applied.has(migration.id)) continue;

    database.exec('BEGIN');
    try {
      database.exec(migration.sql);
      database
        .prepare('INSERT INTO schema_migrations (id, name, applied_at) VALUES (?, ?, ?)')
        .run(migration.id, migration.name, new Date().toISOString());
      database.exec('COMMIT');
      console.log(`[db] migration ${migration.id} applied: ${migration.name}`);
    } catch (error) {
      database.exec('ROLLBACK');
      throw new Error(
        `Migration ${migration.id} (${migration.name}) failed: ${error.message}`,
      );
    }
  }
}

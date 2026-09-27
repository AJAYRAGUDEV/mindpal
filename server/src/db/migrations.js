/**
 * The caregiver schema, as an ordered list of migrations.
 *
 * WHY MIGRATIONS AND NOT A CREATE-TABLE-IF-NOT-EXISTS BLOB. Once a demo has
 * run once, the database file has data in it. Changing the schema then means
 * either losing that data or writing the change as a step — and a numbered,
 * recorded step is the only version of that which is safe to run twice.
 * Each entry runs exactly once, inside a transaction, and is recorded in
 * schema_migrations. Editing an applied migration does nothing; add a new one.
 *
 * WHAT IS DELIBERATELY NOT HERE. No patient health records, no diagnoses, no
 * medication lists. This app does not hold clinical data, and a schema is the
 * cheapest place to make that refusal permanent: a column that does not exist
 * cannot be filled in later by accident.
 */

export const MIGRATIONS = [
  {
    id: 1,
    name: 'caregiver accounts, patients, links and permissions',
    sql: `
      -- A person who looks after someone. Email is the login identity.
      CREATE TABLE caregivers (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        email         TEXT NOT NULL UNIQUE COLLATE NOCASE,
        display_name  TEXT NOT NULL,
        -- scrypt, with a per-user salt. Never the password itself.
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        created_at    TEXT NOT NULL,
        is_demo       INTEGER NOT NULL DEFAULT 0
      );

      -- The person being cared for. A patient exists on their phone first;
      -- this row is the server's handle for them, created when they consent
      -- to a link. No email and no password: patients never log in here.
      CREATE TABLE patients (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        display_name TEXT NOT NULL,
        -- Opaque id the patient's device generates for itself. Lets a device
        -- prove which patient it is without an account.
        device_key   TEXT NOT NULL UNIQUE,
        created_at   TEXT NOT NULL,
        is_demo      INTEGER NOT NULL DEFAULT 0
      );

      -- One caregiver's access to one patient, and exactly what they may do.
      --
      -- Permissions are columns rather than a bitmask or a JSON blob so that
      -- a query can filter on them and a human can read the table. Every one
      -- defaults to OFF: consent is granted explicitly, never inherited.
      CREATE TABLE care_links (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        caregiver_id     INTEGER NOT NULL REFERENCES caregivers(id) ON DELETE CASCADE,
        patient_id       INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        relationship     TEXT NOT NULL DEFAULT '',
        can_view_reminders   INTEGER NOT NULL DEFAULT 0,
        can_edit_reminders   INTEGER NOT NULL DEFAULT 0,
        can_view_vault       INTEGER NOT NULL DEFAULT 0,
        can_edit_vault       INTEGER NOT NULL DEFAULT 0,
        can_view_activity    INTEGER NOT NULL DEFAULT 0,
        -- When the patient agreed, and how. Kept for the audit trail: the
        -- answer to "who allowed this?" must survive the session.
        consented_at     TEXT NOT NULL,
        consent_method   TEXT NOT NULL,
        revoked_at       TEXT,
        UNIQUE (caregiver_id, patient_id)
      );

      -- Short-lived codes a patient reads out to a caregiver.
      --
      -- The patient's device creates one; the caregiver types it in. It is
      -- single use and expires, so a code overheard or left on a screen is
      -- worth nothing a few minutes later.
      CREATE TABLE link_codes (
        code          TEXT PRIMARY KEY,
        patient_id    INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        expires_at    TEXT NOT NULL,
        used_at       TEXT,
        used_by       INTEGER REFERENCES caregivers(id),
        created_at    TEXT NOT NULL
      );

      -- Login sessions. The token itself is never stored, only its hash, so
      -- a leaked database does not hand over live sessions.
      CREATE TABLE sessions (
        token_hash  TEXT PRIMARY KEY,
        caregiver_id INTEGER NOT NULL REFERENCES caregivers(id) ON DELETE CASCADE,
        created_at  TEXT NOT NULL,
        expires_at  TEXT NOT NULL
      );

      CREATE INDEX idx_links_caregiver ON care_links(caregiver_id);
      CREATE INDEX idx_links_patient ON care_links(patient_id);
      CREATE INDEX idx_codes_patient ON link_codes(patient_id);
      CREATE INDEX idx_sessions_caregiver ON sessions(caregiver_id);
    `,
  },
  {
    id: 2,
    name: 'reminders owned by the server, and a sync cursor',
    sql: `
      -- Reminders a caregiver set. The patient's phone pulls these and
      -- schedules its own alarms; the server never sends a notification.
      --
      -- updated_at drives sync: a device asks for everything changed since
      -- the last time it looked, which is the smallest thing that works
      -- offline and survives a device being off for a week.
      CREATE TABLE remote_reminders (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id   INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        created_by   INTEGER REFERENCES caregivers(id),
        title        TEXT NOT NULL,
        notes        TEXT NOT NULL DEFAULT '',
        hour         INTEGER NOT NULL,
        minute       INTEGER NOT NULL,
        repeat       TEXT NOT NULL DEFAULT 'once',
        category     TEXT NOT NULL DEFAULT 'other',
        -- Soft delete: a device that has been offline must learn that a
        -- reminder was removed, and a row that is simply gone cannot tell it.
        deleted_at   TEXT,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL
      );

      CREATE INDEX idx_reminders_patient ON remote_reminders(patient_id, updated_at);
    `,
  },
  {
    id: 3,
    name: 'activity reports, only with consent',
    sql: `
      -- What the patient's device chooses to report: games played, reminders
      -- completed. Written by the device, read by a caregiver who has
      -- can_view_activity.
      --
      -- Deliberately coarse. "Played a memory game, scored 40" is useful to
      -- a family member; a minute-by-minute log of someone's day is
      -- surveillance, and this table has no shape for it.
      CREATE TABLE activity_events (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id  INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
        kind        TEXT NOT NULL,
        summary     TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        created_at  TEXT NOT NULL
      );

      CREATE INDEX idx_activity_patient ON activity_events(patient_id, occurred_at);
    `,
  },
  {
    id: 4,
    name: 'monotonic revision counter for reminder sync',
    sql: `
      -- WHY THIS REPLACES THE TIMESTAMP CURSOR. Sync asked for everything
      -- with updated_at > cursor. ISO timestamps have millisecond
      -- precision, so a reminder created and then deleted inside the same
      -- millisecond produced two rows with identical updated_at, and a
      -- device holding that value as its cursor never saw the second
      -- change. A test caught it doing exactly that.
      --
      -- A counter cannot tie. Every write takes the next value, the device
      -- stores the highest it has seen, and "> cursor" is then exact.
      ALTER TABLE remote_reminders ADD COLUMN rev INTEGER NOT NULL DEFAULT 0;

      -- Existing rows get an order so a device that already synced does not
      -- have to start over.
      UPDATE remote_reminders SET rev = id;

      CREATE INDEX idx_reminders_rev ON remote_reminders(patient_id, rev);
    `,
  },
];

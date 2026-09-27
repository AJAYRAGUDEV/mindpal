import {
  hashPassword,
  verifyPassword,
  createSessionToken,
  hashToken,
  sessionExpiry,
  createLinkCode,
  codeExpiry,
} from './auth.js';

/**
 * Every read and write the caregiver site makes.
 *
 * THE RULE THIS FILE ENFORCES: a caregiver can only ever reach a patient
 * through a care_links row that is not revoked and that grants the specific
 * permission being used. There is no function here that takes a patient id
 * without also taking a caregiver id and checking it — not as a convenience,
 * because a function like that is exactly what gets called from the wrong
 * place six months later.
 *
 * Permission is checked in SQL, in the same statement that fetches the data,
 * so there is no window between "is this allowed?" and "here it is".
 */
export class CareStore {
  constructor(db) {
    this.db = db;
  }

  now() {
    return new Date().toISOString();
  }

  // ------------------------------------------------------------- caregivers

  registerCaregiver({ email, displayName, password, isDemo = false }) {
    const { hash, salt } = hashPassword(password);
    const normalised = email.trim();

    try {
      const result = this.db
        .prepare(
          `INSERT INTO caregivers
             (email, display_name, password_hash, password_salt, created_at, is_demo)
           VALUES (?, ?, ?, ?, ?, ?)`,
        )
        .run(normalised, displayName.trim(), hash, salt, this.now(), isDemo ? 1 : 0);
      return { id: Number(result.lastInsertRowid), email: normalised };
    } catch (error) {
      if (String(error.message).includes('UNIQUE')) {
        return { error: 'An account with that email already exists.' };
      }
      throw error;
    }
  }

  /**
   * Checks an email and password.
   *
   * Returns the same vague failure whether the email is unknown or the
   * password is wrong: telling them apart would let anyone enumerate which
   * addresses have accounts.
   */
  login({ email, password }) {
    const row = this.db
      .prepare('SELECT * FROM caregivers WHERE email = ?')
      .get(String(email ?? '').trim());

    if (!row || !verifyPassword(password, row.password_hash, row.password_salt)) {
      return { error: 'That email and password do not match.' };
    }

    const { token, tokenHash } = createSessionToken();
    this.db
      .prepare(
        `INSERT INTO sessions (token_hash, caregiver_id, created_at, expires_at)
         VALUES (?, ?, ?, ?)`,
      )
      .run(tokenHash, row.id, this.now(), sessionExpiry());

    return {
      token,
      caregiver: { id: row.id, email: row.email, displayName: row.display_name },
    };
  }

  /** The caregiver behind a session token, or null. Expired sessions are swept. */
  caregiverForToken(token) {
    if (typeof token !== 'string' || token.length === 0) return null;

    const row = this.db
      .prepare(
        `SELECT c.id, c.email, c.display_name, s.expires_at
           FROM sessions s
           JOIN caregivers c ON c.id = s.caregiver_id
          WHERE s.token_hash = ?`,
      )
      .get(hashToken(token));

    if (!row) return null;
    if (new Date(row.expires_at) < new Date()) {
      this.logout(token);
      return null;
    }
    return { id: row.id, email: row.email, displayName: row.display_name };
  }

  logout(token) {
    this.db.prepare('DELETE FROM sessions WHERE token_hash = ?').run(hashToken(token));
  }

  // ---------------------------------------------------------------- linking

  /** Registers a patient device and returns its patient row. */
  registerPatient({ displayName, deviceKey, isDemo = false }) {
    const existing = this.db
      .prepare('SELECT * FROM patients WHERE device_key = ?')
      .get(deviceKey);
    if (existing) return existing;

    const result = this.db
      .prepare(
        `INSERT INTO patients (display_name, device_key, created_at, is_demo)
         VALUES (?, ?, ?, ?)`,
      )
      .run(displayName.trim(), deviceKey, this.now(), isDemo ? 1 : 0);

    return this.db
      .prepare('SELECT * FROM patients WHERE id = ?')
      .get(Number(result.lastInsertRowid));
  }

  /**
   * A patient's device asks for a code to read out. Any unused code for that
   * patient is invalidated first, so only the newest one works.
   */
  issueLinkCode(patientId, minutes = 15) {
    this.db
      .prepare('DELETE FROM link_codes WHERE patient_id = ? AND used_at IS NULL')
      .run(patientId);

    const code = createLinkCode();
    const expiresAt = codeExpiry(minutes);
    this.db
      .prepare(
        `INSERT INTO link_codes (code, patient_id, expires_at, created_at)
         VALUES (?, ?, ?, ?)`,
      )
      .run(code, patientId, expiresAt, this.now());

    return { code, expiresAt };
  }

  /**
   * A caregiver redeems a code. This is the moment consent is recorded.
   *
   * Every permission starts OFF. The patient (or the caregiver, with the
   * patient present) turns on what is wanted afterwards — the code grants a
   * link, not authority.
   */
  redeemLinkCode({ caregiverId, code, relationship = '' }) {
    const row = this.db
      .prepare('SELECT * FROM link_codes WHERE code = ?')
      .get(String(code ?? '').trim().toUpperCase());

    if (!row) return { error: 'That code is not valid.' };
    if (row.used_at) return { error: 'That code has already been used.' };
    if (new Date(row.expires_at) < new Date()) {
      return { error: 'That code has expired. Please ask for a new one.' };
    }

    const already = this.db
      .prepare('SELECT id FROM care_links WHERE caregiver_id = ? AND patient_id = ?')
      .get(caregiverId, row.patient_id);
    if (already) return { error: 'You are already linked to this person.' };

    const now = this.now();
    this.db.exec('BEGIN');
    try {
      this.db
        .prepare(
          `INSERT INTO care_links
             (caregiver_id, patient_id, relationship, consented_at, consent_method)
           VALUES (?, ?, ?, ?, ?)`,
        )
        .run(caregiverId, row.patient_id, relationship.trim(), now, 'link_code');
      this.db
        .prepare('UPDATE link_codes SET used_at = ?, used_by = ? WHERE code = ?')
        .run(now, caregiverId, row.code);
      this.db.exec('COMMIT');
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }

    return { patientId: row.patient_id };
  }

  /** Every patient this caregiver may see, with their permissions. */
  patientsFor(caregiverId) {
    return this.db
      .prepare(
        `SELECT p.id, p.display_name AS displayName, l.relationship,
                l.can_view_reminders, l.can_edit_reminders,
                l.can_view_vault, l.can_edit_vault, l.can_view_activity,
                l.consented_at
           FROM care_links l
           JOIN patients p ON p.id = l.patient_id
          WHERE l.caregiver_id = ? AND l.revoked_at IS NULL
          ORDER BY p.display_name`,
      )
      .all(caregiverId)
      .map(shapeLink);
  }

  /**
   * The link between one caregiver and one patient, or null.
   *
   * THE choke point. Everything that touches patient data goes through here
   * first, and a revoked link returns null exactly like a link that never
   * existed.
   */
  linkFor(caregiverId, patientId) {
    const row = this.db
      .prepare(
        `SELECT l.*, p.display_name
           FROM care_links l
           JOIN patients p ON p.id = l.patient_id
          WHERE l.caregiver_id = ? AND l.patient_id = ? AND l.revoked_at IS NULL`,
      )
      .get(caregiverId, Number(patientId));
    return row ?? null;
  }

  /** True only when the link exists AND grants that permission. */
  may(caregiverId, patientId, permission) {
    const link = this.linkFor(caregiverId, patientId);
    return Boolean(link && link[permission] === 1);
  }

  setPermissions({ caregiverId, patientId, permissions }) {
    const link = this.linkFor(caregiverId, patientId);
    if (!link) return { error: 'You are not linked to this person.' };

    const allowed = [
      'can_view_reminders', 'can_edit_reminders',
      'can_view_vault', 'can_edit_vault', 'can_view_activity',
    ];
    const updates = [];
    const values = [];
    for (const key of allowed) {
      if (key in permissions) {
        updates.push(`${key} = ?`);
        values.push(permissions[key] ? 1 : 0);
      }
    }
    if (updates.length === 0) return { ok: true };

    values.push(caregiverId, Number(patientId));
    this.db
      .prepare(
        `UPDATE care_links SET ${updates.join(', ')}
          WHERE caregiver_id = ? AND patient_id = ?`,
      )
      .run(...values);
    return { ok: true };
  }

  /** Ends a link. Kept as a row with revoked_at so the history survives. */
  revokeLink({ caregiverId, patientId }) {
    this.db
      .prepare(
        `UPDATE care_links SET revoked_at = ?
          WHERE caregiver_id = ? AND patient_id = ? AND revoked_at IS NULL`,
      )
      .run(this.now(), caregiverId, Number(patientId));
    return { ok: true };
  }

  // -------------------------------------------------------------- reminders

  listReminders(patientId, { includeDeleted = false } = {}) {
    const sql = includeDeleted
      ? 'SELECT * FROM remote_reminders WHERE patient_id = ? ORDER BY hour, minute'
      : `SELECT * FROM remote_reminders
          WHERE patient_id = ? AND deleted_at IS NULL ORDER BY hour, minute`;
    return this.db.prepare(sql).all(Number(patientId)).map(shapeReminder);
  }

  /** The next revision number. Monotonic, so two writes can never tie. */
  nextRev() {
    const row = this.db
      .prepare('SELECT COALESCE(MAX(rev), 0) + 1 AS next FROM remote_reminders')
      .get();
    return row.next;
  }

  /**
   * Everything changed since a cursor, for a device catching up.
   *
   * The cursor is a revision number, not a timestamp. Timestamps tie: a
   * reminder created and deleted in the same millisecond produced two rows
   * the device could not tell apart, and it silently missed the deletion.
   */
  remindersChangedSince(patientId, sinceRev) {
    const cursor = Number(sinceRev) || 0;
    return this.db
      .prepare(
        `SELECT * FROM remote_reminders
          WHERE patient_id = ? AND rev > ?
          ORDER BY rev`,
      )
      .all(Number(patientId), cursor)
      .map(shapeReminder);
  }

  createReminder({ patientId, caregiverId, title, notes, hour, minute, repeat, category }) {
    const now = this.now();
    const result = this.db
      .prepare(
        `INSERT INTO remote_reminders
           (patient_id, created_by, title, notes, hour, minute, repeat, category,
            created_at, updated_at, rev)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        Number(patientId), caregiverId, title, notes ?? '',
        hour, minute, repeat ?? 'once', category ?? 'other', now, now,
        this.nextRev(),
      );
    return shapeReminder(
      this.db
        .prepare('SELECT * FROM remote_reminders WHERE id = ?')
        .get(Number(result.lastInsertRowid)),
    );
  }

  updateReminder({ patientId, reminderId, fields }) {
    const existing = this.db
      .prepare('SELECT * FROM remote_reminders WHERE id = ? AND patient_id = ?')
      .get(Number(reminderId), Number(patientId));
    if (!existing) return { error: 'That reminder does not exist.' };

    const allowed = ['title', 'notes', 'hour', 'minute', 'repeat', 'category'];
    const updates = [];
    const values = [];
    for (const key of allowed) {
      if (key in fields) {
        updates.push(`${key} = ?`);
        values.push(fields[key]);
      }
    }
    if (updates.length === 0) return shapeReminder(existing);

    updates.push('updated_at = ?', 'rev = ?');
    values.push(this.now(), this.nextRev(), Number(reminderId), Number(patientId));

    this.db
      .prepare(
        `UPDATE remote_reminders SET ${updates.join(', ')}
          WHERE id = ? AND patient_id = ?`,
      )
      .run(...values);

    return shapeReminder(
      this.db.prepare('SELECT * FROM remote_reminders WHERE id = ?').get(Number(reminderId)),
    );
  }

  /**
   * Soft delete. The row stays so a device that has been offline learns the
   * reminder is gone; a hard delete would leave it ringing forever.
   */
  deleteReminder({ patientId, reminderId }) {
    const now = this.now();
    const result = this.db
      .prepare(
        `UPDATE remote_reminders SET deleted_at = ?, updated_at = ?, rev = ?
          WHERE id = ? AND patient_id = ? AND deleted_at IS NULL`,
      )
      .run(now, now, this.nextRev(), Number(reminderId), Number(patientId));
    return { ok: result.changes > 0 };
  }

  // --------------------------------------------------------------- activity

  recordActivity({ patientId, kind, summary, occurredAt }) {
    this.db
      .prepare(
        `INSERT INTO activity_events (patient_id, kind, summary, occurred_at, created_at)
         VALUES (?, ?, ?, ?, ?)`,
      )
      .run(Number(patientId), kind, summary, occurredAt ?? this.now(), this.now());
    return { ok: true };
  }

  listActivity(patientId, limit = 50) {
    return this.db
      .prepare(
        `SELECT kind, summary, occurred_at AS occurredAt
           FROM activity_events
          WHERE patient_id = ?
          ORDER BY occurred_at DESC
          LIMIT ?`,
      )
      .all(Number(patientId), Math.min(Number(limit) || 50, 200));
  }
}

function shapeLink(row) {
  return {
    id: row.id,
    displayName: row.displayName,
    relationship: row.relationship,
    consentedAt: row.consented_at,
    permissions: {
      viewReminders: row.can_view_reminders === 1,
      editReminders: row.can_edit_reminders === 1,
      viewVault: row.can_view_vault === 1,
      editVault: row.can_edit_vault === 1,
      viewActivity: row.can_view_activity === 1,
    },
  };
}

function shapeReminder(row) {
  if (!row) return null;
  return {
    id: row.id,
    title: row.title,
    notes: row.notes,
    hour: row.hour,
    minute: row.minute,
    repeat: row.repeat,
    category: row.category,
    deleted: row.deleted_at !== null,
    updatedAt: row.updated_at,
    // The sync cursor. A device stores the highest it has seen.
    rev: row.rev,
  };
}

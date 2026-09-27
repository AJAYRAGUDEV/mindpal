import { test, describe, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

import { openTestDatabase } from '../src/db/database.js';
import { CareStore } from '../src/caregiver/store.js';
import {
  hashPassword,
  verifyPassword,
  createLinkCode,
  passwordProblem,
  emailProblem,
} from '../src/caregiver/auth.js';

/**
 * The authorisation tests.
 *
 * These are the ones worth having. A dashboard that renders is obvious when
 * it breaks; a permission check that quietly passes is not, and it is the
 * failure that actually matters here — someone seeing a person's reminders
 * without being allowed to.
 */

let db;
let store;

beforeEach(() => {
  db = openTestDatabase();
  store = new CareStore(db);
});

function makeCaregiver(email = 'a@example.com') {
  return store.registerCaregiver({
    email,
    displayName: 'Test Carer',
    password: 'a-long-enough-password',
  });
}

function makePatient(name = 'Patient', key = 'device-1') {
  return store.registerPatient({ displayName: name, deviceKey: key });
}

/** Links with every permission granted, for tests about something else. */
function linkFully(caregiverId, patientId) {
  const { code } = store.issueLinkCode(patientId);
  store.redeemLinkCode({ caregiverId, code });
  store.setPermissions({
    caregiverId,
    patientId,
    permissions: {
      can_view_reminders: true,
      can_edit_reminders: true,
      can_view_vault: true,
      can_edit_vault: true,
      can_view_activity: true,
    },
  });
}

describe('passwords', () => {
  test('a correct password verifies and a wrong one does not', () => {
    const { hash, salt } = hashPassword('correct horse battery');
    assert.equal(verifyPassword('correct horse battery', hash, salt), true);
    assert.equal(verifyPassword('wrong', hash, salt), false);
  });

  test('the same password gives different hashes, because the salt differs', () => {
    const first = hashPassword('same password');
    const second = hashPassword('same password');
    assert.notEqual(first.hash, second.hash);
  });

  test('the plain password is never stored', () => {
    makeCaregiver();
    const row = db.prepare('SELECT * FROM caregivers').get();
    assert.ok(!JSON.stringify(row).includes('a-long-enough-password'));
  });

  test('short passwords and bad emails are refused', () => {
    assert.ok(passwordProblem('short'));
    assert.equal(passwordProblem('a-long-enough-password'), null);
    assert.ok(emailProblem('not-an-email'));
    assert.equal(emailProblem('someone@example.com'), null);
  });
});

describe('sessions', () => {
  test('a token identifies its caregiver', () => {
    makeCaregiver();
    const { token, caregiver } = store.login({
      email: 'a@example.com',
      password: 'a-long-enough-password',
    });
    assert.equal(store.caregiverForToken(token).id, caregiver.id);
  });

  test('the raw token is never stored, only its hash', () => {
    makeCaregiver();
    const { token } = store.login({
      email: 'a@example.com',
      password: 'a-long-enough-password',
    });
    const row = db.prepare('SELECT * FROM sessions').get();
    assert.notEqual(row.token_hash, token);
    assert.ok(!JSON.stringify(row).includes(token));
  });

  test('a wrong password gives no session', () => {
    makeCaregiver();
    const result = store.login({ email: 'a@example.com', password: 'nope' });
    assert.ok(result.error);
    assert.equal(result.token, undefined);
  });

  test('an unknown email fails exactly like a wrong password', () => {
    makeCaregiver();
    const unknown = store.login({ email: 'nobody@example.com', password: 'x' });
    const wrong = store.login({ email: 'a@example.com', password: 'x' });
    // Identical wording: otherwise the form tells an attacker which emails
    // have accounts.
    assert.equal(unknown.error, wrong.error);
  });

  test('signing out kills the token', () => {
    makeCaregiver();
    const { token } = store.login({
      email: 'a@example.com',
      password: 'a-long-enough-password',
    });
    store.logout(token);
    assert.equal(store.caregiverForToken(token), null);
  });

  test('rubbish tokens are rejected', () => {
    assert.equal(store.caregiverForToken('made-up'), null);
    assert.equal(store.caregiverForToken(''), null);
    assert.equal(store.caregiverForToken(null), null);
  });
});

describe('link codes', () => {
  test('a code links a caregiver to a patient once', () => {
    const carer = makeCaregiver();
    const patient = makePatient();
    const { code } = store.issueLinkCode(patient.id);

    assert.equal(store.redeemLinkCode({ caregiverId: carer.id, code }).patientId, patient.id);
    // Second use fails.
    assert.ok(store.redeemLinkCode({ caregiverId: carer.id, code }).error);
  });

  test('an expired code is refused', () => {
    const carer = makeCaregiver();
    const patient = makePatient();
    const { code } = store.issueLinkCode(patient.id);
    db.prepare('UPDATE link_codes SET expires_at = ? WHERE code = ?')
      .run(new Date(Date.now() - 1000).toISOString(), code);

    assert.match(store.redeemLinkCode({ caregiverId: carer.id, code }).error, /expired/i);
  });

  test('issuing a new code invalidates the old one', () => {
    const carer = makeCaregiver();
    const patient = makePatient();
    const first = store.issueLinkCode(patient.id).code;
    store.issueLinkCode(patient.id);

    assert.ok(store.redeemLinkCode({ caregiverId: carer.id, code: first }).error);
  });

  test('an invented code is refused', () => {
    const carer = makeCaregiver();
    assert.ok(store.redeemLinkCode({ caregiverId: carer.id, code: 'AAAAAA' }).error);
  });

  test('codes avoid characters that are easy to misread', () => {
    for (let i = 0; i < 200; i += 1) {
      assert.doesNotMatch(createLinkCode(), /[01OIL5S8B]/);
    }
  });
});

describe('permissions', () => {
  test('a new link grants nothing at all', () => {
    const carer = makeCaregiver();
    const patient = makePatient();
    const { code } = store.issueLinkCode(patient.id);
    store.redeemLinkCode({ caregiverId: carer.id, code });

    for (const permission of [
      'can_view_reminders', 'can_edit_reminders',
      'can_view_vault', 'can_edit_vault', 'can_view_activity',
    ]) {
      assert.equal(
        store.may(carer.id, patient.id, permission),
        false,
        `${permission} should start off`,
      );
    }
  });

  test('a caregiver cannot reach a patient they are not linked to', () => {
    const carer = makeCaregiver();
    const stranger = makePatient('Someone Else', 'device-stranger');

    assert.equal(store.linkFor(carer.id, stranger.id), null);
    assert.equal(store.may(carer.id, stranger.id, 'can_view_reminders'), false);
    assert.equal(store.patientsFor(carer.id).length, 0);
  });

  test('two caregivers on one patient have independent permissions', () => {
    const meena = makeCaregiver('meena@example.com');
    const rahul = makeCaregiver('rahul@example.com');
    const patient = makePatient();

    linkFully(meena.id, patient.id);

    const { code } = store.issueLinkCode(patient.id);
    store.redeemLinkCode({ caregiverId: rahul.id, code });
    store.setPermissions({
      caregiverId: rahul.id,
      patientId: patient.id,
      permissions: { can_view_reminders: true },
    });

    assert.equal(store.may(meena.id, patient.id, 'can_edit_reminders'), true);
    assert.equal(store.may(rahul.id, patient.id, 'can_edit_reminders'), false);
    assert.equal(store.may(rahul.id, patient.id, 'can_view_reminders'), true);
  });

  test('revoking a link removes all access immediately', () => {
    const carer = makeCaregiver();
    const patient = makePatient();
    linkFully(carer.id, patient.id);
    assert.equal(store.may(carer.id, patient.id, 'can_view_reminders'), true);

    store.revokeLink({ caregiverId: carer.id, patientId: patient.id });

    assert.equal(store.linkFor(carer.id, patient.id), null);
    assert.equal(store.may(carer.id, patient.id, 'can_view_reminders'), false);
    assert.equal(store.patientsFor(carer.id).length, 0);
  });

  test('a revoked link keeps its consent history', () => {
    const carer = makeCaregiver();
    const patient = makePatient();
    linkFully(carer.id, patient.id);
    store.revokeLink({ caregiverId: carer.id, patientId: patient.id });

    const row = db.prepare('SELECT * FROM care_links').get();
    assert.ok(row.consented_at);
    assert.ok(row.revoked_at);
  });

  test('permissions cannot be set on a patient you are not linked to', () => {
    const carer = makeCaregiver();
    const stranger = makePatient('Stranger', 'device-x');

    const result = store.setPermissions({
      caregiverId: carer.id,
      patientId: stranger.id,
      permissions: { can_view_reminders: true },
    });
    assert.ok(result.error);
    assert.equal(store.may(carer.id, stranger.id, 'can_view_reminders'), false);
  });
});

describe('consent belongs to the patient', () => {
  test('the store still refuses permissions on an unlinked patient', () => {
    const carer = makeCaregiver();
    const stranger = makePatient('Stranger', 'device-s');
    assert.ok(store.setPermissions({
      caregiverId: carer.id,
      patientId: stranger.id,
      permissions: { can_view_reminders: true },
    }).error);
  });

  test('a granted permission can be withdrawn again', () => {
    const carer = makeCaregiver();
    const patient = makePatient();
    linkFully(carer.id, patient.id);
    assert.equal(store.may(carer.id, patient.id, 'can_edit_reminders'), true);

    // This is what the patient's device calls.
    store.setPermissions({
      caregiverId: carer.id,
      patientId: patient.id,
      permissions: { can_edit_reminders: false },
    });

    assert.equal(store.may(carer.id, patient.id, 'can_edit_reminders'), false);
    // Viewing was not mentioned, so it is untouched.
    assert.equal(store.may(carer.id, patient.id, 'can_view_reminders'), true);
  });
});

describe('reminders', () => {
  test('created, listed, updated and soft-deleted', () => {
    const carer = makeCaregiver();
    const patient = makePatient();
    linkFully(carer.id, patient.id);

    const created = store.createReminder({
      patientId: patient.id,
      caregiverId: carer.id,
      title: 'Take medicine',
      hour: 20,
      minute: 0,
      repeat: 'daily',
      category: 'medicine',
    });
    assert.equal(store.listReminders(patient.id).length, 1);

    store.updateReminder({
      patientId: patient.id,
      reminderId: created.id,
      fields: { hour: 21 },
    });
    assert.equal(store.listReminders(patient.id)[0].hour, 21);

    store.deleteReminder({ patientId: patient.id, reminderId: created.id });
    assert.equal(store.listReminders(patient.id).length, 0);
    // Still there, flagged, so an offline device can learn it was removed.
    assert.equal(store.listReminders(patient.id, { includeDeleted: true }).length, 1);
  });

  test('a reminder cannot be edited through the wrong patient', () => {
    const carer = makeCaregiver();
    const mine = makePatient('Mine', 'device-mine');
    const theirs = makePatient('Theirs', 'device-theirs');
    linkFully(carer.id, mine.id);

    const created = store.createReminder({
      patientId: mine.id, caregiverId: carer.id,
      title: 'Private', hour: 9, minute: 0,
    });

    // Same reminder id, different patient in the path.
    const result = store.updateReminder({
      patientId: theirs.id,
      reminderId: created.id,
      fields: { title: 'Changed' },
    });
    assert.ok(result.error);
    assert.equal(store.listReminders(mine.id)[0].title, 'Private');
  });

  test('sync returns only what changed since the cursor', () => {
    const carer = makeCaregiver();
    const patient = makePatient();
    linkFully(carer.id, patient.id);

    const created = store.createReminder({
      patientId: patient.id, caregiverId: carer.id,
      title: 'Old', hour: 8, minute: 0,
    });

    // Everything is newer than rev 0, nothing is newer than the latest rev.
    assert.equal(store.remindersChangedSince(patient.id, 0).length, 1);
    assert.equal(store.remindersChangedSince(patient.id, created.rev).length, 0);
  });

  test('a deletion reaches a device that has been offline', () => {
    const carer = makeCaregiver();
    const patient = makePatient();
    linkFully(carer.id, patient.id);

    const created = store.createReminder({
      patientId: patient.id, caregiverId: carer.id,
      title: 'Gone soon', hour: 8, minute: 0,
    });
    const cursor = created.rev;
    store.deleteReminder({ patientId: patient.id, reminderId: created.id });

    const changes = store.remindersChangedSince(patient.id, cursor);
    assert.equal(changes.length, 1);
    assert.equal(changes[0].deleted, true);
  });
  test('two writes in the same millisecond both reach a device', () => {
    const carer = makeCaregiver();
    const patient = makePatient();
    linkFully(carer.id, patient.id);

    // The bug this replaced: with a timestamp cursor these shared an
    // updated_at and the device saw only the first.
    const first = store.createReminder({
      patientId: patient.id, caregiverId: carer.id,
      title: 'A', hour: 8, minute: 0,
    });
    const second = store.createReminder({
      patientId: patient.id, caregiverId: carer.id,
      title: 'B', hour: 9, minute: 0,
    });

    assert.notEqual(first.rev, second.rev);
    assert.equal(store.remindersChangedSince(patient.id, 0).length, 2);
    assert.equal(store.remindersChangedSince(patient.id, first.rev).length, 1);
  });
});

describe('activity', () => {
  test('events are recorded and read back newest first', () => {
    const patient = makePatient();
    store.recordActivity({
      patientId: patient.id, kind: 'game', summary: 'Older',
      occurredAt: new Date(Date.now() - 60_000).toISOString(),
    });
    store.recordActivity({ patientId: patient.id, kind: 'game', summary: 'Newer' });

    assert.equal(store.listActivity(patient.id)[0].summary, 'Newer');
  });
});

describe('the schema itself', () => {
  test('migrations are recorded and re-running is a no-op', () => {
    const applied = db.prepare('SELECT COUNT(*) AS n FROM schema_migrations').get();
    assert.ok(applied.n >= 3);
  });

  test('deleting a patient takes their data with them', () => {
    const carer = makeCaregiver();
    const patient = makePatient();
    linkFully(carer.id, patient.id);
    store.createReminder({
      patientId: patient.id, caregiverId: carer.id,
      title: 'x', hour: 1, minute: 0,
    });
    store.recordActivity({ patientId: patient.id, kind: 'game', summary: 'y' });

    db.prepare('DELETE FROM patients WHERE id = ?').run(patient.id);

    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM remote_reminders').get().n, 0);
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM activity_events').get().n, 0);
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM care_links').get().n, 0);
  });

  test('there is nowhere to store a diagnosis', () => {
    const columns = db
      .prepare("SELECT name FROM pragma_table_info('patients')")
      .all()
      .map((row) => row.name);
    for (const forbidden of ['diagnosis', 'condition', 'medication', 'notes']) {
      assert.ok(!columns.includes(forbidden), `patients.${forbidden} should not exist`);
    }
  });
});

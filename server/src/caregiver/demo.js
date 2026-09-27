import { CareStore } from './store.js';

/**
 * Fictional accounts so the site can be shown without a real one.
 *
 * Everyone here is invented. The passwords are printed in DEPLOY.md and are
 * meant to be public — these accounts exist to be logged into by whoever is
 * watching the demo, and they hold nothing worth protecting.
 *
 * Seeded on boot and only when absent, so a restart does not duplicate them
 * and does not overwrite anything a demo has since changed. On Render's free
 * tier the database is wiped on every deploy, which makes this the only
 * reason the site has anything in it at all after a restart.
 */

const DEMO_PASSWORD = 'mindpal-demo-2026';

export function seedDemoData(db) {
  const store = new CareStore(db);

  const already = db
    .prepare('SELECT COUNT(*) AS n FROM caregivers WHERE is_demo = 1')
    .get();
  if (already.n > 0) {
    return { seeded: false, password: DEMO_PASSWORD };
  }

  // Two caregivers, so the demo can show that one cannot see the other's
  // patient — the authorisation story is the interesting part.
  const meena = store.registerCaregiver({
    email: 'meena@example.com',
    displayName: 'Meena Das',
    password: DEMO_PASSWORD,
    isDemo: true,
  });
  const rahul = store.registerCaregiver({
    email: 'rahul@example.com',
    displayName: 'Rahul Das',
    password: DEMO_PASSWORD,
    isDemo: true,
  });

  // Two patients on two different devices.
  const bimala = store.registerPatient({
    displayName: 'Bimala Das',
    deviceKey: 'demo-device-bimala',
    isDemo: true,
  });
  const hari = store.registerPatient({
    displayName: 'Hari Sharma',
    deviceKey: 'demo-device-hari',
    isDemo: true,
  });

  // Meena cares for Bimala, with most permissions granted.
  linkDemo(store, db, {
    caregiverId: meena.id,
    patientId: bimala.id,
    relationship: 'Daughter',
    permissions: {
      can_view_reminders: 1,
      can_edit_reminders: 1,
      can_view_vault: 1,
      can_edit_vault: 0,
      can_view_activity: 1,
    },
  });

  // Rahul cares for Bimala too, but may only LOOK at reminders. This is the
  // row that proves permissions are per caregiver, not per patient.
  linkDemo(store, db, {
    caregiverId: rahul.id,
    patientId: bimala.id,
    relationship: 'Son',
    permissions: {
      can_view_reminders: 1,
      can_edit_reminders: 0,
      can_view_vault: 0,
      can_edit_vault: 0,
      can_view_activity: 0,
    },
  });

  // Hari is linked to nobody, so a "you cannot see this patient" case exists.

  const now = new Date().toISOString();
  for (const reminder of [
    { title: 'Take your morning medicine', hour: 8, minute: 0, repeat: 'daily', category: 'medicine' },
    { title: 'Lunch', hour: 13, minute: 0, repeat: 'daily', category: 'meal' },
    { title: 'Doctor Barua appointment', hour: 15, minute: 30, repeat: 'once', category: 'appointment', notes: 'Bring the blue folder.' },
    { title: 'Evening walk', hour: 17, minute: 30, repeat: 'daily', category: 'dailyActivity' },
  ]) {
    store.createReminder({
      patientId: bimala.id,
      caregiverId: meena.id,
      notes: '',
      ...reminder,
    });
  }

  for (const event of [
    { kind: 'game', summary: 'Played Memory Match, scored 40', hours: 2 },
    { kind: 'reminder', summary: 'Completed: Take your morning medicine', hours: 6 },
    { kind: 'game', summary: 'Played Odd One Out, scored 25', hours: 26 },
    { kind: 'reminder', summary: 'Completed: Lunch', hours: 30 },
  ]) {
    store.recordActivity({
      patientId: bimala.id,
      kind: event.kind,
      summary: event.summary,
      occurredAt: new Date(Date.parse(now) - event.hours * 3_600_000).toISOString(),
    });
  }

  console.log('[care] demo accounts seeded: meena@example.com, rahul@example.com');
  return { seeded: true, password: DEMO_PASSWORD };
}

/** Creates a consented link directly, bypassing the code exchange. */
function linkDemo(store, db, { caregiverId, patientId, relationship, permissions }) {
  db.prepare(
    `INSERT INTO care_links
       (caregiver_id, patient_id, relationship, consented_at, consent_method,
        can_view_reminders, can_edit_reminders, can_view_vault,
        can_edit_vault, can_view_activity)
     VALUES (?, ?, ?, ?, 'demo_seed', ?, ?, ?, ?, ?)`,
  ).run(
    caregiverId, patientId, relationship, new Date().toISOString(),
    permissions.can_view_reminders, permissions.can_edit_reminders,
    permissions.can_view_vault, permissions.can_edit_vault,
    permissions.can_view_activity,
  );
}

export { DEMO_PASSWORD };

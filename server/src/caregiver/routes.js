import express from 'express';

import { CareStore } from './store.js';
import { passwordProblem, emailProblem, createDeviceKey } from './auth.js';

/**
 * The caregiver API, mounted at /api/care.
 *
 * SHAPE OF EVERY PATIENT ROUTE:
 *
 *   requireCaregiver  -> who is asking?
 *   requirePermission -> may they do this to THIS patient?
 *   handler           -> the actual work
 *
 * The handler never re-checks and never sees a request that failed either
 * gate. That is the point: authorisation lives in one place, and adding a
 * route without it is visible in the route definition rather than buried.
 *
 * A caregiver asking about a patient they are not linked to gets 404, not
 * 403. 403 would confirm the patient exists.
 */
export function createCareRouter(db) {
  const store = new CareStore(db);
  const router = express.Router();

  // ------------------------------------------------------------ middleware

  function requireCaregiver(request, response, next) {
    const header = request.get('authorization') ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    const caregiver = store.caregiverForToken(token);

    if (!caregiver) {
      return response.status(401).json({ error: 'Please sign in.' });
    }
    request.caregiver = caregiver;
    next();
  }

  const requirePermission = (permission) => (request, response, next) => {
    const patientId = Number(request.params.patientId);
    if (!Number.isInteger(patientId)) {
      return response.status(400).json({ error: 'Invalid patient.' });
    }

    const link = store.linkFor(request.caregiver.id, patientId);
    // Not linked, or the link is revoked: as far as this caregiver is
    // concerned the patient does not exist.
    if (!link) return response.status(404).json({ error: 'Not found.' });

    if (link[permission] !== 1) {
      return response.status(403).json({
        error: 'You do not have permission for that. Ask the person you care '
          + 'for to allow it.',
      });
    }

    request.patientId = patientId;
    request.link = link;
    next();
  };

  // ----------------------------------------------------------- accounts

  router.post('/register', (request, response) => {
    const { email, displayName, password } = request.body ?? {};

    const emailIssue = emailProblem(email);
    if (emailIssue) return response.status(400).json({ error: emailIssue });

    const passwordIssue = passwordProblem(password);
    if (passwordIssue) return response.status(400).json({ error: passwordIssue });

    if (typeof displayName !== 'string' || displayName.trim().length === 0) {
      return response.status(400).json({ error: 'Please enter your name.' });
    }

    const result = store.registerCaregiver({ email, displayName, password });
    if (result.error) return response.status(409).json({ error: result.error });

    const session = store.login({ email, password });
    return response.status(201).json(session);
  });

  router.post('/login', (request, response) => {
    const { email, password } = request.body ?? {};
    const result = store.login({ email, password });
    if (result.error) return response.status(401).json({ error: result.error });
    return response.json(result);
  });

  router.post('/logout', requireCaregiver, (request, response) => {
    const header = request.get('authorization') ?? '';
    store.logout(header.slice(7));
    return response.json({ ok: true });
  });

  router.get('/me', requireCaregiver, (request, response) =>
    response.json({ caregiver: request.caregiver }),
  );

  // ------------------------------------------------------------- linking

  /** A patient's device registers itself and gets a key it keeps forever. */
  router.post('/device/register', (request, response) => {
    const { displayName } = request.body ?? {};
    if (typeof displayName !== 'string' || displayName.trim().length === 0) {
      return response.status(400).json({ error: 'A name is required.' });
    }
    const patient = store.registerPatient({
      displayName,
      deviceKey: createDeviceKey(),
    });
    return response.status(201).json({
      patientId: patient.id,
      deviceKey: patient.device_key,
    });
  });

  /** The device asks for a code for its owner to read out. */
  router.post('/device/link-code', (request, response) => {
    const { deviceKey } = request.body ?? {};
    const patient = db
      .prepare('SELECT * FROM patients WHERE device_key = ?')
      .get(String(deviceKey ?? ''));
    if (!patient) return response.status(404).json({ error: 'Unknown device.' });

    return response.json(store.issueLinkCode(patient.id));
  });

  router.post('/link', requireCaregiver, (request, response) => {
    const { code, relationship } = request.body ?? {};
    const result = store.redeemLinkCode({
      caregiverId: request.caregiver.id,
      code,
      relationship: typeof relationship === 'string' ? relationship : '',
    });
    if (result.error) return response.status(400).json({ error: result.error });
    return response.status(201).json(result);
  });

  router.get('/patients', requireCaregiver, (request, response) =>
    response.json({ patients: store.patientsFor(request.caregiver.id) }),
  );

  // NOTE THE ABSENCE. There was a PUT here that let a caregiver set their
  // own permissions. It existed so the demo could show what each setting
  // did, and it was indefensible: consent that the party being granted
  // access can edit is not consent.
  //
  // Granting now happens on the patient's own device, through
  // PUT /device/links/:caregiverId/permissions below, which is authenticated
  // by the device key and can only ever act on that device's own patient.
  // The caregiver site shows permissions read-only.

  router.delete('/patients/:patientId/link', requireCaregiver, (request, response) => {
    store.revokeLink({
      caregiverId: request.caregiver.id,
      patientId: Number(request.params.patientId),
    });
    return response.json({ ok: true });
  });

  // ----------------------------------------------------------- reminders

  router.get(
    '/patients/:patientId/reminders',
    requireCaregiver,
    requirePermission('can_view_reminders'),
    (request, response) =>
      response.json({ reminders: store.listReminders(request.patientId) }),
  );

  router.post(
    '/patients/:patientId/reminders',
    requireCaregiver,
    requirePermission('can_edit_reminders'),
    (request, response) => {
      const problem = reminderProblem(request.body ?? {});
      if (problem) return response.status(400).json({ error: problem });

      const { title, notes, hour, minute, repeat, category } = request.body;
      return response.status(201).json({
        reminder: store.createReminder({
          patientId: request.patientId,
          caregiverId: request.caregiver.id,
          title: title.trim(),
          notes: typeof notes === 'string' ? notes.trim() : '',
          hour, minute, repeat, category,
        }),
      });
    },
  );

  router.put(
    '/patients/:patientId/reminders/:reminderId',
    requireCaregiver,
    requirePermission('can_edit_reminders'),
    (request, response) => {
      const fields = request.body ?? {};
      if ('hour' in fields || 'minute' in fields || 'title' in fields) {
        const problem = reminderProblem({
          title: fields.title ?? 'x',
          hour: fields.hour ?? 0,
          minute: fields.minute ?? 0,
          repeat: fields.repeat,
          category: fields.category,
        });
        if (problem) return response.status(400).json({ error: problem });
      }

      const result = store.updateReminder({
        patientId: request.patientId,
        reminderId: request.params.reminderId,
        fields,
      });
      if (result?.error) return response.status(404).json({ error: result.error });
      return response.json({ reminder: result });
    },
  );

  router.delete(
    '/patients/:patientId/reminders/:reminderId',
    requireCaregiver,
    requirePermission('can_edit_reminders'),
    (request, response) => {
      const result = store.deleteReminder({
        patientId: request.patientId,
        reminderId: request.params.reminderId,
      });
      if (!result.ok) return response.status(404).json({ error: 'Not found.' });
      return response.json({ ok: true });
    },
  );

  // ------------------------------------------------------------ activity

  router.get(
    '/patients/:patientId/activity',
    requireCaregiver,
    requirePermission('can_view_activity'),
    (request, response) =>
      response.json({ activity: store.listActivity(request.patientId) }),
  );

  // -------------------------------------------------- the device's own API
  //
  // Authenticated by the device key, not a session: the patient's phone has
  // no account. The key is the secret, so it travels in a header and each
  // route resolves it to exactly one patient.


  function requireDevice(request, response, next) {
    const key = request.get('x-device-key') ?? '';
    const patient = db.prepare('SELECT * FROM patients WHERE device_key = ?').get(key);
    if (!patient) return response.status(401).json({ error: 'Unknown device.' });
    request.patient = patient;
    next();
  }

  /** Who is linked to this patient, and what each may do. */
  router.get('/device/links', requireDevice, (request, response) => {
    const links = db
      .prepare(
        `SELECT c.id AS caregiverId, c.display_name AS caregiverName,
                c.email, l.relationship, l.consented_at AS consentedAt,
                l.can_view_reminders, l.can_edit_reminders,
                l.can_view_vault, l.can_edit_vault, l.can_view_activity
           FROM care_links l
           JOIN caregivers c ON c.id = l.caregiver_id
          WHERE l.patient_id = ? AND l.revoked_at IS NULL
          ORDER BY c.display_name`,
      )
      .all(request.patient.id)
      .map((row) => ({
        caregiverId: row.caregiverId,
        caregiverName: row.caregiverName,
        email: row.email,
        relationship: row.relationship,
        consentedAt: row.consentedAt,
        permissions: {
          viewReminders: row.can_view_reminders === 1,
          editReminders: row.can_edit_reminders === 1,
          viewVault: row.can_view_vault === 1,
          editVault: row.can_edit_vault === 1,
          viewActivity: row.can_view_activity === 1,
        },
      }));
    return response.json({ links });
  });

  /**
   * The patient grants or withdraws one caregiver's permissions.
   *
   * Authenticated by the device key, so it can only ever change links that
   * belong to THIS patient — the caregiver id in the path is checked against
   * that, not trusted. This is the only way permissions change.
   */
  router.put('/device/links/:caregiverId/permissions', requireDevice, (request, response) => {
    const caregiverId = Number(request.params.caregiverId);
    if (!Number.isInteger(caregiverId)) {
      return response.status(400).json({ error: 'Invalid caregiver.' });
    }

    const link = db
      .prepare(
        `SELECT id FROM care_links
          WHERE caregiver_id = ? AND patient_id = ? AND revoked_at IS NULL`,
      )
      .get(caregiverId, request.patient.id);
    if (!link) return response.status(404).json({ error: 'Not found.' });

    const result = store.setPermissions({
      caregiverId,
      patientId: request.patient.id,
      permissions: request.body ?? {},
    });
    if (result.error) return response.status(400).json({ error: result.error });
    return response.json({ ok: true });
  });

  /** The patient ends a link from their own device. */
  router.delete('/device/links/:caregiverId', requireDevice, (request, response) => {
    store.revokeLink({
      caregiverId: Number(request.params.caregiverId),
      patientId: request.patient.id,
    });
    return response.json({ ok: true });
  });

  /**
   * Everything that changed since the device last looked.
   *
   * This is the sync endpoint the patient app would call. Pull-based on
   * purpose: the phone asks when it has a connection, so nothing is lost by
   * being offline for a week, and no push infrastructure is needed.
   */
  router.get('/device/sync', requireDevice, (request, response) => {
    const since = String(request.query.since ?? '');
    return response.json({
      serverTime: new Date().toISOString(),
      reminders: store.remindersChangedSince(request.patient.id, since),
    });
  });

  router.post('/device/activity', requireDevice, (request, response) => {
    const { kind, summary, occurredAt } = request.body ?? {};
    if (typeof kind !== 'string' || typeof summary !== 'string') {
      return response.status(400).json({ error: 'kind and summary are required.' });
    }
    store.recordActivity({
      patientId: request.patient.id,
      kind: kind.slice(0, 40),
      summary: summary.slice(0, 200),
      occurredAt,
    });
    return response.status(201).json({ ok: true });
  });

  return { router, store };
}

/** Validation shared by create and update. Returns a message or null. */
function reminderProblem({ title, hour, minute, repeat, category }) {
  if (typeof title !== 'string' || title.trim().length === 0) {
    return 'Please give the reminder a title.';
  }
  if (title.length > 120) return 'That title is too long.';
  if (!Number.isInteger(hour) || hour < 0 || hour > 23) {
    return 'Please choose an hour between 0 and 23.';
  }
  if (!Number.isInteger(minute) || minute < 0 || minute > 59) {
    return 'Please choose a minute between 0 and 59.';
  }
  if (repeat !== undefined && !['once', 'daily'].includes(repeat)) {
    return 'Repeat must be once or daily.';
  }
  const categories = [
    'dailyActivity', 'meal', 'appointment', 'medicine', 'personal', 'other',
  ];
  if (category !== undefined && !categories.includes(category)) {
    return 'That is not a category we have.';
  }
  return null;
}

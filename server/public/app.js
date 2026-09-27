/* The caregiver dashboard.
 *
 * Plain JavaScript, no framework and no build step, for the same reason the
 * backend has two dependencies: one fewer thing that can break on a laptop
 * two days before a demo. It is about four hundred lines and does four
 * things.
 *
 * The session token is kept in sessionStorage rather than localStorage, so
 * it dies when the tab closes. On a shared or borrowed computer — which a
 * family carer may well be using — that difference matters.
 */

const API = '/api/care';
const $ = (id) => document.getElementById(id);

let token = sessionStorage.getItem('mindpal_care_token');
let patients = [];
let openPatientId = null;

// --------------------------------------------------------------- transport

async function call(path, { method = 'GET', body } = {}) {
  const response = await fetch(API + path, {
    method,
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });

  let data = {};
  try { data = await response.json(); } catch { /* empty body is fine */ }

  if (response.status === 401 && token) {
    // The session expired or was revoked. Do not leave a dead token behind.
    signOut(true);
    throw new Error('Your session has ended. Please sign in again.');
  }
  if (!response.ok) throw new Error(data.error || 'Something went wrong.');
  return data;
}

function toast(message, isError = false) {
  const element = $('toast');
  element.textContent = message;
  element.className = isError ? 'toast error' : 'toast';
  element.hidden = false;
  clearTimeout(toast._timer);
  toast._timer = setTimeout(() => { element.hidden = true; }, 4000);
}

// ------------------------------------------------------------------- auth

$('tab-login').onclick = () => showAuthTab('login');
$('tab-register').onclick = () => showAuthTab('register');

function showAuthTab(which) {
  const isLogin = which === 'login';
  $('tab-login').classList.toggle('active', isLogin);
  $('tab-register').classList.toggle('active', !isLogin);
  $('login-form').hidden = !isLogin;
  $('register-form').hidden = isLogin;
}

$('login-form').onsubmit = async (event) => {
  event.preventDefault();
  try {
    const data = await call('/login', {
      method: 'POST',
      body: { email: $('login-email').value, password: $('login-password').value },
    });
    acceptSession(data);
  } catch (error) { toast(error.message, true); }
};

$('register-form').onsubmit = async (event) => {
  event.preventDefault();
  try {
    const data = await call('/register', {
      method: 'POST',
      body: {
        displayName: $('reg-name').value,
        email: $('reg-email').value,
        password: $('reg-password').value,
      },
    });
    acceptSession(data);
  } catch (error) { toast(error.message, true); }
};

function acceptSession(data) {
  token = data.token;
  sessionStorage.setItem('mindpal_care_token', token);
  $('who-name').textContent = data.caregiver.displayName;
  showDashboard();
  loadPatients();
}

$('logout').onclick = () => signOut(false);

async function signOut(alreadyGone) {
  if (!alreadyGone) { try { await call('/logout', { method: 'POST' }); } catch {} }
  token = null;
  sessionStorage.removeItem('mindpal_care_token');
  patients = [];
  openPatientId = null;
  $('auth').hidden = false;
  $('dashboard').hidden = true;
  $('who').hidden = true;
  $('detail').hidden = true;
}

function showDashboard() {
  $('auth').hidden = true;
  $('dashboard').hidden = false;
  $('who').hidden = false;
}

// --------------------------------------------------------------- linking

$('show-link').onclick = () => {
  const form = $('link-form');
  form.hidden = !form.hidden;
  if (!form.hidden) $('link-code').focus();
};

$('link-form').onsubmit = async (event) => {
  event.preventDefault();
  try {
    await call('/link', {
      method: 'POST',
      body: { code: $('link-code').value, relationship: $('link-rel').value },
    });
    $('link-code').value = '';
    $('link-rel').value = '';
    $('link-form').hidden = true;
    toast('Linked. They can change what you may see at any time.');
    loadPatients();
  } catch (error) { toast(error.message, true); }
};

// -------------------------------------------------------------- dashboard

async function loadPatients() {
  try {
    const data = await call('/patients');
    patients = data.patients;
    renderPatients();
    if (openPatientId) openPatient(openPatientId);
  } catch (error) { toast(error.message, true); }
}

const PERMISSION_LABELS = {
  viewReminders: 'See reminders',
  editReminders: 'Change reminders',
  viewVault: 'See memories',
  editVault: 'Add memories',
  viewActivity: 'See activity',
};


function renderPatients() {
  const container = $('patients');
  container.textContent = '';

  if (patients.length === 0) {
    container.innerHTML =
      '<p class="empty">Nobody yet. Use <strong>Link a new person</strong> '
      + 'and the code from their phone.</p>';
    return;
  }

  for (const patient of patients) {
    const card = document.createElement('div');
    card.className = 'patient';

    const perms = Object.entries(PERMISSION_LABELS)
      .map(([key, label]) => {
        const on = patient.permissions[key];
        return `<span class="perm ${on ? '' : 'off'}">${on ? '✓' : '·'} ${label}</span>`;
      })
      .join('');

    card.innerHTML = `
      <header>
        <h3></h3>
        <span class="rel"></span>
      </header>
      <div class="perms">${perms}</div>
      <div class="actions">
        <button class="secondary small" data-open="${patient.id}">Open</button>
        <button class="secondary small" data-perms="${patient.id}">Permissions</button>
        <button class="danger small" data-unlink="${patient.id}">Unlink</button>
      </div>`;
    // textContent, not innerHTML: a display name comes from user input.
    card.querySelector('h3').textContent = patient.displayName;
    card.querySelector('.rel').textContent = patient.relationship || '';
    container.appendChild(card);
  }

  container.onclick = (event) => {
    const button = event.target.closest('button');
    if (!button) return;
    if (button.dataset.open) openPatient(Number(button.dataset.open));
    if (button.dataset.perms) editPermissions(Number(button.dataset.perms));
    if (button.dataset.unlink) unlink(Number(button.dataset.unlink));
  };
}

async function unlink(patientId) {
  const patient = patients.find((p) => p.id === patientId);
  if (!confirm(`Stop caring for ${patient.displayName}? You can be linked again with a new code.`)) return;
  try {
    await call(`/patients/${patientId}/link`, { method: 'DELETE' });
    if (openPatientId === patientId) { openPatientId = null; $('detail').hidden = true; }
    toast('Unlinked.');
    loadPatients();
  } catch (error) { toast(error.message, true); }
}

function editPermissions(patientId) {
  const patient = patients.find((p) => p.id === patientId);
  const detail = $('detail');
  openPatientId = null;
  detail.hidden = false;

  // READ ONLY, deliberately. A caregiver used to be able to tick these,
  // which meant the person being granted access controlled the consent.
  // Granting now happens on the patient's own phone, and the server has no
  // route that would let this page change them.
  detail.innerHTML = `
    <div class="card">
      <h2>What ${escapeHtml(patient.displayName)} allows you to do</h2>
      <ul class="perm-list">
        ${Object.entries(PERMISSION_LABELS).map(([key, label]) => `
          <li class="${patient.permissions[key] ? 'on' : 'off'}">
            ${patient.permissions[key] ? '✓' : '✗'} ${label}
          </li>`).join('')}
      </ul>
      <p class="notice">
        Only ${escapeHtml(patient.displayName)} can change these, on their own
        phone: <strong>Profile &rsaquo; People who help me</strong>. Ask them
        if you need something you do not have.
      </p>
      <button id="close-perms" class="secondary">Close</button>
    </div>`;

  $('close-perms').onclick = () => { detail.hidden = true; };
}

// ---------------------------------------------------------------- detail

async function openPatient(patientId) {
  const patient = patients.find((p) => p.id === patientId);
  if (!patient) return;
  openPatientId = patientId;

  const detail = $('detail');
  detail.hidden = false;
  detail.innerHTML = `<div class="card"><h2>${escapeHtml(patient.displayName)}</h2>
    <div id="reminders-area"></div>
    <div id="activity-area"></div></div>`;

  await renderReminders(patient);
  await renderActivity(patient);
}

async function renderReminders(patient) {
  const area = $('reminders-area');

  if (!patient.permissions.viewReminders) {
    area.innerHTML = '<h3>Reminders</h3><p class="empty">You do not have permission to see these.</p>';
    return;
  }

  let reminders = [];
  try {
    reminders = (await call(`/patients/${patient.id}/reminders`)).reminders;
  } catch (error) {
    area.innerHTML = `<h3>Reminders</h3><p class="empty">${escapeHtml(error.message)}</p>`;
    return;
  }

  const canEdit = patient.permissions.editReminders;

  area.innerHTML = `
    <h3>Reminders</h3>
    ${reminders.length === 0 ? '<p class="empty">None yet.</p>' : `
      <table>
        <thead><tr><th>Time</th><th>What</th><th>Repeats</th>${canEdit ? '<th></th>' : ''}</tr></thead>
        <tbody>${reminders.map((r) => `
          <tr>
            <td class="time">${formatTime(r.hour, r.minute)}</td>
            <td>${escapeHtml(r.title)}${r.notes ? `<br><span class="hint">${escapeHtml(r.notes)}</span>` : ''}</td>
            <td>${r.repeat === 'daily' ? 'Every day' : 'Once'}</td>
            ${canEdit ? `<td><button class="danger small" data-del="${r.id}">Remove</button></td>` : ''}
          </tr>`).join('')}</tbody>
      </table>`}
    ${canEdit ? `
      <form id="add-reminder" class="grid-2" style="margin-top:16px">
        <div><label for="r-title">New reminder</label>
          <input id="r-title" type="text" placeholder="Take your medicine" required></div>
        <div><label for="r-time">Time</label>
          <input id="r-time" type="time" value="08:00" required></div>
        <div><label for="r-repeat">Repeats</label>
          <select id="r-repeat"><option value="once">Once</option><option value="daily">Every day</option></select></div>
        <div><label for="r-category">Kind</label>
          <select id="r-category">
            <option value="medicine">Medicine</option><option value="meal">Meal</option>
            <option value="appointment">Appointment</option><option value="dailyActivity">Daily activity</option>
            <option value="personal">Personal</option><option value="other">Other</option>
          </select></div>
        <div style="grid-column:1/-1"><button type="submit" class="primary">Add reminder</button></div>
      </form>
      <p class="notice">
        Saved on the server straight away. The phone picks it up the next
        time it syncs — see the limitations note in DEPLOY.md.
      </p>` : '<p class="hint">You may look at these but not change them.</p>'}`;

  if (canEdit) {
    area.querySelector('#add-reminder').onsubmit = async (event) => {
      event.preventDefault();
      const [hour, minute] = $('r-time').value.split(':').map(Number);
      try {
        await call(`/patients/${patient.id}/reminders`, {
          method: 'POST',
          body: {
            title: $('r-title').value,
            hour, minute,
            repeat: $('r-repeat').value,
            category: $('r-category').value,
          },
        });
        toast('Reminder added.');
        renderReminders(patient);
      } catch (error) { toast(error.message, true); }
    };

    area.onclick = async (event) => {
      const button = event.target.closest('button[data-del]');
      if (!button) return;
      try {
        await call(`/patients/${patient.id}/reminders/${button.dataset.del}`, { method: 'DELETE' });
        toast('Removed.');
        renderReminders(patient);
      } catch (error) { toast(error.message, true); }
    };
  }
}

async function renderActivity(patient) {
  const area = $('activity-area');
  if (!patient.permissions.viewActivity) {
    area.innerHTML = '<h3 style="margin-top:24px">Recent activity</h3>'
      + '<p class="empty">You do not have permission to see this.</p>';
    return;
  }

  let activity = [];
  try {
    activity = (await call(`/patients/${patient.id}/activity`)).activity;
  } catch (error) {
    area.innerHTML = `<p class="empty">${escapeHtml(error.message)}</p>`;
    return;
  }

  area.innerHTML = `
    <h3 style="margin-top:24px">Recent activity</h3>
    ${activity.length === 0 ? '<p class="empty">Nothing reported yet.</p>' : `
      <table><tbody>${activity.map((event) => `
        <tr><td class="time">${formatWhen(event.occurredAt)}</td>
            <td>${escapeHtml(event.summary)}</td></tr>`).join('')}</tbody></table>`}
    <p class="hint">
      Only what the phone chooses to report: games played and reminders
      completed. Never location, messages or anything typed.
    </p>`;
}

// --------------------------------------------------------------- helpers

function formatTime(hour, minute) {
  const suffix = hour < 12 ? 'AM' : 'PM';
  const twelve = hour % 12 === 0 ? 12 : hour % 12;
  return `${twelve}:${String(minute).padStart(2, '0')} ${suffix}`;
}

function formatWhen(iso) {
  const when = new Date(iso);
  const hours = Math.round((Date.now() - when.getTime()) / 3_600_000);
  if (hours < 1) return 'Just now';
  if (hours < 24) return `${hours}h ago`;
  return `${Math.round(hours / 24)}d ago`;
}

function escapeHtml(value) {
  const div = document.createElement('div');
  div.textContent = String(value ?? '');
  return div.innerHTML;
}

// ----------------------------------------------------------------- start

(async function start() {
  if (!token) return;
  try {
    const data = await call('/me');
    $('who-name').textContent = data.caregiver.displayName;
    showDashboard();
    loadPatients();
  } catch {
    // A stale token from a previous run; the sign-in form is already shown.
  }
})();

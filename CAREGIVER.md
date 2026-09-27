# The caregiver website

A second product in the same Express process: the patient's Flutter app keeps
using `/api/ai`, and a family carer opens the site at `/`.

```
Caregiver browser  ──▶  Express  ──▶  SQLite (accounts, links, reminders)
Patient's phone    ──▶  Express  ──▶  same database, via a device key
Patient's phone    ──▶  Express  ──▶  Gemini          (unchanged)
```

No new dependencies. `node:sqlite` and `node:crypto` are built into Node 22+,
so the backend still has exactly two: `cors` and `express`.

---

## Running it

```bash
cd server && npm start
```

Then open <http://localhost:8787/>. The database is created and migrated on
first boot, and the fictional accounts are seeded.

## Demo accounts

Both use the password **`mindpal-demo-2026`**.

| Email | Who they are | What they may do |
|---|---|---|
| `meena@example.com` | Bimala's daughter | see and change reminders, see memories, see activity |
| `rahul@example.com` | Bimala's son | **see reminders only** |

Everyone is invented. Sign in as each in turn: the two see the same person,
and Rahul gets no Add form, no Remove buttons, and "You do not have
permission to see this" where activity would be. That is the point of the
demo — permissions belong to a *pair*, not to a patient.

A third patient, Hari Sharma, is linked to nobody, so "a patient you cannot
see returns 404" is demonstrable.

## How linking works

1. The patient opens MindPal and asks for a code. Their device calls
   `POST /api/care/device/link-code` and shows a six-character code.
2. They read it to the caregiver, who types it into **Link a new person**.
3. The server records consent — who, when, by what method — and creates the
   link **with every permission off**.
4. Permissions are granted explicitly afterwards.

Codes expire in 15 minutes, die on first use, and issuing a new one kills the
old. The alphabet has no `0/O`, `1/I/L`, `5/S` or `8/B`, because it is read
off a phone screen by someone with poor eyesight.

## Deploying

It deploys with the existing service — no new Render configuration:

```bash
git push origin main
```

Render rebuilds, the migrations run on boot, and the site is at the same
hostname as the gateway. Set `CAREGIVER_DB_PATH` to move the database file.

**Read the disk warning below before showing this to anyone who matters.**

---

## Limitations, stated plainly

### The database does not survive a deploy

Render's free tier has an **ephemeral filesystem**. The SQLite file is wiped
on every deploy and every restart, taking accounts, links and reminders with
it. The demo accounts are re-seeded on boot so the site is never empty, but
anything typed during a demo is gone after the next push.

Fixes, in order of effort: a Render **persistent disk** (paid, one setting),
or a hosted Postgres. The schema is ordinary SQL and the store is one file.

### The patient's phone does not sync yet

`GET /api/care/device/sync?since=<rev>` is built and tested — it returns
every reminder changed since a revision number, including deletions. **The
Flutter app does not call it.** Nothing in the patient app talks to this
database, so a reminder added on the website does not reach a phone today.

What remains: a sync client in Flutter that stores the device key and the
last revision, polls on launch and on resume, and writes results through the
existing `ReminderService` so alarms are scheduled by the code that already
works. Deliberately pull-based — no Firebase, and a phone offline for a week
catches up in one request.

### Media upload is not built

There is no schema, no endpoint and no storage for caregiver photo or video
upload. It needs a place to put bytes that survives a restart, which the free
tier does not have, and doing it against ephemeral disk would mean uploads
that vanish — worse than not offering it.

### Permissions are editable by the wrong person

The site lets a caregiver change their own permissions, which is obviously
not how consent works. It is there so the demo can show what each setting
does. In the finished product only the patient may change them, on their own
phone; the server would refuse the request.

### Not built

Password reset, email verification, rate limiting on login, CSRF tokens
(the API is token-in-header, not cookies, so it is not directly exposed),
audit log of caregiver actions, and any patient-side UI for showing a code.

---

## What is tested

- **30 unit tests** (`npm test`) on passwords, sessions, link codes,
  permissions, reminder CRUD, sync and the schema.
- **26 end-to-end HTTP checks** covering sign-in, the two caregivers'
  differing permissions, 401 without a token, 403 without permission, 404 for
  an unlinked patient, validation, device sync including deletions, and
  cross-device isolation.
- The dashboard was driven in a browser: both caregivers signed in, and the
  view-only one gets no editing controls.

Not tested: anything on a real phone, because no device sync exists to test.

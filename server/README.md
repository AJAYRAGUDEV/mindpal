# MindPal AI Gateway

A small Express server that sits between the Flutter app and Gemini.

## Why this exists

**So the API key is never on the phone.** Anything shipped in an APK or a web
bundle can be extracted — `strings`, `unzip`, or just opening DevTools. A key
in a Flutter `--dart-define`, a `.env` asset, or a Dart constant is a published
key. The only safe place is a server you control.

```
Flutter app  ──HTTPS──▶  this gateway  ──HTTPS──▶  Gemini
  (no key)                (holds key)
```

## Setup

```bash
cd server
npm install
cp .env.example .env      # then edit .env and paste your real key
npm start
```

Get a key at <https://aistudio.google.com/apikey>.

**Check the model name before your first run.** `.env.example` defaults to
`gemini-2.5-flash`. Google renames and retires models; a stale name returns a
404 that looks like a broken key. Set `GEMINI_MODEL` to whatever is current.

Verify it started correctly:

```bash
curl http://localhost:8787/api/health
```

`{"ok":true,"geminiConfigured":true,"model":"..."}` — note it reports *whether*
a key is set, never the key.

## Endpoints

### `GET /api/health`
Whether the gateway is up and configured.

### `POST /api/ai`

```json
{
  "task": "memory_assistant",
  "language": "en",
  "context": [{ "kind": "person", "name": "Rahul", "relationship": "Son" }],
  "userInput": "Who is Rahul?"
}
```

```json
{ "success": true, "text": "Rahul is your son.", "hasEnoughInformation": true }
```

`task` is `memory_assistant` or `game_questions`.

## What leaves the device

Only the records the app has **already matched locally** for that one question.

For *"Who is Rahul?"* the request carries Rahul's name and relationship — and
deliberately **not** his phone number, not other family members, not notes, not
reminders, and not activity history. If local retrieval finds no match, the app
answers offline and **no request is sent at all**.

The gateway refuses any request carrying more than 8 records, so a bug in the
app cannot turn into a bulk upload.

Nothing is written to disk. The response cache is in memory, keyed by a SHA-256
hash rather than the request text, and dies with the process.

## Cost and rate limits

- `MAX_REQUESTS_PER_MINUTE` (default 20) — a fixed window, returns 429 beyond it
- 10-minute response cache — asking the same thing twice costs one call
- `maxOutputTokens` capped at 200 (answers) / 800 (questions)
- `temperature: 0.2` — we want faithful phrasing, not invention
- `REQUEST_TIMEOUT_MS` (default 15s) via `AbortController`

## Security notes

- The key is read from the environment into `config.js` and never leaves the
  process — not logged, not returned, not in any error message.
- It travels to Google in the `x-goog-api-key` **header**, not the query string,
  so it cannot end up in a proxy's URL log.
- `redact()` strips anything key-shaped from every message before it is logged
  or returned. There is a test for it.
- `.env` is git-ignored at both this level and the repository root.

## Tests

```bash
npm test
```

Covers request validation, key redaction, the cache, and the rate limiter.
**These do not call Gemini** — they are offline unit tests. The live Gemini path
has not been executed by anyone yet.

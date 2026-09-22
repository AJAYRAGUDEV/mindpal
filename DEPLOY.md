# Deploying MindPal for the SIH demo

Two pieces, deployed separately:

```
Flutter Web (Vercel)  ──HTTPS──▶  Node/Express gateway (Render)  ──▶  Gemini
   public link                      holds GEMINI_API_KEY
```

The Gemini key lives **only** in Render's environment. It is never in Flutter
source, never in `build/web`, never in git.

---

## 1. Backend on Render

The backend is **Node/Express**, not FastAPI — there is no Python in this
project. Render supports Node natively, so nothing needs rewriting.

1. Push this repository to GitHub.
2. Render → **New** → **Web Service** → connect the repo.
3. Render reads `render.yaml` at the repo root and fills in:
   - Root directory: `server`
   - Build command: `npm ci --omit=dev`
   - Start command: `npm start`
   - Health check: `/api/health`
4. Add the environment variables (Render dashboard → Environment):

| Key | Value |
|---|---|
| `GEMINI_API_KEY` | your real key — **only here** |
| `GEMINI_MODEL` | `gemini-3.5-flash-lite` (see "Which model" below) |
| `GEMINI_FALLBACK_MODELS` | `gemini-3.1-flash-lite,gemini-3-flash-preview` |
| `ALLOWED_ORIGIN` | your Vercel URL, e.g. `https://mindpal.vercel.app` |

`ALLOWED_ORIGIN` accepts a comma-separated list, and `*` for a quick demo.
You will not know the Vercel URL until step 2, so set it to `*` first and
tighten it afterwards.

5. Deploy, then check:

```bash
curl https://YOUR-SERVICE.onrender.com/api/health
```

Expect `{"ok":true,"geminiConfigured":true,"model":"..."}`. It reports
*whether* a key is set, never the key.

**Free tier sleeps after ~15 minutes idle.** The first request then takes
30–60 seconds. Open the health URL a few minutes before presenting so the
service is awake.

---

## 2. Frontend on Vercel

Flutter Web is built **locally** and the output is uploaded. Vercel has no
Flutter toolchain, so there is no remote build step.

```bash
cd mindpal
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

Then, from `mindpal/`:

```bash
npx vercel --prod
```

`vercel.json` already sets `outputDirectory: build/web` and the SPA rewrite, so
Vercel serves the built app and refreshing any route returns `index.html`
instead of a 404.

**Rebuild and redeploy whenever the backend URL changes** — `API_BASE_URL` is
compiled into the bundle at build time, not read at runtime.

Finally, set `ALLOWED_ORIGIN` on Render to the Vercel URL and redeploy the
backend.

---

## Which model, and why there is a fallback list

Measured on 22 September 2026 with this gateway's exact request, three
requests each:

| Model | Result |
|---|---|
| `gemini-2.5-flash` | 404 every time: "no longer available to new users" |
| `gemini-3.6-flash` | 1 answer, 2 x 503 "high demand" |
| `gemini-3.5-flash-lite` | 3 answers, ~1.3 s each |
| `gemini-3.1-flash-lite` | 3 answers, ~1.2 s each |
| `gemini-3-flash-preview` | 3 answers, ~2.4 s each |

Google sheds free-tier load on its newest models and retires old names while
still listing them, so a single fixed model is a coin toss. The gateway now
tries `GEMINI_MODEL`, then each of `GEMINI_FALLBACK_MODELS` in order, and
returns the first usable answer. Each attempt has its own 12 s deadline
(`REQUEST_TIMEOUT_MS`).

To re-measure, from `server/`:

```bash
npm run check
```

The Render log shows which model answered each request:

```
[ai] #4 task=general_knowledge lang=en input=22ch ctx=0 history=0 origin=https://mindpal.vercel.app
[ai] #4 model=gemini-3.5-flash-lite ok 1463ms
```

The question text is never logged, only its length. The key is never logged.

---

## Verifying Gemini works in production

1. Open the Vercel link.
2. **Memory** tab → People → add `Rahul` / `Son`.
3. Tap **Ask** (the button on every screen).
4. Ask **"Who is Rahul?"**

Read the small grey line under the answer:

| Line | Meaning |
|---|---|
| "Wording generated online from your saved record" | Gemini answered |
| "From your saved information, on this phone" | fell back to offline |

Then ask **"Tell me about Shillong"** — that has no vault entry, so it is a
pure general-knowledge call and only works when the backend is reachable.

If the gateway cannot be reached or every model fails, the app now says so:
"The AI Assistant is temporarily unavailable. Please try again." with a
**Try again** button. It no longer pretends to be offline. The Render log
shows the attempt list for the failed request:

```
[ai] #7 FAILED code=upstream_error attempts=[gemini-3.5-flash-lite:503/2461ms, ...] 9100ms
```

---

## 3. Android APK (same codebase)

The APK is built from the same source as the web app. The backend URL goes in
the same way:

```bash
cd mindpal
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

Output: `mindpal/build/app/outputs/flutter-apk/app-release.apk`. Copy it to a
phone and open it; allow "install from unknown sources" when asked.

The APK contains the backend URL and nothing else. The Gemini key is not in
it — the app talks only to the gateway, exactly as the web build does.

**Memory Vault media.** Photos and videos are copied into the app's private
documents directory (`memory_vault/` under `getApplicationDocumentsPath`).
They survive restarts and app updates and are removed with the app. Picking
uses the system photo picker, so no storage permission is declared or
needed. In the browser the same files go into IndexedDB (per browser, per
site; not shared between devices).

**Permissions.** Our manifest declares `INTERNET` only. The video player
library (ExoPlayer, via `video_player_android`) merges in two more:
`ACCESS_NETWORK_STATE` and `WAKE_LOCK`. Both are "normal" permissions:
granted at install, never prompted, not listed as sensitive. Local storage
needs no permission, and the system photo picker needs none either. Camera,
microphone, storage and notification permissions are *not* declared because
the app has no feature that uses them.

**Plain HTTP** is allowed in debug builds only (for a gateway on
`http://localhost` during development). A release APK refuses cleartext, so
the production gateway must be HTTPS — which Render is.

**Signing.** The release build is signed with the debug keystore, which is
fine for a demo installed by hand. Publishing to the Play Store would need a
real keystore; see `android/app/build.gradle.kts`.

**On this particular PC** the Gradle daemon needs one environment variable or
it dies on startup (`A new daemon was started but could not be connected to`).
Run once:

```bash
setx JAVA_TOOL_OPTIONS "-Djdk.net.unixdomain.tmpdir=C:\gtmp"
```

and open a new terminal. The directory `C:\gtmp` must exist. The reason is
explained in `android/gradle.properties`.

---

## Environment variables, in one place

**Render (backend)** — `GEMINI_API_KEY`, `GEMINI_MODEL`, `ALLOWED_ORIGIN`,
optionally `MAX_REQUESTS_PER_MINUTE`, `REQUEST_TIMEOUT_MS`.

**Vercel (frontend)** — none. The backend URL is a build-time `--dart-define`,
not a runtime variable, and it is not a secret.

**Local** — `server/.env`, copied from `server/.env.example`. Git-ignored.

---

## Local development

```bash
cd server && npm start
```

```bash
cd mindpal && flutter run -d chrome --web-port=5000 --dart-define=API_BASE_URL=http://localhost:8787
```

The app prints its backend on startup:
`BACKEND: http://localhost:8787 (from API_BASE_URL)`.

---

## Cost and rate limits

The gateway caps requests at 20/minute, caches identical requests for 10
minutes, and caps output tokens. Local retrieval runs first, so a question with
no vault match costs nothing — no request is sent at all.

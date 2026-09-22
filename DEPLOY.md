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
| `GEMINI_MODEL` | `gemini-2.5-flash` (verify it is in your model list) |
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

If it falls back, check the Render logs. The gateway prints the reason.

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

**Permissions.** The manifest declares `INTERNET` only. Local storage
(`shared_preferences`) needs no permission. Camera, microphone, and
notification permissions are *not* declared because the app has no feature
that uses them; declaring permissions the app never exercises would only
raise questions.

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

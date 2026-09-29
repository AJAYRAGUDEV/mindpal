# MindPal games — Play, Remember, Connect

*Explore familiar stories, traditions and memories through simple, engaging
games.*

MindPal is a cognitive **gaming** platform for older adults, built around
content from their own region and their own life. This document covers the game
side of the app: what exists, how the cultural content is structured, and what
still needs a person to check.

**What MindPal does not claim.** It does not diagnose, prevent, treat, slow or
reverse dementia or any other condition. It does not measure anybody's memory.
Nothing it records is an assessment, a score of a person, a stage or a trend.
It is a set of games that are enjoyable, culturally familiar, and kind to play.

---

## The games

| Game | Content | Notes |
|---|---|---|
| **Cultural Memory Match** | A cultural pack | Match pairs of named objects. A short fact is offered after each pair is found. |
| **Story Order** | A cultural pack | Read or hear a short story, then tap its scenes in the order they happened. |
| **Cultural Odd-One-Out** | A cultural pack | One object does not belong. The answer is always explained. |
| **Family Photo Match** | The player's own Memory Vault photos | Pairs built from photos the player picks. Nothing leaves the phone. |
| **Memory Moment** | The player's saved People / Places / Notes | Unchanged from before. |
| **Sequence Recall** | The app's own shapes | Unchanged, and kept: it exercises something different from Story Order. |

Cultural Memory Match and Cultural Odd-One-Out **reuse the existing game rules**
(`MemoryMatchGame`, `OddOneOutGame`) with the pictures supplied as a parameter.
Story Order has its own rules class, because "put these in the order they
happened" is not the same exercise as Sequence Recall's watch-and-repeat, and
forcing them into one class would have meant a flag that changes the meaning of
every field.

---

## Cultural content packs

Content lives in `mindpal/lib/content/`, completely separate from game rules.
No file under `content/` imports a game, and no game file contains cultural
data. The only place that knows about both is
`mindpal/lib/games/cultural/cultural_adapters.dart`.

```
content/
  cultural_pack.dart          the shapes: CulturalPack, CulturalItem,
                              CulturalStory, StoryScene, PackReview
  pack_library.dart           the list of packs that ship, and packFor()
  packs/
    assam_bihu_pack.dart      the starter pack
```

A pack carries: id, title, region, language note, review status, items (name,
kind, picture, plain description, optional fact, source), stories (text, ordered
scenes, hint, explanation, origin, attribution), source references, and an
artwork note.

### Adding a pack

1. Write one file in `content/packs/`.
2. Add it to `kCulturalPacks` in `pack_library.dart`.

That is all. No game changes, no UI changes. It appears in the selector
immediately.

### Why Dart `const` data and not JSON

The project already keeps game content this way (`kMemorySymbols`,
`kOddOneOutItems`). Const data cannot fail to parse, costs nothing at runtime,
and the compiler catches a missing field at build time rather than showing a
blank tile in front of a judge. The pack shapes are plain data with no
behaviour, so a JSON loader can be added later and hand back the same objects
without any game changing.

The real cost: a pack cannot be edited by a non-programmer. That is why
`PackReview` exists and is shown on screen.

### What the pack selector will not do

It lists only packs that have playable content. There is no greyed-out row for
Manipur, Nagaland or Mizoram, because a greyed-out row tells a user we have
their content when we do not. Instead the selector says in words that only Assam
is available so far, and that other regions each need a pack written with
somebody from that place.

Assam is **Assam**, not "the North East". One pack does not stand for a region
of eight states.

---

## ⚠ Content that still needs a person

**The starter pack is marked `PackReview.pendingReview`, and this is not a
formality.** Every sentence in it was written from general published knowledge
and **has not been read by an Assamese reviewer**.

While a pack is unreviewed:

* the pack selector shows "Facts not checked yet" on it,
* every cultural game shows the same note above the board,
* every fact shown after a correct answer carries "Not checked by a reviewer
  yet." underneath it.

To enforce the stricter policy — show facts only from a reviewed pack — change
one line in `cultural_adapters.dart`:

```dart
bool factsMayBeShown(CulturalPack pack) => pack.review.isReviewed;
```

### Specifically outstanding

1. **Cultural facts (20 items, 3 stories).** Need checking against a published
   source and reading by an Assamese speaker. Each item carries its own `source`
   field naming what to check it against. Only then should `review` become
   `PackReview.reviewed`.

2. **Artwork.** There are **no photographs or drawn illustrations**. Every
   picture is a stand-in symbol from the Material Design icon set (Apache 2.0),
   chosen to be told apart easily. Some are reasonable (a horn for the pepa, a
   cone for the japi); several are approximations. This is why the name of every
   object is *always* shown beside its picture and read out by TalkBack — the
   game never depends on recognising the symbol. Real photographs or commissioned
   artwork still need to be licensed or made.

3. **The three stories are original, not folklore.** They describe real customs
   (Bihu preparations, Assam tea, muga silk production) but they are not
   traditional tales, and each one carries an attribution saying exactly that,
   shown on screen before playing. A test asserts that any story marked
   `ContentOrigin.original` carries that attribution — presenting an invented
   story as folklore is the kind of error that is very hard to walk back.

4. **Pack content is English only.** The item names are Assamese words written
   in Latin letters, as they are said. Nothing is in the Assamese script. The
   pack's `languageNote` says so. The app's existing NER language support is
   separate and unchanged.

---

## Accessibility

Every game runs inside `GameShell`, which guarantees the same controls in the
same place:

* **Instructions in writing, always on screen** — not a dialog that has to be
  dismissed before playing and can then never be read again.
* **"Read this to me"** — appears only when the device actually has a voice
  installed. When it does not, the button is absent rather than present and
  silent, and the settings sheet says why.
* **Pause / Carry on / Start again / Leave** from one overlay. Memory Match
  genuinely stops its clock while paused, so a pause is not charged as playing
  time.
* **Leaving always returns a result**, so a game that was played is recorded
  even when the player walks away.
* Large touch targets (64dp minimum), text labels beside every icon, and every
  state distinguishable without colour (a number on a placed scene, a word for
  "Chosen", a tick plus a border).
* **No mandatory timer anywhere.** Memory Match shows a clock; it is a display,
  not a limit. Story Order and Odd-One-Out have no clock at all.
* Feedback is gentle and never says "wrong": *"Something else comes before that
  one. Have another look."*
* Answers are always **explained**, not just marked.

### Large text

`GameBoardLayout` caps the header to a fraction of the screen and lets it
scroll inside itself, so at a large system font size the words stay full size
and the board stays usable. Tests run all three boards at 1.5× and 2× and assert
no overflow.

The **board never scrolls** — scrolling a memory board would hide the cards the
player is trying to remember. The **footer is never capped or scrolled either**,
and must hold buttons rather than prose: it carries the action the player needs
next, so it has to stay reachable. An earlier version did cap it, and
Odd-One-Out's answer explanation pushed "Next question" off the bottom of the
screen — built, so a test could find it, but outside the viewport, so a tap on it
hit nothing. The explanation now sits in the scrolling header instead.

Clamping the text scale would have been two lines, and would have meant deciding
that a low-vision user may not have large text in the part of the app they came
to use.

### Settings

Games tab → **Sound, movement and reading aloud**: sounds and buzzes, less
movement, read instructions aloud, and whether MindPal may suggest a different
level. Saved under `game_settings_v1` and applied on the next launch.

**Sounds and buzzes** uses the platform's own click and haptics
(`GameFeedback`) — no audio files, no audio package, works offline, and it
follows the phone, so silent mode stays silent. It is a click confirming a tap
registered, not a chime or a buzzer: a wrong tap gets a lighter buzz rather than
a harsher noise, because a game for someone with memory difficulty should not
sound like a telling-off. Tests assert the switch genuinely silences it, by
counting haptic calls — Flutter's own InkWell plays a click on every tap, so
counting clicks would prove nothing.

---

## Adaptive difficulty

Rule-based, and the app calls it exactly that. It is a handful of `if`
statements over the last few saved sessions. **It is not a trained model and
must never be described as one.**

Thresholds live in one place — `AdaptiveDifficultyConfig` in
`mindpal/lib/services/adaptive_difficulty.dart`:

| Setting | Default | Meaning |
|---|---|---|
| `comfortableStreak` | 3 | Comfortable sessions before a harder level is offered |
| `strugglingStreak` | 2 | Hard-going sessions before an easier level is offered |
| `comfortableMistakes` | 1 | At most this many misses counts as comfortable |
| `strugglingMistakes` | 4 | This many misses or more counts as hard going |
| `comfortableHints` | 0 | Hints allowed while still "comfortable" |
| `strugglingHints` | 2 | Hints that count as hard going |

Three things it deliberately does not do:

* **It never reads how long anyone took.** `durationSeconds` is recorded and
  displayed, but no decision touches it. Playing slowly is not playing badly.
  There is a test for this.
* **It never changes the level itself.** It makes an offer; the player or a
  caregiver accepts it, declines it, or switches suggestions off entirely.
* **It draws no conclusion about the person.** The wording is always about the
  games ("the last three went smoothly"), never about a mind.

---

## Progress

Saved through the existing `GameHistoryService` / `LocalStorage`. Each session
records: game, cultural pack, difficulty, date, correct answers, mistakes, hints
used, duration, completion.

`GameResult` gained `packId`, `correct` and `hintsUsed`. `fromMap` defaults all
three, so **history written before cultural packs existed still reads** — there
is a test for that shape exactly.

**Games tab → Your progress** shows finished games and, kept separately, games
that were started and stopped. Starting a game and stopping is a normal thing to
do and is not tallied against anyone.

There is deliberately no chart, no percentage, no "improving" or "declining", no
stage and no comparison. A trend line drawn from four sessions of a matching
game would be noise dressed up as a diagnosis. A test asserts the words
"dementia", "decline", "improving", "worsening", "stage", "assessment" and
"diagnos…" appear nowhere on that screen.

### Caregiver dashboard

A finished game is reported to the existing `POST /api/care/device/activity`
endpoint and appears under **Recent activity** — but only for a caregiver the
patient granted `can_view_activity`, which the server enforces on the read.

What is sent is one predictable sentence:

```
Finished Cultural Memory Match (Assam: Bihu and everyday things) on Easy. 4 right, 1 missed.
```

Built in exactly one place, `CareSyncService.reportGameActivity`, so the rule is
checkable: **no photo, no photo caption, no memory title, no vault content, and
nothing from the family board beyond the fact that it was played.** Family Photo
Match is built from private pictures, and a summary reading "matched
Grandmother's funeral" would put a private caption on somebody else's screen.
There is a test asserting nothing private goes with it.

Reporting fails silently. Being offline is normal, and a game that was played
and enjoyed must not produce an error because a courtesy report could not be
filed.

---

## Offline

**Every bundled game and the whole starter pack work with no internet at all.**
The content is compiled into the app, progress and settings are local, and no
game screen takes a network client, an `AiService` or a `CareSyncService`. There
is a test that opens all three cultural games with no services passed to them,
so a bundled game growing a dependency on the gateway would break the build
rather than break a demo.

What does need connectivity, and says so where it is used:

* the Memory Assistant (Gemini, through the Express backend),
* Memory Moment's generated questions (it falls back to the deterministic
  service offline),
* caregiver sync and activity reporting.

**Audio is checked, not promised.** `VoiceController` asks the device which
voices it actually has. Where there is none, the Listen buttons are absent and
the settings sheet explains why, rather than the app claiming spoken
instructions everywhere.

---

## Family Photo Match and privacy

* Photos are read from the app's own media store, decoded, shown, and dropped
  when the game closes.
* **No face recognition.** No automatic grouping of people.
* **Nothing is uploaded.** No photo or caption is sent to Gemini or any other
  service, and none is written into a saved result.
* Cards pair on the vault record's id, never on the photo's caption — two
  memories can easily share a title, and matching on the title would let two
  different photos count as a pair.
* **Deleting a photo is safe by construction.** The selection is never stored,
  so there is no list of photo ids that can go stale: each game reads the vault
  again, and a deleted photo is simply not offered. If a file disappears between
  choosing and playing, the card falls back to the title on a plain tile and the
  game carries on. Both paths are tested.
* At least 3 photos are needed. With fewer, the game says how many are needed
  and where to add them.

---

## Running it

```bash
cd mindpal && flutter run
```

Web demo and Android APK are built exactly as before (see `DEPLOY.md`). The
caregiver site and backend are unchanged (see `CAREGIVER.md`).

### Demonstrating it

1. **Home** opens on **Play a game**, with Continue playing beneath it and the
   games named with their difficulty.
2. **Games tab** — pick the Assam pack, pick a difficulty.
3. **Cultural Memory Match** — match a pair, read the fact, note that it says it
   is unchecked. Press **Pause**.
4. **Story Order** — read "Tea in the morning", press **I am ready**, tap the
   three scenes in order, read **Why this order**.
5. **Cultural Odd-One-Out** on Hard — note that it says the board is six tiles
   rather than nine, because the pack has five items per kind. Ask for a hint.
6. **Family Photo Match** — needs 3 photos in the Memory Vault first.
7. **Your progress** — finished games, and started-but-stopped kept separate.
8. Turn the phone's font size up to maximum and replay step 3.

---

## Tests

```bash
cd mindpal && flutter analyze && flutter test
cd server && npm test
```

New game-related coverage lives in:

* `test/cultural_content_test.dart` — pack integrity, the adapters, Story Order
  rules, pause, adaptive difficulty, settings, saved-progress compatibility
* `test/cultural_games_widget_test.dart` — the three cultural games, Family
  Photo Match (including no photos, too few photos and a missing file), the
  progress screen, large text at 1.5× and 2×, and running with no services
* `test/game_hub_test.dart` — the hub, the pack selector, difficulty
  suggestions, the settings sheet, and progress surviving a restart
* `test/care_sync_test.dart` — what the activity report does and does not contain

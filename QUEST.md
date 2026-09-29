# Festival Quest

*Explore a village, talk to people, solve a small mystery, and help get a
celebration ready.*

Festival Quest is MindPal's main experience: one five-to-seven minute adventure
with three locations, four characters, a market, a mystery, a courtyard to
prepare and two endings. It runs with no internet at all.

The older matching and sequencing games are still whole, under **Quick Games**.

---

## Playing it

```bash
cd mindpal && flutter run
```

The app opens on Festival Quest. **Start Adventure** → read the introduction →
**Begin the adventure**.

A demo path, about six minutes:

1. **Village square.** Tap **Ammal**, hear her out, offer to fetch the list.
   She gives you 26 coins and names five things.
2. Tap **Murugan**. He mentions seeing Selvi carry her flower basket towards
   the market before dawn — that is your first clue — and asks whether he may
   bring the cows to the celebration. **This is the decision that changes the
   ending.**
3. **To the market.** Tap **The stalls**. The jaggery has sold out; tap
   **Kannan** and he tells you palm sugar will do just as well. Buy a pot, rice,
   the palm sugar, milk and sugarcane.
4. **To the courtyard.** Tap **Selvi**: the kolam stencil is missing.
5. Back at the market a **stack of boards** has appeared behind Kannan's stall —
   it only appears once you know a flat board is missing. Tap it.
6. In the courtyard, **Say where the stencil went**: choose *Market*, tick all
   three clues, and say what you think.
7. **Get the courtyard ready**: tap a thing, tap where it goes. Choose how it
   should look. **Begin the celebration.**

Play again and turn Murugan down to see the other ending.

---

## What is where

```
mindpal/lib/adventure/
  model/requirement.dart      Requirement and Effect — the whole rule language
  model/adventure.dart        Locations, characters, dialogue, market, mystery,
                              courtyard, quests, endings
  engine/adventure_state.dart One playthrough, immutable
  engine/adventure_engine.dart The rules. No Flutter import.
  validation/adventure_validator.dart  Structure
  validation/adventure_solver.dart     Can it actually be finished?
  content/pongal_adventure.dart        The bundled adventure
  generation/adventure_variation.dart  Applying generated words to the template
  generation/adventure_generator.dart  Asking the backend, and falling back
  storage/adventure_store.dart         Adventures, progress and finished runs
  ui/                                  The screens
server/src/adventure/variation.js      The Gemini prompt, retries and sanitiser
```

---

## How the AI is used, and what it cannot do

**Gemini writes words. It does not write rules.**

The app sends a list of *text slots* — `char.ammal.name`, `clue.clue_basket.text`,
`ending.ending_quiet.text`, and about a hundred others generated from the
adventure itself. Gemini returns replacement strings. `applyVariation` puts them
into the hand-written template, and there is **nowhere in that function to put a
requirement, an effect, a price, a coin total, a clue relationship, a quest
dependency or an ending condition**. Those are copied from the template
unchanged, every time.

The one mechanical choice a generation may make is which item has sold out, and
it must come from a two-entry list that was checked with the solver in advance.
An unrecognised value is ignored and the standard one is used.

So the worst a bad generation can do is read oddly. Three layers stand behind
that anyway:

| Layer | Where | What it catches |
|---|---|---|
| Sanitiser | Server | Keys the app never asked for, non-strings, empty or oversized values. Drives up to 3 retries. |
| `applyVariation` | App | Anything mechanical, by construction — it cannot be expressed. |
| `AdventureValidator` + `AdventureSolver` | App | Structure, and whether the finished adventure can actually be completed, by playing it. |

If any of that fails the player gets the bundled adventure and is told why in
plain words. **The key never leaves the server**, exactly as with the assistant.

### The solver

`AdventureSolver` plays an adventure every way it can, through the same
`availableActions` list the UI offers, and reports which endings are reachable.
Nothing is published to a player until it says yes.

It runs one guided depth-first search per ending, ordered by how close a
position is to *that* ending. Breadth-first was the first attempt and does not
survive the shopping: six buyable things make sixty-four baskets, and multiplied
by flags, clues and placements that is hundreds of thousands of positions before
the search ever reaches the courtyard. The guided version settles the bundled
adventure in **98 positions, about 66ms**. Nothing is pruned — the ordering only
decides what is looked at first — so an adventure that can be finished is still
found, and one that cannot is still explored in full before being called broken.

---

## Things the tests found

Three real bugs, all caught by tests rather than by playing:

1. **A player could strand themselves in the market.** Both pots cost 15 of 26
   coins and the rest of the list then costs 16, with no way to sell anything
   back — the adventure would still be running and no longer finishable. The
   market now refuses a purchase that would leave the remaining list
   unaffordable, and says so: *"You will need your coins for the rest of the
   list."* Every genuinely valid basket is still available.
2. **Selvi greeted every new player with the answer to a question they had not
   asked.** The node meant for "tell me about it again" was unconditional and
   listed above her opening line, and a character opens with the *first* line
   whose condition is met. The validator now refuses any adventure where an
   unconditional line is not the last one.
3. **The highlight ring pulsed for ever**, which is exactly what the "less
   movement" setting exists to remove — and it meant the widget tree never
   settled, so every test that waited on it hung. It is a steady ring now.

---

## Difficulty

Two paces, chosen before each adventure. **Guidance only** — the story, the
prices, the puzzles and the cultural content are identical.

| | Relaxed | Standard |
|---|---|---|
| Shopping list | Always on show | In the journal |
| Interactive points | Ringed | Not ringed |
| Hints | Direct | Point at what to think about |

Hints are free, always available, and counted only so the summary can mention
them. Nothing reads the count to make anything harder.

---

## Accessibility

* The scene fills the screen; everything else arrives as a panel over it.
* **Every person and object is named in the picture.** Nothing is a
  guess-the-icon puzzle.
* Dialogue is one line at a time in a readable panel, with the speaker's name
  *and* who they are, every time.
* **Tap to select, tap to place. Dragging is never required** — drag-and-drop
  needs a press, a hold, a controlled move and a release, and failing any part
  undoes the whole attempt.
* Large text and large touch targets throughout; a word under every icon.
* **No timers anywhere, and nothing reflex-based.**
* Narration where the device has a voice; where it does not, no dead buttons,
  and the text is always on screen.
* A wrong answer is never an ending: the mystery gives a nudge, a wrong
  placement says *"nothing is lost"*, and the courtyard arrangement is never
  wrong at all.

---

## Offline and saving

**The bundled adventure is compiled into the app and needs no connection.**
Progress is written after every action — location, inventory, coins, flags,
clues, decisions, placements and the arrangement — so closing the app never
loses anything.

A generated adventure is saved in full the moment it arrives and replays offline
like any other. Up to six are kept; the bundled one can never be removed.

**Making a new adventure needs a connection**, and the app says so next to the
button. Where no backend is configured the button is absent rather than present
and broken.

---

## Navigation

| Destination | What it holds |
|---|---|
| **Festival Quest** | Start, Continue, Saved Adventures |
| **Quick Games** | Cultural Memory Match, Story Order, Cultural Odd-One-Out, Family Photo Match, Memory Moment, Sequence Recall |
| **My Progress** | Adventures finished, endings discovered, and a link to the quick-game record |
| **Extras** | Reminders, Memory Vault, the assistant, profile and caregiver linking |

**Caregiver linking is no longer on the way into anything.** It is preserved in
full — accounts, consent codes, permissions, reminder sync, activity reports —
and it now lives in Extras. A test asserts that nothing on the path into an
adventure mentions a caregiver, a code or a sign-in.

---

## ⚠ Still needing a person

1. **There is no artwork.** Scenes are two colours and a horizon; people and
   objects are Material icons on coloured discs. Every one carries its name, so
   the game never depends on recognising a picture — but this is placeholder art
   and it looks it. Replacing it changes one file, `ui/adventure_scene.dart`:
   every hotspot already carries a position, a colour and a label.
2. **The cultural note is unreviewed.** What the adventure says about Pongal is
   widely published, but no Tamil reviewer has read this text, and the app says
   so on the introduction screen.
3. **The story is fiction and is labelled as fiction** before play begins and
   again on the ending screen. Kalvayal and everyone in it are invented.
4. **Replay variation is narrow.** Generation varies the wording and which item
   has sold out. It does *not* vary the mystery's solution: whether a set of
   clues really points at a place is a question about meaning, and no validator
   can check it — so a wrong answer would be undetectable. Widening this means
   hand-writing a second mystery configuration and checking it with the solver,
   not asking the model for one.
5. **Generation is untested against the live model.** The sanitiser, the retry
   loop, the fallbacks and the validation are all tested; a real Gemini response
   is not, because that needs a key and a network.

---

## Tests

```bash
cd mindpal && flutter analyze && flutter test   # 489 tests
cd server && npm test                           # 58 tests
```

* `test/adventure_engine_test.dart` — the rules: money, the sold-out
  alternative, the soft-lock guard, the mystery, the courtyard, both endings,
  the journal, save/restore, and seven broken adventures the validator must
  reject
* `test/adventure_variation_test.dart` — every allowed variation is solvable; a
  hostile text pack cannot change a single rule; the generator falls back rather
  than failing
* `test/adventure_ui_test.dart` — the screens: scenes, conversations, the
  market, the journal, the mystery, tap-to-place, the ending, and saving
* `test/widget_test.dart` — the four destinations, Extras, and that playing is
  never gated on a caregiver
* `server/test/adventure.test.js` — what the server will and will not pass on

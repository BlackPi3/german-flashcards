# TODO: Card layout redesign — make reviewing fast and gradable

**Status:** fold + `Q` shortcut are live **deck-wide** as of 2026-09-01, via a template script — no per-note migration was needed. The grading rule is written into CLAUDE.md (Rule 25) and the rules version is bumped to **2.1.1**. Only the fold's Styling box CSS is still open — see "Session 2026-09-01" below.

---

## The problem, stated

Reviewing takes too long, and — the sharper issue — **it is not clear what to press.**

A Vollkarte shows badge + meanings + English lines + examples + Grammatik box with `bl`,
`vl`, Wendungen, NVV, Kollokationen, Synonyme, Antonyme. When the back appears the user has
to scan all of it, and then decide Again/Hard/Good/Easy against a target that was never
defined. "I knew the meaning but not the Feste Wendung" has no correct button.

Two distinct costs:
1. **Time** — re-reading reference material on every rep, forever.
2. **Grading noise** — an ambiguous grading target feeds FSRS bad data, which is worse
   than slow reviews. This is the real reason to fix it.

The card is doing two jobs at once: it is a **test** (front → can I produce the meaning?)
and a **reference sheet** (everything known about the word). The reference sheet is
valuable and worth keeping. It just should not be unconditionally displayed, and it must
not be part of what gets graded.

---

## Current state (verified 2026-08-18)

- Deck: `Einfach Besser! 500 B2`, ~1900+ notes.
- Note type: `Einfach Besser!` — a **Basic clone**. Two fields, `Front` / `Back`.
  One card template:
  - Front: `{{Front}}`
  - Back: `{{FrontSide}}<hr id=answer>{{Back}}`
- All structure lives inside the `Back` field as HTML with CSS classes
  (`c fq mn gr bl vl ex tr tl-* ver`); the stylesheet lives in the note type's Styling box.
- Because everything is one opaque field, the template can currently do **nothing**
  selectively — it cannot hide, reorder, or generate a second card from part of the content.
  That limitation is the crux of the whole decision.

---

## Options on the table

### A. Fold the reference tail (progressive disclosure)
Wrap the tail of the Grammatik box in `<details>` so it renders collapsed.

- **Visible by default:** badge, meaning(s), English lines, example + translation,
  `bl` line, `vl` line + its example. Everything production-critical — gender, plural,
  auxiliary, preposition.
- **Collapsed:** Nominalisierung, Feste Wendungen, NVV, Kollokationen, Redemittel,
  Synonym, Antonym. Recognition material, wanted on demand, not every rep.
- **Grading rule becomes explicit:** you grade the visible part only.
- **Cost:** low if done in the template; but with a single opaque `Back` field the template
  cannot find the seam — so this likely needs either a field split (option C) or a
  JS snippet in the template that locates `.tl-*` elements and wraps them at render time.
  The JS route touches nothing in 1900 notes and works on legacy cards too. Worth testing.
- **Risk:** folded content is content you stop looking at. Mitigated by the cut line above —
  nothing load-bearing is hidden.

### B. Split into several cards per word — the idea that started this
"Conjugation one card, meaning another, NVVs, Kollokationen…"

- **Rejected in its general form.** A card whose answer is a *list* cannot be graded:
  "NVVs with *Frage*?" → you recall one of three and have no honest button to press.
  Same for Kollokationen, Synonyme, Antonyme. Conjugation has the same defect — the
  answer is a table.
- Also multiplies ~1900 notes into ~9000 cards, most of them low-value.
- **The one exception worth doing: valency.** `scheitern an + Dat` is a genuinely
  independent failure — the word is known and the preposition still comes out wrong.
  Correct shape is a **cloze on a sentence**, not Front/Back:
  `„Der Umbau ist {{c1::am}} Geld gescheitert."`
  Three seconds, tests production in context, unambiguous to grade. Same shape would work
  for plural and Perfekt auxiliary. Only for words actually being got wrong — not by default.

### C. Restructure the note type into real fields
Split `Back` into e.g. `Bedeutung`, `Beispiel`, `Grammatik`, `Wendungen`, `Register`, `Meta`.

- Makes the template genuinely able to control layout, hide sections, and generate
  extra cards (e.g. a valency cloze) without new notes.
- Clean long-term answer; the current single-field design is what blocks everything else.
- **Cost is the migration:** every existing note has to be parsed out of its `Back` HTML
  into the new fields. Doable — the HTML is regular and class-tagged — but it is a real
  one-off job across the whole deck, and it interacts with the ongoing rules-version
  backlog maintenance.
- Scheduling is safe (fields/templates don't reset scheduling as long as the card
  template count and ordering are handled carefully).

---

## Decisions to make when we pick this up

1. **What exactly is the grading target?** Write it down as one sentence that applies to
   every card, e.g. *"Again/Hard/Good/Easy answers only: did I produce the meaning and the
   core valency?"* Everything else on the card is reference and never affects the button.
   → This should end up in CLAUDE.md as a rule, and ideally printed on the card itself.
2. **Fold via template JS (no migration) or restructure into fields (migration)?**
3. **If restructuring: what is the field list?** Decide once — changing it later is another
   migration.
4. **Do we add valency cloze cards?** If yes: new note type, and a rule for when a word
   earns one (only on demonstrated errors, not by default).
5. **Do Kurzkarten still make sense** if the Vollkarte folds by default? Folding may make
   the Kurz/Voll distinction redundant — one card shape that expands on demand.
6. **Rules version bump.** Any of this is at least MINOR; option C is MAJOR.

---

## Measure first

Before committing to anything: check Anki's stats for **seconds/card** and reviews/day.

- ~8s × 250 cards → the problem is volume, not layout. Folding barely helps; the answer is
  workload (new-card limit, deck size, suspending Kurzkarten).
- ~30s × 60 cards → the problem is exactly the card, and folding is the fix.

Cheap to check, and it decides which option is even worth building.

**Skipped rather than measured** — user confirmed by direct experience (2026-09-01) that
reviews genuinely take too long, and separately said he *likes* reading the reference
material — he doesn't want it gone, he wants it not to be mandatory reading on every rep.
That statement is itself the case for Option A (folding), so the stats check was treated as
already answered qualitatively. Fine to still pull the numbers later out of curiosity, but
it's no longer a gate on proceeding.

---

## Session 2026-09-01 — direction chosen, build blocked

**Decision: Option A (fold via template JS), not Option C (field restructuring).**
Reasoning: no migration across ~1900+ notes, works retroactively on legacy cards too, and
is easy to undo if it doesn't help. Option C stays the long-term answer if Option A turns
out to be insufficient, but it's not the first thing to build.

**Cut line for the fold** (as proposed, not yet confirmed against a live card):
- **Visible by default:** badge (`fq`), meaning(s) (`mn` box in full — definition, English
  lines, example), the `bl` line, the `vl` line(s) + their examples.
- **Folded behind `<details>`:** `tl-nom`, `tl-fw` (+ its example), `tl-nvv` (+ its example),
  `tl-kl`, `tl-rm`, `tl-syn`, `tl-ant`.
- **New grading rule** (to be added to CLAUDE.md once the prototype is approved): grade
  Again/Hard/Good/Easy on the visible part only — meaning + core valency. Folded content is
  reference and never a grading input.

**User go-ahead:** "implement your idea on one flashcard and i'll see how it looks" — a
real card, prototype only, not a deck-wide change. This is a go-ahead for the *one-card
prototype*, not for rolling it out — still confirm before touching the note type's Styling
box for real or before writing the grading rule into CLAUDE.md.

**Blocked on:** Anki MCP connection. Both configured servers (`anki`, `claude.ai AnkiMCP`)
showed not-connected this session. Verified with `curl` that the Anki desktop app *is*
running and its addon *is* serving MCP on `127.0.0.1:3141` (responds to a JSON-RPC POST,
just wants `Accept: application/json, text/event-stream` — i.e. it's speaking
streamable-HTTP/SSE) — so the addon side is healthy. The client-side connection is what's
down: user ran `/mcp` from the terminal and got "5 MCP server(s): 0 connected, 5 not
connected, 0 disabled" — reconnect attempt did not fix it. Suspect this needs a fresh
Claude Code session (not just `/mcp` mid-session) to re-init the MCP client, but that's
unconfirmed.

**Outcome (2026-09-01):** Anki MCP connected fine on this session (no client-side issue
after all — worth noting in case it recurs). Built the prototype on note `Sorge`
(noteId 1776708671262):
- Tail (`tl-fw`+ex, `tl-nvv`+ex, `tl-syn`, `tl-ant`) wrapped in
  `<details class="fold"><summary>Mehr: Wendungen, Synonyme, Antonyme</summary>…</details>`
  written into that one note's `Back` field via `update_note_fields`.
- User then asked for a keyboard shortcut to open the fold instead of clicking. First
  attempt put a `<script>` in the note's own field — **Anki silently strips `<script>`
  from field content on save** (the write tool reports success with no warning; only a
  re-read shows the script is gone — see [[anki-script-sanitization]]). Had to move the
  listener into the note type's **card template** instead (Card 1, Back side, appended
  after `{{Back}}`), which is not sanitized. `Q` toggles all `details.fold` elements;
  checked against Anki's documented default reviewer shortcuts first (1–4, Space/Enter, E,
  R, M, -, =, @, Ctrl+K, Ctrl+1–7, Ctrl+Z, O) and it's free. Guarded with
  `window.__foldQBound` so re-rendering the same card doesn't stack duplicate listeners.
- **User confirmed 2026-09-01: "yes it works. nice job."**
- Note: the template change is technically live for every note using this note type, not
  just `Sorge` — but it's a no-op everywhere else since no other note has a `details.fold`
  element yet. Still, it's a bigger blast radius than the field-only edit was, worth
  flagging if this comes up again.
- Styling box untouched — the fold currently renders with the browser's plain default
  disclosure triangle, no custom CSS.

**Rollout (2026-09-01):** user asked "isn't there a better way" than editing every note by
hand for every change — answer was: push structural/presentational changes into the
template (as already done for the `Q` shortcut), reserve per-note edits for actual content
changes. Built it: a second script block in Card 1's Back template scans every `.gr` box
at render time, finds the first `tl-nom`/`tl-fw`/`tl-nvv`/`tl-kl`/`tl-rm`/`tl-syn`/`tl-ant`
child, and moves it plus everything after it into an auto-created `details.fold`. Live now
for the whole deck (157+ notes have `tl-nvv` alone) with zero per-note edits. Skips `.gr`
boxes that already contain a `details.fold` (so `Sorge`'s hand-built version isn't
double-processed) and ones with no tail content (⚙ Grammatikkarten). See
[[card-redesign-open]] for the full script and the legacy-card trace that verified it.

**Decisions made 2026-09-01 (via AskUserQuestion):**
- Auto-expand on Again/Hard? **No — always start collapsed.** Settled.
- Kurzkarte vs. Vollkarte still worth keeping? **Yes, keep Kurzkarte as-is** — it solves a
  different problem (how much content a card holds) than the fold does (what's shown per
  rep).
- Grading rule: written into CLAUDE.md as **Rule 25**, rules version bumped to **2.1.1**,
  changelog entry added. No rework needed — the fold and the rule both already apply to
  every existing note regardless of stamp.

**Styling built 2026-09-01 — initiative closed.** Added `details.fold`/`summary` CSS
(dashed top divider, `▸`/`▾` marker that flips on `[open]`, neutral blue-grey color, night
mode variants) to the note type's Styling box, mirrored into
`.claude/reference/anki-stylesheet.md`. Also changed the deck-wide summary label to
`Mehr: Wendungen, Synonyme, Antonyme (Taste: Q)` so the shortcut is discoverable, and
patched `Sorge`'s hand-built fold to match (its summary text was baked into the field, not
generated by the script, so it needed its own edit).

**Status: everything from this todo has shipped.** Fold (deck-wide, zero migration), `Q`
shortcut (deck-wide), grading-rule Rule 25 + CLAUDE.md version 2.1.1, and styling are all
live. Nothing left open from this file — see [[card-redesign-open]] if picking this thread
back up later.

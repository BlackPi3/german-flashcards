---
name: flashcard-maintenance
description: Migrate stale notes in the Anki deck "Einfach Besser! 500 B2" up to CLAUDE.md's current Rules Version. Rebuilds are staged as local files under staged/ instead of being written to Anki, so the user can keep studying; `apply` pushes them into Anki on command. Takes the number of notes to process this run as an argument (default 5), or `apply` / `status`; counts above 5 are split into batches of 5, one subagent per batch. Use when the user asks to continue backlog maintenance, rework stale cards, bring the deck up to the current rules version, or apply/submit staged maintenance changes.
---

# Flashcard backlog maintenance

Bring notes in `Einfach Besser! 500 B2` up to the Rules Version current in
`CLAUDE.md`. CLAUDE.md is the sole authority on card content — this file only
describes the *migration mechanism*.

The queue is **self-consuming**: a rebuilt note gets the current `Regeln::`
tag, which drops it out of the backlog query. Never keep a separate list of
processed notes; re-query every cycle.

## Stage, don't write

**A maintenance run never writes to Anki.** Writing while the user studies
locks them out of reviewing, so every rebuild and every companion/bonus card is
**staged as files** under `staged/pending/` and pushed into Anki later, in one
go, when the user asks for it. During a run Anki is only *read*
(`find_notes`, `notes_info`); `update_note_fields`, `add_note` and
`tag_management` are never called by this skill.

The mechanics live in `anki_stage.py` at the repo root (run it with `--help`
for the file format):

| Command | Does |
|---|---|
| `python3 anki_stage.py status` | counts staged rebuilds / new notes / conflicts |
| `python3 anki_stage.py ids` | staged note ids, comma-separated — excluded from the queue |
| `python3 anki_stage.py has-front WORD` | exit 0 if a staged new note already has that front |
| `python3 anki_stage.py apply [--dry-run]` | pushes everything staged into Anki |

Because staged rebuilds haven't reached Anki, their old `Regeln::` tag is still
there — so the queue is **self-consuming only together with the staging
area**: every backlog query excludes staged ids (step 2).

`apply` refuses to overwrite a note that was edited in Anki after it was staged
(its `mod` no longer matches `base_mod`); that change moves to
`staged/conflicts/`, and the note simply comes back through the queue for a
fresh rebuild.

## Argument: how many notes this run

`/flashcard-maintenance [N]` — `N` is the total number of notes to migrate
(stage) this run. **Default `N = 5`** when no argument is given.

`/flashcard-maintenance apply` — no migration. Run
`python3 anki_stage.py apply --dry-run`, then `python3 anki_stage.py apply`,
and relay its output (✅ applied, ⚠ conflicts, ⏭ duplicates, ✗ errors, and any
`⚠ Front geändert` lines). Only ever on the user's explicit request — this is
the one step that writes to Anki, so it must not happen while they study.
Anki has to be open.

`/flashcard-maintenance status` — run `python3 anki_stage.py status` plus the
backlog count, report, stop.

- **`N ≤ 5`** → a single batch of `N`, one subagent, then stop.
- **`N > 5`** → split into batches of **5** (the last batch takes the
  remainder, e.g. `N = 12` → 5, 5, 2). One subagent per batch, back to back,
  no approval step between batches (see "Relay and continue" below) — but the
  run still ends the moment `N` notes have been migrated or the backlog hits
  0, whichever comes first.

`N` replaces the old fixed 50-note/5-batch cap — the cap *is* whatever the
user asked for this run.

## One cycle

### 1. Read the current version

Read the `## Rules Version` heading in `CLAUDE.md`. Call it `VCUR`. Never
hardcode it here — it moves.

### 2. Pull the next batch — oldest rules version first

**Work the deck in ascending stamp order, not note-ID order.** Creation order
is *not* version order: an old note may have been rebuilt recently, so an
ID-sorted batch comes out mixed. Always drain the lowest-versioned bucket
before moving to the next.

**Exclude everything already staged.** Run `python3 anki_stage.py ids` once
per batch and, if it prints anything, append `-nid:<that list>` to every query
below (e.g. `deck:"Einfach Besser! 500 B2" -nid:123,456 Back:*v1.0.0*`). A
staged note still carries its old stamp in Anki; without the exclusion it gets
rebuilt twice. Counts reported to the user are likewise *after* exclusion.

Take the first bucket below that still returns results, and pull up to **5**
from it (or fewer, if the remaining count toward `N` this run is smaller):

| Order | Query (after `deck:"Einfach Besser! 500 B2"`) |
|---|---|
| 1 | `-Back:*class=\"ver\"*` — unstamped, pre-1.0 legacy |
| 2 | `Back:*v1.0.0*` |
| 3 | `Back:*v1.2.0*` |
| 4 | `Back:*v1.3.0*` |
| 5 | `Back:*v1.4.0*` |
| 6 | `Back:*v1.4.1*` |
| 7 | `Back:*v1.5.0*` |
| 8 | `Back:*v1.6.1*` |
| 9 | `Back:*v1.6.2*` |
| 10 | `Back:*v1.7.0*` |
| 11 | `Back:*v2.0.0*` |

The stamp lives in the `Back` field, so these are field-content searches;
the escaped quotes in the legacy query are required. **Derive the ladder from
the changelog rather than trusting this list** — add a row whenever a version
ships, and drop the bottom row once it equals `VCUR`. `v1.1.0` and `v1.6.0` are
absent because no card in the deck carries them.

Legacy first is deliberate: those cards have no badge, no `mn` box, dead `tl`
classes and free-standing examples, so they are both the worst cards in the
deck and the ones a rebuild improves most.

Report the remaining total each cycle so the user sees it shrink, and say which
bucket the batch came from. When every bucket is empty the backlog is clear:
say so and stop.

**Distribution snapshot, 2026-08-11** — re-query live, this moves:

| Stamp | Notes |  | Stamp | Notes |
|---|---|---|---|---|
| *(unstamped)* | 1189 | | v1.4.1 | 27 |
| v1.0.0 | 101 | | v1.5.0 | 86 |
| v1.2.0 | 22 | | v1.6.1 | 28 |
| v1.3.0 | 46 | | v1.6.2 | 226 |
| v1.4.0 | 8 | | v1.7.0 | 196 |
| | | | v2.0.0 | 419 |

Deck total 2348. Stamp and `Regeln::` tag were verified to agree in both
directions on every v2.0.0 note, so either can be trusted for that bucket.

> **TODO — retire the `Back` ladder once every note is tagged.**
> The ladder above exists only because tags started at v1.7.0, so the untagged
> notes (1733 of 2348 as of 2026-08-11) cannot be ordered any other way — a
> legacy card and a v1.6.2 card are both simply "no tag". Every note this skill
> touches gets a `Regeln::` tag, so that number only goes down.
>
> **When `deck:"Einfach Besser! 500 B2" -tag:Regeln::*` returns 0, delete the
> ladder and this note.** Finding the oldest is then one tag query sorted by
> its `Regeln::` subtag, and no `Back` field search is ever needed again:
>
> ```
> deck:"Einfach Besser! 500 B2" -tag:Regeln::vVCUR
> ```
>
> Check the count at the start of a run; it is cheap and the switch-over should
> not be missed. Keep reading the stamp to *verify* a note once opened — tag and
> stamp are two copies of one fact and can drift; the stamp is the card face and
> wins. Only the *search* moves to tags.

### 3. Classify each note

```
notes_info  notes=[...]  exclude_fields=["css"]
```

**Read the version from the `ver` stamp in the `Back` field, not from the
tags.** Tags only exist from v1.7.0 onward, so an untagged note is usually a
stamped v1.x note, not a legacy one. `<span class="ver">v1.3.0</span>` means
v1.3.0 regardless of what tags are or aren't present.

| Stamp vs. `VCUR` | Action |
|---|---|
| No stamp at all | Legacy (pre-1.0) → **full rebuild** |
| MAJOR behind | **Full rebuild** (CLAUDE.md Rule 15) |
| Same MAJOR, MINOR behind | **Additive patch** — add only what the changelog entries between the two versions require; leave correct content alone |
| PATCH behind only | Nothing to change. Re-tag to `VCUR` so it leaves the queue |

To decide what a MINOR patch needs, read the `### Changelog` entries in
CLAUDE.md between the note's stamp and `VCUR` — each one states what it added.

*As of v2.0.0 the whole backlog is 1.x, so every note is a full rebuild. The
table matters for the next MINOR bump.*

### 4. Dispatch one subagent for the batch

One subagent per batch of up to 5 — this is the context-management lever. The
orchestrating session must **never rebuild cards inline**; it queries,
classifies, dispatches, and relays short summaries. That is what lets a loop
session run for hours without bloating.

Hand the subagent: the note IDs, each one's front + current stamp + `mod` +
verdict (rebuild / patch-to-`VCUR` / re-tag only), and `VCUR`. Brief it to:

- Read `/Users/parham/Desktop/Berlitz/Flashcard/CLAUDE.md` in full first — it
  is the authority on card content, depth and format.
- **Never call `update_note_fields`, `add_note` or `tag_management`.** Anki
  is read-only for this run; every change is staged as files (below). Where
  CLAUDE.md says to write a note or set tags, stage it instead.
- Pull each note with `notes_info`, rebuild or patch the `Back` field per
  CLAUDE.md, and stage it: first write the full Back HTML to
  `staged/pending/<note_id>.back.html`, **then** `staged/pending/<note_id>.json`
  (the `.json` is written last — it marks the change as complete):
  `{"op": "update", "note_id": <id>, "base_mod": <mod from notes_info>,
  "front": "<front>", "tags": [...], "summary": "<front> — <English gloss>"}`.
  `base_mod` must be copied exactly from the same `notes_info` read the rebuild
  was based on.
- Decide **Vollkarte vs. Kurzkarte from the badge** before writing (Rule 19c).
  A Kurzkarte is the right size, not a worse card — never pad one out.
- Stamp `VCUR` and list the note's tags in the `.json` `tags` array —
  `Regeln::vVCUR`, `Häufigkeit::`, `Register::`, plus `Karte::IT` /
  `Karte::Grammatik` where they apply. List **only these managed tags**: on
  apply, stale `Regeln::`/`Häufigkeit::`/`Register::`/`Karte::` tags are
  removed and any other tag on the note is left alone. `apply` rejects a change
  whose `Regeln::` tag doesn't match its stamp.
- **Keep the front unless it is actually wrong** under CLAUDE.md's front rules.
  The `.json` `front` is always the intended front (unchanged or new). If it
  changes, report it as `⚠ Front geändert: alt → neu` (Rule 15a).
- Stage companion and bonus cards triggered by Rules 13a (Group 3 reflexive),
  18a (spoken equivalent) and 20 (cognates). **Duplicate check in both places
  first** — `find_notes` in Anki *and* `python3 anki_stage.py has-front <word>`
  for one already staged — then write `staged/pending/add-<slug>.back.html`
  followed by `staged/pending/add-<slug>.json`:
  `{"op": "add", "front": "<front>", "tags": [...], "summary": "..."}`
  (`<slug>` = the front, lowercased, spaces → `-`, umlauts kept). `apply`
  re-checks for duplicates before adding.
- Return a compact summary only: numbered front + English gloss, any changed
  front on its own line, and new companion/bonus cards listed separately.
  No HTML, no per-card commentary.

### 5. Relay and continue

Post the subagent's summary plus the remaining count toward `N`. Then start
the next batch immediately — no approval step between batches, as long as
notes migrated so far is still below `N` and the backlog isn't empty.

**Stop once `N` notes are staged — or the backlog hits 0, whichever comes
first.** That is one run, not a target to push past. Report the total staged
(out of `N` requested), the remaining backlog, and the `anki_stage.py status`
line, and remind the user that nothing reaches Anki until they run
`/flashcard-maintenance apply` (or `python3 anki_stage.py apply`). Then wait for
the user to ask for another run (with a new `N`, or the default 5).
Do not offer to keep going in a way that reads as waiting for permission to
continue; the run is simply over.

## Never start unprompted

Staging keeps writes away from study time, but a run still reads the live
collection and **`apply` writes to it** — the user decides when either happens.
So:

- **Only begin — or apply — when the user explicitly asks.** Not on a hunch that the backlog
  is large, not because a previous session left it unfinished, not as a
  follow-on to unrelated flashcard work. A stale backlog is never a reason to
  start on your own.
- **Stop when they say stop**, and stop *promptly* — finish the batch in flight
  if it is nearly done, otherwise abandon it. A half-staged batch costs
  nothing: a note without a `.json` isn't staged and comes back next cycle.
  (Delete a stray `.back.html` with no `.json` beside it if you abandon one.)
- Never run `apply` as a follow-on to a migration run, and never suggest it
  would be a good moment — the user may be studying.

## Rules of engagement

- **Never bulk-edit.** Every note goes through a real rebuild against
  CLAUDE.md. A scripted find-and-replace on the HTML would produce notes that
  pass the tag query while still being wrong, and the tag is then a lie.
- **Never retro-tag without rebuilding**, for the same reason.
- Don't touch scheduling. Tags sit on the note and are scheduling-neutral;
  `anki_stage.py apply` only uses `update_note_fields`, `tag_management` and
  `add_note`. The migration run itself uses no write calls at all.
- `update_note_fields` fails on a note open in the Anki browser. `apply`
  leaves such a change in `pending/` and prints ✗ — relay it, don't hide it;
  the next `apply` retries.
- **A run is capped at the requested `N` notes (batches of 5), then it ends
  on its own.** It also ends early if the user stops it or the backlog hits
  0. Never run open-endedly — see "Never start unprompted" for when starting
  is allowed at all. Migrating ~1,900 notes is many separate runs by design,
  not one long session.

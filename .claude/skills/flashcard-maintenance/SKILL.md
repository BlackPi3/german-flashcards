---
name: flashcard-maintenance
description: Migrate stale notes in the Anki deck "Einfach Besser! 500 B2" up to CLAUDE.md's current Rules Version. Takes the number of notes to process this run as an argument (default 5); counts above 5 are split into batches of 5, one subagent per batch. Use when the user asks to continue backlog maintenance, rework stale cards, or bring the deck up to the current rules version. Typically driven by /loop during an attended Anki session.
---

# Flashcard backlog maintenance

Bring notes in `Einfach Besser! 500 B2` up to the Rules Version current in
`CLAUDE.md`. CLAUDE.md is the sole authority on card content — this file only
describes the *migration mechanism*.

The queue is **self-consuming**: a rebuilt note gets the current `Regeln::`
tag, which drops it out of the backlog query. Never keep a separate list of
processed notes; re-query every cycle.

## Argument: how many notes this run

`/flashcard-maintenance [N]` — `N` is the total number of notes to migrate
this run. **Default `N = 5`** when no argument is given.

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

Hand the subagent: the note IDs, each one's front + current stamp + verdict
(rebuild / patch-to-`VCUR` / re-tag only), and `VCUR`. Brief it to:

- Read `/Users/parham/Desktop/Berlitz/Flashcard/CLAUDE.md` in full first — it
  is the authority on card content, depth and format.
- Pull each note with `notes_info`, rebuild or patch the `Back` field per
  CLAUDE.md, and write it with `update_note_fields`.
- Decide **Vollkarte vs. Kurzkarte from the badge** before writing (Rule 19c).
  A Kurzkarte is the right size, not a worse card — never pad one out.
- Stamp `VCUR` and set tags with `tag_management` — `Regeln::`, `Häufigkeit::`,
  `Register::`, plus `Karte::IT` / `Karte::Grammatik` where they apply. Use
  `replace_tags` to clear a stale `Regeln::v1.x`, `add_tags` otherwise. A note
  left with its old `Regeln::` tag silently re-enters the queue next cycle.
- **Keep the front unless it is actually wrong** under CLAUDE.md's front rules.
  If it changes, report it as `⚠ Front geändert: alt → neu` (Rule 15a).
- Create companion and bonus cards triggered by Rules 13a (Group 3 reflexive),
  18a (spoken equivalent) and 20 (cognates) — **`find_notes` for a duplicate
  first**, then `add_note` into the same deck with note type `Einfach Besser!`
  and full `VCUR` tags.
- Return a compact summary only: numbered front + English gloss, any changed
  front on its own line, and new companion/bonus cards listed separately.
  No HTML, no per-card commentary.

### 5. Relay and continue

Post the subagent's summary plus the remaining count toward `N`. Then start
the next batch immediately — no approval step between batches, as long as
notes migrated so far is still below `N` and the backlog isn't empty.

**Stop once `N` notes are migrated — or the backlog hits 0, whichever comes
first — and hand Anki back.** That is one run, not a target to push past.
Report the total done (out of `N` requested) and the remaining backlog, and
wait for the user to ask for another run (with a new `N`, or the default 5).
Do not offer to keep going in a way that reads as waiting for permission to
continue; the run is simply over.

## Never start unprompted

**Writing to Anki blocks the user from studying.** A batch in flight means they
cannot review cards. So:

- **Only begin when the user explicitly asks.** Not on a hunch that the backlog
  is large, not because a previous session left it unfinished, not as a
  follow-on to unrelated flashcard work. A stale backlog is never a reason to
  start on your own.
- **Stop when they say stop**, and stop *promptly* — finish the batch in flight
  if it is nearly done, otherwise abandon it. A half-migrated batch costs
  nothing: the untouched notes keep their old tag and come back next cycle.
- Between batches is the natural place to hand Anki back. If the user says
  anything mid-run, treat it as stop-and-yield rather than finishing the queue.

## Rules of engagement

- **Never bulk-edit.** Every note goes through a real rebuild against
  CLAUDE.md. A scripted find-and-replace on the HTML would produce notes that
  pass the tag query while still being wrong, and the tag is then a lie.
- **Never retro-tag without rebuilding**, for the same reason.
- Don't touch scheduling. Tags sit on the note and are scheduling-neutral;
  `update_note_fields` and `tag_management` are the only write calls used.
- If the user is reviewing in Anki, `update_note_fields` fails on a note open
  in the browser. Surface the failure, don't silently skip it.
- **A run is capped at the requested `N` notes (batches of 5), then it ends
  on its own.** It also ends early if the user stops it or the backlog hits
  0. Never run open-endedly — see "Never start unprompted" for when starting
  is allowed at all. Migrating ~1,900 notes is many separate runs by design,
  not one long session.

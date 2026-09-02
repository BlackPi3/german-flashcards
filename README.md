# German Anki Flashcard Generator

An AI tutor setup for building a German Anki deck through Claude Code. Point it
at a German text, a screenshot of a textbook page with underlined words, or a
fill-in-the-blank exercise, and it writes properly structured flashcards
straight into a live Anki collection — no CSV export, no manual import.

## The story

The deck started as a straight read-through of the *Einfach Besser! 500 B2*
vocabulary book — that's where the deck's name comes from. But it didn't stay
scoped to the book for long: words and phrases I picked up from conversations,
news, work, and everyday life kept getting folded in too. The name is just
where it began, not a boundary on what belongs in it anymore. These days the
deck is closer to "everything worth remembering in German," with the original
book as the seed.

**Current focus: spoken German.** Vocabulary I'd actually use in conversation
(plus anything IT/software-related, since that's my work) gets the full card
treatment. Formal, bureaucratic, or rare vocabulary still gets a card if it
came up somewhere real, but a deliberately smaller one — see "Card structure"
below. The point is to spend review time on the words that pay off when I
open my mouth, not on cramming everything a textbook could theoretically
throw at a B2 learner.

## How it works

`CLAUDE.md` is the whole spec: what makes a word worth a card, how much detail
it earns, and the exact HTML layout to write. Claude Code reads it as project
instructions on every run, so there's no separate app or script generating
cards — it's one long, carefully iterated prompt plus a live connection to
Anki via an MCP connector (`add_note` / `update_note_fields` / `find_notes`,
etc.), so cards land directly in the collection as they're written.

There are two ways cards get made:

- **Live sessions** — I hand Claude a sentence, a word list, or a photo of a
  textbook page, and it creates cards immediately, no approval step, with a
  short summary of what was added at the end.
- **Backlog maintenance, unattended** — the rules have gone through several
  revisions (see the version history in `CLAUDE.md`), so older cards fall
  behind the current format. The `.claude/skills/flashcard-maintenance` skill
  reworks stale notes back up to the current rules version, batch by batch.

### `loop.sh` — running maintenance overnight

`flashcard-maintenance` only migrates a handful of notes per invocation (context
management — one subagent per batch of 5 keeps each run small and reliable).
`loop.sh` is what turns that into an unattended job:

```
./loop.sh <number-of-runs>
```

Each run launches a **fresh, non-interactive `claude -p` session** that invokes
the skill on the next batch of stale notes, then exits. `loop.sh` just keeps
starting new sessions back to back — one per line of output — until the
requested number of runs is done. It also watches for rate-limit messages and
sleeps (default one hour) before retrying the same run rather than failing
the whole job. That combination — small isolated batches, a fresh session
each time, automatic backoff — is what makes it safe to kick off before bed
and wake up to a smaller backlog, without babysitting it or risking a wall of
half-finished edits if a session runs out of steam.

Tunable via environment variables (model, effort level, batch prompt, sleep
intervals) — see the comments at the top of the script.

## Card structure

Every card is built from the same three blocks, plus a version stamp:

```
┌─ badge ─────────────────────────────────────────────────────
│ Häufigkeit: hoch · Register: gesprochen
└───────────────────────────────────────────────────────────────

┌─ meaning box (mn) ─────────────────────────────────────────────
│ Bedeutung: <German definition>
│   → <English translation of the definition>
│   → <short English gloss>
│ „<example sentence>"
│   → <English translation>
└───────────────────────────────────────────────────────────────

┌─ grammar box (gr) — always visible ─────────────────────────────
│ <article + plural — or conjugation + Perfekt auxiliary>
│ <valency pattern>
│ „<example>"
│   → <English translation>
│
│ ▸ Mehr: Wendungen, Synonyme, Antonyme (Taste: Q)   ← folded, collapsed by default
│   Feste Wendungen · NVV · Kollokationen · Redemittel · Synonym · Antonym
│                                        (click the toggle, or press Q, to expand)
└───────────────────────────────────────────────────────────────

v2.1.1                                              ← version stamp, closes the card
```

The fold exists because a review grade (Again/Hard/Good/Easy) needs one clear
target: did I know the meaning and produce it correctly? Everything above the
fold is that test. Everything inside it — fixed expressions, collocations,
synonyms/antonyms — is depth material for building expertise, never something
the grade depends on, so it stays out of the way until asked for.

1. **Badge** — `Häufigkeit` (how common the word is: `hoch`/`mittel`/`niedrig`)
   and `Register` (how it's actually used: `gesprochen`/`neutral`/`eher
   schriftlich`/`Amtssprache`). Anything not already `gesprochen` must also
   name the everyday spoken alternative, so a formal word never becomes a
   dead end — the colloquial version gets pulled onto its own card too.
2. **Meaning box** — a German definition, two English lines (a direct
   translation, then a short practical gloss), and one example sentence per
   meaning, in whatever register the word actually lives in.
3. **Grammar box** — gender/plural for nouns, conjugation quirks and the
   Perfekt auxiliary for verbs, valency patterns with case governance, each
   with its own example. A reference tail (fixed expressions, near-synonym
   collocations, synonyms/antonyms) is folded behind a `<details>` toggle at
   render time — useful for building depth, but never part of what a review
   grade is judged on.

Depth follows the two things I actually need: **spoken German and IT/software
vocabulary get the full card above.** Everything else that still earned a
place (formal correspondence, bureaucratic terms, rare words encountered in
passing) gets a **Kurzkarte** — badge, one meaning, minimal grammar, one
example, nothing more. A short card isn't an unfinished one; it's sized to
match how much attention that word deserves.

A separate card type, marked `⚙`, exists for grammar choices that no single
word's card can teach on its own — which preposition a verb takes, `als` vs.
`wenn`, that kind of fork between options.

## Repo layout

```
CLAUDE.md                          the full ruleset — content rules, card format, versioning
.claude/skills/flashcard-maintenance/  the backlog-rework skill (see loop.sh above)
.claude/reference/anki-stylesheet.md   the CSS the cards render with in Anki
.claude/settings.json                  Claude Code permissions for this project
loop.sh                             unattended overnight batch runner
docs/card-redesign.md               design log behind the current card layout (closed/shipped)
export/einfach-besser-500-b2.jsonl  a point-in-time export of the deck
```

`export/einfach-besser-500-b2.jsonl` is one JSON object per line —
`{"front": ..., "back": ..., "tags": [...]}` — pulled directly from the live
Anki collection. `back` is the raw card HTML described above. It's a snapshot,
not something the workflow reads from; the deck itself is the source of
truth, this is just what it looked like when exported.

## Requirements to run this yourself

- [Claude Code](https://claude.com/claude-code)
- Anki, with the [AnkiMCP Server addon](https://github.com/ankimcp/anki-mcp-server-addon)
  installed (`Tools → Add-ons → Get Add-ons`, code `124672614`). It runs an MCP
  server inside Anki itself — no AnkiConnect needed — exposing `add_note`,
  `update_note_fields`, `find_notes`, `notes_info`, `tag_management`, etc.
  directly against your collection. See [ankimcp.ai](https://ankimcp.ai/docs/how-to/connect-claude/)
  for wiring it up to Claude Code/Desktop.
- A note type with `Front` / `Back` fields and the stylesheet from
  `.claude/reference/anki-stylesheet.md` in its Styling box

## License

[MIT](LICENSE) — use, copy, modify, and redistribute freely, attribution
appreciated.

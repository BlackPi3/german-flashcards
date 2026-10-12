# Project summary — German Anki Flashcard Generator

Plain-language snapshot of what this project is and what it currently does.
Written to be source material for a CV/resume update — current state only,
no version history (see `CLAUDE.md`'s changelog for that).

## What it is

A personal German-vocabulary learning system built on top of Claude Code and
Anki. Instead of manually writing flashcards, I hand Claude a German text, a
photo of a textbook page, or a fill-in-the-blank exercise, and it generates
fully-structured, pedagogically-designed flashcards and writes them straight
into a live spaced-repetition deck — no export file, no manual import step.

## Scale

- **2,800+ flashcards** in active use, spaced-repetition reviewed daily.
- **1,050** tagged as top-priority (core spoken German or IT/work vocabulary).
- **83** IT/software-specific vocabulary cards (reflecting real work usage).
- **23** dedicated grammar-contrast cards for rules that trip up learners
  (preposition choice, case governance, verb-pair confusions).
- A ~40-page specification (`CLAUDE.md`) defines the entire card format,
  content-inclusion criteria, and a semantic-versioning scheme so the format
  can keep evolving without silently breaking already-created cards.

## System design

- **Specification-driven generation.** All content rules — what counts as
  common vs. rare vocabulary, how much detail a word earns, exact output
  format — live in a single versioned specification document that an LLM
  (Claude) reads and applies on every card it writes. There is no separate
  generation script; the spec itself is the program.
- **Live integration via MCP.** Cards are created/edited directly in the
  Anki desktop app's live collection through a Model Context Protocol server,
  with duplicate detection against the real deck before every write.
- **Template-driven rendering, not per-card markup.** Visual and behavioral
  features (an importance indicator, register/spoken-equivalent chips, a
  collapsible "reference" section, audio playback) are implemented once in
  the card's HTML/CSS/JS template and computed at render time from each
  note's tags and existing content — so a presentation change ships across
  the entire deck instantly, without touching any of the 2,800+ individual
  records. Tags double as lightweight structured data for this purpose.
- **Staged writes with a validation gate.** Bulk maintenance (bringing older
  cards up to the current spec) never writes to the live collection directly.
  Every change is staged to disk first and validated — structurally (is the
  record well-formed) and semantically (does the content actually satisfy
  the spec's requirements, e.g. does every listed meaning have an example) —
  before a separate, explicit "apply" step pushes it live. This exists
  specifically to catch a rebuild that *looks* complete (right version stamp,
  right tags) but silently carries over incomplete content.
- **Cost-aware batch orchestration.** A backlog-processing skill dispatches
  one subordinate AI task per small batch of records rather than one giant
  session, deliberately trading parallelism for lower per-unit cost and
  staying within a subscription's usage limits instead of metered API spend.
  An unattended overnight runner retries on rate limits, stops immediately on
  billing errors, and logs every failure for inspection.

## Stack

Claude Code (LLM-driven generation + orchestration) · Anki + a custom MCP
server (data store, spaced-repetition scheduling, rendering) · Python
(staging/validation tooling) · Bash (unattended batch runner) · HTML/CSS/JS
(card template and rendering logic).

## What this demonstrates

Designing a content specification precise enough for an LLM to apply
consistently at scale; building a rendering architecture that separates
computed/derived presentation from authored content so changes propagate
without a data migration; building a validation layer that catches a
semantically incomplete result that passes structural checks; and running
cost-aware, fault-tolerant batch automation against a real usage-limited
LLM subscription.

# Anki stylesheet — `Einfach Besser!` note type

Reference copy. **The authoritative version lives in Anki**, in the note type's
*Styling* box. This file is a mirror kept for version history and for editing
offline — if the two ever disagree, Anki is right. Read it back with the MCP
call `model_styling(model_name="Einfach Besser!")`, write it with
`update_model_styling`.

Moved out of `CLAUDE.md` on 2026-08-11: it is only consulted when changing the
styling, so it does not need to load into every card-building session. Nothing
here changed in the move.

## Rules for editing it

The stylesheet is never inline in the `Back` field — that would repeat it on
every one of thousands of notes. There is one stylesheet for the whole deck, so
it has to serve old and new cards at once. Two consequences:

- **Nothing is ever removed from it.** `.tl` is dead in new cards but stays
  forever, because legacy cards still reference it. Deleting a class is the one
  edit that breaks old cards.
- **Adding a class is always safe** — cards that don't use it can't be
  affected. Changing a *colour* applies deck-wide, which is how the dark-mode
  fix reaches legacy cards too.

`.mn` is amber against `.gr`'s blue so the two boxes never read as one. Both
borders work on light and dark, so they need no night-mode override.

Every card's Back HTML marks section gaps (badge → `mn` → `gr` → stamp) with a
literal `<br><br>`, while in-section line breaks (Rule 12) use a single `<br>`.
`.c br + br` targets only the *second* `<br>` of each pair — the one that adds
the blank line — via the browser trick of setting `line-height` directly on a
`<br>` to size the empty line it produces. That halves the section gap without
touching normal single-`<br>` spacing, and needs no per-card markup change
since it's a CSS-only selector on an existing pattern.

## Current stylesheet

**2026-10-07 (b):** word → pips gap halved again. `.wgt-chiprow` is now a flex row, so the chip no longer sits on a full-height text line (that strut was ~4px of empty space above the chip), `margin-top:-3px` was too tight, settled on `0` (about 9–10px gap).

**2026-10-07:** phone-browser text bump. AnkiWeb renders at real device width (`width=device-width`), so the 14px `.mn`/`.gr` text set on 2026-09-23 really was 14px on a phone. A `max-width:600px` block raises `.card`/`.c`/`.mn`/`.gr`/chips there, skipping the phone apps via their `.mobile` class. Pinch-zoom on AnkiWeb resets on every card because the card re-renders; CSS cannot persist it, hence a fixed size instead.

**2026-10-06 (v3.0.2):** the opening badge is hidden on the back (`.card .c > .fq:first-child`) and its Register / `gespr.:` / usage-warning segments render on the front as `.wgt-tag` chips under the pips, tinted per Gewicht (`--bg` = the pip chip's background, `--ink` = a darker shade of the dot colour). The word → pips gap was halved (`.wgt-chiprow` margin-top 8px → 0).

**2026-09-23:** the `line-height` trick on `.c br + br` never really worked —
an empty line can't be shorter than the parent's strut (`.c` line-height 1.6
≈ 26px), so each section gap stayed one to two full blank lines. The
section-gap `<br>`s adjacent to `.fq`/`.mn`/`.gr` are now `display:none` and
the gap comes from margins (10px between sections, after a first pass at 4–6px felt too tight). Selectors are
anchored to those blocks, so legacy cards without `mn`/`gr` keep their line
breaks. `.mn`/`.gr` text dropped 16px → 14px. Gap above the badge cut too:
`hr#answer` bottom margin → 4px, and on cards where an `mn` box follows, the
badge becomes a block (both `<br>`s after it hidden) so it no longer sits in a
full-height line box with extra space above the chip. `.mn-row` lays each
meaning out as two columns (definition | example) on screens ≥760px wide; the
rows are built by the template script (see `anki-templates.md`).

Verified identical to the live Anki note type on 2026-09-08. Section gaps
(`.c br + br`) cut another 50% this round (0.6em → 0.3em, on top of the
0.8em → 0.6em from 2026-09-01) — smaller gaps deck-wide, per user request.
`.fq` is now a real chip (background, radius, padding) instead of plain
coloured text, and its rendered wording is abbreviated (`schriftl.` /
`Amtsspr.` / `gespr.:`) so the badge is glanceable instead of a sentence to
read — see CLAUDE.md's Häufigkeit/Register badge section. The `.card` block
at the top is Anki's own default wrapper, present in the note type but not
previously mirrored in `CLAUDE.md`.

```css
.card {
    font-family: arial;
    font-size: 20px;
    line-height: 1.5;
    text-align: center;
    color: black;
    background-color: white;
}
.c  { font-size:16px; line-height:1.6; text-align:left; }
.c br + br { line-height:0.3em; }
/* Section gaps: hide the <br><br> between badge / mn / gr / stamp — margins below set the gap instead */
.c > .fq + br + br:has(+ .mn),
.c > .mn + br, .c > .mn + br + br,
.c > .gr + br, .c > .gr + br + br { display:none; }
.c > .mn, .c > .gr { font-size:14px; }
/* Bedeutung in two columns on wide screens: definition left, example right (rows built by the template script) */
.mn-row + .mn-row { margin-top:8px; }
@media (min-width:760px) {
    .mn-row { display:grid; grid-template-columns:1fr 1fr; column-gap:24px; }
}
/* Gap above the badge: tighten the divider, and lift the badge out of its 26px line box */
hr#answer { margin-bottom:4px; }
.c > .fq:has(+ br + br + .mn) { display:block; width:fit-content; }
.c > .fq + br:has(+ br + .mn) { display:none; }
.c > .mn, .c > .gr, .c > .ver { margin-top:10px; }
.tr { color:#888; font-size:smaller; }
.gr { border-left:3px solid #42A5F5; padding-left:10px; margin:4px 0; }
.bl { color:#1565C0; }
.vl { color:#9C27B0; }
.tl { color:#00838F; }
.ex { color:#2E7D32; }
.tl-nom { color:#00838F; }
.tl-fw  { color:#BF360C; }
.tl-nvv { color:#6A1B9A; }
.tl-kl  { color:#00695C; }
.tl-rm  { color:#AD1457; }
.tl-syn { color:#0277BD; }
.tl-ant { color:#C62828; }
.ver { color:#bbb; font-size:10px; text-align:right; display:block; }

.mn { border-left:3px solid #FFA726; padding-left:10px; margin:4px 0; }
.fq {
    display:inline-block;
    background:#EFEBE9;
    color:#6D4C41;
    font-size:11px;
    font-weight:bold;
    letter-spacing:0.2px;
    padding:2px 8px;
    border-radius:10px;
}

.nightMode .fq  { background:#4E342E; color:#D7CCC8; }
.nightMode .tr  { color:#aaa; }
.nightMode .bl  { color:#64B5F6; }
.nightMode .vl  { color:#CE93D8; }
.nightMode .ex  { color:#81C784; }
.nightMode .tl, .nightMode .tl-nom, .nightMode .tl-kl { color:#4DB6AC; }
.nightMode .tl-fw  { color:#FF8A65; }
.nightMode .tl-nvv { color:#BA68C8; }
.nightMode .tl-rm  { color:#F06292; }
.nightMode .tl-syn { color:#4FC3F7; }
.nightMode .tl-ant { color:#EF5350; }
.nightMode .ver { color:#666; }

/* Gewicht: label chip above the front word. Only on notes tagged Gewicht::rot|orange|gelb|grau;
   the front-template script builds it. Untagged cards are unaffected. */
.wgt-chiprow { margin-top:0; display:flex; justify-content:center; }
.wgt-chip {
    display:inline-flex;
    align-items:center;
    gap:5px;
    padding:6px 10px;
    border-radius:10px;
}
.wgt-chip i {
    display:block;
    width:7px;
    height:7px;
    border-radius:50%;
    background:var(--dot);
}
.wgt-chip i.off { background:transparent; box-shadow:inset 0 0 0 1.5px var(--dot); }
.wgt-chip.rot    { background:#FFEBEE; --dot:#E53935; }
.wgt-chip.orange { background:#FFF3E0; --dot:#FB8C00; }
.wgt-chip.gelb   { background:#FFF8E1; --dot:#F9A825; }
.wgt-chip.grau   { background:#F1F1F1; --dot:#9E9E9E; }
.nightMode .wgt-chip.rot    { background:#4A2326; --dot:#FF8A80; }
.nightMode .wgt-chip.orange { background:#4A3118; --dot:#FFB74D; }
.nightMode .wgt-chip.gelb   { background:#463F17; --dot:#FFEE58; }
.nightMode .wgt-chip.grau   { background:#383838; --dot:#BDBDBD; }

/* Register / gespr. / usage chips under the pips, tinted like the Gewicht chip. Built by the front-template
   script from the badge text; the badge itself is hidden on the back. */
.wgt-meta {
    margin-top:4px;
    display:flex;
    flex-wrap:wrap;
    justify-content:center;
    gap:5px;
}
.wgt-tag {
    font-size:12px;
    font-weight:600;
    line-height:1.3;
    letter-spacing:0.2px;
    padding:3px 9px;
    border-radius:10px;
    background:var(--bg);
    color:var(--ink);
}
.wgt-tag.sp, .wgt-tag.x { font-weight:400; }
.wgt-tag.rot    { --bg:#FFEBEE; --ink:#C62828; }
.wgt-tag.orange { --bg:#FFF3E0; --ink:#E65100; }
.wgt-tag.gelb   { --bg:#FFF8E1; --ink:#8D6E00; }
.wgt-tag.grau   { --bg:#F1F1F1; --ink:#616161; }
.nightMode .wgt-tag.rot    { --bg:#4A2326; --ink:#FF8A80; }
.nightMode .wgt-tag.orange { --bg:#4A3118; --ink:#FFB74D; }
.nightMode .wgt-tag.gelb   { --bg:#463F17; --ink:#FFEE58; }
.nightMode .wgt-tag.grau   { --bg:#383838; --ink:#BDBDBD; }
/* Opening badge: shown on the front as chips now, so hidden on the back. Per-meaning badges inside .mn stay. */
.card .c > .fq:first-child { display:none; }

/* Phone browser (AnkiWeb): the sizes above are tuned for the desktop app and read too small on a phone.
   Bigger text on narrow screens only; the phone apps (AnkiMobile/AnkiDroid tag the page .mobile) keep theirs. */
@media (max-width:600px) {
    :root:not(.mobile) .card:not(.mobile) { font-size:24px; }
    :root:not(.mobile) .card:not(.mobile) .c { font-size:18px; }
    :root:not(.mobile) .card:not(.mobile) .c > .mn,
    :root:not(.mobile) .card:not(.mobile) .c > .gr { font-size:17px; }
    :root:not(.mobile) .card:not(.mobile) .fq { font-size:12px; }
    :root:not(.mobile) .card:not(.mobile) .wgt-tag { font-size:13px; }
}

details.fold {
    margin-top:4px;
    border-top:1px dashed #B0BEC5;
    padding-top:2px;
}
details.fold > summary {
    cursor:pointer;
    color:#607D8B;
    font-size:smaller;
    letter-spacing:0.2px;
    list-style:none;
}
details.fold > summary::-webkit-details-marker { display:none; }
details.fold > summary::before { content:"▸ "; }
details.fold[open] > summary::before { content:"▾ "; }
details.fold[open] > summary { margin-bottom:3px; }

.nightMode details.fold { border-top-color:#455A64; }
.nightMode details.fold > summary { color:#90A4AE; }
```

`details.fold` is the collapsed reference tail (Rule 25). As of 2026-09-08 the
card template's fold script starts the fold at the first `vl` **or** `tl-*`
node — whichever comes first in the `gr` box — instead of only `tl-*`. Since
`vl` always precedes any `tl-*` class in the authored order, this means the
fold now swallows every valency pattern and its `ex`/`tr` too, leaving only
the `bl` line visible by default. This needs no per-note authoring, same as
before.

The script also **no longer pulls the `<br>` immediately before the fold
start into the `<details>`.** It used to (so the first folded line wouldn't
run into `summary` on one line), but `<summary>` already forces block-level
flow, so that extra `<br>` was rendering as a full blank line between the
summary and the first folded line every time the fold was opened — the "huge
gap" the fold used to have right after opening. Dropping it left the
preceding `<br>` in the *visible* part of `gr` instead (harmless — it's what
puts the dashed fold border on its own line under `bl`).

A dashed top border separates the fold from the always-visible `bl` content
above; the `▸`/`▾` marker swaps on `[open]` instead of a transform, since
Anki's WebEngine renders `list-style:none` + `::before` more reliably than
relying on `::marker` across versions. Colour is a neutral blue-grey,
deliberately outside the `tl-*` palette so it doesn't compete with any of
them once expanded. The card template's `Q` keyboard shortcut and its
`<script>` for building the fold are unchanged in mechanism — see
`model_templates(model_name="Einfach Besser!")` — only `TAIL_CLASSES` (now
including `'vl'`), the dropped back-shift, and the summary text (now generic:
"Mehr anzeigen (Taste: Q)", since the fold no longer covers only Wendungen/
Synonyme/Antonyme) changed.

## Proposed but not adopted

`.gk` for the Grammatikkarte label. ⚙ cards currently reuse `.fq` so they render
without a note type change. If this is ever added, switch the ⚙ label over to it:

```css
.gk { color:#4527A0; font-size:smaller; letter-spacing:0.3px; }
```

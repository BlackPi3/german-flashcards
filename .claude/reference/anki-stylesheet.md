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

Verified identical to the live Anki note type on 2026-09-01. `.c br + br`
tightens the gap between sections: 50% off the original, then a further 25%
off that (0.8em → 0.6em), both per user request. The `.card` block at the top
is Anki's own default wrapper, present in the note type but not previously
mirrored in `CLAUDE.md`.

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
.c br + br { line-height:0.6em; }
.tr { color:#888; font-size:smaller; }
.fq { color:#8D6E63; font-size:smaller; letter-spacing:0.3px; }
.mn { border-left:3px solid #FFA726; padding-left:10px; margin:4px 0; }
.gr { border-left:3px solid #42A5F5; padding-left:10px; margin:4px 0; }
.bl { color:#1565C0; }
.vl { color:#9C27B0; }
.tl { color:#00838F; }   /* legacy only — use the tl-* classes below */
.ex { color:#2E7D32; }
.tl-nom { color:#00838F; }
.tl-fw  { color:#BF360C; }
.tl-nvv { color:#6A1B9A; }
.tl-kl  { color:#00695C; }
.tl-rm  { color:#AD1457; }
.tl-syn { color:#0277BD; }
.tl-ant { color:#C62828; }
.ver { color:#bbb; font-size:10px; text-align:right; display:block; }

/* Anki night mode — the dark tones above are unreadable on a dark background.
   Applies to legacy cards too, since the classes are the same. */
.nightMode .fq  { color:#D7CCC8; }
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

details.fold {
    margin-top:8px;
    border-top:1px dashed #B0BEC5;
    padding-top:4px;
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
details.fold[open] > summary { margin-bottom:6px; }

.nightMode details.fold { border-top-color:#455A64; }
.nightMode details.fold > summary { color:#90A4AE; }
```

`details.fold` is the collapsed reference tail (Rule 25) — the card template wraps
`tl-nom`/`tl-fw`/`tl-nvv`/`tl-kl`/`tl-rm`/`tl-syn`/`tl-ant` in it automatically at render
time, so this class needs no per-note authoring. A dashed top border separates it from the
always-visible `bl`/`vl` content above; the `▸`/`▾` marker swaps on `[open]` instead of a
transform, since Anki's WebEngine renders `list-style:none` + `::before` more reliably than
relying on `::marker` across versions. Colour is a neutral blue-grey, deliberately outside
the `tl-*` palette so it doesn't compete with any of them once expanded.

## Proposed but not adopted

`.gk` for the Grammatikkarte label. ⚙ cards currently reuse `.fq` so they render
without a note type change. If this is ever added, switch the ⚙ label over to it:

```css
.gk { color:#4527A0; font-size:smaller; letter-spacing:0.3px; }
```

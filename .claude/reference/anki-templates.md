# Anki card templates — `Einfach Besser!` note type

Reference copy. **The authoritative version lives in Anki**, in the note
type's *Cards…* editor. This file is a mirror kept for version history and
for editing offline — if the two ever disagree, Anki is right. Read it back
with the MCP call `model_templates(model_name="Einfach Besser!")`, write it
with `update_model_templates`.

The note type is a clone of Anki's built-in **Basic**: two fields (`Front`,
`Back`), one card template (`Card 1`). All content lives in the `Back`
field's HTML (see `CLAUDE.md` for what goes in it); the template itself only
adds the answer-side plumbing plus the fold behaviour from Rule 25 — a note's
fields never contain a `<details>` element or the script below.

## Card 1 — Front

```html
{{Front}}
```

Unmodified from Basic.

## Card 1 — Back

```html
{{FrontSide}}

<hr id=answer>

{{Back}}

<script>
if (!window.__foldQBound) {
  window.__foldQBound = true;
  document.addEventListener('keydown', function (e) {
    if (e.key && e.key.toLowerCase() === 'q') {
      document.querySelectorAll('details.fold').forEach(function (d) {
        d.open = !d.open;
      });
    }
  });
}

(function () {
  var TAIL_CLASSES = ['tl-nom', 'tl-fw', 'tl-nvv', 'tl-kl', 'tl-rm', 'tl-syn', 'tl-ant'];
  document.querySelectorAll('.gr').forEach(function (gr) {
    if (gr.querySelector('details.fold')) return;
    var nodes = Array.prototype.slice.call(gr.childNodes);
    var startIdx = -1;
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      if (n.nodeType === 1 && TAIL_CLASSES.some(function (c) { return n.classList && n.classList.contains(c); })) {
        startIdx = i;
        break;
      }
    }
    if (startIdx === -1) return;
    if (startIdx > 0 && nodes[startIdx - 1].nodeType === 1 && nodes[startIdx - 1].tagName === 'BR') {
      startIdx -= 1;
    }
    var tailNodes = nodes.slice(startIdx);
    var details = document.createElement('details');
    details.className = 'fold';
    var summary = document.createElement('summary');
    summary.textContent = 'Mehr: Wendungen, Synonyme, Antonyme (Taste: Q)';
    details.appendChild(summary);
    tailNodes.forEach(function (n) { details.appendChild(n); });
    gr.appendChild(details);
  });
})();
</script>
```

### What the script does

Two independent pieces, both scoped to the rendered DOM — neither touches the
note's stored fields:

1. **`Q` toggles every fold on the card.** A `window.__foldQBound` guard stops
   duplicate listeners from stacking when Anki re-renders the same card
   (e.g. after an answer is shown).
2. **Auto-fold on render.** For each `.gr` box, it finds the first child
   carrying one of the reference-tail classes (`tl-nom`, `tl-fw`, `tl-nvv`,
   `tl-kl`, `tl-rm`, `tl-syn`, `tl-ant`), takes that node and everything after
   it (plus one preceding `<br>`, so the section gap collapses cleanly), and
   moves them into a generated `<details class="fold">`. A `.gr` with no
   tail content (⚙ Grammatikkarten, a Kurzkarte's minimal grammar box) is
   left alone — there's nothing to fold.

This is why folding needed **zero migration** across ~2,400 existing notes:
the transformation runs once per render, driven purely by which CSS classes
are already present in the `Back` field HTML, not by any per-note markup.
Corollary: if you rename or add a `tl-*` class, add it to `TAIL_CLASSES` here
or it silently stays outside the fold.

**Why this lives in the template and not the field:** Anki strips
`<script>` tags from note field content on save (a sanitization pass) even
though the write API reports success — confirmed by writing a script
directly into a `Back` field and re-reading it back missing. Card templates
are trusted, author-controlled code and aren't sanitized, so any card
behaviour that needs JavaScript has to go here, not into `CLAUDE.md`'s output.

Pairs with the CSS in `.claude/reference/anki-stylesheet.md` — `details.fold`
and its `summary` marker (`▸`/`▾`) are styled there, including night mode.

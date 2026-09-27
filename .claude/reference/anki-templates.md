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
  var TAIL_CLASSES = ['vl', 'tl-nom', 'tl-fw', 'tl-nvv', 'tl-kl', 'tl-rm', 'tl-syn', 'tl-ant'];
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
    var tailNodes = nodes.slice(startIdx);
    var details = document.createElement('details');
    details.className = 'fold';
    var summary = document.createElement('summary');
    summary.textContent = 'Mehr anzeigen (Taste: Q)';
    details.appendChild(summary);
    tailNodes.forEach(function (n) { details.appendChild(n); });
    gr.appendChild(details);
  });
})();

(function () {
  // Split each meaning in .mn into definition (left) + example (right); CSS makes them columns on wide screens.
  function isJunk(n) {
    return (n.nodeType === 1 && n.tagName === 'BR') || (n.nodeType === 3 && !n.textContent.trim());
  }
  function trim(arr) {
    while (arr.length && isJunk(arr[0])) arr.shift();
    while (arr.length && isJunk(arr[arr.length - 1])) arr.pop();
    return arr;
  }
  function wrap(cls, arr) {
    var d = document.createElement('div');
    d.className = cls;
    arr.forEach(function (n) { d.appendChild(n); });
    return d;
  }
  document.querySelectorAll('.mn').forEach(function (mn) {
    if (mn.querySelector('.mn-row') || !mn.querySelector('.ex')) return;
    var head = [], groups = [], cur = null;
    Array.prototype.slice.call(mn.childNodes).forEach(function (n) {
      var txt = (n.nodeType === 1 && n.tagName === 'B') ? n.textContent.trim() : null;
      if (txt !== null && !groups.length && /^Bedeutung/.test(txt)) {
        head.push(n); cur = []; groups.push(cur); return;
      }
      if (txt !== null && /^\d+\.$/.test(txt)) { cur = []; groups.push(cur); }
      if (cur) cur.push(n); else head.push(n);
    });
    groups = groups.map(trim).filter(function (g) { return g.length; });
    if (!groups.length) return;
    while (mn.firstChild) mn.removeChild(mn.firstChild);
    trim(head).forEach(function (n) { mn.appendChild(n); });
    groups.forEach(function (g) {
      var row = document.createElement('div');
      row.className = 'mn-row';
      var exIdx = -1;
      for (var i = 0; i < g.length; i++) {
        if (g[i].nodeType === 1 && g[i].classList.contains('ex')) { exIdx = i; break; }
      }
      if (exIdx === -1) {
        row.appendChild(wrap('mn-def', g));
      } else {
        row.appendChild(wrap('mn-def', trim(g.slice(0, exIdx))));
        row.appendChild(wrap('mn-ex', trim(g.slice(exIdx))));
      }
      mn.appendChild(row);
    });
  });
})();
</script>
```

### What the script does

Three independent pieces, all scoped to the rendered DOM — none touches the
note's stored fields:

1. **`Q` toggles every fold on the card.** A `window.__foldQBound` guard stops
   duplicate listeners from stacking when Anki re-renders the same card
   (e.g. after an answer is shown).
2. **Auto-fold on render.** For each `.gr` box, it finds the first child
   carrying `vl` or one of the reference-tail classes (`tl-nom`, `tl-fw`,
   `tl-nvv`, `tl-kl`, `tl-rm`, `tl-syn`, `tl-ant`), takes that node and
   everything after it, and moves them into a generated
   `<details class="fold">` with the summary "Mehr anzeigen (Taste: Q)".
   Since `vl` always comes right after `bl`, only the `bl` line stays visible
   (Rule 25, since v3.0.0). A `.gr` with nothing after `bl` is left alone —
   there's nothing to fold.

   The `<br>` just before the fold start stays *outside* the `<details>`.
   Until v3.0.0 the script pulled it in, but `<summary>` already starts a new
   line, so that `<br>` showed up as an empty line every time the fold was
   opened.

3. **Bedeutung in two columns (since 2026-09-23).** For each `.mn` box that
   has an example, it splits the content at the numbered `<b>1.</b>`,
   `<b>2.</b>` markers (or takes everything after `<b>Bedeutung:</b>` on a
   single-meaning card) and wraps each meaning in a `div.mn-row` holding
   `div.mn-def` (badge, definition, both English lines) and `div.mn-ex`
   (example + its translation). The CSS in the stylesheet mirror puts the two
   side by side at ≥760px width and leaves them stacked below that, so phones
   are unaffected. `.mn` boxes without an `.ex` (some legacy cards) are left
   alone.

This is why folding needed **zero migration** across ~2,400 existing notes:
the transformation runs once per render, driven purely by which CSS classes
are already present in the `Back` field HTML, not by any per-note markup.
Corollary: if you rename or add a `vl`/`tl-*` class, add it to `TAIL_CLASSES`
here or it silently stays outside the fold.

**Why this lives in the template and not the field:** Anki strips
`<script>` tags from note field content on save (a sanitization pass) even
though the write API reports success — confirmed by writing a script
directly into a `Back` field and re-reading it back missing. Card templates
are trusted, author-controlled code and aren't sanitized, so any card
behaviour that needs JavaScript has to go here, not into `CLAUDE.md`'s output.

Pairs with the CSS in `.claude/reference/anki-stylesheet.md` — `details.fold`
and its `summary` marker (`▸`/`▾`) are styled there, including night mode.

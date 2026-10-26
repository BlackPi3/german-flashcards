# Anki card templates — `Deutsch · Alltag & IT` note type

Reference copy. **The authoritative version lives in Anki**, in the note
type's *Cards…* editor. This file is a mirror kept for version history and
for editing offline — if the two ever disagree, Anki is right. Read it back
with the MCP call `model_templates(model_name="Deutsch · Alltag & IT")`, write it
with `update_model_templates`.

The note type is a clone of Anki's built-in **Basic**: two fields (`Front`,
`Back`), one card template (`Card 1`). All content lives in the `Back`
field's HTML (see `CLAUDE.md` for what goes in it); the template itself only
adds the answer-side plumbing plus the fold behaviour from Rule 25 — a note's
fields never contain a `<details>` element or the script below.

## Card 1 — Front

```html
<div class="wgt" data-tags="{{Tags}}">{{Front}}</div>
<template class="bk-src">{{Back}}</template>

<script>
(function () {
  var box = document.querySelector('.wgt');
  if (!box || box.querySelector('.wgt-chiprow')) return;
  var PIPS = { rot: 4, orange: 3, gelb: 2, grau: 1 };
  var m = (box.getAttribute('data-tags') || '').match(/Gewicht::(rot|orange|gelb|grau)/);
  if (!m) return;
  var row = document.createElement('div');
  row.className = 'wgt-chiprow';
  var chip = document.createElement('span');
  chip.className = 'wgt-chip ' + m[1];
  for (var i = 0; i < 4; i++) {
    var dot = document.createElement('i');
    if (i >= PIPS[m[1]]) dot.className = 'off';
    chip.appendChild(dot);
  }
  row.appendChild(chip);
  box.appendChild(row);
})();

(function () {
  // Register + spoken equivalent (+ any usage warning) as chips under the pips.
  // The badge is hidden on the back; its text is read from the inert <template> copy of the Back field.
  var box = document.querySelector('.wgt');
  if (!box || box.querySelector('.wgt-meta')) return;
  var tags = box.getAttribute('data-tags') || '';
  var src = document.querySelector('template.bk-src');
  var badge = src && src.content ? src.content.querySelector('.c > .fq:first-child') : null;
  var segs = badge ? badge.textContent.split('·').map(function (s) { return s.replace(/\s+/g, ' ').trim(); }).filter(Boolean) : [];
  if (segs.length && segs[0].charAt(0) === '⚙') return;
  var REG = { gesprochen: 'gesprochen', neutral: 'neutral', eher_schriftlich: 'schriftl.', Amtssprache: 'Amtsspr.' };
  var r = tags.match(/Register::(\S+)/);
  var reg = r ? (REG[r[1]] || r[1].replace(/_/g, ' ')) : null;
  var spoken = null, extras = [];
  segs.forEach(function (s) {
    var mm;
    if (/^H.ufigkeit\s*:/.test(s)) return;
    if ((mm = s.match(/^Register\s*:\s*(.+)$/))) { if (!reg) reg = mm[1]; return; }
    if ((mm = s.match(/^(?:gespr\.|gesprochen sagt man eher|gesprochen)\s*:\s*(.+)$/))) { spoken = mm[1]; return; }
    extras.push(s);
  });
  var items = [];
  if (reg) items.push(['reg', reg]);
  if (spoken) items.push(['sp', 'gespr.: ' + spoken]);
  extras.forEach(function (e) { items.push(['x', e]); });
  if (!items.length) return;
  var w = tags.match(/Gewicht::(rot|orange|gelb|grau)/);
  var row = document.createElement('div');
  row.className = 'wgt-meta';
  items.forEach(function (it) {
    var chip = document.createElement('span');
    chip.className = 'wgt-tag ' + (w ? w[1] : 'grau') + ' ' + it[0];
    chip.textContent = it[1];
    row.appendChild(chip);
  });
  box.appendChild(row);
})();

(function () {
  // Speaker button: plays _tts_<front word>.mp3 on tap only, never automatically.
  // Shown only on notes tagged Audio::Wort, so cards without a file never get a dead button.
  var box = document.querySelector('.wgt');
  if (!box || box.querySelector('.say-btn')) return;
  if (!/(^|\s)Audio::Wort(\s|$)/.test(box.getAttribute('data-tags') || '')) return;
  var SKIP = ['wgt-chiprow', 'wgt-meta', 'say-btn'];
  var word = '';
  Array.prototype.forEach.call(box.childNodes, function (n) {
    if (n.nodeType === 1 && SKIP.some(function (c) { return n.classList.contains(c); })) return;
    word += n.textContent;
  });
  word = word.replace(/\s+/g, ' ').trim();
  if (word.normalize) word = word.normalize('NFC');
  if (!word) return;
  var file = '_tts_' + word.replace(/[\/\\:*?"<>|#]/g, '_') + '.mp3';
  var audio = null;
  var btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'say-btn';
  btn.textContent = '🔊';
  btn.title = 'Aussprache anhören (Taste: R)';
  btn.style.cssText = 'display:block;margin:6px auto 0;font-size:22px;line-height:1;padding:4px 10px;border:none;border-radius:8px;background:transparent;cursor:pointer;';
  btn.addEventListener('click', function (e) {
    e.stopPropagation();
    if (!audio) audio = new Audio(encodeURIComponent(file));
    audio.currentTime = 0;
    audio.play();
  });
  box.appendChild(btn);
})();

// R (Anki's "replay audio" key) only replays [sound:] tags, so route it to the speaker button too.
if (!window.__sayRBound) {
  window.__sayRBound = true;
  document.addEventListener('keydown', function (e) {
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    if (e.key && e.key.toLowerCase() === 'r') {
      var b = document.querySelector('.say-btn');
      if (b) b.click();
    }
  });
}
</script>
```

### What the front script does (since 2026-10-06)

1. **Gewicht pips** (v3.0.1): reads `Gewicht::rot|orange|gelb|grau` from `{{Tags}}` and draws four dots under the word.
2. **Badge chips** (v3.0.2): `{{Back}}` is embedded in an inert `<template class="bk-src">` — not rendered, its scripts and images don't run or load, and `document.querySelectorAll` doesn't see into it. The script reads the opening `.fq` badge from it and renders `Register` (from the `Register::` tag, falling back to the badge text), `gespr.: …` and any usage warning as `.wgt-tag` chips under the pips, tinted with the note's Gewicht colour. ⚙ cards (badge starts with ⚙) get no chips. **Caveat:** any `[sound:]` tag in a `Back` field would now also play on the front, because Anki extracts audio tags from the whole rendered question — keep audio out of `Back` (checked: none as of 2026-10-06).
3. **Speaker button** (pilot): on notes tagged `Audio::Wort`, a 🔊 button plays `_tts_<front text>.mp3` from the media folder on tap only — never autoplay. Filename: front text with whitespace collapsed, NFC-normalised, `/\:*?"<>|#` → `_`. The leading underscore keeps Anki's Check Media from flagging the files as unused. A global `keydown` handler routes `R` to the button, since Anki's own R only replays `[sound:]` tags.

## Card 1 — Back

```html
{{FrontSide}}

<hr id=answer>

{{Back}}

<script>
(function () {
  // The opening badge is hidden by CSS (it now shows as chips on the front, under the pips).
  // Drop the <br>s that followed it, so no blank line is left at the top of the back.
  document.querySelectorAll('.c').forEach(function (c) {
    var f = c.firstElementChild;
    if (!f || !f.classList.contains('fq')) return;
    var n = f.nextSibling;
    while (n && ((n.nodeType === 3 && !n.textContent.trim()) || n.nodeName === 'BR')) {
      var next = n.nextSibling;
      c.removeChild(n);
      n = next;
    }
  });
})();

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

Four independent pieces, all scoped to the rendered DOM — none touches the
note's stored fields:

0. **Drop the opening badge's leftover line breaks (v3.0.2).** CSS hides the badge (`.card .c > .fq:first-child`); this removes the `<br>`s and whitespace right after it so the back starts without a blank line.
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

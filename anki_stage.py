#!/usr/bin/env python3
"""anki_stage.py — staged writes for flashcard maintenance.

Maintenance runs never write to Anki directly; they stage every change as files
under staged/pending/, so Anki stays free for studying. This script pushes the
staged changes into Anki when you say so.

Usage:
  python3 anki_stage.py status             what is waiting to be applied
  python3 anki_stage.py ids                staged note ids, comma-separated (for -nid:)
  python3 anki_stage.py has-front WORD     exit 0 if a staged new note already has this front
  python3 anki_stage.py apply [--dry-run]  push everything in staged/pending/ into Anki

Staged change = <key>.back.html (the full Back field) + <key>.json (written last):
  rebuild:  staged/pending/<note_id>.json
    {"op": "update", "note_id": 123, "base_mod": 1700000000, "front": "scheitern",
     "tags": ["Regeln::v3.0.0", "Häufigkeit::mittel", "Register::gesprochen"],
     "summary": "scheitern — To fail"}
  new note: staged/pending/add-<slug>.json
    {"op": "add", "front": "schiefgehen", "tags": [...], "summary": "..."}

`tags` lists only the managed tags (Regeln::, Häufigkeit::, Register::, Karte::);
any other tag already on the note is left alone.

On apply, a rebuild whose note changed in Anki since it was staged (mod differs
from base_mod) is NOT written — it moves to staged/conflicts/ for a fresh rebuild.
Applied changes move to staged/applied/<timestamp>/. Anything that errors stays
in pending/ so the next apply retries it.
"""

import json
import re
import shutil
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "staged"
PENDING = ROOT / "pending"
APPLIED = ROOT / "applied"
CONFLICTS = ROOT / "conflicts"

ANKI_URL = "http://127.0.0.1:3141/"
DECK = "Einfach Besser! 500 B2"
MODEL = "Einfach Besser!"
MANAGED_PREFIXES = ("regeln::", "häufigkeit::", "register::", "karte::")


# --- staged files -----------------------------------------------------------

def load_pending():
    """Yield (key, meta, back_html) for every complete staged change."""
    if not PENDING.exists():
        return
    for meta_path in sorted(PENDING.glob("*.json")):
        key = meta_path.stem
        back_path = PENDING / f"{key}.back.html"
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        back = back_path.read_text(encoding="utf-8") if back_path.exists() else None
        yield key, meta, back


def move(key, dest):
    dest.mkdir(parents=True, exist_ok=True)
    for path in PENDING.glob(f"{key}.*"):
        shutil.move(str(path), str(dest / path.name))


def validate(meta, back):
    """Return an error string, or None if the staged change is well-formed."""
    if back is None:
        return "missing .back.html"
    if meta.get("op") not in ("update", "add"):
        return f"unknown op {meta.get('op')!r}"
    if not meta.get("front", "").strip():
        return "missing front"
    if meta["op"] == "update" and not (meta.get("note_id") and meta.get("base_mod")):
        return "update needs note_id and base_mod"
    stamp = re.search(r'<span class="ver">v([\d.]+)</span>', back)
    if not stamp:
        return "Back has no version stamp"
    regeln = [t for t in meta.get("tags", []) if t.lower().startswith("regeln::")]
    if regeln != [f"Regeln::v{stamp.group(1)}"]:
        return f"Regeln tag {regeln} does not match stamp v{stamp.group(1)}"
    return None


# --- Anki MCP over HTTP -----------------------------------------------------

class Anki:
    def __init__(self):
        self.session = None
        self.next_id = 0
        self._rpc("initialize", {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {"name": "anki_stage", "version": "1"},
        })
        self._post({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def _post(self, payload):
        headers = {"Content-Type": "application/json",
                   "Accept": "application/json, text/event-stream"}
        if self.session:
            headers["Mcp-Session-Id"] = self.session
        req = urllib.request.Request(ANKI_URL, json.dumps(payload).encode(), headers)
        with urllib.request.urlopen(req, timeout=120) as resp:
            self.session = resp.headers.get("Mcp-Session-Id") or self.session
            return resp.read().decode("utf-8")

    def _rpc(self, method, params):
        self.next_id += 1
        body = self._post({"jsonrpc": "2.0", "id": self.next_id,
                           "method": method, "params": params})
        # Responses arrive either as plain JSON or as SSE "data:" lines.
        chunks = [line[5:].strip() for line in body.splitlines() if line.startswith("data:")]
        for chunk in chunks or [body]:
            if not chunk:
                continue
            msg = json.loads(chunk, strict=False)
            if msg.get("id") == self.next_id:
                if "error" in msg:
                    raise RuntimeError(msg["error"].get("message", msg["error"]))
                return msg["result"]
        raise RuntimeError(f"no response to {method}")

    def call(self, tool, **args):
        result = self._rpc("tools/call", {"name": tool, "arguments": args})
        text = "".join(c.get("text", "") for c in result.get("content", []))
        if result.get("isError"):
            raise RuntimeError(text or "tool error")
        if result.get("structuredContent") is not None:
            data = result["structuredContent"]
            return data.get("result", data) if set(data) == {"result"} else data
        return json.loads(text, strict=False) if text else {}


# --- apply ------------------------------------------------------------------

def apply_update(anki, meta, back):
    nid = int(meta["note_id"])
    info = anki.call("notes_info", notes=[nid], include_fields=["Front"])
    notes = info.get("notes", [])
    if not notes:
        return "conflict", "note no longer exists"
    note = notes[0]
    if int(note["mod"]) != int(meta["base_mod"]):
        return "conflict", "note was edited in Anki after it was staged"

    anki.call("update_note_fields", id=nid, fields={"Front": meta["front"], "Back": back})

    current = note.get("tags", [])
    new = meta["tags"]
    new_lower = {t.lower() for t in new}
    remove = [t for t in current if t.lower().startswith(MANAGED_PREFIXES) and t.lower() not in new_lower]
    current_lower = {t.lower() for t in current}
    add = [t for t in new if t.lower() not in current_lower]
    ops = []
    if remove:
        ops.append({"type": "remove", "note_ids": [nid], "tags": " ".join(remove)})
    if add:
        ops.append({"type": "add", "note_ids": [nid], "tags": " ".join(add)})
    if ops:
        anki.call("tag_management", params={"action": "batch_tags", "operations": ops})

    old_front = note["fields"]["Front"]["value"]
    changed = f"  ⚠ Front geändert: {old_front} → {meta['front']}" if old_front != meta["front"] else ""
    return "applied", changed


def apply_add(anki, meta, back):
    front = meta["front"].replace('"', '\\"')
    found = anki.call("find_notes", query=f'deck:"{DECK}" "Front:{front}"', limit=1)
    if found.get("total", 0):
        return "duplicate", "already in Anki"
    anki.call("add_note", deck_name=DECK, model_name=MODEL,
              fields={"Front": meta["front"], "Back": back}, tags=meta["tags"])
    return "applied", ""


def cmd_apply(dry_run):
    items = list(load_pending())
    if not items:
        print("Nothing staged.")
        return 0

    bad = [(k, e) for k, m, b in items if (e := validate(m, b))]
    for key, err in bad:
        print(f"✗ {key}: {err} — left in pending/")
    good = [(k, m, b) for k, m, b in items if not validate(m, b)]
    # Rebuilds first, so a new note's duplicate check sees the rebuilt fronts.
    good.sort(key=lambda item: item[1]["op"] != "update")

    if dry_run:
        for key, meta, _ in good:
            print(f"  would {meta['op']}: {meta.get('summary') or meta['front']}")
        print(f"\n{len(good)} ready, {len(bad)} invalid. Nothing written (dry run).")
        return 0

    try:
        anki = Anki()
    except OSError as e:
        print(f"Cannot reach Anki at {ANKI_URL} — is Anki open? ({e})")
        return 1

    batch = APPLIED / time.strftime("%Y-%m-%d_%H%M%S")
    counts = {"applied": 0, "conflict": 0, "duplicate": 0, "error": len(bad)}
    for key, meta, back in good:
        label = meta.get("summary") or meta["front"]
        try:
            fn = apply_update if meta["op"] == "update" else apply_add
            outcome, note = fn(anki, meta, back)
        except Exception as e:  # noqa: BLE001 — report and keep going
            outcome, note = "error", str(e)
        counts[outcome] += 1
        if outcome == "applied":
            move(key, batch)
            print(f"✅ {label}" + (f"\n{note}" if note else ""))
        elif outcome == "conflict":
            move(key, CONFLICTS)
            print(f"⚠ {label}: {note} — moved to conflicts/, will be rebuilt again")
        elif outcome == "duplicate":
            move(key, batch / "skipped_duplicates")
            print(f"⏭ {label}: {note}")
        else:
            print(f"✗ {label}: {note} — left in pending/")

    print(f"\napplied {counts['applied']} · conflicts {counts['conflict']} · "
          f"duplicates {counts['duplicate']} · errors {counts['error']}")
    return 1 if counts["error"] else 0


def cmd_status():
    items = list(load_pending())
    updates = sum(1 for _, m, _ in items if m.get("op") == "update")
    conflicts = len(list(CONFLICTS.glob("*.json"))) if CONFLICTS.exists() else 0
    print(f"pending: {updates} rebuilds, {len(items) - updates} new notes · conflicts: {conflicts}")
    return 0


def cmd_ids():
    ids = [str(m["note_id"]) for _, m, _ in load_pending() if m.get("op") == "update"]
    print(",".join(ids))
    return 0


def cmd_has_front(word):
    word = word.strip().casefold()
    hit = any(m.get("op") == "add" and m.get("front", "").strip().casefold() == word
              for _, m, _ in load_pending())
    print("staged" if hit else "not staged")
    return 0 if hit else 1


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    cmd, rest = argv[0], argv[1:]
    if cmd == "apply":
        return cmd_apply("--dry-run" in rest)
    if cmd == "status":
        return cmd_status()
    if cmd == "ids":
        return cmd_ids()
    if cmd == "has-front" and rest:
        return cmd_has_front(" ".join(rest))
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

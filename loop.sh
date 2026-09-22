#!/usr/bin/env bash
# loop.sh — run flashcard-maintenance in a fresh Claude Code session, N times.
#
# Runs only STAGE changes (files under staged/) — nothing is written to Anki,
# so you can keep studying while it runs. Push the staged changes into Anki
# later, when you're not studying:
#
# Usage:
#   ./loop.sh                     the overnight job: 60 runs of 10 legacy cards,
#                                 logged to logs/, survives closing the terminal
#   ./loop.sh <number-of-runs>    same, but stop after this many runs
#   ./loop.sh status              what is staged and waiting
#   ./loop.sh apply [--dry-run]   write everything staged into Anki (Anki must be open)
#
# Tunables (env vars):
#   MODEL          model to use              (default: sonnet)
#   EFFORT         low|medium|high|xhigh|max (default: high)
#   PROMPT         prompt sent each run      (default: 10 legacy cards, stage only)
#   ALLOWED_TOOLS  tools the prompt may use  (default: Skill,Agent,Read,Write,Bash,
#                  mcp__anki__find_notes,mcp__anki__notes_info)
#   DENIED_TOOLS   hard-blocked, so no run can write to Anki (default: every Anki write tool)
#   SLEEP_ON_LIMIT seconds to wait when rate limited (default: 3600)
#   SLEEP_BETWEEN  seconds to wait between sessions (default: 2)
#   PRETTY         1 = live filtered stream, 0 = plain final text (default: 1)
#
# Example:
#   ./loop.sh 20
#   MODEL=opus EFFORT=medium ./loop.sh 5

set -uo pipefail

cd "$(dirname "$0")"

case "${1:-}" in
  apply)  shift; exec python3 anki_stage.py apply "$@" ;;
  status) exec python3 anki_stage.py status ;;
esac

RUNS="${1:-60}"
if ! [[ "$RUNS" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 [number-of-runs] | status | apply [--dry-run]" >&2
  exit 2
fi

# Keep running if the terminal window goes away.
trap '' HUP

# Everything below is written to the terminal AND to a timestamped log, so a
# failure at 3am still has evidence in the morning. Note whether the terminal
# was a tty *before* redirecting, or colors would be disabled for both.
ISTTY=0; [[ -t 1 ]] && ISTTY=1
mkdir -p logs
LOG="logs/$(date +%F-%H%M).log"
exec > >(tee "$LOG") 2>&1
echo "logging to $LOG"

MODEL="${MODEL:-sonnet}"
EFFORT="${EFFORT:-high}"
PROMPT="${PROMPT:-Use the flashcard-maintenance skill to stage 10 notes. Work only the unstamped legacy bucket. Do not apply.}"
ALLOWED_TOOLS="${ALLOWED_TOOLS:-Skill,Agent,Read,Write,Bash,mcp__anki__find_notes,mcp__anki__notes_info}"
ANKI_WRITES="update_note_fields update_notes add_note add_notes tag_management delete_notes change_note_type"
DENIED_DEFAULT=""
for t in $ANKI_WRITES; do
  DENIED_DEFAULT+="mcp__anki__$t,mcp__claude_ai_AnkiMCP__$t,"
done
DENIED_TOOLS="${DENIED_TOOLS:-${DENIED_DEFAULT%,}}"
SLEEP_ON_LIMIT="${SLEEP_ON_LIMIT:-3600}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-2}"
PRETTY="${PRETTY:-1}"

export CLAUDE_CODE_EFFORT_LEVEL="$EFFORT"

# --- subscription only, never pay-as-you-go API credit ---------------------
# An exported ANTHROPIC_API_KEY (or ANTHROPIC_AUTH_TOKEN) silently takes
# precedence over the claude.ai login for every `claude` invocation — there is
# no fallback and no warning beyond one line at session start. A long
# unattended job then bills the API account until its balance runs dry.
# Removing it here is what makes "wait for the rate limit" meaningful: with no
# key in the environment, exhausting the subscription produces a rate-limit
# error the loop can sleep on, instead of a charge.
if [[ "${ALLOW_API_KEY:-0}" != "1" ]]; then
  for v in ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN; do
    if [[ -n "${!v:-}" ]]; then
      echo "${DIM:-}$v is set — unset for this run (subscription only; ALLOW_API_KEY=1 overrides).${OFF:-}"
      unset "$v"
    fi
  done
fi

# PRETTY needs jq; fall back to plain output if it's missing.
if [[ "$PRETTY" == "1" ]] && ! command -v jq >/dev/null; then
  echo "jq not found — falling back to plain output."
  PRETTY=0
fi

# Colors (skip if not a terminal, so log files stay clean).
if (( ISTTY )); then
  DIM=$'\033[2m'; CYAN=$'\033[36m'; GREEN=$'\033[32m'; RED=$'\033[31m'; OFF=$'\033[0m'
else
  DIM=""; CYAN=""; GREEN=""; RED=""; OFF=""
fi

RAW=$(mktemp)
trap 'rm -f "$RAW"' EXIT

echo "${DIM}model=$MODEL  effort=$EFFORT  tools=$ALLOWED_TOOLS  pretty=$PRETTY${OFF}"

i=0
while (( i < RUNS )); do
  i=$(( i + 1 ))

  echo ""
  echo "${CYAN}=========================================="
  echo "  RUN $i of $RUNS  —  new session"
  echo "==========================================${OFF}"

  start=$(date +%s)

  if [[ "$PRETTY" == "1" ]]; then
    # Stream JSON events -> save raw for grepping, render a readable view live.
    claude -p "$PROMPT" \
        --model "$MODEL" \
        --allowedTools "$ALLOWED_TOOLS" \
        --disallowedTools "$DENIED_TOOLS" \
        --verbose --output-format stream-json 2>&1 \
      | tee "$RAW" \
      | jq -r --unbuffered '
          if .type == "assistant" then
            (.message.content[]? |
              if .type == "text" then .text
              elif .type == "tool_use" then "  → \(.name)"
              else empty end)
          elif .type == "result" then
            "  ✓ \(.num_turns // "?") turns"
          else empty end
        ' 2>/dev/null
    status=${PIPESTATUS[0]}
  else
    claude -p "$PROMPT" \
        --model "$MODEL" \
        --allowedTools "$ALLOWED_TOOLS" \
        --disallowedTools "$DENIED_TOOLS" 2>&1 \
      | tee "$RAW"
    status=${PIPESTATUS[0]}
  fi

  elapsed=$(( $(date +%s) - start ))

  if (( status == 0 )); then
    echo "${GREEN}[run $i ok — ${elapsed}s]${OFF}"
  else
    echo "${RED}[run $i exit $status — ${elapsed}s]${OFF}"
  fi

  # Classify on error-bearing lines only. Matching the whole transcript would
  # trip on a flashcard that merely contains the word "Limit".
  ERRTEXT=$(grep -aiE '"is_error":true|"type":"result"|"subtype":"error|error|limit|credit|balance|quota' "$RAW" | tail -n 60)

  # --- out of credit: waiting changes nothing, so stop loudly ---
  if grep -qiE "credit balance is too low|insufficient (credits?|funds)|payment required|billing" <<<"$ERRTEXT"; then
    mkdir -p logs
    keep="logs/failed-run-$i-$(date +%Y%m%d-%H%M%S).log"
    cp "$RAW" "$keep"
    echo "${RED}Out of API credit — a billing stop, not a rate limit; sleeping would not help."
    echo "This loop is meant to run on your Claude subscription, so seeing this means"
    echo "an API key reached the environment anyway (ALLOW_API_KEY=1, or a wrapper)."
    echo "Raw stream kept at $keep${OFF}"
    exit 1
  fi

  # --- rate limited: wait it out, re-checking every SLEEP_ON_LIMIT ---
  if grep -qiE "hit your limit|usage limit|rate.?limit|429|quota|overloaded" <<<"$ERRTEXT"; then
    limit_waits=$(( ${limit_waits:-0} + 1 ))
    total=$(( limit_waits * SLEEP_ON_LIMIT ))
    printf "%sRate limited. Waiting %ss before retrying run %s (attempt %s, %sm waited so far; resume ~%s).%s\n" \
      "$RED" "$SLEEP_ON_LIMIT" "$i" "$limit_waits" "$(( total / 60 ))" \
      "$(date -v +"${SLEEP_ON_LIMIT}"S '+%H:%M' 2>/dev/null || date -d "+${SLEEP_ON_LIMIT} seconds" '+%H:%M' 2>/dev/null || echo '?')" "$OFF"
    i=$(( i - 1 ))
    sleep "$SLEEP_ON_LIMIT"
    continue
  fi

  # --- any other failure: stop, and keep the evidence ---
  if (( status != 0 )); then
    mkdir -p logs
    keep="logs/failed-run-$i-$(date +%Y%m%d-%H%M%S).log"
    cp "$RAW" "$keep"
    echo "${RED}Stopping — unrecognised failure. Raw stream kept at $keep${OFF}"
    grep -aiE '"is_error":true|"subtype":"error|error' "$RAW" | tail -n 5
    exit "$status"
  fi

  limit_waits=0

  sleep "$SLEEP_BETWEEN"
done

echo ""
echo "${GREEN}All $RUNS runs completed.${OFF}"
python3 anki_stage.py status
echo "Nothing is in Anki yet — run ${CYAN}./loop.sh apply${OFF} when you're not studying."
#!/usr/bin/env bash
# loop.sh — run flashcard-maintenance in a fresh Claude Code session, N times.
#
# Usage:
#   ./loop.sh <number-of-runs>
#
# Tunables (env vars):
#   MODEL          model to use              (default: sonnet)
#   EFFORT         low|medium|high|xhigh|max (default: high)
#   PROMPT         prompt sent each run       (default: flashcard-maintenance skill, 50 notes)
#   ALLOWED_TOOLS  tools the prompt may use  (default: Skill,Agent,Read,Bash,mcp__anki)
#   SLEEP_ON_LIMIT seconds to wait when rate limited (default: 3600)
#   SLEEP_BETWEEN  seconds to wait between sessions (default: 2)
#   PRETTY         1 = live filtered stream, 0 = plain final text (default: 1)
#
# Example:
#   ./loop.sh 20
#   MODEL=opus EFFORT=medium ./loop.sh 5

set -uo pipefail

RUNS="${1:?Usage: $0 <number-of-runs>}"

MODEL="${MODEL:-sonnet}"
EFFORT="${EFFORT:-high}"
PROMPT="${PROMPT:-Use the flashcard-maintenance skill to migrate 50 notes.}"
ALLOWED_TOOLS="${ALLOWED_TOOLS:-Skill,Agent,Read,Bash,mcp__anki}"
SLEEP_ON_LIMIT="${SLEEP_ON_LIMIT:-3600}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-2}"
PRETTY="${PRETTY:-1}"

export CLAUDE_CODE_EFFORT_LEVEL="$EFFORT"

# PRETTY needs jq; fall back to plain output if it's missing.
if [[ "$PRETTY" == "1" ]] && ! command -v jq >/dev/null; then
  echo "jq not found — falling back to plain output."
  PRETTY=0
fi

# Colors (skip if not a terminal, so log files stay clean).
if [[ -t 1 ]]; then
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
        --allowedTools "$ALLOWED_TOOLS" 2>&1 \
      | tee "$RAW"
    status=${PIPESTATUS[0]}
  fi

  elapsed=$(( $(date +%s) - start ))

  if (( status == 0 )); then
    echo "${GREEN}[run $i ok — ${elapsed}s]${OFF}"
  else
    echo "${RED}[run $i exit $status — ${elapsed}s]${OFF}"
  fi

  # --- rate limited? sleep, then retry this same run ---
  if grep -qiE "hit your limit|usage limit|rate limit|quota" "$RAW"; then
    echo "${RED}Rate limited. Sleeping ${SLEEP_ON_LIMIT}s, then retrying run $i.${OFF}"
    i=$(( i - 1 ))
    sleep "$SLEEP_ON_LIMIT"
    continue
  fi

  # --- any other failure: stop ---
  if (( status != 0 )); then
    echo "${RED}Stopping.${OFF}"
    tail -n 20 "$RAW"
    exit "$status"
  fi

  sleep "$SLEEP_BETWEEN"
done

echo ""
echo "${GREEN}All $RUNS runs completed.${OFF}"
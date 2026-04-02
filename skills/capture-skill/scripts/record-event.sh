#!/bin/bash
# Record a session event to the session log file
# Usage: echo '{"json":"data"}' | record-event.sh <event_type> <session_id>

EVENT_TYPE="$1"
SESSION_ID="$2"
LOG_DIR="$HOME/.claude/session-logs"
LOG_FILE="$LOG_DIR/${SESSION_ID}.jsonl"

mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR"

INPUT=$(cat)

# Redact sensitive patterns from a string
redact() {
  sed -E \
    -e 's/(key|token|secret|password|passwd|credential|auth|bearer|api_key|apikey|access_key|private_key)["\x27]?\s*[:=]\s*["\x27]?[A-Za-z0-9_\-\.\/\+]{8,}["\x27]?/\1=[REDACTED]/gi' \
    -e 's/(sk|pk|ak|rk|xox[bpas])-[A-Za-z0-9_\-]{10,}/[REDACTED]/g' \
    -e 's/ghp_[A-Za-z0-9_]{36,}/[REDACTED]/g' \
    -e 's/eyJ[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}/[REDACTED]/g'
}

case "$EVENT_TYPE" in
  user)
    echo "$INPUT" | jq -c '{type:"user", text:.user_prompt, ts: (now|todate)}' 2>/dev/null | redact >> "$LOG_FILE"
    ;;
  tool)
    echo "$INPUT" | jq -c '{
      type: "tool",
      name: .tool_name,
      input: (.tool_input | tostring | .[:300]),
      output: (.tool_output | tostring | .[:300]),
      ts: (now|todate)
    }' 2>/dev/null | redact >> "$LOG_FILE"
    ;;
  stop)
    echo "{\"type\":\"stop\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$LOG_FILE"
    ;;
esac

chmod 600 "$LOG_FILE" 2>/dev/null

exit 0

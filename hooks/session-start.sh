#!/bin/bash
# SessionStart hook: Injects workspace context at session start.
# Also detects stale sessions (from IDE restart, crash, etc.)
# by comparing session checkpoint timestamp against session.md date.
#
# Configure: Set SESSION_FILE to your memory system's session file path.
#            Set WORKSPACE_CONTEXT to describe your workspace layout.

PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
if [ -z "$PYTHON" ]; then
  echo "session-start: python not found -- session context not injected" >&2
  exit 0
fi

# Path to your session memory file (set to your memory repo path)
SESSION_FILE="${MEMORY_PATH:-$HOME/memory-core}/core/session.md"
CHECKPOINT_FILE="$HOME/.claude/session-checkpoint.txt"
export PRICING_FILE="$HOME/.claude/metrics/pricing.json"

# Detect stale session (session.md older than last checkpoint)
STALE_WARNING=""
if [ -f "$CHECKPOINT_FILE" ] && [ -f "$SESSION_FILE" ]; then
  CHECKPOINT_DATE=$(head -1 "$CHECKPOINT_FILE" | cut -d' ' -f1)
  SESSION_DATE=$(grep -m1 'Last Updated' "$SESSION_FILE" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')

  if [ -n "$CHECKPOINT_DATE" ] && [ -n "$SESSION_DATE" ]; then
    # Use POSIX-compatible test (bash 3.2+, also dash/ash). YYYY-MM-DD format sorts lexically.
    if [ "$CHECKPOINT_DATE" \> "$SESSION_DATE" ]; then
      export STALE_WARNING="STALE SESSION DETECTED: Last checkpoint was $CHECKPOINT_DATE but session.md was last updated $SESSION_DATE. A previous session may have ended abruptly. Check recent plan files and git status to recover context."
    fi
  fi
fi

# Configure: Describe your workspace layout and critical rules here
export WORKSPACE_CONTEXT="Active workspace: $(pwd). Always verify after completing work: run tests, check types, hit live endpoints."

$PYTHON -c "
import os, json, sys

stale = os.environ.get('STALE_WARNING', '')
workspace = os.environ.get('WORKSPACE_CONTEXT', '')
pricing_file = os.environ.get('PRICING_FILE', '')

pending_note = ''
if pricing_file and os.path.isfile(pricing_file):
    try:
        with open(pricing_file, 'r', encoding='utf-8') as f:
            pricing = json.load(f)
        models_block = pricing.get('models', {})
        pending = pricing.get('_pending_models', [])
        if not models_block:
            pending_note = (
                'PRICING NOT SEEDED: ' + pricing_file + ' has no model pricing entries yet. '
                'Run /request-model-prices to fetch and record current rates before cost '
                'tracking will report accurate USD/GBP figures. '
            )
        elif pending:
            names = ', '.join(repr(m) for m in pending)
            pending_note = (
                'PENDING MODEL PRICING: cost-tracker recorded ' + str(len(pending)) +
                ' model(s) with no pricing entry in pricing.json: ' + names +
                '. Run /request-model-prices to fetch and record current rates for them. '
            )
    except Exception as e:
        print(f'session-start: pending-models check failed: {e}', file=sys.stderr)
        pending_note = ''

parts = [p for p in (stale, pending_note, workspace) if p]
context = ' '.join(parts)
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': context
    }
}))
"

exit 0

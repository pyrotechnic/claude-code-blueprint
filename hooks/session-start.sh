#!/bin/bash
# SessionStart hook: injects a short note only when cost-tracker has models with no pricing.
# Silent (no output, no context cost) when there is nothing to report.

PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
if [ -z "$PYTHON" ]; then
  echo "session-start: python not found -- nothing injected" >&2
  exit 0
fi

export PRICING_FILE="$HOME/.claude/metrics/pricing.json"

$PYTHON -c "
import os, json, sys

pricing_file = os.environ.get('PRICING_FILE', '')
note = ''
if pricing_file and os.path.isfile(pricing_file):
    try:
        with open(pricing_file, 'r', encoding='utf-8') as f:
            pricing = json.load(f)
        models_block = pricing.get('models', {})
        pending = pricing.get('_pending_models', [])
        if not models_block:
            note = ('PRICING NOT SEEDED: ' + pricing_file + ' has no model pricing entries yet. '
                    'Run /request-model-prices to fetch and record current rates before cost '
                    'tracking will report accurate USD/GBP figures.')
        elif pending:
            names = ', '.join(repr(m) for m in pending)
            note = ('PENDING MODEL PRICING: cost-tracker recorded ' + str(len(pending)) +
                    ' model(s) with no pricing entry in pricing.json: ' + names +
                    '. Run /request-model-prices to fetch and record current rates for them.')
    except Exception as e:
        print(f'session-start: pending-models check failed: {e}', file=sys.stderr)

if note:
    print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': note}}))
"

exit 0

#!/bin/bash
# Hook: Stop (async) — Cost Tracker
# Appends a JSONL entry per stop event with real token usage, cost (USD + GBP),
# and the currently active plan/phase (from docs/plans/*.md).
#
# Requires: python or python3 on PATH
# Exit code: always 0 (never blocks responses)

PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
if [ -z "$PYTHON" ]; then
  echo "cost-tracker: python not found -- cost not logged" >&2
  exit 0
fi

METRICS_DIR="$HOME/.claude/metrics"
METRICS_FILE="$METRICS_DIR/costs.jsonl"
PRICING_FILE="$METRICS_DIR/pricing.json"

mkdir -p "$METRICS_DIR" 2>/dev/null || {
  echo "cost-tracker: cannot create $METRICS_DIR" >&2
  exit 0
}

INPUT=$(cat)

export HOOK_INPUT="$INPUT"
export HOOK_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export HOOK_METRICS_FILE="$METRICS_FILE"
export HOOK_METRICS_DIR="$METRICS_DIR"
export HOOK_PRICING_FILE="$PRICING_FILE"

$PYTHON -c "
import os, json, sys, re, urllib.request
from datetime import datetime, timezone

FX_STALE_SECONDS = 7 * 24 * 3600
MAX_SCAN_BYTES = 5_000_000
CHUNK_SIZE = 65536

def _try_parse_usage_line(raw):
    if b'usage' not in raw:
        return None, None
    try:
        entry = json.loads(raw.decode('utf-8', errors='replace'))
    except Exception:
        return None, None
    msg = entry.get('message') if isinstance(entry, dict) else None
    usage = msg.get('usage') if isinstance(msg, dict) else None
    model = msg.get('model') if isinstance(msg, dict) else None
    if usage is None and isinstance(entry, dict):
        usage = entry.get('usage')
    if model is None and isinstance(entry, dict):
        model = entry.get('model')
    if isinstance(usage, dict):
        return {
            'input_tokens': usage.get('input_tokens'),
            'cache_creation_input_tokens': usage.get('cache_creation_input_tokens'),
            'cache_read_input_tokens': usage.get('cache_read_input_tokens'),
            'output_tokens': usage.get('output_tokens'),
        }, model
    return None, None

def get_last_usage_and_model(transcript_path):
    if not transcript_path or not os.path.isfile(transcript_path):
        return None, None
    try:
        file_size = os.path.getsize(transcript_path)
        with open(transcript_path, 'rb') as f:
            data, pos, scanned = b'', file_size, 0
            while pos > 0 and scanned < MAX_SCAN_BYTES:
                read_size = min(CHUNK_SIZE, pos)
                pos -= read_size
                f.seek(pos)
                data = f.read(read_size) + data
                scanned += read_size
                lines = data.split(b'\n')
                data = lines[0]
                for raw in reversed(lines[1:]):
                    usage, model = _try_parse_usage_line(raw)
                    if usage is not None:
                        return usage, model
            # If the scan reached the true start of the file (pos == 0, not just the
            # MAX_SCAN_BYTES safety cap), the remaining data holds the first line's
            # full content -- it was only ever treated as a carry-over fragment for a
            # next chunk that never comes, so it must be checked here or it's dropped.
            if pos == 0 and data:
                usage, model = _try_parse_usage_line(data)
                if usage is not None:
                    return usage, model
            return None, None
    except Exception:
        return None, None

def get_active_plan_and_phase(cwd):
    if not cwd or not os.path.isdir(cwd):
        return None, None
    plans_dir = os.path.join(cwd, 'docs', 'plans')
    if not os.path.isdir(plans_dir):
        return None, None
    try:
        candidates = []
        for name in os.listdir(plans_dir):
            full = os.path.join(plans_dir, name)
            if os.path.isfile(full) and name.endswith('.md'):
                candidates.append((os.path.getmtime(full), full, name))
        if not candidates:
            return None, None
        candidates.sort(reverse=True)
        _, plan_path, plan_name = candidates[0]
        plan_id = plan_name[:-len('.md')]

        current_heading, phase_heading = None, None
        with open(plan_path, 'r', encoding='utf-8', errors='replace') as f:
            for line in f:
                stripped = line.strip()
                if re.match(r'#{1,6}\s+Phase\b', stripped):
                    current_heading = stripped.lstrip('#').strip()
                    continue
                m = re.match(r'\*\*Status:\*\*\s*(.+)', stripped)
                if current_heading and m:
                    if m.group(1).strip().lower() == 'in progress':
                        phase_heading = current_heading
                        break
                    current_heading = None
        return (plan_id, phase_heading) if phase_heading else (None, None)
    except Exception:
        return None, None

def refresh_fx_rate_if_stale(pricing, pricing_file):
    try:
        exchange = pricing.get('exchange_rate', {})
        fx_updated = exchange.get('fx_updated')
        now = datetime.now(timezone.utc)
        stale = True
        if fx_updated:
            try:
                last = datetime.strptime(fx_updated, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
                stale = (now - last).total_seconds() >= FX_STALE_SECONDS
            except Exception:
                stale = True
        if not stale:
            return pricing
        req = urllib.request.Request(
            'https://api.exchangerate-api.com/v4/latest/USD',
            headers={'User-Agent': 'claude-code-cost-tracker'},
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode('utf-8'))
        gbp = data.get('rates', {}).get('GBP')
        if gbp is None:
            return pricing
        pricing.setdefault('exchange_rate', {})
        pricing['exchange_rate']['usd_to_gbp'] = gbp
        pricing['exchange_rate']['fx_updated'] = now.strftime('%Y-%m-%dT%H:%M:%SZ')
        tmp = pricing_file + '.tmp'
        with open(tmp, 'w', encoding='utf-8') as f:
            json.dump(pricing, f, indent=2)
        os.replace(tmp, pricing_file)
        return pricing
    except Exception as e:
        print(f'cost-tracker: fx refresh failed: {e}', file=sys.stderr)
        return pricing

def compute_cost(usage, model, pricing_models):
    if not usage or not model or model not in pricing_models:
        return None
    rates = pricing_models[model]
    try:
        cost = (
            (usage.get('input_tokens') or 0)  * rates.get('input', 0) +
            (usage.get('output_tokens') or 0) * rates.get('output', 0) +
            (usage.get('cache_creation_input_tokens') or 0) * rates.get('cache_write', 0) +
            (usage.get('cache_read_input_tokens') or 0)      * rates.get('cache_read', 0)
        ) / 1_000_000
        return round(cost, 6)
    except Exception:
        return None

try:
    hook_input_raw = os.environ.get('HOOK_INPUT', '')
    try:
        hook_input = json.loads(hook_input_raw) if hook_input_raw else {}
    except Exception:
        hook_input = {}

    session_id = hook_input.get('session_id') or 'unknown'
    transcript_path = hook_input.get('transcript_path')
    cwd = hook_input.get('cwd')
    timestamp = os.environ.get('HOOK_TIMESTAMP', '')
    metrics_file = os.environ.get('HOOK_METRICS_FILE', '')
    metrics_dir = os.environ.get('HOOK_METRICS_DIR', '')
    pricing_file = os.environ.get('HOOK_PRICING_FILE', '')

    usage, model = get_last_usage_and_model(transcript_path)
    plan_id, phase = get_active_plan_and_phase(cwd)

    pricing = {}
    if pricing_file and os.path.isfile(pricing_file):
        try:
            with open(pricing_file, 'r', encoding='utf-8') as f:
                pricing = json.load(f)
        except Exception:
            pricing = {}

    if pricing_file:
        pricing = refresh_fx_rate_if_stale(pricing, pricing_file)

    new_model_flagged = False
    if pricing_file and model:
        pricing_models_check = pricing.get('models', {})
        pending = pricing.get('_pending_models', [])
        if model not in pricing_models_check and model not in pending:
            pending.append(model)
            pricing['_pending_models'] = pending
            try:
                tmp = pricing_file + '.tmp'
                with open(tmp, 'w', encoding='utf-8') as f:
                    json.dump(pricing, f, indent=2)
                os.replace(tmp, pricing_file)
                new_model_flagged = True
            except Exception as e:
                print(f'cost-tracker: failed to record pending model: {e}', file=sys.stderr)

    pricing_models = pricing.get('models', {})
    exchange_rate = pricing.get('exchange_rate', {}).get('usd_to_gbp')

    cost_usd = compute_cost(usage, model, pricing_models)
    cost_gbp = round(cost_usd * exchange_rate, 6) if (cost_usd is not None and exchange_rate is not None) else None

    current_month = timestamp[:7] if len(timestamp) >= 7 else ''
    if os.path.isfile(metrics_file):
        try:
            with open(metrics_file, 'r') as f:
                first_line = f.readline().strip()
            if first_line:
                first_entry = json.loads(first_line)
                first_month = first_entry.get('timestamp', '')[:7]
                if first_month and first_month != current_month:
                    archive = os.path.join(metrics_dir, f'costs-{first_month}.jsonl')
                    os.rename(metrics_file, archive)
        except Exception:
            pass

    MAX_SIZE = 10 * 1024 * 1024
    if os.path.isfile(metrics_file) and os.path.getsize(metrics_file) > MAX_SIZE:
        try:
            with open(metrics_file, 'r') as f:
                lines = f.readlines()
            with open(metrics_file, 'w') as f:
                f.writelines(lines[len(lines)//2:])
        except Exception:
            pass

    entry = {
        'session_id': session_id,
        'timestamp': timestamp,
        'event': 'stop',
        'cwd': cwd,
        'model': model,
        'usage': usage,
        'cost_usd': cost_usd,
        'cost_gbp': cost_gbp,
        'plan': plan_id,
        'phase': phase,
    }
    try:
        with open(metrics_file, 'a') as f:
            f.write(json.dumps(entry) + '\n')
    except Exception as e:
        print(f'cost-tracker: write failed: {e}', file=sys.stderr)

    if new_model_flagged:
        msg = ('cost-tracker: new model ' + repr(model) +
               ' has no pricing entry in ~/.claude/hooks/pricing.json (added to _pending_models). '
               'Look up current per-MTok pricing (see the claude-api skill) and fill it in, or edit the file manually.')
        print(json.dumps({'systemMessage': msg}))
except Exception as e:
    print(f'cost-tracker: unexpected failure: {e}', file=sys.stderr)
"

exit 0

#!/bin/bash
# Hook: PreToolUse (Bash|PowerShell) -- "careful" guard.
# Asks before destructive commands and denies the very worst. Written for this setup after
# reviewing the /careful idea in garrytan/gstack (not a copy of its code).
#
#   ASK  : recursive deletes, DROP/TRUNCATE, force-push, reset --hard, checkout/restore ".",
#          git clean -f, branch -D, stash drop/clear, artisan migrate:fresh|reset|refresh|db:wipe,
#          Format-Volume/Clear-Disk, -EncodedCommand/iex, curl|sh pipes, shell obfuscation.
#   DENY : (simple commands only) recursive delete of /, ~, $HOME, a drive root; force-push to main/master.
#   SAFE : a lone recursive delete whose targets are all regenerable folders (node_modules, dist,
#          build, .cache, coverage, .vite, .next, .turbo, __pycache__, vendor) is allowed silently.
#
# LIMITS (be honest about them): this is string matching, not a sandbox. Text inside quotes and
# heredoc bodies is ignored, except for `sh -c "..."`-style wrappers. Commands built at runtime
# (variables, base64, eval) can slip through. In `dontAsk` permission mode an "ask" is auto-denied.
# Fail-open: any parse problem exits 0 with no output. Exit code is always 0; the decision is
# returned as JSON (permissionDecision).

PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null)
if [ -z "$PYTHON" ]; then exit 0; fi

INPUT=$(cat)
export HOOK_INPUT="$INPUT"

$PYTHON - <<'PYEOF' 2>/dev/null
import os, re, sys, json

try:
    data = json.loads(os.environ.get('HOOK_INPUT', ''))
    cmd = (data.get('tool_input') or {}).get('command', '')
    if not isinstance(cmd, str) or not cmd.strip():
        sys.exit(0)
except Exception:
    sys.exit(0)

def decide(kind, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": kind,
        "permissionDecisionReason": "[careful] " + reason}}))
    sys.exit(0)

# 1. drop heredoc bodies, then blank out quoted strings (keep a wrapper's quoted payload if it is `sh -c "..."`)
text = re.sub(r"<<-?\s*(['\"]?)(\w+)\1[^\n]*\n.*?\n\s*\2\b", " ", cmd, flags=re.S)
wrapper = re.search(r"\b(?:bash|sh|zsh|cmd(?:\.exe)?|powershell(?:\.exe)?|pwsh(?:\.exe)?)\b[^|;&\n]*?\s(?:-c|-command|/c)\s+(['\"])(.*?)\1", text, re.S | re.I)
payload = wrapper.group(2) if wrapper else ''
stripped = re.sub(r"'[^']*'|\"[^\"]*\"", '""', text)
scan = stripped + ('\n' + payload if payload else '')
low = scan.lower()
compound = bool(re.search(r"[;&|\n]", stripped.strip()))

SAFE = {'node_modules', 'dist', 'build', '.cache', 'coverage', '.vite', '.next', '.turbo', '__pycache__', 'vendor'}
ROOTISH = re.compile(r"^(/|/\*|~|~/|~/\*|\$home|\$home/|\$env:userprofile|%userprofile%|[a-z]:[\\/]?|[a-z]:[\\/]\*)$", re.I)

def targets_of(simple, kind):
    """Extract probable target paths of a recursive delete in a simple command."""
    toks = re.findall(r'"[^"]*"|\'[^\']*\'|\S+', simple)
    out, skip = [], False
    for i, t in enumerate(toks[1:], 1):
        if skip:
            skip = False
            out.append(t); continue
        tl = t.lower()
        if kind == 'ps':
            if tl in ('-path', '-literalpath'):
                skip = True; continue
            if tl in ('-include', '-exclude', '-filter'):
                return None
        if t.startswith('-') or (kind == 'cmd' and t.startswith('/')):
            continue
        out.append(t)
    return [x.strip('"\'') for x in out]

def classify_delete(simple, kind):
    tg = targets_of(simple, kind)
    if tg is None or not tg:
        return 'ask', 'recursive delete with no clear target'
    if any(ROOTISH.match(x.strip()) for x in tg):
        return ('deny' if not compound else 'ask'), 'recursive delete aimed at a root, home or drive'
    if any('*' in x or '..' in x.replace('\\', '/').split('/') for x in tg):
        return 'ask', 'recursive delete with a wildcard or parent path'
    if all(os.path.basename(x.rstrip('/\\').replace('\\', '/')) in SAFE for x in tg):
        return 'safe', ''
    return 'ask', 'recursive delete'

# 2. recursive deletes
m = re.search(r"(?:^|[\s;&|(])rm\s+[^|;&\n]*?(-[a-z]*r[a-z]*|--recursive)\b[^|;&\n]*", low)
if m:
    seg = scan[m.start():m.end()].strip().lstrip(';&|( ')
    k, why = classify_delete(seg, 'sh')
    if k == 'deny': decide('deny', why)
    if k == 'ask': decide('ask', why + ' (rm -r)')
m = re.search(r"(?:^|[\s;&|(])(?:remove-item|ri)\b[^|;&\n]*\s-(?:recurse|force|r)\b[^|;&\n]*", low)
if m:
    seg = scan[m.start():m.end()].strip().lstrip(';&|( ')
    k, why = classify_delete(seg, 'ps')
    if k == 'deny': decide('deny', why)
    if k == 'ask': decide('ask', why + ' (Remove-Item)')
m = re.search(r"(?:^|[\s;&|(])(?:rd|rmdir)\s+[^|;&\n]*?/s\b[^|;&\n]*|(?:^|[\s;&|(])(?:del|erase)\s+[^|;&\n]*?/s\b[^|;&\n]*", low)
if m:
    seg = scan[m.start():m.end()].strip().lstrip(';&|( ')
    k, why = classify_delete(seg, 'cmd')
    if k == 'deny': decide('deny', why)
    if k == 'ask': decide('ask', why + ' (cmd delete /s)')

# 3. force pushes
if re.search(r"\bgit\s+push\b[^|;&\n]*(\s--force(?![-\w])|\s-[a-z]*f[a-z]*\b|\s\+\S+)", low):
    if not compound and re.search(r"(?:\s|:|\+)(main|master)\b", low):
        decide('deny', 'force-push to main/master')
    decide('ask', 'force-push (use --force-with-lease if you must)')

# 4. other destructive git
for pat, why in [
    (r"\bgit\s+reset\s+[^|;&\n]*--hard\b", 'git reset --hard discards uncommitted work'),
    (r"\bgit\s+checkout\s+(?:--\s+)?\.(?:\s|$)", 'git checkout . discards uncommitted changes'),
    (r"\bgit\s+restore\s+(?:--\S+\s+)*\.(?:\s|$)", 'git restore . discards uncommitted changes'),
    (r"\bgit\s+clean\s+[^|;&\n]*-[a-z]*f", 'git clean -f deletes untracked files'),
    (r"\bgit\s+branch\s+[^|;&\n]*-D\b", 'git branch -D deletes a branch even if unmerged'),
    (r"\bgit\s+stash\s+(?:drop|clear)\b", 'git stash drop/clear discards stashed work'),
]:
    if re.search(pat, scan if '-D' in pat else low):
        decide('ask', why)

# 5. database and Laravel. SQL usually sits inside quotes (mysql -e "DROP ..."), so read the raw
# text, but only when a SQL client is involved; that keeps commit messages and echo from tripping it.
raw_low = re.sub(r"<<-?\s*(['\"]?)(\w+)\1[^\n]*\n.*?\n\s*\2\b", lambda mm: mm.group(0), cmd, flags=re.S).lower()
sql_client = re.search(r"\b(?:mysql|mariadb|psql|sqlite3|sqlcmd|mysqladmin)\b|artisan\s+(?:tinker|db)\b|\bdb::(?:statement|unprepared)", raw_low)
if sql_client:
    for pat, why in [
        (r"\bdrop\s+(?:table|database|schema)\b", 'DROP statement'),
        (r"\btruncate\s+(?:table\s+)?[\w`\"\[]", 'TRUNCATE statement'),
    ]:
        if re.search(pat, raw_low):
            decide('ask', why)
if re.search(r"\bartisan\s+(?:migrate:fresh|migrate:reset|migrate:refresh|db:wipe)\b", low):
    decide('ask', 'artisan command that wipes the database')

# 6. disk, encoded or piped-to-shell commands
for pat, why in [
    (r"\b(?:format-volume|clear-disk|initialize-disk)\b|\bformat\s+[a-z]:", 'disk format/clear'),
    (r"-(?:encodedcommand|enc|ec)\s+\S", 'encoded PowerShell command'),
    (r"(?:^|[\s;&|(])(?:iex|invoke-expression)\b", 'Invoke-Expression'),
    (r"\b(?:curl|wget|iwr|invoke-webrequest|irm|invoke-restmethod)\b[^\n]*\|\s*(?:sh|bash|zsh|iex|invoke-expression|python3?)\b", 'downloads and pipes straight into an interpreter'),
    (r"\$\{ifs\}|base64\s+(?:-d|--decode)[^\n]*\|\s*(?:sh|bash)", 'shell obfuscation'),
]:
    if re.search(pat, low):
        decide('ask', why)

sys.exit(0)
PYEOF
exit 0

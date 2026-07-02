---
name: e2e-check
description: "Run E2E tests or interactive browser verification. Triggers on: 'run e2e', 'e2e test', 'browser test', 'check in browser', 'verify UI', 'interactive test'."
user-invocable: true
argument-hint: "[project] [test-filter] [--interactive]"
---

Run E2E tests or perform interactive browser-based verification.

## Mode Detection

Parse `$ARGUMENTS` to determine mode:
- **Runner mode** (default): Run the Playwright test suite via CLI
- **Interactive mode**: If `--interactive` or `interactive` appears in args, use the Claude Preview MCP tools for manual browser walkthrough

---

## Runner Mode

### 1. Detect project

From `$ARGUMENTS` or current working directory:
- Match project name from cwd (e.g., `my-app` if cwd contains `my-app`)
- Check `CLAUDE.md` in the project root for the configured dev port and test command
- No match: ask which project to target

### 2. Pre-flight check

Check if the dev server is running on the expected port (read from `CLAUDE.md` or `package.json`):

Use: `bash -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:{port}/ 2>/dev/null"` or equivalent.

If the server is NOT running:
- Report: "Dev server not running on port {port}. Start it with `yarn dev` / `npm run dev`, then re-run /e2e-check."
- **Do NOT auto-start the dev server.** Stop here.

### 3. Run tests

Run the E2E test command from `CLAUDE.md` or `package.json` (e.g., `yarn test:e2e` or `npm run test:e2e`).

If a test filter was provided (e.g., `auth`), resolve it to the spec file path:
- `auth` → `tests/e2e/auth.spec.ts`
- Full path → use as-is

If no test command is documented and no Playwright config exists (`playwright.config.*`), report "No E2E test suite configured yet" and stop rather than guessing a command.

### 4. Parse output

Extract from Playwright output:
- Total, passed, failed, skipped counts
- Duration
- On failure: spec file name, test name, error message

### 5. Report

```
E2E Test Results -- {project}
================================
Total: X | Passed: X | Failed: X | Skipped: X
Duration: Xs
Baseline: {expected from CLAUDE.md} tests

[If failures:]
FAILURES:
- {spec-file} > {test-name}: {error summary}

[If screenshots saved:]
Screenshots: test-results/{spec-file}/
```

### 6. On failure

- Check `test-results/` directory for saved screenshots
- Analyze failure type: timeout? Element not found? Assertion mismatch? Network error?
- Suggest fix based on the failure pattern

---

## Interactive Mode

Use the Claude Preview MCP tools (`mcp__Claude_Preview__*`) to manually verify a user journey in the running dev server — no Playwright test suite required.

**Tool mapping** (this environment has no `playwright` MCP server — use these instead):

| Need | Tool |
|---|---|
| Launch/attach to the dev server | `preview_start` |
| List already-running preview servers | `preview_list` |
| Click a link/button, or navigate via in-app links | `preview_click` |
| Fill a form field | `preview_fill` |
| Read the current DOM / accessibility tree | `preview_snapshot` |
| Visual screenshot as evidence | `preview_screenshot` |
| Check for runtime JS errors | `preview_console_logs` |
| Check for failed network requests | `preview_network` |
| Inspect precise computed styles (colors, spacing) | `preview_inspect` |
| Test responsive layouts | `preview_resize` |
| Run arbitrary JS for debugging | `preview_eval` |
| Stop the preview server | `preview_stop` |

There is no dedicated "navigate to URL" or "wait for element" tool in this family:
- **Navigation** happens via `preview_start` for the initial load, then `preview_click` on in-app links/buttons for subsequent navigation (client-side routing).
- **Waiting for state** — there's no dedicated wait primitive. Re-read the page via `preview_snapshot` (or `preview_screenshot`) after an action; if the expected content isn't present yet, a short pause before re-checking is acceptable, but never poll indefinitely — report what's actually rendered rather than assuming success.
- **Dropdowns/selects** — use `preview_fill` where the underlying element accepts a value directly; fall back to `preview_click` + `preview_snapshot` to drive native `<select>` interactions, or `preview_eval` for anything more complex.

### 1. Start

Use `preview_start` to launch (or attach to) the dev server. Confirm it started successfully before proceeding.

### 2. Default journey (if no specific flow in args)

This project has no authentication — do not assume a login flow. Unless the project's own CLAUDE.md documents a specific key user journey (which takes precedence over this default):

1. Load the home/landing route via `preview_start` (or the app's default route)
2. Take a snapshot via `preview_snapshot` — verify the page renders real content, not a loading/error/empty state
3. Check `preview_console_logs` for runtime errors
4. Navigate to one representative content page via `preview_click` (e.g. a detail page, a key feature view)
5. Verify data is present (not a loading spinner, not an error, not an empty state) via `preview_snapshot`
6. Take a screenshot via `preview_screenshot` as evidence

### 3. Custom journey

If args specify a flow (e.g., `--interactive search`), walk through that specific flow step by step using the tool mapping above — `preview_start` once, then `preview_click`/`preview_fill` for interaction, `preview_snapshot` to read state, `preview_screenshot` for evidence at key checkpoints.

### 4. Report

Summarize:
- What pages/views were visited
- What was verified (data rendered, forms worked, navigation succeeded)
- Any issues found (console errors, failed network requests, empty states, broken elements)
- Screenshot references for evidence

---

## Rules

- **Never auto-start the dev server** in Runner Mode — report and stop if not running. `preview_start` in Interactive Mode is expected to launch/attach, since that's its purpose.
- **Dev port**: read from `CLAUDE.md` or `package.json` for the active project
- **Package manager**: check `CLAUDE.md` or detect from lockfile (`yarn.lock` → yarn, `package-lock.json` → npm)
- **E2E baselines** (Runner Mode): compare against baseline documented in `CLAUDE.md`

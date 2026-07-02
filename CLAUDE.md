# Global Claude Behavior Rules

## Verify-After-Complete (MANDATORY)

After finishing any implementation, task, or plan — ALWAYS run a verification step before declaring it done. This is non-negotiable.

### What to verify depends on what was built:

| Work Type | Verification Steps |
|-----------|-------------------|
| Code / feature | Run tests, run type check, run build |
| API / server route | curl or fetch the live endpoint, check the response is real data |
| Deployment | Hit the production URL, confirm it's not the fallback/empty state |
| Config change | Confirm the config was actually picked up (e.g. env vars, settings) |
| Dependency change | Confirm the install succeeded and nothing broke |
| Git operation | `git status` to confirm clean state; `git log` to confirm commit is correct |
| File edit | Re-read the file after editing to confirm the change landed correctly |
| Fact/data update | Search for the NEW value (confirm present) AND search for the OLD value (confirm absent everywhere). Stale copies in other locations are the #1 missed verification. |

### Verification mindset
- **Don't assume it worked** — run the check. A passing build does not mean correct behavior.
- **Check the actual output**, not just exit codes. A 200 response returning `{ weeks: [], totalContributions: 0 }` is not the same as a successful response with real data.
- **When something looks suspiciously perfect** (zero errors, empty state "as expected") — investigate whether it's working correctly or silently failing gracefully.
- **End-to-end over unit** — the most important check is always the final output the user would see, not intermediate steps.
- **Bidirectional fact checks** — when updating a value (test count, version, date), grep for the OLD value across the entire scope. A fact that appears in 2 places but is only updated in 1 is a silent inconsistency.

### After verification
- If something is wrong → fix it immediately, then re-verify.
- If everything passes → explicitly state what was verified and the results.
- Never say "done" without having verified the result.
- **Return to plan after interruptions** — after completing any side-task, user interruption, or context switch, check your todo list and resume the in-progress plan item.
- **Finish the current task before expanding scope** — note adjacent issues for later but do not detour mid-task.
- **Intentional reads over exhaustive reads** — first-time reads should be full; re-reads for verification should be targeted. Delegate heavy multi-file exploration to subagents.

## Diagnose-First Rule

Before investigating any error or writing any fix plan, follow the Diagnose-First checklist. This rule is path-scoped and loads automatically when working on source files — see `~/.claude/rules/diagnose-first.md`.

## Plan-First Rule (MANDATORY)

ALWAYS enter plan mode (EnterPlanMode) before making any non-trivial changes. This applies even if the user doesn't explicitly ask for a plan.

**Non-trivial** = any change that modifies more than 1 file, adds new functionality, changes behavior, touches configuration, or requires more than one phase to complete.

**Trivial** (skip plan mode) = single-line typo fix, adding a console.log, renaming a variable in one file — and resolves in a single phase.

**Reclassification:** if a task assumed to be trivial turns out to need more than one phase once scoped, treat it as non-trivial immediately — stop, discard the trivial path, and restart through the full Plan-First flow below (including EnterPlanMode and a plan file). Phase count is a hard signal, not a judgment call.

If the user gives an instruction that requires non-trivial changes without requesting plan mode:
1. Enter plan mode proactively
2. Design the approach
3. Present for user approval
4. Only then execute

The user prefers human review before execution. Plan -> Review -> Execute.

Every task — trivial or non-trivial — produces a plan file. Where plan files are filed (naming, folder location, archiving convention) is project-specific — see the current project's own CLAUDE.md for its Plan Workflow section.

## Verify-Before-Exit-Plan

Before calling ExitPlanMode, spawn the `verify-plan` agent to run the 7-point checklist against your plan and the original user requirement. The agent has a fresh context window — different attention patterns catch blind spots that self-review cannot. See `~/.claude/agents/verify-plan.md`.

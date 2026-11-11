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

Non-trivial tasks produce a plan file. A trivial task needs no plan file; a one-line note in the todo list is enough. Where plan files are filed and archived follows the defaults under "Plan Tracking → Plan files: default location and archiving", unless the current project's own CLAUDE.md has a Plan Workflow section that overrides them.

## Verify-Before-Exit-Plan

Before calling ExitPlanMode, spawn the `verify-plan` agent to run the 7-point checklist against your plan and the original user requirement. The agent has a fresh context window — different attention patterns catch blind spots that self-review cannot. See `~/.claude/agents/verify-plan.md`.

## Plan Tracking

Once a plan file exists (see Plan-First Rule for where it's filed), track it
consistently across all projects:

**Plan files: default location and archiving** — a project's own CLAUDE.md
Plan Workflow section overrides any of these. Where it is missing or silent on
a point, use the default and say so once in the plan; never treat "not
defined" as "skip it".
- **Active plans:** `<project root>/docs/plans/<short-kebab-name>-plan.md`
  (create the folder if needed). This matches NodeCraft and claude-config,
  and the global permissions already allow edits there.
- **Archive:** when every phase is Completed or Cancelled, move the plan to
  `docs/plans/archived/` under the same filename, add a one-line outcome and
  completion date under its title, and update every reference to the old
  path (project files, rules, skills, memory). Do it in the same step as the
  plan's final commit, not later.
- **Not archived:** living documents that have no phases to finish
  (roadmaps, overviews, catalogs, running notes) stay where they are.
- If a project needs a different structure, write it into that project's
  CLAUDE.md as a Plan Workflow section rather than leaving it implicit.

**Status vocabulary** — every phase uses:
`Not Started | In Progress | Completed | Blocked | Cancelled`. Update the
phase's Status line before starting work on it, not after.

**Recommended model** — each phase should record the Claude model best
suited to it. Keep this field accurate as the plan evolves; check it before
actioning a phase to decide whether to switch models.

**Plan file location during planning** — `EnterPlanMode` may draft the plan
into a fixed location outside the current project (e.g. a profile-level
scratch path). Treat that as a draft only. Before calling `ExitPlanMode`,
ensure the canonical copy exists inside the project (per that project's own
Plan Workflow conventions, else the default above) — even if this means briefly exiting plan mode to
write it there, then re-entering plan mode to finalize and request
approval. A plan is not considered saved until it exists in the project,
not just approved.

**Testing considerations** — where applicable, plans should include a phase
for creating automated tests using the project's own test tooling. Don't
assume a specific framework — confirm what's actually installed before
naming one.

### Open Question Workflow

Open questions are decision points, not implementation approval.

When a user responds to an open question:
- Update the relevant plan document
- Record the user's decision
- Update any affected phases, requirements, assumptions, risks, or implementation notes
- Remove resolved questions from the Open Questions section where appropriate

Unless the user explicitly instructs otherwise, a response to an open
question does NOT constitute approval to begin or continue implementation,
start the next phase, modify code, or execute the plan. After updating the
plan, summarise the changes and wait for further instruction.

Only begin or resume implementation when explicitly instructed
("implement the plan", "action phase X", "continue implementation", etc.).

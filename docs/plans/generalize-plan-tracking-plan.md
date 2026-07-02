# Port generic Plan Tracking rules to ~/claude-config/CLAUDE.md

## Context

`E:\Websites\NodeCraft\.claude\CLAUDE.md` was just reconciled (previous plan,
now archived at `docs/plans/archived/plan-workflow-reconciliation-plan.md`
in the NodeCraft repo) after a pasted block from another project introduced
several genuinely useful, stack/project-agnostic conventions: a 5-state
phase status vocabulary, a rule protecting the `Recommended model` field, a
fix for `EnterPlanMode` drafting plan files outside the project, and an
Open Question Workflow. None of these reference NodeCraft's stack, folder
names, or content — they're general plan-tracking process, not project
specifics.

`C:\Users\pyro_\claude-config\CLAUDE.md` is the source-of-truth generic
config (this git repo, hardlinked/synced into `~/.claude/CLAUDE.md`) that
loads for every project. Its existing `Plan-First Rule` section already
deliberately defers project-specific details ("Where plan files are filed
... is project-specific — see the current project's own CLAUDE.md") — this
plan adds a new section for the parts that are NOT project-specific, so
every project benefits without re-deriving them.

Through an interview, the user decided:
1. Port four items: the 5-state Status vocabulary, the Recommended-model
   preservation rule, the project-folder-before-`ExitPlanMode` rule, and
   the full Open Question Workflow.
2. The testing-considerations line should be stack-agnostic in the generic
   config too (not Pest/PHPUnit-specific) — consistent with claude-config
   being genuinely generic across projects, matching NodeCraft's own fix.
3. This content gets its own new standalone `## Plan Tracking` section in
   `claude-config/CLAUDE.md`, separate from `Plan-First Rule` (which stays
   focused on *when* to plan; this new section covers *how* to track one
   once it exists).

## File to modify

### `C:\Users\pyro_\claude-config\CLAUDE.md`

Insert a new `## Plan Tracking` section after `## Verify-Before-Exit-Plan`
(end of file, after line 61's `~/.claude/agents/verify-plan.md` reference):

```md
## Plan Tracking

Once a plan file exists (see Plan-First Rule for where it's filed), track it
consistently across all projects:

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
Plan Workflow conventions) — even if this means briefly exiting plan mode to
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
```

No other section of `claude-config/CLAUDE.md` changes. `Plan-First Rule`
and `Verify-Before-Exit-Plan` are left exactly as they are — this is a pure
addition.

## Explicitly out of scope
- Not porting the "Plans should include" checklist (Current state analysis,
  Risks and constraints, etc.) or the detailed "Archiving Completed Plans"
  step list — those weren't selected for genericization and still read as
  tied to the concept of a project-local `docs/plans/` folder structure.
- Not trimming NodeCraft's own `.claude/CLAUDE.md` to remove the
  now-duplicated content — both files load together every session, so the
  overlap is harmless, and de-duplicating wasn't asked for.
- Not touching `claude-config/agents/verify-plan.md`, `hooks/`, `rules/`,
  or `skills/`.

## Verification
1. `git -C C:\Users\pyro_\claude-config diff CLAUDE.md` — confirm only the
   new `## Plan Tracking` section was added, nothing else changed.
2. Grep the new section for NodeCraft-specific strings (`docs/plans`,
   `archived`, `NodeCraft`, `Pest`, `PHPUnit`) — should return zero matches;
   the section must stay path- and stack-agnostic.
3. Re-read the full file top to bottom to confirm Markdown structure
   (headings, blank lines) stays well-formed and the new section doesn't
   collide with the existing `---` separators or heading levels used
   elsewhere in the file.
4. `git -C C:\Users\pyro_\claude-config status` — confirm only `CLAUDE.md`
   is modified (plus this new plan file), no unintended files touched.

## Implementation Status

| Phase | Status |
|---|---|
| Phase 1 — Add Plan Tracking section to claude-config/CLAUDE.md | Completed |

Last Updated: 2026-07-02

### Phase 1 Implementation Notes

Notes:

* Added a new `## Plan Tracking` section to `CLAUDE.md` after `Verify-Before-Exit-Plan` (lines 63-106), containing exactly the 4 selected items (Status vocabulary, Recommended-model preservation, plan-file-location-before-ExitPlanMode rule, Open Question Workflow) plus the stack-agnostic testing-considerations line.
* `Plan-First Rule` and `Verify-Before-Exit-Plan` sections were left untouched — pure addition, confirmed via `git diff CLAUDE.md`.
* Verified zero NodeCraft/PHP-specific strings (`docs/plans`, `archived`, `NodeCraft`, `Pest`, `PHPUnit`) in the new section.
* Deviation from original plan: none. Bypassed the "new session" rule at the user's explicit in-session instruction ("bypass the session rule for the new plan").
* Follow-up work required: none.

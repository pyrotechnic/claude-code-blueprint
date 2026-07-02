---
description: Diagnose-First rule — run 4 checks before investigating any error or writing a fix plan
globs:
  - "src/**/*.ts"
  - "src/**/*.tsx"
  - "src/**/*.js"
  - "src/**/*.jsx"
  - "**/*.config.*"
  - "**/*.json"
---

# Diagnose-First Rule (Before Any Fix)

Before investigating any error or writing any fix plan, always run these four checks first:

## 1. Check git state
```bash
git status        # are files missing due to unstaged deletions?
git log --oneline -5  # was this already fixed in a recent commit?
```
A "missing file" finding is meaningless without first confirming it isn't just an unstaged deletion. A fix plan is pointless if the fix already exists in git history.

## 2. Identify the error source
Determine WHERE the error is coming from before investigating the code:
- **VSCode Problems panel** (source label: "Prisma", "ESLint", "TypeScript") → editor extension diagnostic, may be a false positive
- **Terminal / CLI** (`prisma generate`, `pnpm build`, etc.) → real tooling error
- **Runtime / server logs** → real application error

Never treat a VSCode editor diagnostic as a CLI or runtime error without confirming. Extension language servers can report v7-style errors on v6 code, missing file errors on symlinked paths, etc.

## 3. Check for existing suppression settings
Before planning a fix, check:
- `.vscode/settings.json` — does a suppression/pin setting already exist?
- Recent commits (`git log --grep=keyword`) — was this already addressed?

## 4. Apply minimum viable diagnosis
Ask: what is the simplest explanation that fits all the evidence?
- File not found → check `git status` before concluding the file is missing from the repo
- Build/lint error → confirm the error reproduces in CLI before assuming code needs to change
- Version-related error → confirm the installed version before assuming an upgrade is needed

Only proceed with investigation and planning AFTER these checks pass. Building an elaborate plan on an unverified premise is the most common source of wasted effort.

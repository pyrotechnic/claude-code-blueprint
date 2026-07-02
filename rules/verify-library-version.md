---
description: Verify the actually-installed library/framework version before answering "how do I do X" questions or writing code against a library's API — prevents stale training-data answers (e.g. describing Laravel 5 syntax when the project is on Laravel 12)
globs:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.php"
  - "**/*.py"
  - "**/*.rb"
  - "**/*.go"
  - "**/*.java"
  - "**/package.json"
  - "**/composer.json"
  - "**/requirements.txt"
  - "**/pyproject.toml"
  - "**/Gemfile"
  - "**/go.mod"
---

# Verify Library/Framework Version Before Answering

Training data skews toward older, more common library versions. Before answering
"how do I do X in `<library/framework>`", or before writing/suggesting code that
uses a library's API, don't answer purely from memory.

## 1. Check the actually installed version
Look at the project's manifest (`package.json`, `composer.json`, `requirements.txt`,
`pyproject.toml`, `Gemfile`, `go.mod`, etc.) for the real installed/pinned version
before assuming one.

## 2. Verify current usage against that version
- Prefer `context7` (`resolve-library-id` + `get-library-docs`) for current,
  version-matched documentation.
- If `context7`'s tools aren't available or fail, fall back to `WebSearch`/`WebFetch`
  for the official docs at that version.
- Don't present a remembered API from training data as current without one of the
  above checks — especially for fast-moving frameworks (Laravel, Next.js, React,
  Rails, etc.) where major-version behavior changes often.

## 3. Flag uncertainty
If you can't verify the current API (no manifest found, doc lookup fails), say so
explicitly rather than guessing confidently. State which version your answer assumes.

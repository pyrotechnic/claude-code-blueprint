---
name: request-model-prices
description: "Fetch and record real per-MTok pricing for any Claude model currently listed in ~/.claude/metrics/pricing.json's _pending_models, or seed pricing.json from scratch on a fresh machine where the models table is empty. Run when cost-tracker.sh's systemMessage says a model is pending, or proactively after setting up Claude Code on a new machine."
user-invocable: true
---

# Request Model Prices — Fetch and Record Pricing

`~/.claude/metrics/pricing.json`'s `models` block holds per-million-token USD rates
used by `cost-tracker.sh` to compute real session cost. Nothing fetches this
automatically — hooks are plain bash/python subprocesses with no model or web access,
so only a live Claude turn (this skill) can look up current rates and write them.

## Workflow

### 1. Read the current state

Read `~/.claude/metrics/pricing.json`. Build the target list:

- Every entry in `_pending_models`.
- If `models` is empty (a completely fresh file, e.g. new machine): also add the
  currently-known Claude model family base names as a seed set, so the file isn't left
  at zero entries after this runs. Use whatever generation is current — check your own
  system prompt / model knowledge for the current model family names (e.g. Opus,
  Sonnet, Haiku lines) rather than hardcoding a specific version here, since this file
  should not need editing every time a new model ships.

If both `_pending_models` is empty and `models` is non-empty, report that there's
nothing to do and stop.

### 2. Normalize model IDs

For each target model, strip a trailing `-YYYYMMDD` date/snapshot suffix (same rule as
`cost-tracker.sh`'s `base_model_id()`: regex `-\d{8}$`) to get the base family name.
Pricing is tracked per base family, not per dated snapshot.

### 3. Look up current pricing

For each base model name, find current official per-MTok rates:
- input tokens
- output tokens
- cache write (prompt caching, write side)
- cache read (prompt caching, read side)

Use WebSearch/WebFetch against Anthropic's public pricing page
(`https://www.anthropic.com/pricing` or `https://platform.claude.com/docs/en/about-claude/pricing`)
as the source of truth — don't rely on a cached skill or trained-in numbers alone,
since rates change. Do not fabricate a rate you can't find; if a model can't be found,
say so explicitly rather than guessing.

### 4. Confirm before writing

Present the proposed rates in a table (model | input | output | cache_write |
cache_read) and ask the user to confirm before writing anything:

> "Here's what I found for [models]. Should I save these to pricing.json?"

Do not write until the user confirms. If the user corrects a rate or says a model
doesn't belong, adjust and re-present.

### 5. Write confirmed entries

For each confirmed model:
- Add/update its entry in `pricing.json`'s `models` block.
- Remove it from `_pending_models` if it was there.
- Update the top-level `_updated` field to today's date.

Write directly with the Edit/Write tools (this runs inside a normal Claude turn, so
there's no need for the atomic temp-file-then-rename pattern the hooks use to avoid
partial writes from a crashed subprocess).

### 6. Report

Summarize what was added/updated and what (if anything) is still pending or couldn't
be found.

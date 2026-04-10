---
name: 'Atomic Commit Guard'
description: 'Validates that the staged changes form a single logical unit before commit. Checks compilation, test pass, and no domain entity leaks. Runs as a pre-commit hook.'
tags: [git, quality, java, quarkus]
---

# Atomic Commit Guard

Enforces the atomic commit protocol from `skills/git-atomic-commit/SKILL.md` before every commit.

## What It Does

1. **Compilation check** — runs `./mvnw compile -q` and blocks commit if it fails.
2. **Test check** — runs `./mvnw test -q` and blocks commit if any test is red.
3. **Entity leak check** — scans staged `.java` files for `Entity` types imported outside `data/` packages.
4. **Conventional message check** — validates commit message matches `type(scope): subject` pattern.

## Installation

Copy `hooks.json` to your project's `.github/hooks/atomic-commit/hooks.json` and reference in Copilot settings.

## Files

- `README.md` — this file (hook spec)
- `hooks.json` — hook event configuration
- `scripts/atomic-commit-check.sh` — validation script

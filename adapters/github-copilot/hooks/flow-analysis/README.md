---
name: 'Flow Analysis on Change'
description: 'Runs AST-based impact analysis when a Java file with high fan-in is modified. Alerts if more than 5 callers are affected by the change. Runs as a pre-commit hook.'
tags: [java, analysis, impact, quarkus]
---

# Flow Analysis on Change

Runs `scripts/analyze-java.py` impact analysis before committing changes to Java files with high fan-in. Prevents accidental breakage of callers.

## What It Does

1. Detects which Java files are staged.
2. For each staged file, runs `python scripts/analyze-java.py impact <ClassName> .`
3. If fan-in > 5 (more than 5 callers), prints a warning with the caller list.
4. Does NOT block the commit — outputs an advisory that the developer must acknowledge.

## Files

- `README.md` — this file (hook spec)
- `hooks.json` — hook event configuration
- `scripts/flow-analysis-check.sh` — analysis script

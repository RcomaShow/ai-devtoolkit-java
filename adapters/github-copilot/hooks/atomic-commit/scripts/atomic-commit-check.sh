#!/usr/bin/env bash
# Atomic Commit Guard — validates staged changes before commit
set -euo pipefail

STAGED=$(git diff --cached --name-only)
JAVA_STAGED=$(echo "$STAGED" | grep '\.java$' || true)

echo "[atomic-commit] Checking staged changes..."

# 1. Compilation check
if [ -f "./mvnw" ]; then
  echo "[atomic-commit] Running compilation check..."
  ./mvnw compile -q 2>&1 || {
    echo "[atomic-commit] BLOCKED: Compilation failed. Fix errors before committing."
    exit 1
  }
fi

# 2. Test check (only if test files are staged)
TEST_STAGED=$(echo "$STAGED" | grep 'Test\.java$' || true)
if [ -n "$TEST_STAGED" ] && [ -f "./mvnw" ]; then
  echo "[atomic-commit] Running test check..."
  ./mvnw test -q 2>&1 || {
    echo "[atomic-commit] BLOCKED: Tests failed. All tests must be green before committing."
    exit 1
  }
fi

# 3. Entity leak check — Entity class used outside data/ package
if [ -n "$JAVA_STAGED" ]; then
  echo "[atomic-commit] Checking for entity leaks..."
  while IFS= read -r file; do
    if [[ "$file" != *"/data/"* ]] && grep -q 'Entity\b' "$file" 2>/dev/null; then
      echo "[atomic-commit] WARNING: '$file' may reference an Entity class outside data/ package."
      echo "  → Verify that no *Entity type crosses the data/ boundary."
    fi
  done <<< "$JAVA_STAGED"
fi

# 4. Conventional commit message check
COMMIT_MSG_FILE="${1:-.git/COMMIT_EDITMSG}"
if [ -f "$COMMIT_MSG_FILE" ]; then
  MSG=$(head -1 "$COMMIT_MSG_FILE")
  PATTERN='^(feat|fix|refactor|test|docs|chore|perf|style)(\([a-z0-9-]+\))?: .+'
  if ! echo "$MSG" | grep -qE "$PATTERN"; then
    echo "[atomic-commit] BLOCKED: Commit message does not follow conventional commit format."
    echo "  Expected: type(scope): subject"
    echo "  Examples: feat(nominas): add POST endpoint"
    echo "            test(service): add branch coverage for NominaService"
    echo "  Got: $MSG"
    exit 1
  fi
fi

echo "[atomic-commit] All checks passed."

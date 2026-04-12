#!/usr/bin/env bash
set -euo pipefail

STAGED=$(git diff --cached --name-only --diff-filter=ACM)
JAVA_STAGED=$(echo "$STAGED" | grep '\.java$' || true)

echo "[flow-analysis] Checking staged Java changes..."

if [ -z "$JAVA_STAGED" ]; then
  echo "[flow-analysis] No staged Java files found."
  exit 0
fi

if ! command -v python >/dev/null 2>&1; then
  echo "[flow-analysis] Python not found. Skipping advisory analysis."
  exit 0
fi

for file in $JAVA_STAGED; do
  [ -f "$file" ] || continue
  class_name=$(basename "$file" .java)

  if [[ "$file" == *"/src/main/java/"* ]]; then
    source_root="${file%%/src/main/java/*}/src/main/java"
  elif [[ "$file" == *"/src/test/java/"* ]]; then
    source_root="${file%%/src/test/java/*}/src/test/java"
  else
    source_root=$(dirname "$file")
  fi

  impact_json=$(python .ai-devtoolkit/scripts/analyze-java.py impact "$source_root" "$class_name" 2>/dev/null || true)
  if [ -z "$impact_json" ]; then
    continue
  fi

  fan_in=$(printf '%s' "$impact_json" | python -c "import sys, json; data=sys.stdin.read().strip(); print(len(json.loads(data)) if data else 0)" 2>/dev/null || echo 0)
  if [ "$fan_in" -gt 5 ]; then
    echo "[flow-analysis] WARNING: $class_name has fan-in $fan_in from $source_root"
  fi
done

echo "[flow-analysis] Advisory analysis completed."
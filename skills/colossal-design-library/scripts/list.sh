#!/usr/bin/env bash
# List all design references in this skill with their meta fields.
# Output: JSON array of { slug, meta } objects.
# Usage: list.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
REF_DIR="$SKILL_DIR/references"

if [ ! -d "$REF_DIR" ]; then
  echo "ERROR: references directory not found: $REF_DIR" >&2
  exit 1
fi

echo "["
first=true
for dir in "$REF_DIR"/*/; do
  json="$dir/design.json"
  [ -f "$json" ] || continue
  slug=$(basename "$dir")
  meta=$(jq '.meta' "$json")
  if [ "$first" = true ]; then
    first=false
  else
    echo ","
  fi
  jq -n --arg slug "$slug" --argjson meta "$meta" '{ slug: $slug, meta: $meta }'
done
echo "]"

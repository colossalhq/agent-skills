#!/usr/bin/env bash
# Generate an image using Gemini API and save to disk.
# Usage: gen-image.sh <output_path> <prompt> [aspect_ratio] [size]
# Example: gen-image.sh public/images/hero.png "editorial beauty photo" "21:9" "2K"

set -euo pipefail

OUTPUT="$1"
PROMPT="$2"
ASPECT="${3:-16:9}"
SIZE="${4:-2K}"

if [ -z "${GEMINI_API_KEY:-}" ]; then
  echo "ERROR: GEMINI_API_KEY not set" >&2
  exit 1
fi

BASE_URL="${GOOGLE_AI_BASE_URL:-https://generativelanguage.googleapis.com}"

mkdir -p "$(dirname "$OUTPUT")"

RESPONSE=$(curl -s -X POST \
  "$BASE_URL/v1beta/models/gemini-3-pro-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"contents\": [{\"parts\": [{\"text\": $(printf '%s' "$PROMPT" | jq -Rs .)}]}],
    \"generationConfig\": {
      \"responseModalities\": [\"TEXT\", \"IMAGE\"],
      \"imageConfig\": {\"aspectRatio\": \"$ASPECT\", \"imageSize\": \"$SIZE\"}
    }
  }")

# Extract base64 image data
IMAGE_DATA=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[] | select(.inlineData) | .inlineData.data')

if [ -z "$IMAGE_DATA" ] || [ "$IMAGE_DATA" = "null" ]; then
  echo "ERROR: No image data in response" >&2
  echo "$RESPONSE" | jq '.candidates[0].content.parts[] | select(.text) | .text' 2>/dev/null >&2
  exit 1
fi

echo "$IMAGE_DATA" | base64 -d > "$OUTPUT"
echo "Saved: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"

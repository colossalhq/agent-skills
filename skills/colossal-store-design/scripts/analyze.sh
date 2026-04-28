#!/usr/bin/env bash
# Analyze one or more store screenshots → design.json + theme.css
# in the sibling colossal-design-library skill.
#
# Usage: analyze.sh <image-path>... <store-slug>
# Examples:
#   bash analyze.sh ~/Desktop/ref-store.jpg bold-comfort-basics
#   bash analyze.sh ~/Desktop/page1.jpg ~/Desktop/page2.jpg soft-luxe-beauty
#
# Multiple images are sent as separate parts in one Gemini request, so the
# model can see the full site across screenshots.
#
# Requires: GEMINI_API_KEY env var, jq, node
# Output: <colossal-design-library>/references/<store-slug>/{design.json, theme.css}
#
# By default, the output skill is found at ../../colossal-design-library
# (i.e. installed as a sibling skill). Override with COLOSSAL_DESIGN_LIBRARY_DIR.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
PROMPT_FILE="$SCRIPT_DIR/prompt.txt"
LIB_SKILL_DIR="${COLOSSAL_DESIGN_LIBRARY_DIR:-$(dirname "$SKILL_DIR")/colossal-design-library}"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <image-path>... <store-slug>" >&2
  echo "  Last argument is the store slug, all preceding arguments are image paths." >&2
  exit 1
fi

if [ -z "${GEMINI_API_KEY:-}" ]; then
  echo "ERROR: GEMINI_API_KEY is not set" >&2
  exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: Prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

if [ ! -d "$LIB_SKILL_DIR" ]; then
  echo "ERROR: colossal-design-library skill not found at: $LIB_SKILL_DIR" >&2
  echo "  Install it as a sibling skill, or set COLOSSAL_DESIGN_LIBRARY_DIR." >&2
  exit 1
fi

# Last argument is the slug, everything else is an image path
STORE_SLUG="${!#}"
IMAGE_PATHS=()
COUNT=0
TOTAL=$#
for arg in "$@"; do
  COUNT=$((COUNT + 1))
  if [ "$COUNT" -lt "$TOTAL" ]; then
    IMAGE_PATHS+=("$arg")
  fi
done

# Validate all images exist
for img in "${IMAGE_PATHS[@]}"; do
  if [ ! -f "$img" ]; then
    echo "ERROR: Image not found: $img" >&2
    exit 1
  fi
done

MODEL="${GEMINI_MODEL:-gemini-3.1-pro-preview}"
OUTPUT_DIR="$LIB_SKILL_DIR/references/$STORE_SLUG"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$OUTPUT_DIR"

echo "=> Encoding ${#IMAGE_PATHS[@]} image(s)..."

# Build payload with multiple images via node
node -e "
const fs = require('fs');
const path = require('path');

const promptFile = process.argv[1];
const outputFile = process.argv[2];
const imagePaths = process.argv.slice(3);

let prompt = fs.readFileSync(promptFile, 'utf-8');

if (imagePaths.length > 1) {
  prompt += '\n\nNOTE: You are receiving multiple screenshots of the SAME store/website. They show different sections of the same page or different pages. Combine them into a SINGLE unified design.json — one meta, one theme, one header, one footer, one productCard, one productGrid, one featuredProducts, and one combined sections array covering ALL visible sections across all images. Do NOT produce separate analyses per image.';
}

const parts = [{ text: prompt }];

const mimeMap = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp' };

for (const imgPath of imagePaths) {
  const ext = path.extname(imgPath).toLowerCase().slice(1);
  const mime = mimeMap[ext] || 'image/jpeg';
  const b64 = fs.readFileSync(imgPath).toString('base64');
  parts.push({ inlineData: { mimeType: mime, data: b64 } });
}

const payload = {
  contents: [{ parts }],
  generationConfig: { responseMimeType: 'application/json' }
};

fs.writeFileSync(outputFile, JSON.stringify(payload));
" "$PROMPT_FILE" "$TMP_DIR/payload.json" "${IMAGE_PATHS[@]}"

BASE_URL="${GOOGLE_AI_BASE_URL:-https://generativelanguage.googleapis.com}"

echo "=> Sending to Gemini ($MODEL)..."
RESPONSE=$(curl -s -X POST \
  "$BASE_URL/v1beta/models/$MODEL:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d @"$TMP_DIR/payload.json")

# Check for errors
ERROR=$(echo "$RESPONSE" | jq -r '.error.message // empty')
if [ -n "$ERROR" ]; then
  echo "ERROR from Gemini: $ERROR" >&2
  exit 1
fi

# Extract JSON result
RESULT=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text')
if [ -z "$RESULT" ] || [ "$RESULT" = "null" ]; then
  echo "ERROR: No text in response" >&2
  echo "$RESPONSE" | jq . >&2
  exit 1
fi

# Save design.json (pretty-printed, unwrap array if needed, strip links)
echo "$RESULT" | node -e "
const fs = require('fs');
let input = '';
process.stdin.on('data', c => input += c);
process.stdin.on('end', () => {
  let data = JSON.parse(input);
  if (Array.isArray(data)) data = data[0];
  // Strip links — these are never extracted, added by customer later
  if (data.header) delete data.header.links;
  if (data.footer) delete data.footer.columns;
  fs.writeFileSync(process.argv[1], JSON.stringify(data, null, 2));
});
" "$OUTPUT_DIR/design.json"
echo "=> Saved design.json"

# Generate theme.css
node "$SCRIPT_DIR/gen-theme.cjs" "$OUTPUT_DIR/design.json" "$OUTPUT_DIR/theme.css"
echo "=> Saved theme.css"

echo ""
echo "Done! Output: $OUTPUT_DIR"
echo "  design.json  $(wc -c < "$OUTPUT_DIR/design.json" | tr -d ' ') bytes"
echo "  theme.css    $(wc -c < "$OUTPUT_DIR/theme.css" | tr -d ' ') bytes"

# Print summary
node -e "
const d = JSON.parse(require('fs').readFileSync('$OUTPUT_DIR/design.json', 'utf-8'));
const m = d.meta;
console.log('  Industry:  ' + m.industry);
console.log('  Aesthetic: ' + m.aesthetic);
console.log('  Mood:      ' + m.mood);
console.log('  Sections:  ' + m.sectionNames.join(', '));
"

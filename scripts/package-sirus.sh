#!/usr/bin/env bash
# Build a drop-in release archive for the Sirus (3.3.5a) backport.
#
#   bash scripts/package-sirus.sh [version]
#
# Produces dist/DialogueUI-<version>-sirus.zip whose only top-level entry is
# the DialogueUI/ folder (the 3.3.5a client only lists the addon when the
# folder name matches DialogueUI.toc), so it can be unpacked straight into
# World of Warcraft/Interface/AddOns. The version defaults to the
# "## Version:" line of DialogueUI.toc (spaces become "-": "1.0.7 b" -> "1.0.7-b").
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ADDON="DialogueUI"
TOC="${ADDON}.toc"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  VERSION="$(sed -n 's/^## Version:[[:space:]]*//p' "$TOC" | tr -d '\r' | head -n 1)"
fi
VERSION="$(printf '%s' "$VERSION" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[[:space:]]\{1,\}/-/g')"
VERSION="${VERSION#v}"
if [ -z "$VERSION" ]; then
  echo "error: no '## Version:' line in $TOC" >&2
  exit 1
fi

DIST="$ROOT/dist"
STAGE="$DIST/stage"
ZIP_NAME="${ADDON}-${VERSION}-sirus.zip"
OUT="$DIST/$ZIP_NAME"

# Everything the client needs at runtime. Dev files (_Dev, _Build, scripts,
# CI configs, editor folders) stay out.
ITEMS=(
  "$TOC"
  API.lua
  API.xml
  Fonts.xml
  Initialization.lua
  Art
  Code
  Fonts
  Locales
  Sound
)

rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE/$ADDON"

for item in "${ITEMS[@]}"; do
  if [ ! -e "$item" ]; then
    echo "error: package item not found: $item" >&2
    exit 1
  fi
  cp -R "$item" "$STAGE/$ADDON/"
done
for extra in LICENSE LICENSE.md LICENSE.txt README.md; do
  if [ -f "$extra" ]; then cp "$extra" "$STAGE/$ADDON/"; fi
done

# Editor / OS junk.
find "$STAGE/$ADDON" \( -name '.DS_Store' -o -name 'Thumbs.db' -o -name '*.bak' -o -name '*.orig' \) -type f -delete

# Every file listed in the TOC must be in the package. WoW on Windows is
# case-insensitive, so compare lower-cased paths.
FILE_LIST="$(cd "$STAGE/$ADDON" && find . -type f | sed 's|^\./||' | tr '[:upper:]' '[:lower:]')"
missing=0
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  case "$line" in
    "" | "#"*) continue ;;
  esac
  path="$(printf '%s' "$line" | tr '\\' '/' | tr '[:upper:]' '[:lower:]')"
  if ! grep -Fxq -- "$path" <<<"$FILE_LIST"; then
    echo "error: $TOC references a file that is not in the package: $line" >&2
    missing=1
  fi
done < "$STAGE/$ADDON/$TOC"
if [ "$missing" -ne 0 ]; then
  exit 1
fi

(cd "$STAGE" && zip -q -r -9 -X "$OUT" "$ADDON")
rm -rf "$STAGE"

echo "Packaged $OUT"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "zip_path=$OUT"
    echo "zip_name=$ZIP_NAME"
    echo "version=$VERSION"
  } >> "$GITHUB_OUTPUT"
fi

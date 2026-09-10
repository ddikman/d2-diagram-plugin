#!/usr/bin/env bash
# gallery.sh — regenerate docs/presets/*.svg, the nine images embedded in the README.
#
# Usage: gallery.sh [--check]
#   --check  render into a temp dir and report differences instead of writing (exit 1 if stale).
#
# d2 salts every CSS class name with a content hash, so the hash is normalised before comparing;
# otherwise an unrelated d2 build would make every file look changed.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
check=0
case "${1:-}" in
  --check) check=1 ;;
  -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *) echo "error: unknown option $1" >&2; exit 2 ;;
esac

tmp="$(mktemp -d "${TMPDIR:-/tmp}/d2-gallery.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
bash "$ROOT/scripts/preview.sh" --out "$tmp" --no-open >/dev/null
mkdir -p "$ROOT/docs/presets"

norm() { sed -E 's/d2-[0-9]{6,}/d2-HASH/g' "$1"; }

stale=0
for f in "$tmp"/0[1-9]-*.svg; do
  dest="$ROOT/docs/presets/$(basename "$f")"
  if [ ! -f "$dest" ] || ! diff -q <(norm "$f") <(norm "$dest") >/dev/null; then
    stale=1
    if [ "$check" = 1 ]; then
      echo "stale: docs/presets/$(basename "$f")"
    else
      cp "$f" "$dest"
    fi
  fi
done

if [ "$check" = 1 ]; then
  if [ "$stale" = 0 ]; then echo "docs/presets is up to date"; else echo "run scripts/gallery.sh"; exit 1; fi
else
  echo "docs/presets: $(ls "$ROOT"/docs/presets/*.svg | wc -l | tr -d ' ') SVGs written"
fi
exit 0

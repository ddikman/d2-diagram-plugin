#!/usr/bin/env bash
# preview.sh — render the sample diagram in every numbered preset and open a contact sheet.
#
# Usage: preview.sh [--out DIR] [--no-open]
#
# Writes DIR/NN-name.d2 (preset + sample), DIR/NN-name.svg and DIR/index.html, opens the sheet in
# the default browser (unless --no-open or no opener is available), then prints "SHEET: <path>"
# and the numbered list of styles so the user can pick by number even without a display.
# SVG only, so this never needs Chromium.
set -e
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${TMPDIR:-/tmp}/d2-diagram-preview"; out="${out%/}"
open_it=1
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="$2"; shift 2 ;;
    --no-open) open_it=0; shift ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown option $1" >&2; exit 2 ;;
  esac
done
command -v d2 >/dev/null 2>&1 || { echo "error: d2 is not installed (brew install d2)" >&2; exit 3; }
mkdir -p "$out"

html_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

cards=""
listing=""
n=0
for preset in "$PLUGIN_ROOT"/assets/presets/0[1-9]-*.d2; do
  [ -f "$preset" ] || continue
  n=$((n + 1))
  fname="$(basename "$preset" .d2)"
  name="${fname#*-}"
  caption="$(head -1 "$preset" | sed -E 's/^# d2-diagram preset: [^ ]+ *(—|-)? *//')"
  theme="$(grep -Eo 'theme-id:[[:space:]]*[0-9]+' "$preset" | head -1 | grep -Eo '[0-9]+')"
  star=""; classes=""
  case "$caption" in *Recommended*) star=" ★"; classes="recommended" ;; esac
  if [ "${theme:-0}" -ge 200 ] && [ "${theme:-0}" -lt 300 ]; then classes="$classes dark"; fi
  cat "$preset" "$PLUGIN_ROOT/assets/sample.d2" > "$out/$fname.d2"
  if ! bash "$PLUGIN_ROOT/scripts/render.sh" "$out/$fname.d2" --format svg --style "$preset" --out "$out/$fname.svg" >/dev/null; then
    echo "error: failed to render preset $name" >&2
    exit 1
  fi
  esc_caption="$(printf '%s' "$caption" | html_escape)"
  cards="$cards
<figure class=\"$classes\">
  <div class=\"head\"><span class=\"num\">$n</span><span class=\"name\">$name</span>${star:+<span class=\"star\">★ recommended</span>}</div>
  <div class=\"caption\">$esc_caption</div>
  <div class=\"img\"><img src=\"$fname.svg\" alt=\"$name\"></div>
</figure>"
  listing="$listing
$n. $name$star — $caption"
done

extras="$(ls "$PLUGIN_ROOT"/assets/presets/*.d2 | grep -v '/0[1-9]-' | sed 's|.*/||; s|\.d2$||' | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
template="$(cat "$PLUGIN_ROOT/assets/contact-sheet.html")"
html="${template//\{\{TITLE\}\}/D2 diagram styles}"
html="${html//\{\{CARDS\}\}/$cards}"
html="${html//\{\{FOOTER\}\}/More styles by name: $extras. Change your choice any time with /d2:style.}"
printf '%s\n' "$html" > "$out/index.html"

opened=0
if [ "$open_it" = 1 ]; then
  if command -v open >/dev/null 2>&1; then open "$out/index.html" >/dev/null 2>&1 && opened=1
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$out/index.html" >/dev/null 2>&1 && opened=1
  elif command -v start >/dev/null 2>&1; then start "$out/index.html" >/dev/null 2>&1 && opened=1
  fi
  [ "$opened" = 1 ] || echo "OPEN: failed (no browser opener found; share the path below)"
fi
echo "SHEET: $out/index.html"
echo "STYLES:$listing"
echo "EXTRAS: $extras"
exit 0

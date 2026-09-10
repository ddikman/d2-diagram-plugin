#!/usr/bin/env bash
# preview.sh — render the sample diagram in every colour theme and open a contact sheet.
#
# Usage: preview.sh [--out DIR] [--no-open] [--sample FILE]
#
# Writes DIR/NN-name.d2 (preset + sample), DIR/NN-name.svg and DIR/index.html, opens the sheet in
# the default browser (unless --no-open or no opener is available), then prints "SHEET: <path>"
# and the numbered list of styles so the user can pick by number even without a display.
# SVG only, so this never needs Chromium.
#
# --sample swaps in one of your own diagrams to judge the themes on something you actually draw.
# The file must not import a style of its own (no ...@_style line) — the theme supplies that.
set -e
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${TMPDIR:-/tmp}/d2-diagram-preview"; out="${out%/}"
open_it=1
sample="$PLUGIN_ROOT/assets/sample.d2"
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="$2"; shift 2 ;;
    --no-open) open_it=0; shift ;;
    --sample) sample="$2"; shift 2 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown option $1" >&2; exit 2 ;;
  esac
done
command -v d2 >/dev/null 2>&1 || { echo "error: d2 is not installed (brew install d2)" >&2; exit 3; }
[ -f "$sample" ] || { echo "error: no such sample: $sample" >&2; exit 2; }
grep -q '^\.\.\.@' "$sample" && { echo "error: $sample imports its own style (...@); the preset supplies the style" >&2; exit 2; }
sample="$(cd "$(dirname "$sample")" && pwd)/$(basename "$sample")"
mkdir -p "$out"

html_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

cards=""
listing=""
n=0
for preset in "$PLUGIN_ROOT"/assets/themes/0[1-9]-*.d2; do
  [ -f "$preset" ] || continue
  n=$((n + 1))
  fname="$(basename "$preset" .d2)"
  name="${fname#*-}"
  caption="$(head -1 "$preset" | sed -E 's/^# d2 theme: [^ ]+ *(—|-)? *//')"
  theme="$(grep -Eo 'theme-id:[[:space:]]*[0-9]+' "$preset" | head -1 | grep -Eo '[0-9]+')"
  layout="$(grep -Eo 'layout-engine:[[:space:]]*[a-z]+' "$preset" | head -1 | sed -E 's/.*:[[:space:]]*//')"
  # Scope the font lookup to the data: line; a house-style `style.font: mono` must not match.
  font="$(grep -m1 'data:' "$preset" | grep -Eo 'font:[[:space:]]*[A-Za-z0-9_./-]+' | sed -E 's/.*:[[:space:]]*//')"
  sketchy="$(grep -Eo 'sketch:[[:space:]]*(true|false)' "$preset" | head -1 | sed -E 's/.*:[[:space:]]*//')"
  chips="<span>theme $theme</span><span>${layout:-dagre}</span><span>${font:-default}</span>"
  [ "$sketchy" = true ] && chips="$chips<span>sketch</span>"
  star=""; classes=""
  if [ "${theme:-0}" -ge 200 ] && [ "${theme:-0}" -lt 300 ]; then classes="$classes dark"; fi
  cat "$preset" "$sample" > "$out/$fname.d2"
  if ! bash "$PLUGIN_ROOT/scripts/render.sh" "$out/$fname.d2" --format svg --style "$preset" --out "$out/$fname.svg" >/dev/null; then
    echo "error: failed to render theme $name" >&2
    exit 1
  fi
  esc_caption="$(printf '%s' "$caption" | html_escape)"
  cards="$cards
<figure class=\"$classes\">
  <div class=\"head\"><span class=\"num\">$n</span><span class=\"name\">$name</span>${star:+<span class=\"star\">★ recommended</span>}</div>
  <div class=\"caption\">$esc_caption</div>
  <div class=\"meta\">$chips</div>
  <div class=\"img\"><a href=\"$fname.svg\" target=\"_blank\" rel=\"noopener\"><img src=\"$fname.svg\" alt=\"$name\" loading=\"lazy\"></a></div>
</figure>"
  listing="$listing
$n. $name$star — $caption"
done

template="$(cat "$PLUGIN_ROOT/assets/contact-sheet.html")"
html="${template//\{\{TITLE\}\}/D2 colour themes}"
html="${html//\{\{CARDS\}\}/$cards}"
html="${html//\{\{FOOTER\}\}/Switch any time with /d2 style NAME. Themes are plain D2 files under assets/themes: edit the colours to taste.}"
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
exit 0

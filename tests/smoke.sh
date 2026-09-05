#!/usr/bin/env bash
# smoke.sh — end-to-end check of the plugin's scripts, presets and fonts.
#
# Usage: tests/smoke.sh [--png]
#   --png  also renders a PNG, which needs d2's Chromium (downloaded once with consent).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/d2-smoke.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
want_png=0; [ "${1:-}" = "--png" ] && want_png=1
fails=0
ok()   { echo "ok    $*"; }
fail() { echo "FAIL  $*"; fails=$((fails + 1)); }
render="$ROOT/scripts/render.sh"

command -v d2 >/dev/null 2>&1 || { echo "d2 is not installed (brew install d2)"; exit 3; }
ok "d2 $(d2 --version 2>/dev/null | head -1)"

# 1. contact sheet: nine numbered presets rendered to SVG plus index.html
if bash "$ROOT/scripts/preview.sh" --out "$tmp/preview" --no-open >"$tmp/preview.log" 2>&1; then
  n="$(ls "$tmp"/preview/0[1-9]-*.svg 2>/dev/null | wc -l | tr -d ' ')"
  [ "$n" = 9 ] && ok "preview renders 9 preset SVGs" || fail "preview rendered $n SVGs, expected 9"
  [ "$(grep -c '<figure' "$tmp/preview/index.html")" = 9 ] && ok "contact sheet has 9 cards" || fail "contact sheet card count"
  grep -q '^SHEET: ' "$tmp/preview.log" && grep -q '^3\. blueprint' "$tmp/preview.log" && ok "preview prints the numbered list" || fail "preview listing"
else
  fail "preview.sh failed: $(tail -3 "$tmp/preview.log")"
fi

# 2. every preset (numbered and extras) compiles with the sample diagram
for p in "$ROOT"/assets/presets/*.d2; do
  name="$(basename "$p" .d2)"
  cat "$p" "$ROOT/assets/sample.d2" > "$tmp/$name.d2"
  if d2 validate "$tmp/$name.d2" >/dev/null 2>"$tmp/$name.err"; then ok "preset $name validates"; else fail "preset $name: $(head -1 "$tmp/$name.err")"; fi
done

# 3. fonts: the flags are built and d2 reports loading the bundled files
for pair in "03-blueprint:inter:Inter-Regular.ttf" "07-mono:plex-mono:IBMPlexMono-Regular.ttf" "06-earth:lora:Lora-Regular.ttf"; do
  IFS=: read -r name font file <<< "$pair"
  dry="$(bash "$render" "$tmp/$name.d2" --format svg --style "$ROOT/assets/presets/$name.d2" --dry-run 2>&1)"
  printf '%s' "$dry" | grep -q -- "--font-regular .*$file" && ok "$name builds --font-regular $file" || fail "$name font flags: $dry"
  log="$(bash "$render" "$tmp/$name.d2" --format svg --style "$ROOT/assets/presets/$name.d2" --out "$tmp/$name.svg" 2>&1)"
  printf '%s' "$log" | grep -Eq "FONT: $font \((4|8) font files loaded" && ok "$name: d2 loaded the $font files" || fail "$name font load: $log"
done
if [ -f "$tmp/preview/01-clean.svg" ] && [ -f "$tmp/03-blueprint.svg" ]; then
  a="$(grep -o 'base64,[A-Za-z0-9+/=]\{0,80\}' "$tmp/preview/01-clean.svg" | head -1)"
  b="$(grep -o 'base64,[A-Za-z0-9+/=]\{0,80\}' "$tmp/03-blueprint.svg" | head -1)"
  [ -n "$a" ] && [ "$a" != "$b" ] && ok "embedded font differs from the default" || fail "embedded font identical to default"
fi

# 4. project flow: _style.d2 next to a diagram that imports it, plus preflight resolution
proj="$tmp/proj"; mkdir -p "$proj/docs/diagrams" "$proj/other"
proj="$(cd "$proj" && pwd -P)"   # preflight prints physical paths (/private/var on macOS)
( cd "$proj" && git init -q . )
cp "$ROOT/assets/presets/03-blueprint.d2" "$proj/docs/diagrams/_style.d2"
{ echo '...@_style'; echo; cat "$ROOT/assets/sample.d2"; } > "$proj/docs/diagrams/flow.d2"
( cd "$proj" && d2 fmt docs/diagrams/flow.d2 && d2 validate docs/diagrams/flow.d2 ) >/dev/null 2>&1 && ok "diagram importing _style.d2 formats and validates" || fail "import flow validate"
log="$(cd "$proj" && bash "$render" docs/diagrams/flow.d2 --format svg 2>&1)"
[ -f "$proj/docs/diagrams/flow.svg" ] && ok "render.sh resolves the imported style and writes flow.svg" || fail "import render: $log"
printf '%s' "$log" | grep -q 'FONT: inter' && ok "font taken from the imported style" || fail "font from import: $log"
pre="$(cd "$proj/other" && bash "$ROOT/scripts/preflight.sh")"
printf '%s' "$pre" | grep -q "PROJECT_STYLE: $proj/docs/diagrams/_style.d2" && ok "preflight finds the project style from a subdirectory" || fail "preflight project style: $pre"
printf '%s' "$pre" | grep -q "DIAGRAMS_DIR: $proj/docs/diagrams" && ok "preflight diagrams dir" || fail "preflight diagrams dir: $pre"
printf '%s' "$pre" | grep -q 'AUTO: on' && ok "preflight AUTO on by default" || fail "preflight AUTO: $pre"
mkdir -p "$proj/.claude" && printf '{"skillOverrides": {"d2:diagram": "user-invocable-only"}}\n' > "$proj/.claude/settings.local.json"
pre="$(cd "$proj" && bash "$ROOT/scripts/preflight.sh")"
printf '%s' "$pre" | grep -q 'AUTO: off (' && ok "preflight AUTO off via skillOverrides" || fail "preflight AUTO off: $pre"
pre="$(cd "$tmp" && bash "$ROOT/scripts/preflight.sh")"
printf '%s' "$pre" | grep -q 'PROJECT_ROOT: none' && ok "preflight outside a repo" || fail "preflight outside repo: $pre"
pre="$(cd "$proj" && D2_THEME=6 bash "$ROOT/scripts/preflight.sh")"
printf '%s' "$pre" | grep -q 'ENV_OVERRIDE: D2_THEME=6' && ok "preflight reports D2_* overrides" || fail "preflight env: $pre"

# 5. animation rules
{ echo '...@_style'; echo 'a -> b'; echo 'steps: {'; echo '  1: { a -> b }'; echo '  2: { b -> c }'; echo '}'; } > "$proj/docs/diagrams/walk.d2"
dry="$(cd "$proj" && bash "$render" docs/diagrams/walk.d2 --format gif --dry-run 2>&1)"
printf '%s' "$dry" | grep -q -- '--animate-interval 1200' && printf '%s' "$dry" | grep -q 'walk.gif' && ok "steps + gif adds --animate-interval" || fail "gif dry-run: $dry"
dry="$(cd "$proj" && bash "$render" docs/diagrams/walk.d2 --format animated-svg --dry-run 2>&1)"
printf '%s' "$dry" | grep -q 'walk-animated.svg' && ok "animated svg gets the -animated suffix" || fail "animated svg: $dry"
dry="$(cd "$proj" && bash "$render" docs/diagrams/walk.d2 --format png --dry-run 2>&1)"
printf '%s' "$dry" | grep -q -- "--target ''" && ok "static render of a multi-board file targets the root board" || fail "multiboard static: $dry"
dry="$(cd "$proj" && bash "$render" docs/diagrams/flow.d2 --format gif --dry-run 2>&1)"
printf '%s' "$dry" | grep -q 'NOTE: .*single board' && printf '%s' "$dry" | grep -q 'flow.png' && ok "gif on a single board falls back to png with a note" || fail "single-board gif: $dry"
( cd "$proj" && bash "$render" docs/diagrams/walk.d2 --format animated-svg >/dev/null 2>&1 ) && [ -f "$proj/docs/diagrams/walk-animated.svg" ] && ok "animated svg renders" || fail "animated svg render"
dry="$(cd "$proj" && D2_THEME=6 bash "$render" docs/diagrams/flow.d2 --format svg --dry-run 2>&1)"
printf '%s' "$dry" | grep -q 'NOTE: ignoring D2_THEME' && ok "render.sh scrubs D2_* variables" || fail "env scrub: $dry"
dry="$(cd "$proj" && bash "$render" docs/diagrams/flow.d2 --dry-run 2>&1)"
printf '%s' "$dry" | grep -q 'flow.png' && ok "default format comes from the style (png)" || fail "default format: $dry"

# 6. optional: PNG export (needs Chromium; --accept-chromium is the explicit consent)
if [ "$want_png" = 1 ]; then
  log="$(cd "$proj" && bash "$render" docs/diagrams/flow.d2 --format png --accept-chromium 2>&1)"
  if [ -f "$proj/docs/diagrams/flow.png" ] && [ "$(head -c 8 "$proj/docs/diagrams/flow.png" | xxd -p)" = "89504e470d0a1a0a" ]; then ok "png export"; else fail "png export: $log"; fi
fi

# 7. plugin manifest
if command -v claude >/dev/null 2>&1; then
  ( cd "$ROOT" && claude plugin validate ./ --strict >/dev/null 2>&1 ) && ok "claude plugin validate --strict" || fail "claude plugin validate"
fi

echo
if [ "$fails" = 0 ]; then echo "all checks passed"; else echo "$fails check(s) failed"; exit 1; fi

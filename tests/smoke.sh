#!/usr/bin/env bash
# smoke.sh — end-to-end check of the skill's scripts and themes.
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

# 1. contact sheet: six themes rendered to SVG plus index.html
if bash "$ROOT/scripts/preview.sh" --out "$tmp/preview" --no-open >"$tmp/preview.log" 2>&1; then
  n="$(ls "$tmp"/preview/0[1-9]-*.svg 2>/dev/null | wc -l | tr -d ' ')"
  [ "$n" = 6 ] && ok "preview renders 6 theme SVGs" || fail "preview rendered $n SVGs, expected 6"
  [ "$(grep -c '<figure' "$tmp/preview/index.html")" = 6 ] && ok "contact sheet has 6 cards" || fail "contact sheet card count"
  grep -q '^SHEET: ' "$tmp/preview.log" && grep -q '^3\. sunset' "$tmp/preview.log" && ok "preview prints the numbered list" || fail "preview listing: $(cat "$tmp/preview.log")"
else
  fail "preview.sh failed: $(tail -3 "$tmp/preview.log")"
fi

# 2. every theme renders the sample and every d2 shape (validate alone misses illegal style keys)
for t in "$ROOT"/assets/themes/*.d2; do
  name="$(basename "$t" .d2)"
  cat "$t" "$ROOT/assets/sample.d2" > "$tmp/$name.d2"
  if d2 "$tmp/$name.d2" "$tmp/$name.svg" >/dev/null 2>"$tmp/$name.err"; then ok "theme $name renders the sample"; else fail "theme $name: $(grep -m1 err "$tmp/$name.err")"; fi
  bg="$(grep -Eo 'style\.fill: "#[0-9a-f]{6}"' "$t" | grep -Eo '#[0-9a-f]{6}')"
  grep -qi "fill=\"$bg\"" "$tmp/$name.svg" && ok "theme $name paints its paper colour" || fail "theme $name paper colour $bg missing"
  cat "$t" "$ROOT/tests/fixtures/shapes.d2" > "$tmp/$name.shapes.d2"
  if err="$(d2 --target '' "$tmp/$name.shapes.d2" - 2>&1 >/dev/null | grep -E '^err:' | head -1)"; [ -z "$err" ]; then
    ok "theme $name renders every shape"
  else
    fail "theme $name on shapes.d2: $err"
  fi
  grep -q '^\*\*\*' "$t" && ok "theme $name has house rules" || fail "theme $name has no *** rules"
done

# 3. project flow: _style.d2 next to a diagram that imports it, plus preflight resolution
proj="$tmp/proj"; mkdir -p "$proj/docs/diagrams" "$proj/other"
proj="$(cd "$proj" && pwd -P)"   # preflight prints physical paths (/private/var on macOS)
( cd "$proj" && git init -q . )
cp "$ROOT/assets/themes/03-sunset.d2" "$proj/docs/diagrams/_style.d2"
{ echo '...@_style'; echo; cat "$ROOT/assets/sample.d2"; } > "$proj/docs/diagrams/flow.d2"
( cd "$proj" && d2 fmt docs/diagrams/flow.d2 && d2 validate docs/diagrams/flow.d2 ) >/dev/null 2>&1 && ok "diagram importing _style.d2 formats and validates" || fail "import flow validate"
log="$(cd "$proj" && bash "$render" docs/diagrams/flow.d2 --format svg 2>&1)"
[ -f "$proj/docs/diagrams/flow.svg" ] && ok "render.sh writes flow.svg" || fail "import render: $log"
grep -q 'fill="#fbf4e6"' "$proj/docs/diagrams/flow.svg" && ok "theme colours survive ...@_style" || fail "sunset paper colour not found after import"
{ echo '...@_style'; echo; echo 'grp: Group {inner}'; } > "$proj/docs/diagrams/glob.d2"
( cd "$proj" && bash "$render" docs/diagrams/glob.d2 --format svg ) >/dev/null 2>&1
grep -q 'font-size:20px' "$proj/docs/diagrams/glob.svg" 2>/dev/null && ok "*** house rules survive ...@_style" || fail "*** globs lost across the import"
pre="$(cd "$proj/other" && bash "$ROOT/scripts/preflight.sh")"
printf '%s' "$pre" | grep -q "PROJECT_STYLE: $proj/docs/diagrams/_style.d2" && ok "preflight finds the project style from a subdirectory" || fail "preflight project style: $pre"
printf '%s' "$pre" | grep -q "DIAGRAMS_DIR: $proj/docs/diagrams" && ok "preflight diagrams dir" || fail "preflight diagrams dir: $pre"
pre="$(cd "$tmp" && bash "$ROOT/scripts/preflight.sh")"
printf '%s' "$pre" | grep -q 'PROJECT_ROOT: none' && ok "preflight outside a repo" || fail "preflight outside repo: $pre"
pre="$(cd "$proj" && D2_THEME=6 bash "$ROOT/scripts/preflight.sh")"
printf '%s' "$pre" | grep -q 'ENV_OVERRIDE: D2_THEME=6' && ok "preflight reports D2_* overrides" || fail "preflight env: $pre"

# 4. render rules
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

# 5. optional: PNG export (needs Chromium; --accept-chromium is the explicit consent)
if [ "$want_png" = 1 ]; then
  log="$(cd "$proj" && bash "$render" docs/diagrams/flow.d2 --format png --accept-chromium 2>&1)"
  if [ -f "$proj/docs/diagrams/flow.png" ] && [ "$(head -c 8 "$proj/docs/diagrams/flow.png" | xxd -p)" = "89504e470d0a1a0a" ]; then ok "png export"; else fail "png export: $log"; fi
fi

echo
if [ "$fails" = 0 ]; then echo "all checks passed"; else echo "$fails check(s) failed"; exit 1; fi

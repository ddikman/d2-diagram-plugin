#!/usr/bin/env bash
# render.sh — render a .d2 file the way the d2 skill expects.
#
# Usage: render.sh FILE.d2 [--format png|svg|gif|animated-svg|animated|pdf|pptx] [--out PATH]
#                  [--scale N] [--interval MS] [--target BOARD] [--all-boards] [--timeout SECONDS]
#                  [--style PATH] [--accept-chromium] [--dry-run]
#
# Theme, layout, sketch mode and padding live in the .d2 files themselves (each diagram imports a
# shared _style.d2), so plain `d2 file.d2` already reproduces them. This wrapper only adds what
# cannot live in the file: the animation interval for multi-board diagrams, sensible output names,
# and protection against stray D2_* environment variables, which would silently override the
# in-file style. It also turns d2's interactive Chromium prompt into an explicit consent step.
#
# Prints "OUT: <path>" on success. Exit codes: 0 ok, 1 d2 failed, 2 usage or config error,
# 3 d2 missing, 4 Chromium download needed (re-run with --accept-chromium after the user agrees).
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

file=""; format=""; out=""; scale=""; interval=""; target=""; target_set=0; all_boards=0
timeout_s=""; style=""; accept=0; dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --format) format="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    --scale) scale="$2"; shift 2 ;;
    --interval) interval="$2"; shift 2 ;;
    --target) target="$2"; target_set=1; shift 2 ;;
    --all-boards) all_boards=1; shift ;;
    --timeout) timeout_s="$2"; shift 2 ;;
    --style) style="$2"; shift 2 ;;
    --accept-chromium) accept=1; shift ;;
    --dry-run) dry=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "error: unknown option $1" >&2; usage >&2; exit 2 ;;
    *) if [ -z "$file" ]; then file="$1"; else echo "error: unexpected argument: $1" >&2; exit 2; fi; shift ;;
  esac
done

if ! command -v d2 >/dev/null 2>&1; then
  echo "error: d2 is not installed. Install it with: brew install d2  (or: curl -fsSL https://d2lang.com/install.sh | sh -s --)" >&2
  exit 3
fi
[ -n "$file" ] || { usage >&2; exit 2; }
[ -f "$file" ] || { echo "error: no such file: $file" >&2; exit 2; }
file_abs="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
dir="$(dirname "$file_abs")"; base="$(basename "$file_abs")"; stem="${base%.d2}"

# --- which style file applies: --style, else the ...@name import at the top of the diagram ----
if [ -z "$style" ]; then
  imp="$(grep -m1 -E '^\.\.\.@' "$file_abs" | sed -E 's/^\.\.\.@//; s/[[:space:]]+$//; s/^"//; s/"$//')"
  if [ -n "$imp" ]; then
    case "$imp" in *.d2) ;; *) imp="$imp.d2" ;; esac
    case "$imp" in /*) style="$imp" ;; *) style="$dir/$imp" ;; esac
  fi
fi
if [ -n "$style" ] && [ ! -f "$style" ]; then
  echo "error: style file not found: $style (the diagram imports it; create it with /d2 style)" >&2
  exit 2
fi

# --- read plugin settings from the data: {...} map of a file (single- or multi-line) ---------
data_block() {
  awk '/(^|[[:space:]])data:[[:space:]]*\{/ { inb = 1 } inb { print; if ($0 ~ /\}/) inb = 0 }' "$1" 2>/dev/null
}
data_get() {  # data_get KEY FILE... (later files override earlier ones)
  local key="$1" v="" f m; shift
  for f in "$@"; do
    [ -f "$f" ] || continue
    m="$(data_block "$f" | grep -Eo "(^|[{;[:space:]])$key:[[:space:]]*[^;}[:space:]]+" | tail -1 | sed -E "s/.*$key:[[:space:]]*//")"
    [ -n "$m" ] && v="$m"
  done
  printf '%s' "$v"
}

[ -n "$format" ] || format="$(data_get default-format "$style" "$file_abs")"
[ -n "$format" ] || format="png"
animated_fmt="$(data_get animated-format "$style" "$file_abs")"; [ -n "$animated_fmt" ] || animated_fmt="gif"
[ -n "$interval" ] || interval="$(data_get animate-interval "$style" "$file_abs")"
[ -n "$interval" ] || interval=1200

case "$format" in
  animated) if [ "$animated_fmt" = "svg" ]; then format="animated-svg"; else format="gif"; fi ;;
  animated-svg|gif|png|svg|pdf|pptx) ;;
  *) echo "error: unknown format '$format' (use png, svg, gif, animated-svg, animated, pdf or pptx)" >&2; exit 2 ;;
esac

# --- shell variables that would override the in-file style ---------------------------------
for v in D2_THEME D2_DARK_THEME D2_SKETCH D2_LAYOUT D2_PAD D2_CENTER D2_ANIMATE_INTERVAL; do
  if [ -n "${!v:-}" ]; then echo "NOTE: ignoring $v=${!v} from your shell (the style file wins)"; unset "$v"; fi
done

# --- boards: animation needs steps/scenarios/layers; static output of those is one board -----
multiboard=0
grep -Eq '^[[:space:]]*(steps|scenarios|layers)[[:space:]]*:' "$file_abs" && multiboard=1
animated=0
case "$format" in gif|animated-svg) animated=1 ;; esac
if [ "$animated" = 1 ] && [ "$multiboard" = 0 ]; then
  echo "NOTE: $base has a single board (no steps:, scenarios: or layers:), so there is nothing to animate; rendering a static image instead. Add steps: for a walkthrough."
  if [ "$format" = "gif" ]; then format="png"; else format="svg"; fi
  animated=0
fi

if [ -z "$out" ]; then
  case "$format" in
    animated-svg) out="$dir/$stem-animated.svg" ;;
    *) out="$dir/$stem.$format" ;;
  esac
fi
mkdir -p "$(dirname "$out")"

args=()
[ "$animated" = 1 ] && args+=(--animate-interval "$interval")
if [ "$animated" = 0 ] && [ "$multiboard" = 1 ] && [ "$target_set" = 0 ] && [ "$all_boards" = 0 ]; then
  target=""; target_set=1
  echo "NOTE: $base has several boards; rendering the root board only. Use --target steps.NAME for one board, --all-boards for every board, or --format gif for an animation."
fi
[ "$target_set" = 1 ] && args+=(--target "$target")
[ -n "$scale" ] && args+=(--scale "$scale")
[ -n "$timeout_s" ] && args+=(--timeout "$timeout_s")

cmd=(d2 ${args[@]+"${args[@]}"} "$file_abs" "$out")
if [ "$dry" = 1 ]; then
  printf 'CMD:'; printf ' %q' "${cmd[@]}"; printf '\n'
  echo "OUT: $out"
  exit 0
fi

# d2 prints its Chromium prompt on stdout and reads the answer from stdin; with stdin closed it
# fails with "failed to read user input". Capture both streams so either message is recognised.
logf="$(mktemp "${TMPDIR:-/tmp}/d2-render.XXXXXX")"
"${cmd[@]}" </dev/null >"$logf" 2>&1; rc=$?
if [ "$rc" -ne 0 ] && grep -Eq 'install Chromium|failed to read user input' "$logf"; then
  if [ "$accept" = 1 ]; then
    echo "NOTE: d2 is downloading Chromium for PNG/GIF export (one-time, about 150 MB)..."
    CI=1 "${cmd[@]}" </dev/null >"$logf" 2>&1; rc=$?
  else
    echo "CHROMIUM: consent needed. d2 must download Chromium (about 150 MB, one-time) to render $format. Re-run with --accept-chromium once the user agrees, or use --format svg."
    rm -f "$logf"
    exit 4
  fi
fi
if [ "$rc" -ne 0 ]; then
  cat "$logf" >&2
  rm -f "$logf"
  echo "error: d2 exited with status $rc" >&2
  exit 1
fi
grep -Ei 'warn' "$logf" | sed 's/^/d2: /' >&2
rm -f "$logf"
if [ -d "$out" ]; then
  echo "OUT_DIR: $out"
  ls "$out" | sed "s|^|OUT: $out/|"
else
  echo "OUT: $out"
fi
exit 0

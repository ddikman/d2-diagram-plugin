#!/usr/bin/env bash
# preflight.sh — environment probe for the d2 plugin skills.
#
# Prints a small fixed contract (one KEY: value per line) that the skills read before doing
# anything: whether d2 exists, which style file applies (project first, personal second), where
# diagrams live, whether auto-invocation was switched off for this workspace, and anything in
# the shell environment that would silently override the in-file style.
#
# This script is run from a skill's dynamic-context line, where a non-zero exit aborts the whole
# skill invocation. It therefore never fails: every probe is best-effort and the script always
# exits 0.
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
cwd="$(pwd -P 2>/dev/null || pwd)"

# --- d2 ---------------------------------------------------------------------------------------
if command -v d2 >/dev/null 2>&1; then
  ver="$(d2 --version 2>/dev/null | head -1)"
  echo "D2: ${ver:-unknown} ($(command -v d2))"
else
  echo "D2: missing"
fi

# --- project root: nearest ancestor containing .git (a directory, or a file in worktrees) ----
root=""
d="$cwd"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  if [ -e "$d/.git" ]; then root="$d"; break; fi
  d="$(dirname "$d")"
done
echo "PROJECT_ROOT: ${root:-none}"

# --- project style: nearest _style.d2 (ancestors of cwd first, then shallowest in the repo) --
project_style=""
d="$cwd"
while [ -n "$d" ]; do
  if [ -f "$d/_style.d2" ]; then project_style="$d/_style.d2"; break; fi
  [ "$d" = "${root:-/}" ] && break
  [ "$d" = "/" ] && break
  d="$(dirname "$d")"
done
if [ -z "$project_style" ] && [ -n "$root" ]; then
  project_style="$(find "$root" -name _style.d2 -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/vendor/*' 2>/dev/null | awk '{ print length($0) "\t" $0 }' | sort -n | head -1 | cut -f2-)"
fi
echo "PROJECT_STYLE: ${project_style:-none}"

# --- personal style ---------------------------------------------------------------------------
personal_style="${XDG_CONFIG_HOME:-$HOME/.config}/d2-diagram/_style.d2"
if [ -f "$personal_style" ]; then
  echo "PERSONAL_STYLE: $personal_style"
else
  echo "PERSONAL_STYLE: none (would be $personal_style)"
fi

# --- diagrams directory -----------------------------------------------------------------------
if [ -n "$project_style" ]; then
  diagrams_dir="$(dirname "$project_style")"
elif [ -n "$root" ] && [ -d "$root/docs" ]; then
  diagrams_dir="$root/docs/diagrams"
elif [ -n "$root" ]; then
  diagrams_dir="$root/diagrams"
elif [ -d "$cwd/docs" ]; then
  diagrams_dir="$cwd/docs/diagrams"
else
  diagrams_dir="$cwd/diagrams"
fi
echo "DIAGRAMS_DIR: $diagrams_dir"
count=0
if [ -d "$diagrams_dir" ]; then
  count="$(ls "$diagrams_dir"/*.d2 2>/dev/null | grep -v '/_[^/]*\.d2$' | wc -l | tr -d ' ')"
fi
echo "EXISTING_DIAGRAMS: $count"

# --- auto-invocation switch (skillOverrides for d2:diagram) -----------------------------------
auto="on"
auto_src=""
for f in "${root:-$cwd}/.claude/settings.local.json" "${root:-$cwd}/.claude/settings.json" "$HOME/.claude/settings.json"; do
  [ -f "$f" ] || continue
  if command -v jq >/dev/null 2>&1; then
    v="$(jq -r '.skillOverrides["d2:diagram"] // empty' "$f" 2>/dev/null)"
  else
    v="$(grep -Eo '"d2:diagram"[[:space:]]*:[[:space:]]*"[a-z-]+"' "$f" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*"([a-z-]+)"/\1/')"
  fi
  case "$v" in
    off|user-invocable-only|name-only) auto="off"; auto_src="$f"; break;;
  esac
done
if [ "$auto" = "off" ]; then echo "AUTO: off ($auto_src)"; else echo "AUTO: on"; fi

# --- shell overrides that beat in-file config -------------------------------------------------
overrides="$(env 2>/dev/null | grep -E '^D2_(THEME|DARK_THEME|SKETCH|LAYOUT|PAD|CENTER|ANIMATE_INTERVAL|FONT_[A-Z_]+)=' | tr '\n' ' ')"
echo "ENV_OVERRIDE: ${overrides:-none}"

# --- host hints -------------------------------------------------------------------------------
if env 2>/dev/null | grep -q "^CONDUCTOR_"; then
  echo "CONDUCTOR: true"
else
  echo "CONDUCTOR: false"
fi
if [ -n "${SSH_CONNECTION:-}" ] && [ -z "${DISPLAY:-}" ] && [ "$(uname -s 2>/dev/null)" != "Darwin" ]; then
  echo "HEADLESS: likely"
else
  echo "HEADLESS: no"
fi
# Best-effort: CI markers mean nobody can answer a question; anything else counts as interactive.
if [ -n "${CI:-}${GITHUB_ACTIONS:-}${GSTACK_HEADLESS:-}" ] && ! env 2>/dev/null | grep -q "^CONDUCTOR_"; then
  echo "SESSION: headless"
else
  echo "SESSION: interactive"
fi
echo "PLUGIN_ROOT: $PLUGIN_ROOT"
exit 0

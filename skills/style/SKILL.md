---
name: style
description: >-
  Choose or change the visual style used for D2 diagrams by /d2:diagram: preview nine presets
  (clean, sketch, blueprint, flagship, vivid-sketch, earth, mono, dark, colorblind) on a contact
  sheet and save one as the project's or the user's personal default; switch theme, sketch mode,
  layout engine, font, padding or default output format; adopt the style in existing .d2 files;
  turn automatic D2 use on or off for this workspace; check the d2 setup. Use when the user wants
  to pick, preview, change, reset or inspect the diagram style, says diagrams should look
  different, or asks Claude to stop or start using D2 automatically.
argument-hint: "[pick | set <preset> | show | tweak <key> <value> | adopt | auto on|off | doctor | reset] [--project|--personal|--global]"
allowed-tools:
  - Bash(d2 *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# D2 style

The style is a small D2 file, `_style.d2`, that every diagram imports on its first line. It holds
`vars: {d2-config: {...}}` with the theme, sketch flag, layout engine, padding and, under `data`,
the plugin's own settings (font and output formats), followed by a **house style**: a handful of
`***` glob rules (rounding, shadows, stroke weight, label size) that give the preset its look and
reach every diagram importing the file. Two copies can exist:

- project: `<diagrams dir>/_style.d2`, committed with the diagrams, wins when present;
- personal: `${XDG_CONFIG_HOME:-$HOME/.config}/d2-diagram/_style.d2`, the default for repos
  that have none yet (it is copied into the repo on first use there).

## Current setup

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"`

## Presets

!`for f in "${CLAUDE_PLUGIN_ROOT}"/assets/presets/*.d2; do printf '%s: ' "$(basename "$f" .d2)"; head -1 "$f" | sed 's/^# d2-diagram preset: [^ ]* *— *//'; done`

Numbered files (`01-clean` ... `09-colorblind`) are the nine shown on the contact sheet; the rest
are reachable by name. What each key in the file means, and how to write your own variations:
`references/style-config.md`.

## House style

Each preset ends with a block of glob rules. They must be **triple** globs (`***`): d2 does not
carry single (`*`) or double (`**`) globs across an import, so those would stay behind in
`_style.d2` and never reach the diagram. Filters: `&leaf: true` targets leaf shapes, `&leaf: false`
containers; `sql_table` and `class` shapes match neither and pick up only the unfiltered rules.

Safe keys: `border-radius` (0-20), `shadow`, `stroke-width` (1-15), `font-size` (8-100),
`fill-pattern` (`dots`/`lines`/`grain`), `bold`, `italic`, `underline`, `text-transform`,
`opacity`, `stroke-dash`, `multiple`, `font`, `fill`, `stroke`.

**Never put `style.3d` or `style.double-border` behind a glob.** d2 rejects them for cylinders,
people, queues, tables and markdown blocks, so the whole diagram stops compiling as soon as one
appears. `d2 validate` reports such a file as valid — only a render catches it, which is why the
checks below render instead of validating.

## Modes

Work out the mode from `$ARGUMENTS` or the request. Scope defaults to `--project` inside a git
repo and `--personal` outside one; `--global` only matters for `auto`.

### pick (no arguments, or "choose", "preview", "show me the styles")

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/preview.sh"`. It renders the sample in the nine
   numbered presets, opens `index.html` in the browser and prints `SHEET: <path>` and the list.
   The default sample is a service architecture. If the user mostly draws something else, add
   `--sample <name>`: `pipeline` (linear flow with a decision), `sequence` (sequence diagram) or
   `data-model` (related SQL tables) ship with the plugin, and `--sample path/to/their.d2` works
   for a diagram they already have, as long as it has no `...@_style` line of its own. Offer this
   when the first sheet does not look like their kind of diagram.
2. Show the numbered list in prose, mention that the sheet is open (or give the path when it
   printed `OPEN: failed`), and ask for a number or name plus the scope: "project" (this repo),
   "personal" (default everywhere) or "both". Never use AskUserQuestion here: nine options exceed
   its limit and Conductor blocks it. Stop and wait.
3. Apply the answer with `set` below.

### set <preset> [--project|--personal|--both]

Copy the preset to the target path(s), creating directories:

```bash
mkdir -p "<DIAGRAMS_DIR>" && cp "${CLAUDE_PLUGIN_ROOT}/assets/presets/<file>.d2" "<DIAGRAMS_DIR>/_style.d2"
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/d2-diagram" && cp "${CLAUDE_PLUGIN_ROOT}/assets/presets/<file>.d2" "${XDG_CONFIG_HOME:-$HOME/.config}/d2-diagram/_style.d2"
```

A number maps to the numbered file (`3` → `03-blueprint.d2`); a name maps to `<name>.d2` with or
without its number. Check the result by **rendering** it with the sample, not with `d2 validate`
(which accepts style keys that then fail to compile — see House style above):

```bash
cat "<target>/_style.d2" "${CLAUDE_PLUGIN_ROOT}/assets/sample.d2" > /tmp/d2-style-check.d2 \
  && bash "${CLAUDE_PLUGIN_ROOT}/scripts/render.sh" /tmp/d2-style-check.d2 --format svg --out /tmp/d2-style-check.svg
```
Confirm the path in one line. If `EXISTING_DIAGRAMS` is non-zero, offer to re-render them (see
below); when the project already had a different style, the change affects every diagram that
imports it, which is the point.

### show

Print the resolved style file (project, else personal) with its path and say which one applies.
When `data.font` names a bundled font, also print the lines a CI job or teammate without the
plugin would need to get the same font:

```bash
export D2_FONT_REGULAR="${CLAUDE_PLUGIN_ROOT}/assets/fonts/<family>/<Name>-Regular.ttf"
export D2_FONT_BOLD=...   # Bold, Italic, SemiBold likewise
```

### tweak <key> <value>

Edit the resolved style file in place with Edit. Accepted keys: `theme-id` (see the theme table in
`references/style-config.md`), `dark-theme-id`, `sketch` (`true`/`false`), `layout-engine`
(`dagre`/`elk`), `pad`, `center`, and inside `data`: `font` (`default`, `inter`, `plex-mono`,
`lora`, or a directory of TTFs), `default-format` (`png`/`svg`), `animated-format`
(`gif`/`svg`), `animate-interval` (ms). Colour overrides go under `theme-overrides` (keys and
roles in the reference).

House-style keys edit the `***` lines instead of `vars`: `border-radius` (0-20, `0` for square),
`shadow` (`true`/`false`, on the `&leaf: true` line), `font-size`, `stroke-width`, `edge-width` and
`edge-font-size` (the `(*** -> ***)[*]` lines), `fill-pattern`, `bold`, `italic`, `text-transform`,
and `container-dash` (`0` for solid, on the `&leaf: false` line). `tweak look off` deletes the whole
house block and leaves the `vars` block, which restores plain theme output. Refuse `3d` and
`double-border` with one line saying why (they break every diagram containing a cylinder, person,
queue, table or markdown block).

Keep the first comment line, updating the preset name to `custom` when the result no longer matches
a preset. Check as in `set` — render, do not validate — then offer to re-render the diagrams.

### adopt

For `.d2` files in `DIAGRAMS_DIR` that neither start with `...@_style` nor define their own
`vars: {d2-config: ...}`, insert `...@_style` plus a blank line at the top, `d2 validate` each,
and re-render. Only on request; list the files first when there are more than a few.

### auto on | off [--project|--global]

Controls whether Claude may start `/d2:diagram` on its own in this workspace. Claude Code reads
`skillOverrides` from its settings; `user-invocable-only` keeps the slash command working while
stopping automatic use. Default target is `.claude/settings.local.json` (this checkout only, not
committed); `--project` uses `.claude/settings.json`; `--global` uses `~/.claude/settings.json`.
Read the file if it exists, merge the key, write it back with 2-space indentation:

```json
{
  "skillOverrides": {
    "d2:diagram": "user-invocable-only"
  }
}
```

`auto on` removes the `d2:diagram` entry (and an empty `skillOverrides`). Tell the user the switch
takes effect for new prompts, that `/d2:diagram` still works when typed, and that preflight also
honours the setting, so the skill stops itself even if the host ignores plugin keys.

### doctor

Print the preflight block, `d2 layout` (available engines) and `d2 themes` on request. If the
resolved style file has no `***` lines it was written by an older version of the plugin and has no
house style — mention that `/d2:style reset` refreshes it. If the user wants to check raster
output, render the sample to PNG with
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/render.sh" /tmp/d2-style-check.d2 --format png --style "<style>"`
after asking about the Chromium download when it returns exit 4.

### reset

`set` the preset named in the style file's first comment line (or `clean`), overwriting the file.

## Re-rendering after a change

```bash
for f in "<DIAGRAMS_DIR>"/*.d2; do case "$f" in */_*) ;; *) bash "${CLAUDE_PLUGIN_ROOT}/scripts/render.sh" "$f";; esac; done
```

Count the files first and ask in prose before re-rendering more than a handful; PNG output may
need the one-time Chromium download (exit 4 → ask, then `--accept-chromium`).

---
name: d2
description: >-
  Draw diagrams with D2 (d2lang) in my vivid sketch style: architecture, system and service
  diagrams, request and data flows, sequence diagrams, ER/SQL schemas, state machines, C4, and any
  picture for a README, design doc, PR or slide. Writes a .d2 source next to a rendered PNG
  (default), SVG or animated GIF, styled by a shared _style.d2 chosen from six colour themes.
  Use whenever I ask to diagram, draw, sketch, visualise or map out a system, flow, process,
  pipeline or architecture, mention D2 or a .d2 file, or want to switch the diagram colour theme.
argument-hint: "[what to draw | path/to/file.d2] [as svg|animated] | style [theme]"
allowed-tools:
  - Bash(d2 *)
  - Bash(bash ${CLAUDE_SKILL_DIR}/scripts/*)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# D2 diagrams, vivid sketch style

A request becomes a `.d2` source file plus a rendered image. Every diagram imports a small style
file, `_style.d2`, on its first line: theme colours, sketch mode, layout, padding, paper colour and
a few house rules (big bold labels, heavy strokes). That way plain `d2 file.d2` reproduces the look,
and changing the theme means swapping one file. The six themes live in
`${CLAUDE_SKILL_DIR}/assets/themes/`; they are plain D2, so edit them freely.

## Environment

!`bash "${CLAUDE_SKILL_DIR}/scripts/preflight.sh"`

Read the block above first:

- `D2: missing`: stop and say how to install it (`brew install d2`). Do not install it yourself.
- `PROJECT_STYLE: <path>`: the style for this repo. Nothing to set up.
- `PROJECT_STYLE: none` and `PERSONAL_STYLE: <path>`: seed the repo from the personal file:
  `mkdir -p <DIAGRAMS_DIR> && cp <PERSONAL_STYLE> <DIAGRAMS_DIR>/_style.d2`, and say so in one line.
- Both `none`: copy the default theme to both places and mention `/d2 style` for switching:
  `mkdir -p <DIAGRAMS_DIR> "${XDG_CONFIG_HOME:-$HOME/.config}/d2-diagram" && cp "${CLAUDE_SKILL_DIR}/assets/themes/01-poster.d2" <DIAGRAMS_DIR>/_style.d2 && cp "${CLAUDE_SKILL_DIR}/assets/themes/01-poster.d2" "${XDG_CONFIG_HOME:-$HOME/.config}/d2-diagram/_style.d2"`
- `ENV_OVERRIDE` lists shell variables such as `D2_THEME` that would override the file style;
  `render.sh` ignores them, so only mention it if I wonder why a variable has no effect.
- `CONDUCTOR: true`: AskUserQuestion is unavailable, ask any question in prose.

## Drawing

1. **Decide what to draw** with `${CLAUDE_SKILL_DIR}/references/diagram-types.md` (read it unless the answer is
   obvious). One idea per diagram; a data model plus a request flow is two diagrams.
2. **Existing diagram?** If the request names a `.d2` file, or `EXISTING_DIAGRAMS` is non-zero and
   the topic matches a file in `DIAGRAMS_DIR`, edit that file rather than starting over.
3. **Format.** "png", "image", Slack, Notion → png. "svg" → svg. "animated" or "gif" → gif.
   "animated svg" → animated-svg. Otherwise leave it to `render.sh` (the style says png).
4. **Write `<DIAGRAMS_DIR>/<slug>.d2`.** Line 1 is `...@_style`, then a blank line, `direction:`
   and the content. Labels of three or four words, detail in `tooltip` or `|md` blocks, 10 to 30
   nodes per board, `layers` beyond that. The house rules (`***` globs in the style file) already
   size labels and strokes, so do not restyle nodes by hand; override one thing when needed
   (`api.style.fill: "#f85838"`). A diagram that wants a different layout engine gets a second
   `vars: {d2-config: {layout-engine: elk}}` block after the import (later blocks merge). Never pass
   `--theme`, `--sketch`, `--layout` or `--pad` on the command line: flags override the file.
   Syntax: `${CLAUDE_SKILL_DIR}/references/d2-cheatsheet.md`.
5. **Format and validate.** `d2 fmt <file> && d2 validate <file>`. Errors come as
   `file:line:col: message`; fix them before rendering.
6. **Render.** `bash "${CLAUDE_SKILL_DIR}/scripts/render.sh" <file> [--format png|svg|gif|animated-svg] [--scale 2]`.
   It prints `OUT: <path>`. Exit code 4 means d2 needs its one-time Chromium download (about
   150 MB) for PNG or GIF: ask once, then re-run with `--accept-chromium` and a long Bash timeout;
   if I decline, render `--format svg`. Details: `${CLAUDE_SKILL_DIR}/references/output-formats.md`.
7. **Look at it.** Open the PNG with Read and check for overlapping labels, edges through boxes,
   the wrong direction, or a picture that reads badly. Fix the source (regroup into containers,
   change `direction`, try `layout-engine: elk`, split) and re-render. This is what makes the
   diagrams good; do not skip it.
8. **Report.** Source path, output path, an embed line such as
   `![Checkout flow](docs/diagrams/checkout-flow.png)`, and one sentence: other formats on request,
   theme via `/d2 style`.

**Animated.** D2 animates by cycling through boards. When the content has an order (a walkthrough,
"first... then..."), model it as `steps:` (each step inherits the previous one) or `scenarios:`
and render `--format gif` (`--format animated-svg` on request). A single-board file has nothing to
animate; `render.sh` says so and renders a static image, so add steps first. For "animated
arrows" on a static picture set `style.animated: true` on those connections instead (SVG only).

## `/d2 style [theme]`

- **No theme given, or "show me the themes":** run `bash "${CLAUDE_SKILL_DIR}/scripts/preview.sh"`.
  It renders the sample in all six themes, opens a contact sheet in the browser and prints
  `SHEET: <path>` plus the numbered list. Show the list in prose, ask for a number or name, and
  whether to make it the personal default too (project only is the default answer). Stop and wait.
  `--sample path/to/my.d2` previews the themes on one of my own diagrams (it must not have an
  import line of its own).
- **Theme given** (number or name, e.g. `3` or `sunset`): copy it.
  `cp "${CLAUDE_SKILL_DIR}/assets/themes/<file>.d2" <DIAGRAMS_DIR>/_style.d2`, plus the personal
  path when asked. Check it by rendering, not validating (illegal style keys pass `d2 validate` and
  fail only on render):
  `cat <DIAGRAMS_DIR>/_style.d2 "${CLAUDE_SKILL_DIR}/assets/sample.d2" > /tmp/d2-style-check.d2 && bash "${CLAUDE_SKILL_DIR}/scripts/render.sh" /tmp/d2-style-check.d2 --format svg --out /tmp/d2-style-check.svg`
  Then offer to re-render the existing diagrams:
  `for f in <DIAGRAMS_DIR>/*.d2; do case "$f" in */_*) ;; *) bash "${CLAUDE_SKILL_DIR}/scripts/render.sh" "$f";; esac; done`
- **Tweaks** ("make the arrows red", "less padding", "no paper colour"): edit `_style.d2` directly
  with Edit. Which colour key drives what, and which house-style keys are safe:
  `${CLAUDE_SKILL_DIR}/references/style.md`. Check by rendering the sample as above.
- **Adopt**: on request, add `...@_style` plus a blank line to `.d2` files that lack it (skip files
  that define their own `vars: {d2-config: ...}`), then re-render.

## Good to know

- Icons (`icon: https://icons.terrastruct.com/...`) need network at render time; local images work
  offline. Use icons only when asked.
- `tooltip` and `link` survive only in SVG.
- Never put `style.3d` or `style.double-border` behind a glob: d2 allows them only on squares,
  rectangles, circles, ovals and hexagons, and `d2 validate` will not warn you.
- Big graphs: `elk` is slower than `dagre`; pass `--timeout 300` to `render.sh` and consider
  `layers`. Sequence diagrams ignore the layout engine; keep them to about a dozen messages.
- `d2 -w <file>` is a live preview for hand edits; suggest it, never run it (it does not exit).
- For play.d2lang.com or a single-file share, replace the import line with the contents of
  `_style.d2`.

## References

- `${CLAUDE_SKILL_DIR}/references/diagram-types.md`: which diagram fits which question, with the D2 construct to use.
- `${CLAUDE_SKILL_DIR}/references/d2-cheatsheet.md`: the syntax that is easy to get wrong.
- `${CLAUDE_SKILL_DIR}/references/output-formats.md`: formats, naming, where each works, Chromium notes.
- `${CLAUDE_SKILL_DIR}/references/style.md`: the style file, the six themes, colour keys, house rules.

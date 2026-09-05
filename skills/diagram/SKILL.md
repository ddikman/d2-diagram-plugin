---
name: diagram
description: >-
  Create, edit or render diagrams with D2 (d2lang): architecture, system design, infrastructure,
  request and data flows, sequence diagrams, ER/SQL schemas, C4, state machines, and any diagram
  for docs, READMEs, ADRs, PRs or design reviews. Writes a .d2 source and renders PNG (default),
  SVG, or an animated GIF/SVG using the project's or the user's saved style. Use whenever the user
  mentions D2 or .d2 files, or asks to diagram, draw, visualise, map out or sketch a system, flow,
  process, pipeline or architecture, even without naming a tool. Defer to mermaid or excalidraw
  only when the user names them.
argument-hint: "[what to diagram | path/to/file.d2] [as png|svg|animated|animated svg]"
allowed-tools:
  - Bash(d2 *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*)
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# D2 diagrams

You turn a request into a `.d2` source file plus a rendered image, in the style this project (or
the user) has chosen. The style is a small D2 file called `_style.d2` that every diagram imports on
its first line, so plain `d2 file.d2` reproduces the look for teammates and CI. Fonts are the one
thing d2 cannot read from a file, so rendering always goes through `scripts/render.sh`.

## Environment

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"`

Read the block above before anything else:

- `AUTO: off (...)` means the user switched off automatic D2 use for this workspace. If they did
  not type `/d2:diagram` or ask for D2 by name in their message, stop with one line: "D2
  auto-invocation is off for this workspace (see <file>). Type /d2:diagram to use it anyway, or
  /d2:style auto on." Otherwise carry on; an explicit request always wins.
- `D2: missing` means d2 is not installed. Stop and tell the user how to install it (`brew install
  d2`, or `curl -fsSL https://d2lang.com/install.sh | sh -s --`). Do not install it yourself.
- `PROJECT_STYLE: <path>` is the style to use. Nothing more to set up.
- `PROJECT_STYLE: none` with `PERSONAL_STYLE: <path>` means the user has a personal style but this
  repo has none yet. Copy it: `mkdir -p <DIAGRAMS_DIR> && cp <PERSONAL_STYLE> <DIAGRAMS_DIR>/_style.d2`,
  then say in one line that you seeded `docs/diagrams/_style.d2` from their personal style and it
  should be committed with the diagrams. The copy is what the diagram's import resolves against.
- Both `none`: do the first-run pick below, then continue with the original request.
- `ENV_OVERRIDE` lists shell variables such as `D2_THEME` that would silently override the file
  style. `render.sh` ignores them; mention it only if the user wonders why a variable has no effect.
- `CONDUCTOR: true` means AskUserQuestion is unavailable; ask every question in prose.

## First run: pick a style (only when no style exists)

1. Say one line: "No D2 style is set up yet. One-time pick, then I'll do the diagram."
2. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/preview.sh"`. It renders the same sample in nine
   styles, opens a contact sheet in the browser and prints `SHEET: <path>` plus the numbered list.
3. Show the numbered list in prose (never AskUserQuestion: nine options exceed its limit and some
   hosts block it). Say the sheet is open (or give the path if `OPEN: failed`), and finish with:
   "Reply with a number or name. I'll save it to this project (<DIAGRAMS_DIR>/_style.d2); add
   `personal` to make it your default for every project instead, or `both`."
   Then stop and wait for the answer.
4. Apply the reply: a number maps to the numbered preset file, a name to `assets/presets/<name>.d2`
   (extras such as `terminal`, `origami`, `c4`, `adaptive`, `berry` work too). Copy it:
   `mkdir -p <DIAGRAMS_DIR> && cp "${CLAUDE_PLUGIN_ROOT}/assets/presets/<file>.d2" <DIAGRAMS_DIR>/_style.d2`
   and, for `personal`/`both`, also to `${XDG_CONFIG_HOME:-$HOME/.config}/d2-diagram/_style.d2`.
   Confirm in one line and mention `/d2:style` for changes. Do not ask anything else.
5. If the user answers the original question instead of picking, or nobody can answer
   (`SESSION: headless`, a `claude -p` run, CI): skip the pick, write the diagram with the `clean`
   preset's `vars` block inlined at the top (no import, no files added), mention `/d2:style` once,
   and move on.

## Workflow

1. **Decide what to draw.** Match the request to a diagram type with
   `references/diagram-types.md` (read it unless the answer is obvious). One idea per diagram; a
   request that mixes a data model and a request flow is two diagrams.
2. **Existing diagram?** If the request names a `.d2` file, or `EXISTING_DIAGRAMS` is non-zero and
   the topic matches a file in `DIAGRAMS_DIR`, edit that file instead of starting over.
3. **Format.** "png", "rendered", "image", Slack, Notion, Confluence → png. "svg" → svg.
   "animated", "animate", "gif" → gif. "animated svg" → animated-svg. Otherwise leave it to
   `render.sh`, which reads `default-format` from the style.
4. **Write `<DIAGRAMS_DIR>/<slug>.d2`.** Line 1 is `...@_style`, then a blank line, then
   `direction:` and the content. Keep labels to three or four words and put detail in `tooltip`
   or `|md` blocks; aim for 10 to 30 nodes per board and split bigger topics into several
   diagrams or `layers`. A diagram that needs a different layout engine or padding gets a second
   `vars: {d2-config: {layout-engine: elk}}` block after the import (later blocks merge). Never
   pass `--theme`, `--sketch`, `--layout` or `--pad` on the command line: flags override the file
   and the result would not match what teammates see. Syntax help: `references/d2-cheatsheet.md`.
5. **Format and validate.** `d2 fmt <file> && d2 validate <file>`. Errors come as
   `file:line:col: message`; fix them before rendering.
6. **Render.** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/render.sh" <file> [--format png|svg|gif|animated-svg] [--scale 2]`.
   It prints `OUT: <path>`. Exit code 4 means d2 needs a one-time Chromium download (about
   150 MB) for PNG or GIF: ask the user once, then re-run with `--accept-chromium`; if they
   decline, render `--format svg` and say why. Give the Bash call a long timeout for that first
   download. Details and the platform table: `references/output-formats.md`.
7. **Look at it.** When a PNG was produced, open it with Read and check for overlapping labels,
   edges crossing through boxes, the wrong direction, or a diagram that reads badly. Fix the source
   (regroup into containers, switch `direction`, try `layout-engine: elk` for busy graphs, split)
   and re-render. This step is what makes the diagrams good; do not skip it.
8. **Report.** The source path, the output path(s), an embed line such as
   `![Checkout flow](docs/diagrams/checkout-flow.png)`, and one sentence: other formats on request
   (`as svg`, `animated`), style changes via `/d2:style`.

## Animated diagrams

D2 animates by cycling through boards. When the content has an order (a request walkthrough, a
build-up, "first... then..."), model it as `steps:` (each step inherits the previous one) or
`scenarios:` (variants of one base) and render `--format gif`, or `--format animated-svg` when the
user asks for SVG. A single-board file has nothing to animate; `render.sh` says so and renders a
static image, so add steps first. For "animated arrows" or "show data flowing" on a static
picture, set `style.animated: true` on those connections instead (SVG only) and say which of the
two you chose.

## Changing the look

The style file governs every diagram that imports it. To restyle, use `/d2:style` (or edit
`_style.d2` when the user asks you directly), then re-render:
`for f in <DIAGRAMS_DIR>/*.d2; do case "$f" in */_*) ;; *) bash "${CLAUDE_PLUGIN_ROOT}/scripts/render.sh" "$f";; esac; done`.
Files the user wrote themselves, without the import, render as they are; add `...@_style` only when
asked. A file that already sets its own `vars: {d2-config: ...}` is never modified. For pasting
into play.d2lang.com or sharing a single file, produce a standalone copy: replace the import line
with the contents of `_style.d2`.

## Good to know

- Icons (`icon: https://icons.terrastruct.com/...`) are fetched at render time and need network;
  use them only when the user asks for icons. Local image files work offline.
- `tooltip` and `link` survive only in SVG.
- Large diagrams: `elk` is slower than `dagre`; pass `--timeout 300` to `render.sh` for big graphs
  and consider splitting into `layers`.
- Sequence diagrams ignore the layout engine; keep them to about a dozen messages.
- `d2 -w <file>` opens a live-reloading preview for the user to iterate by hand; suggest it, do not
  run it yourself (it never exits).

## References

- `references/diagram-types.md`: which diagram fits which question, with the D2 construct to use.
- `references/d2-cheatsheet.md`: the syntax that is easy to get wrong.
- `references/output-formats.md`: formats, naming, where each format works, Chromium notes.
- `${CLAUDE_PLUGIN_ROOT}/skills/style/references/style-config.md`: what the style file can contain.

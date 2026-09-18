---
name: d2
description: >-
  Draw diagrams with D2 (d2lang) in my personal style: architecture, system and service diagrams,
  request and data flows, sequence diagrams, ER/SQL schemas, state machines, and any picture for a
  README, design doc, PR or slide. Writes a .d2 source next to a rendered PNG (default), SVG or
  animated GIF. Use whenever I ask to diagram, draw, sketch, visualise or map out a system, flow,
  process, pipeline or architecture, or mention D2 or a .d2 file.
argument-hint: "[what to draw | path/to/file.d2] [as svg|animated]"
compatibility: >-
  Needs the d2 CLI; when it is missing the skill asks before installing it (Homebrew on macOS,
  otherwise the official install script into ~/.local). PNG and GIF output need d2's one-time
  Chromium download, which is also asked about first.
allowed-tools:
  - Bash(d2 *)
  - Read
  - Write
  - Edit
  - Glob
---

# D2 diagrams in my style

A request becomes a `.d2` source file plus a rendered image. Every diagram imports `_style.d2` on
its first line, a copy of `${CLAUDE_SKILL_DIR}/style.d2`: vivid sketch mode, my colours, paper
background and a few `***` house rules (big bold labels, heavy strokes). Plain `d2 file.d2`
therefore reproduces the look anywhere.

## Setup

d2: !`d2 --version 2>/dev/null || echo "missing"`
style: !`ls docs/diagrams/_style.d2 diagrams/_style.d2 2>/dev/null || echo "none yet"`

- If d2 is missing, do not install anything yet. Ask me first, in prose, naming the exact command
  you would run: `brew install d2` when Homebrew is available (`command -v brew`), otherwise the
  official script into a user-writable prefix with no sudo,
  `curl -fsSL https://d2lang.com/install.sh | sh -s -- --method standalone --prefix ~/.local`
  (on Windows `scoop install main/d2` or `choco install d2`). Then stop and wait. Install only
  after I say yes; a question, silence, or anything less than a clear yes means no, in which case
  stop and leave the command for me to run myself. After installing, confirm with `d2 --version`
  (for the script, use `~/.local/bin/d2` this session and tell me to add `~/.local/bin` to `PATH`).
- Diagrams live in `docs/diagrams/` when the repo has a `docs/` folder, else in `diagrams/`.
  If that folder has no `_style.d2`, copy mine in and mention it in one line:
  `mkdir -p docs/diagrams && cp "${CLAUDE_SKILL_DIR}/style.d2" docs/diagrams/_style.d2`

## Drawing

1. **Decide what to draw** with `${CLAUDE_SKILL_DIR}/references/diagram-types.md` (read it unless
   the answer is obvious). One idea per diagram.
2. **Existing diagram?** If the request names a `.d2` file or matches one in the diagrams folder,
   edit that file rather than starting over.
3. **Write `docs/diagrams/<slug>.d2`.** Line 1 is `...@_style`, then a blank line, `direction:`
   and the content. Labels of three or four words, detail in `tooltip` or `|md` blocks, 10 to 30
   nodes per board. The house rules already size labels and strokes, so do not restyle nodes; override
   one thing when needed (`api.style.fill: "#f89058"`). A diagram that wants another layout engine
   adds `vars: {d2-config: {layout-engine: elk}}` after the import. Syntax that is easy to get wrong:
   `${CLAUDE_SKILL_DIR}/references/d2-cheatsheet.md`.
4. **Format and validate.** `d2 fmt <file> && d2 validate <file>`; errors are `file:line:col: message`.
5. **Render** next to the source, same basename. Never pass `--theme`, `--sketch`, `--layout` or
   `--pad`: flags override the style file. If any `D2_*` variable is set in the shell, prefix the
   command with `env -u D2_THEME -u D2_SKETCH -u D2_LAYOUT -u D2_PAD`.
   - PNG (default): `d2 docs/diagrams/x.d2 docs/diagrams/x.png` (`--scale 2` for retina READMEs)
   - SVG: `d2 docs/diagrams/x.d2 docs/diagrams/x.svg`
   - Animated: write the diagram as `steps:` (each step inherits the previous) or `scenarios:`,
     then `d2 --animate-interval 1200 docs/diagrams/x.d2 docs/diagrams/x.gif`, or `x-animated.svg`
     when I ask for SVG. A single-board file has nothing to animate; for "animated arrows" on a
     static picture set `style.animated: true` on the connections instead (SVG only).
   - The first PNG or GIF on a machine makes d2 ask to download Chromium (about 150 MB). Ask me once,
     then run the same command with `CI=1` in front and a long timeout. If I decline, render SVG.
6. **Look at it.** Read the PNG and check for overlapping labels, edges through boxes, the wrong
   direction. Fix the source (containers, `direction`, `layout-engine: elk`, split) and re-render.
7. **Report.** Source path, output path and an embed line such as
   `![Checkout flow](docs/diagrams/checkout-flow.png)`.

## Changing the style

`style.d2` in this skill is the master; `_style.d2` in a repo is a copy. To restyle a repo, copy the
master over its `_style.d2` and re-render every `.d2` there except `_style.d2` itself. Colour keys
are explained at the top of the file. Keep the `***` rules as triple globs (only those survive the
import) and never put `style.3d` or `style.double-border` behind a glob: d2 rejects them on
cylinders, people, queues and tables, and `d2 validate` will not warn you, so check style edits by
rendering.

## Good to know

- Icons (`icon: https://icons.terrastruct.com/...`) need network at render time; use them only when asked.
- `tooltip` and `link` survive only in SVG.
- `elk` is slower than `dagre`; pass `--timeout 300` for big graphs. Sequence diagrams ignore the
  layout engine; keep them to about a dozen messages.
- `d2 -w <file>` is a live preview for hand edits; suggest it, never run it (it does not exit).
- For play.d2lang.com or a single-file share, replace the import line with the contents of `_style.d2`.

---
name: d2
description: >-
  Draw diagrams with D2 (d2lang) in my personal style: sequence, flow and process diagrams, C4
  system context, deployment, component and class diagrams, sitemaps, service dependency maps,
  architecture, ER/SQL schemas, state machines, and any picture for a README, design doc, PR or
  slide. Writes a .d2 source next to a rendered PNG (default), SVG or an animated SVG whose lines
  flow. Use whenever I ask to diagram, draw, sketch, visualise or map out a system, flow, process,
  pipeline, architecture, infrastructure or site structure, or mention D2 or a .d2 file.
argument-hint: "[what to draw | path/to/file.d2] [as svg|animated]"
compatibility: >-
  Needs the d2 CLI; when it is missing the skill asks before installing it (Homebrew on macOS,
  otherwise the official install script into ~/.local). PNG output needs d2's one-time Chromium
  download, which is also asked about first.
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

1. **Pick the type from the question** the reader has: one diagram, one argument. My everyday three
   cover most requests; the other six are for when the question matches.

   | The reader asks | Draw | Start from |
   |---|---|---|
   | Who does what, in which order? | Sequence | `sequence.d2` |
   | What happens, and where does it branch? | Flow | `flow.d2` |
   | What are the steps, start to finish? | Process | `process.d2` |
   | What is in scope, and who and what does it talk to? | C4 system context | `c4-context.d2` |
   | Where does it run: regions, zones, clusters, replicas? | Deployment | `deployment.d2` |
   | What are the parts, and who depends on whom? | Component | `component.d2` |
   | Which entities, with which fields and cardinalities? | Class | `class.d2` |
   | Which pages and routes exist? | Sitemap | `sitemap.d2` |
   | Where does live traffic go, and where do errors sit? | Service dependency map | `service-dependency-map.d2` |

   Read the matching example in `${CLAUDE_SKILL_DIR}/diagrams/` before writing; all nine draw one
   small online shop. When the choice is not obvious,
   `${CLAUDE_SKILL_DIR}/references/diagram-types.md` says when to use and skip each type and
   covers what else D2 draws (ER schemas, state machines, grids). A request that mixes two
   questions gets two diagrams.
2. **Existing diagram?** If the request names a `.d2` file or matches one in the diagrams folder,
   edit that file rather than starting over.
3. **Write `docs/diagrams/<slug>.d2`.** Line 1 is `...@_style`, then a blank line, `direction:`
   (sequence diagrams and grids have none) and the content. Labels of three or four words, detail
   in `tooltip` or `|md` blocks, at most 30 nodes per board, one level of abstraction, and a label
   on every arrow. Highlight the one thing the diagram is about with a brick red outline and label,
   `{style.stroke: "#c8401f"; style.font-color: "#c8401f"}` (on a `class` or `sql_table`,
   `style.fill: "#c8401f"`), and draw systems outside our control dashed and pale,
   `{style.stroke-dash: 5; style.fill: "#fbfaf6"}`. Beyond that, do not restyle nodes: the house
   rules already size labels and strokes. Override one thing when needed
   (`api.style.fill: "#f89058"`). A PR or README shows the picture about 850 px wide, and every hop
   of `direction: right` adds width: use `direction: down` when edge labels are long, and shorten
   labels first. A diagram that wants another layout engine adds
   `vars: {d2-config: {layout-engine: elk}}` after the import. Syntax that is easy to get wrong:
   `${CLAUDE_SKILL_DIR}/references/d2-cheatsheet.md`.

   When colour sorts shapes into kinds the reader has to decode (what a PR adds, changes or
   leaves alone; which team owns what; what is live and what is planned), the diagram gets a
   small legend. Make each kind a class named for its meaning, the plain default included, and
   give every class its own `style.fill`. The legend has one row per class, a small swatch with
   its meaning beside it, plus rows for the highlight and dashed externals if the diagram has
   them. A diagram whose only colours are the highlight and dashed externals needs no legend.
   Recipe: `${CLAUDE_SKILL_DIR}/references/diagram-types.md`.
4. **Format and validate.** `d2 fmt <file> && d2 validate <file>`; errors are `file:line:col: message`.
5. **Render** next to the source, same basename. Never pass `--theme`, `--sketch`, `--layout` or
   `--pad`: flags override the style file. If any `D2_*` variable is set in the shell, prefix the
   command with `env -u D2_THEME -u D2_SKETCH -u D2_LAYOUT -u D2_PAD`.
   - PNG (default): `d2 docs/diagrams/x.d2 docs/diagrams/x.png` (`--scale 2` for retina READMEs)
   - SVG: `d2 docs/diagrams/x.d2 docs/diagrams/x.svg`
   - Animated means the lines move, never a slideshow of frames. Keep one board and set
     `style.animated: true` on the connections that carry the flow, or on all of them with one glob
     per arrow type in use (`(** -> **)[*].style.animated: true`, the same again with `<-`). Dashes
     flow towards the arrowhead. Number the edge labels when order matters (`"1 · mint"`) and colour
     the main path. Render both `x.svg` (the animation) and `x.png` (the still, for step 6 and for
     Slack or slides, which cannot play SVG). Only SVG moves: never make a PNG or GIF "animated".
   - A step-by-step walkthrough (`steps:`) only when I ask for one in those words; follow the
     recipe in `${CLAUDE_SKILL_DIR}/references/diagram-types.md`.
   - The first PNG on a machine makes d2 ask to download Chromium (about 150 MB). Ask me once,
     then run the same command with `CI=1` in front and a long timeout. If I decline, render SVG.
6. **Look at it.** Read the PNG and check for overlapping labels, labels running into a container
   border, edges through boxes, the wrong direction, a colour that sorts shapes but has no legend
   row, and a legend swatch that looks different from its shapes. If labels are hard to read
   with the whole picture in view, the canvas is too wide for a PR. Fix the source (containers,
   `direction`, two-line labels, `layout-engine: elk`, split) and re-render.
7. **Report.** Source path, output path and an embed line for the doc, ticket or PR where the
   diagram is used, such as `![Checkout flow](docs/diagrams/checkout-flow.png)`.

## Changing the style

`style.d2` in this skill is the master; `_style.d2` in a repo is a copy. To restyle a repo, copy the
master over its `_style.d2` and re-render every `.d2` there except `_style.d2` itself. Colour keys
are explained at the top of the file. Keep the `***` rules as triple globs (only those survive the
import) and never put `style.3d` or `style.double-border` behind a glob: d2 rejects them on
cylinders, people, queues and tables, and `d2 validate` will not warn you, so check style edits by
rendering.

## Good to know

- Remote icons (`icon: https://icons.terrastruct.com/...`) need network at render time; use them
  only when asked. The component icon is a local file, so component diagrams always get it.
- `tooltip` and `link` survive only in SVG.
- Keep `|md` text to ASCII plus `·`. A glyph the sketch font lacks (`…`, arrows, emoji) renders wider
  than d2 measured, so the line wraps and is cut off. `d2 validate` cannot see it, only the render.
- `elk` is slower than `dagre`; pass `--timeout 300` for big graphs. Sequence diagrams ignore the
  layout engine; keep them to about a dozen messages.
- `d2 -w <file>` is a live preview for hand edits; suggest it, never run it (it does not exit).
- For play.d2lang.com or a single-file share, replace the import line with the contents of `_style.d2`.

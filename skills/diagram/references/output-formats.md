# Output formats

Always render through `bash "${CLAUDE_PLUGIN_ROOT}/scripts/render.sh" FILE.d2 [options]`. It
resolves the imported style, adds the font flags d2 cannot read from a file, ignores stray `D2_*`
environment variables, picks a sensible file name and prints `OUT: <path>`.

| Option | Effect |
|---|---|
| `--format png` | Raster image next to the source, `name.png`. Needs d2's Chromium (see below). Default for most presets. |
| `--format svg` | Vector, `name.svg`. No browser needed; keeps `tooltip`, `link`, dark-mode switching and `style.animated`. |
| `--format gif` | Animated GIF from a multi-board file, `name.gif`. Needs Chromium. |
| `--format animated-svg` | Animated SVG from a multi-board file, `name-animated.svg` (so it never overwrites the static SVG). |
| `--format animated` | Whichever of gif or animated-svg the style's `animated-format` names. |
| `--format pdf` / `pptx` | Print or slide deck. Needs Chromium. |
| `--out PATH` | Explicit output path. |
| `--scale 2` | Hi-DPI raster for READMEs and retina screens; doubles PNG dimensions. |
| `--interval MS` | Milliseconds per board for animations (default from the style, usually 1200). |
| `--target BOARD` | One board of a multi-board file, e.g. `steps.3`, `scenarios.failure`, `layers.detail`; `''` is the root. |
| `--all-boards` | Let d2 write a directory with every board as a static image. |
| `--timeout S` | d2 compile/layout timeout (default 120 s). Raise for big `elk` layouts. |
| `--style PATH` | Use this style file instead of the one the diagram imports (previews use it). |
| `--accept-chromium` | Consent to the one-time Chromium download for raster output. |
| `--dry-run` | Print the d2 command instead of running it. |

Exit codes: 0 ok · 1 d2 failed (its message is on stderr) · 2 usage or style problem · 3 d2 not
installed · 4 Chromium consent needed.

## Board rules

| File | Requested | What happens |
|---|---|---|
| single board | png / svg | normal render |
| single board | gif / animated | `NOTE: single board...` and a static png/svg instead; add `steps:` first |
| multi-board | gif / animated-svg | one animated file, `--animate-interval` applied |
| multi-board | png / svg | root board only (`--target ''`) with a note; use `--target` or `--all-boards` for others |

## Chromium for raster output

d2 renders PNG, GIF, PDF and PPTX through a headless Chromium that it downloads on first use
(about 150 MB, into d2's own cache). With stdin closed the download prompt fails, so `render.sh`
returns exit 4 and prints `CHROMIUM: consent needed`. Ask the user once, then re-run with
`--accept-chromium`; give that Bash call a generous timeout (several minutes on a slow link).
Later renders are quick. If the user declines, deliver SVG and say why. Upcoming d2 releases
render PNG without a browser, at which point this step disappears.

## Where each format works

| Destination | Use | Why |
|---|---|---|
| GitHub README, PR description, issue | png (`--scale 2`) or svg | Both render inline; SVG stays crisp, PNG previews everywhere including mobile apps. GIF animates. |
| Slack, Notion, Confluence, Google Docs | png or gif | Uploads of SVG are blocked or shown as files. |
| Docs sites (MkDocs, Docusaurus, Starlight, Hugo) | svg | Crisp at any size, hover tooltips and links work, `adaptive` style follows dark mode. |
| Slides and print | pptx / pdf, or png `--scale 2` | Vector where the tool accepts it. |
| Chat message from Claude | png | The image can be viewed directly. |

Embed with a relative path next to the source so reviewers can diff the `.d2` file:
`![Checkout flow](docs/diagrams/checkout-flow.png)`. Keep the `.d2` committed; the image is a
build artefact that any teammate can regenerate with `d2 docs/diagrams/checkout-flow.d2 out.png`
(fonts excepted, see style-config.md).

## Handy d2 commands for the user

- `d2 -w docs/diagrams/x.d2` opens a live preview that re-renders on save (never run it from the
  skill; it does not exit).
- `d2 play x.d2` opens the diagram in the online playground; it needs a standalone file, so inline
  the style block first.
- `d2 fmt x.d2` formats in place; `d2 validate x.d2` checks without rendering.
- `d2 themes` lists theme ids; `d2 layout` lists layout engines.
- `--salt` (pass through d2 directly) gives unique ids when several SVGs share one HTML page.

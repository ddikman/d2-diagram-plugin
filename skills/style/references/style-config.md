# The style file

`_style.d2` is ordinary D2. Everything in it is merged into each diagram that imports it, so it
can hold anything a diagram can: the `d2-config` block, `classes`, colour variables, glob rules.
The plugin only requires the `data` entries it reads.

```d2
# d2-diagram preset: blueprint — Cool blues with orthogonal routing (ELK) and the Inter font.
# Shared style for every diagram in this folder; diagrams import it via ...@_style. Edit freely.
vars: {
  d2-config: {
    theme-id: 4
    sketch: false
    layout-engine: elk
    pad: 32
    data: {font: inter; default-format: png; animated-format: gif; animate-interval: 1200}
  }
}
```

## Where it lives and which one wins

| Scope | Path | Used when |
|---|---|---|
| project | `<diagrams dir>/_style.d2`, usually `docs/diagrams/` (or `diagrams/` without a docs folder) | always, when present; nearest to the working directory wins if a repo has several |
| personal | `${XDG_CONFIG_HOME:-$HOME/.config}/d2-diagram/_style.d2` | copied into a repo that has no project style the first time a diagram is made there |

The file must sit next to the diagrams (or in a plain subdirectory) because d2 resolves
`...@_style` relative to the importing file and drops a leading dot from import paths, so a
`.claude/` or `.config/` location inside the repo cannot be imported.

## `d2-config` keys

| Key | Values | Notes |
|---|---|---|
| `theme-id` | see table | colours, and for Terminal themes also caps + monospace + dotted containers |
| `dark-theme-id` | theme id | SVG follows the viewer's `prefers-color-scheme`; PNG ignores it |
| `sketch` | `true` / `false` | hand-drawn strokes and fonts; a custom font replaces the hand-drawn font |
| `layout-engine` | `dagre` (fast, compact) / `elk` (orthogonal edges, better for many crossings) | TALA if installed |
| `pad` | pixels | margin around the diagram (d2 default 100; presets use 32) |
| `center` | `true` / `false` | centre the SVG in its viewbox |
| `theme-overrides` | map of colour keys | replace individual theme colours (below) |
| `dark-theme-overrides` | map of colour keys | same for the dark theme |
| `data` | free-form map | plugin settings; d2 ignores it |

Flags and `D2_*` environment variables override these values; `render.sh` never passes the flags
and unsets the variables so the file is the single source of truth.

### Themes (`d2 themes`)

| id | name | | id | name |
|---|---|---|---|---|
| 0 | Neutral Default | | 103 | Earth Tones |
| 1 | Neutral Grey | | 104 | Everglade Green |
| 3 | Flagship Terrastruct | | 105 | Buttered Toast |
| 4 | Cool Classics | | 200 | Dark Mauve (dark) |
| 5 | Mixed Berry Blue | | 201 | Dark Flagship Terrastruct (dark) |
| 6 | Grape Soda | | 300 | Terminal |
| 7 | Aubergine | | 301 | Terminal Grayscale |
| 8 | Colorblind Clear | | 302 | Origami |
| 100 | Vanilla Nitro Cola | | 303 | C4 |
| 101 | Orange Creamsicle | | | |
| 102 | Shirley Temple | | | |

### Colour override keys

```d2
theme-overrides: {
  B1: "#0f172a"   # B1–B6: base palette, darkest to lightest (strokes, fills, container levels)
  B2: "#1e3a8a"
  B3: "#3b82f6"
  B4: "#93c5fd"
  B5: "#dbeafe"
  B6: "#eff6ff"
  AA2: "#7c3aed"  # AA2, AA4, AA5: first accent family (e.g. sql_table headers, highlights)
  AA4: "#c4b5fd"
  AA5: "#ede9fe"
  AB4: "#fb7185"  # AB4, AB5: second accent family (constraints, warnings)
  AB5: "#ffe4e6"
  N1: "#0f172a"   # N1–N7: neutrals, darkest text to lightest background
  N2: "#1e293b"
  N3: "#475569"
  N4: "#94a3b8"
  N5: "#cbd5e1"
  N6: "#e2e8f0"
  N7: "#f8fafc"
}
```

Override only what you need; unspecified keys keep the theme's colour. Not every theme uses every
key.

## `data` keys read by the plugin

| Key | Values | Meaning |
|---|---|---|
| `font` | `default`, `inter`, `plex-mono`, `lora`, or a directory path | `default` keeps d2's Source Sans Pro (or the hand-drawn font in sketch mode); a directory must contain `*-Regular.ttf`, `*-Bold.ttf`, `*-Italic.ttf`, `*-SemiBold.ttf` |
| `default-format` | `png`, `svg` | what `render.sh` produces when no format is requested |
| `animated-format` | `gif`, `svg` | what "animated" means |
| `animate-interval` | milliseconds | time per board in animations |

A diagram can override any of these in its own `vars: {d2-config: {data: {...}}}` block after
the import; `render.sh` reads the diagram after the style.

## Fonts

d2 accepts fonts only as command-line flags pointing at `.ttf` files, so the font is the one part
of the style that plain `d2 file.d2` does not reproduce (it falls back to Source Sans Pro). The
plugin bundles three families under `assets/fonts/`, each with its SIL Open Font License text:

| name | family | look |
|---|---|---|
| `inter` | Inter | modern neutral sans |
| `plex-mono` | IBM Plex Mono | monospace for all text, including code and tables |
| `lora` | Lora | serif, print-like |

Built-in looks without any font file: Source Sans Pro (default), Source Code Pro via
`**.style.font: mono` glob rules or the Terminal themes, and Architect's Daughter / Fuzzy
Bubbles in sketch mode. To reproduce a bundled font outside the plugin, export the variables d2
reads (`D2_FONT_REGULAR`, `D2_FONT_BOLD`, `D2_FONT_ITALIC`, `D2_FONT_SEMIBOLD`, and the
`D2_FONT_MONO*` set for `plex-mono`) pointing at the files in `assets/fonts/<family>/`.

## Recipes

Monospace labels without leaving your theme (no font files):

```d2
**.style.font: mono
(** -> **)[*].style.font: mono
```

Follow the viewer's dark mode (SVG only):

```d2
vars: {
  d2-config: {
    theme-id: 0
    dark-theme-id: 200
  }
}
```

House classes shared by every diagram, defined once in the style file:

```d2
classes: {
  external: {style.stroke-dash: 5}
  db: {shape: cylinder}
}
```

Standalone copy for the playground or a single-file share: replace the diagram's `...@_style`
line with the contents of `_style.d2`.

## Switching automatic use on and off

`/d2:style auto off` writes `skillOverrides: {"d2:diagram": "user-invocable-only"}` to
`.claude/settings.local.json` (per checkout; `--project` and `--global` target the shared and
user settings). Claude Code then lists the skill for slash use only, and the skill's own preflight
prints `AUTO: off` so it stops itself when started without an explicit request, even on hosts that
ignore plugin-scoped override keys. `auto on` removes the entry.

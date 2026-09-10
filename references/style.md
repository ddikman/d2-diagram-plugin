# The style file and the six themes

`_style.d2` is ordinary D2 that every diagram spreads in with `...@_style`. It carries four things:

```d2
# d2 theme: poster — The whole infographic: slate ink, teal and cyan shapes, yellow groups, ...
vars: {
  d2-config: {
    theme-id: 0
    sketch: true
    layout-engine: dagre
    pad: 40
    theme-overrides: { B1: "#2f3e4e"; ... }          # the palette (keys below)
    data: {default-format: png; animated-format: gif; animate-interval: 1200}
  }
}

style.fill: "#f3f1ea"                               # paper colour behind the whole diagram

***.style.font-size: 20                             # house rules: big bold labels, heavy strokes
***.style.bold: true
***.style.stroke-width: 3
(*** -> ***)[*].style.stroke-width: 3
(*** -> ***)[*].style.font-size: 18
***: {&shape: person; width: 64; height: 88}        # d2 sizes people from their label; pin the box
```

## Where it lives

| Scope | Path | Used when |
|---|---|---|
| project | `<diagrams dir>/_style.d2`, usually `docs/diagrams/` (or `diagrams/`) | always, when present; nearest to the working directory wins |
| personal | `${XDG_CONFIG_HOME:-$HOME/.config}/d2-diagram/_style.d2` | copied into a repo that has no project style the first time a diagram is made there |

It must sit next to the diagrams (or in a plain subdirectory): d2 resolves `...@_style` relative
to the importing file and drops a leading dot from import paths, so `.claude/` or `.config/` inside
the repo cannot be imported. `d2 fmt` keeps the comments and the inline maps.

## The six themes (`assets/themes/`)

All six are sketch mode on `theme-id: 0` with a full set of colour overrides, inspired by a flat
infographic palette (teal `#0888a8`, cyan `#38b4c8`, orange-red `#f85838`, yellow `#f8c848`,
slate `#2f3e4e`).

| # | name | ink and edges | shapes and groups | databases | paper |
|---|---|---|---|---|---|
| 1 | poster | slate | cyan shapes, teal people, yellow groups | soft orange | warm grey |
| 2 | teal | dark teal | light to mid teal | yellow | cool mist |
| 3 | sunset | dark brown ink, red edges | orange shapes, orange-red people, yellow groups | teal | cream |
| 4 | ocean | navy | light to mid blue | yellow | pale blue |
| 5 | plum | plum | gold shapes, plum people, cream groups | teal | warm cream |
| 6 | chalkboard | yellow ink, cyan edges | slate boards, light text | orange-red | dark slate |

Switch with `/d2 style <name>` (copies the file over `_style.d2`). To invent a seventh, copy one,
change the hex values and the first comment line, and check it by rendering the sample.

## Which colour key drives what

Measured on d2 0.8.1 (theme 0 base). Fills get lighter with nesting depth.

| Key | Used for |
|---|---|
| `B1` | shape outlines, root-level connections and arrowheads |
| `B2` | connections that touch nested objects, column names in tables |
| `B3` | `person` and `c4-person` fill |
| `B4` | root-level container fill |
| `B5` | shapes inside a container (and nested containers) |
| `B6` | root-level shapes, `oval`, `circle`, `square`, deepest nesting |
| `AA2` | `PK`/`FK` constraint text in tables |
| `AA4` | `cylinder`, `package`, `stored_data` fill |
| `AA5`, `AB5` | reserved by d2, unused in practice; keep them as light tints |
| `AB4` | `step`, `page`, `document` fill |
| `N1` | label text, table and class headers, table outlines |
| `N2` | connection labels, column types |
| `N3`, `N6` | markdown block text and rules |
| `N4` | `diamond` fill |
| `N5` | `queue`, `hexagon`, `parallelogram` fill |
| `N7` | table and class bodies, `cloud` and `callout` fill, markdown background |

Consequences worth knowing: labels are always `N1`, so every fill must contrast with it (this is
why chalkboard makes `N1` light and all fills dark); `B2` doubles as the column-name colour, so a
loud edge colour shows up in tables; diamonds and queues follow the neutrals, which is why each
theme tints `N4`/`N5` instead of leaving them grey.

## House rules (the `***` globs)

Only triple globs survive an import: `*` and `**` would stay behind in `_style.d2`. Filters:
`***: {&leaf: true; ...}` for shapes without children, `&leaf: false` for containers,
`(*** -> ***)[*]` for every connection, `***.style.KEY` for everything. `sql_table` and `class`
match neither leaf filter and take only unfiltered rules.

Safe keys: `border-radius` (0-20), `shadow`, `stroke-width` (1-15), `font-size` (8-100),
`fill-pattern` (`dots`/`lines`/`grain`, grain adds ~29 KB per SVG), `bold`, `italic`, `underline`,
`text-transform`, `opacity`, `stroke-dash`, `multiple`, `font` (`mono`), `fill`, `stroke`.

Never `style.3d` or `style.double-border` behind a glob: d2 accepts them only on squares,
rectangles, circles, ovals and hexagons, so the first cylinder, person, queue, table or markdown
block breaks the render, and `d2 validate` still calls the file valid. Check styles by rendering.

Person shapes are sized from their label, so long names stretch the icon sideways; the pinned
64x88 box keeps them looking like people. `&shape: person` does not match `c4-person`.

## Overriding

For one object, after the import line: `api.style.shadow: true`, `api.style.fill: "#f85838"`.
For a whole diagram, restate a `***` rule after the import; the later rule wins. To drop the paper
colour for one diagram: `style.fill: transparent` after the import. For a whole project, edit
`_style.d2`. A diagram can also override the `data` settings in its own
`vars: {d2-config: {data: {default-format: svg}}}` block.

Shared classes belong in the style file too, so every diagram can use them:

```d2
classes: {
  external: {style.stroke-dash: 5}
  db: {shape: cylinder}
}
```

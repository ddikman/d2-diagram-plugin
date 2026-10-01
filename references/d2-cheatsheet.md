# D2 cheat sheet

The parts of D2 that are easy to get wrong, plus the constructs this plugin relies on. Run
`d2 validate FILE` after writing; errors are `file:line:col: message`.

## File layout used by this plugin

```d2
...@_style          # line 1: spread-import the shared style (theme, layout, sketch, pad, font)

direction: right    # up | down | left | right; root only (see Containers)

# optional per-diagram override; later vars blocks merge with the imported one
vars: {
  d2-config: {
    layout-engine: elk
  }
}
```

Only these keys are valid under `d2-config`: `theme-id`, `dark-theme-id`, `sketch`,
`layout-engine`, `pad`, `center`, `theme-overrides`, `dark-theme-overrides`, `data`. Anything else
is a compile error. Inline maps separate entries with `;` not `,`: `{fill: red; stroke: blue}`.

## Shapes and labels

```d2
api                       # key doubles as label
db: Postgres              # key: label
db.shape: cylinder        # or db: Postgres {shape: cylinder}
"a.b": Odd key            # quote keys containing . : # or spaces
```

Shapes: `rectangle` (default), `square`, `page`, `parallelogram`, `document`, `cylinder`,
`queue`, `package`, `step`, `callout`, `stored_data`, `person`, `diamond`, `oval`, `circle`,
`hexagon`, `cloud`, `text`, `code`, `class`, `sql_table`, `image`, `sequence_diagram`,
`c4-person`.

Sizes: `x.width: 200`, `x.height: 80` (not on containers with children).

## Connections

```d2
a -> b                    # directed
a <- b
a <-> b                   # both ways
a -- b                    # undirected
a -> b: label             # label
a -> b -> c: same label   # chain
a -> b: {                 # styled edge
  style.stroke-dash: 3
  style.animated: true    # dashes flow towards the arrowhead; SVG only, a PNG shows them frozen
  target-arrowhead: {shape: diamond; style.filled: false}
  source-arrowhead.shape: cf-many
}
(a -> b)[0].style.stroke: red   # refer to an existing edge by index
```

Which shape comes first depends on the engine. dagre (the default) ranks by the arrowhead:
`a -> b` and `b <- a` both put `a` first. elk ranks by the order you write the shapes:
`backend.api <- phone.app` keeps `backend` above `phone` although the arrow points up. In dagre,
keep `backend` on top with an edge that points down (the reply), or switch to elk. Refer to an
edge with the spelling it was written in, `(backend.api <- phone.app)[0]`.

Arrowheads: `triangle` (default), `arrow`, `diamond`, `circle`, `box`, `cf-one`, `cf-many`,
`cf-one-required`, `cf-many-required`, `cross`, `none`. A shape shows only on an end that has an
arrow: `source-arrowhead.shape` on `a -> b` draws nothing, so write `a <- b` (or `<->`). A label
shows on either end: `source-arrowhead: 1` and `target-arrowhead: "0..*"` print cardinality.

Edges into a container's child need the full path: `web -> api.handler`. Inside a container, `_`
is the parent: `api: { handler -> _.db }` connects to the sibling `db` at the outer level.

## Containers

```d2
platform: Platform {
  api: API
  worker: Worker
  api -> worker
}
platform.db: Postgres {shape: cylinder}   # add from outside with dotted paths
platform.style.fill: "#f5f5f5"
```

`direction` inside a container is honoured only by TALA. dagre and elk ignore it without a
warning, so every container follows the root direction.

A container's label sits top-centre, exactly where an edge from above enters it;
`label.near: top-left` moves it out of the way.

## Styles

`style.` keys: `opacity`, `stroke`, `fill`, `fill-pattern` (`dots`, `lines`, `grain`, `paper`),
`stroke-width`, `stroke-dash`, `border-radius`, `shadow`, `3d`, `multiple`, `double-border`,
`font` (only `mono`), `font-size`, `font-color`, `bold`, `italic`, `underline`,
`text-transform` (`uppercase`, `lowercase`, `title`, `none`), `animated` (edges), `filled`
(arrowheads). Colours are hex strings in quotes or CSS names.

Prefer `classes` over repeating styles:

```d2
classes: {
  external: {style.stroke-dash: 5; style.fill: "#fafafa"}
  db: {shape: cylinder}
}
stripe: Stripe {class: external}
pg: Postgres {class: db}
cache: Redis {class: [db; external]}   # several classes
```

Globs apply to many things at once: `*.style.fill: "#fff"` (direct children),
`**.style.font: mono` (all descendants), `(** -> **)[*].style.animated: true` (every `->` edge,
nested ones included; `(* -> *)` only sees edges between root shapes), `*.shape: circle`. An edge
glob matches one arrow type: `(** -> **)[*]` skips `<-`, `<->` and `--` edges, so add a line for
each arrow type in use.

## Variables and substitution

```d2
vars: {
  accent: "#0f766e"
}
api.style.stroke: ${accent}
```

Put user variables in their own `vars` block; leave `d2-config` to the style file unless the
diagram deliberately overrides it.

## Text, markdown, code

```d2
note: |md
  ## Cache policy
  Entries expire after **5 minutes**.
| {near: top-right}

snippet: |go
  func main() {}
|

explanation: |||md
  Use three pipes when the text itself contains a pipe |
|||
```

Long labels: `x: "Two line\nlabel"` or a markdown block. `x.tooltip: text` and
`x.link: https://...` show on hover/click in SVG only.

## Positions with `near`

Constants: `top-left`, `top-center`, `top-right`, `center-left`, `center-right`, `bottom-left`,
`bottom-center`, `bottom-right`. A shape placed with a constant sits outside the layout, so the
diagram does not move: a title `{near: top-center}`. A corner constant puts it diagonally outside
the picture (`top-right` is above and to the right), so the canvas grows both ways. `x.near: y`
places `x` beside another shape (`x` must be at the root level).

A legend is a small container written last and left in the layout, which tucks it into free space
(recipe in `diagram-types.md`). d2's own `vars: {d2-legend: {...}}` draws a white card in 14 px
plain text with hairline swatch outlines, outside the house style.

## Icons and images

```d2
s3: Bucket {icon: https://icons.terrastruct.com/aws%2FStorage%2FAmazon-Simple-Storage-Service-S3.svg}
logo: {shape: image; icon: ./logo.png}
```

Remote icons are fetched at render time (network needed). Local paths are relative to the `.d2`
file and are embedded in the output.

`icon.near: top-right` puts the icon in a corner. d2 gives an icon a box of about 64 px and grows
the shape to fit it, so for a badge-sized mark draw the glyph small in one corner of a padded
`viewBox` (as `diagrams/_component-icon.svg` does), set `label.near: center-center` so the label
does not dodge it, and fix `width` so the box does not turn square.

## SQL tables

```d2
orders: orders {
  shape: sql_table
  id: uuid {constraint: primary_key}
  user_id: uuid {constraint: foreign_key}
  sku: text {constraint: [unique; foreign_key]}
  total: numeric
}
orders.user_id -> users.id
```

## Classes (UML)

```d2
Repo: {
  shape: class
  +items: "[]Item"          # + public, - private, # protected
  -cache: Map
  +find(id string): Item
}
Repo -> Store: {target-arrowhead: {shape: triangle; style.filled: false}}   # inheritance
```

On `class` and `sql_table` shapes `style.fill` colours the header and `style.stroke` the rows, so
highlight one with `style.fill`. Composition puts a filled diamond on the whole:
`order <- line: {source-arrowhead: {shape: diamond; style.filled: true}}`.

## Sequence diagrams

```d2
shape: sequence_diagram
user: Customer {shape: person}
web; api; db          # actor order = order of first mention; declare up front to control it

user -> web: submit form
web -> api: POST /orders
api -> db: insert
db -> api: ok
api -> web: 201 Created
web -> user: confirmation

retry: Retry loop {   # group
  api -> db: insert
  db -> api: timeout
}
api.t1 -> db.t1: span      # spans: a lifeline segment named t1 on each actor
api."validates payload"    # note on an actor
api -> api: self message
```

The layout engine is ignored for sequence diagrams. Keep them to roughly twelve messages; split
long flows into several diagrams.

## Grids

```d2
options: Options {
  grid-rows: 2
  grid-columns: 3
  grid-gap: 20
  a: Fast
  b: Cheap
  c: Good
  d: |md **Pick two** |
}
```

No edges between cells: d2 draws them as straight lines through whatever sits in between. Use a
grid to lay out cards, not graphs. `grid-rows: 1` at the root lines shapes up in declaration
order, which is how a process of `shape: step` chevrons stays as narrow as its steps.

## Boards: layers, scenarios, steps

```d2
a -> b

layers: {                 # independent boards; nothing inherited
  detail: { a -> b: with details; b -> c }
}
scenarios: {              # inherit the root board and change it
  failure: { b -> a: error {style.stroke: red} }
}
steps: {                  # each step inherits the previous one
  1: { a -> b }
  2: { b -> c }
}
```

Render one board with `--target layers.detail` / `--target scenarios.failure` / `--target steps.2`
(under a second, the way to check a step); `--target ''` is the root only. Multi-board files
animate with `--animate-interval` into one SVG; rendered statically without a target they produce
a directory of boards, so pass `--target ''` for a static picture of the root board. A shape with
`link: layers.detail` drills down in SVG.

Each board is laid out on its own: a shape or edge that first appears in a later step moves
everything else. The style file's `***` rules also re-apply on every board, so a `font-size`,
`bold` or `stroke-width` set on the root board falls back to the house value in the steps (fill,
stroke and opacity survive). Set those inside the step, or use a markdown heading for big text.

## Imports

```d2
...@_style           # spread: merge file contents here (paths relative to this file, no .d2)
...@shared/classes   # subdirectories are fine
x: @models           # regular import: the file becomes the value of x
y: @models.users     # partial import
```

Only `.d2` files can be imported. A leading dot in the path written after `@` is dropped by d2
(`...@.hidden/x` resolves to `hidden/x.d2`), so never import from a dot-directory. Where the
diagram itself lives does not matter: `.context/x.d2` importing `_style` beside it works.

## Comments

```d2
# line comment
"""
block comment
"""
```

## Frequent compile errors

- `"steps" is a reserved keyword`: keys such as `steps`, `layers`, `scenarios`, `vars`, `classes`,
  `style`, `shape`, `label`, `near`, `direction`, `constraint`, `icon`, `link`, `tooltip`, `width`,
  `height`, `grid-rows` are reserved; rename the object (`step1`, `stepsList`).
- `... is not a valid config`: an unknown key under `d2-config`; only `theme-id`, `dark-theme-id`,
  `sketch`, `layout-engine`, `pad`, `center`, `theme-overrides`, `dark-theme-overrides` and `data`
  are allowed.
- `maps must be terminated with }` on one line: use `;` between entries of an inline map.
- Edge to `api.handler` fails: the child must exist (declare it inside the container first) and the
  edge must use the full path from where it is written.
- Label with a colon (`POST: /x`) or a hash: quote the label.
- `direction` inside `steps`/`layers` boards must be set per board if it differs from the root.

## Problems only the render shows

`d2 validate` passes all of these; look at the picture.

- A `|md` line wraps and its second line is cut off: the text holds a glyph the sketch font lacks
  (`…`, arrows, emoji), which renders wider than d2 measured. Write `...`, `->`, `2 to N`. `·` is
  fine, and plain shape and edge labels are not affected.
- Some edges are thinner or not animated: an edge glob covers one arrow type (see Styles).
- Children ignore a container's `direction`: only TALA honours it (see Containers).
- `reserved keywords are prohibited in edges` at render time: a shape is named `top` or `left`,
  which are position keywords. Rename it (`upper`, `first`).

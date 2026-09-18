# D2 cheat sheet

The parts of D2 that are easy to get wrong, plus the constructs this plugin relies on. Run
`d2 validate FILE` after writing; errors are `file:line:col: message`.

## File layout used by this plugin

```d2
...@_style          # line 1: spread-import the shared style (theme, layout, sketch, pad, font)

direction: right    # up | down | left | right; also allowed inside a container

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
  style.animated: true    # flowing dashes, SVG only
  target-arrowhead: {shape: diamond; style.filled: false}
  source-arrowhead.shape: cf-many
}
(a -> b)[0].style.stroke: red   # refer to an existing edge by index
```

Arrowheads: `triangle` (default), `arrow`, `diamond`, `circle`, `box`, `cf-one`, `cf-many`,
`cf-one-required`, `cf-many-required`, `cross`, `none`.

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

Containers inherit `direction` from the root unless set inside them.

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
`**.style.font: mono` (all descendants), `(* -> *)[*].style.animated: true` (all edges at this
level), `*.shape: circle`.

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
`bottom-center`, `bottom-right`. Typical use: a title or legend `{near: top-center}`. `x.near: y`
places `x` beside another shape (`x` must be at the root level).

## Icons and images

```d2
s3: Bucket {icon: https://icons.terrastruct.com/aws%2FStorage%2FAmazon-Simple-Storage-Service-S3.svg}
logo: {shape: image; icon: ./logo.png}
```

Remote icons are fetched at render time (network needed). Local paths are relative to the `.d2`
file and are embedded in the output.

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
Repo -> Store: {target-arrowhead.shape: triangle}   # inheritance style
```

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

No edges between cells; use a grid to lay out cards, not graphs.

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

Render one board with `--target layers.detail` / `--target scenarios.failure` / `--target steps.2`;
`--target ''` is the root only. Multi-board files animate with `--animate-interval` (gif or
animated svg); rendered statically without a target they produce a directory of boards, so pass
`--target ''` for a static picture of the root board. A shape with `link: layers.detail` drills
down in SVG.

## Imports

```d2
...@_style           # spread: merge file contents here (paths relative to this file, no .d2)
...@shared/classes   # subdirectories are fine
x: @models           # regular import: the file becomes the value of x
y: @models.users     # partial import
```

Only `.d2` files can be imported. A leading dot in the path is dropped by d2 (`...@.hidden/x`
resolves to `hidden/x.d2`), so never place a shared file in a dot-directory.

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

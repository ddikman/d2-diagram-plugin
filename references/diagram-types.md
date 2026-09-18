# Which diagram, when

Pick the diagram from the question the reader has, not from the data you happen to have. One
diagram answers one question; when a request mixes two, make two diagrams.

| The reader wants to know | Diagram | D2 construct | Layout notes |
|---|---|---|---|
| What happens in what order (process, pipeline, decision path) | Flowchart | Shapes and `->` edges, `direction: down` (or `right` for pipelines), `shape: diamond` for decisions, `shape: oval` for start/end | dagre; keep one main path top-to-bottom |
| What the system is made of and what talks to what | Architecture / container diagram | Nested containers for boundaries, `shape: cylinder` (db), `queue`, `cloud`, `person`, `classes` for repeated roles, optional icons | elk for orthogonal edges in busy diagrams; `blueprint`/`c4` presets |
| C4 context or container view | C4 | Same as above with the `c4` preset (theme 303), `shape: c4-person` for actors, containers per system | elk |
| Who calls whom, in which order, with what result | Sequence diagram | `shape: sequence_diagram`; actors in order of first mention; messages `a -> b: label`; `group` for loops/alt; spans (`a.t1 -> b.t1`); notes (`a."text"`) | layout engine ignored; keep to about 12 messages, split longer flows |
| How data is structured and related | ER diagram | `shape: sql_table` per table, `constraint: primary_key|foreign_key|unique`, relations `orders.user_id -> users.id` | dagre; `direction: right` for wide schemas |
| Types, interfaces, inheritance | Class diagram | `shape: class`, `+field: type`, `-method(arg): ret`, edges with `target-arrowhead.shape: triangle` for inheritance, `diamond` for composition | dagre |
| Lifecycle, modes, transitions | State diagram | Plain shapes for states, `shape: circle` for initial/final, labelled edges for events, `style.stroke-dash` for optional transitions | dagre, `direction: right` |
| Where something sits in a hierarchy (org, taxonomy, file tree) | Tree | Nesting or edges, `direction: down` | dagre |
| Compare options side by side, a matrix, a dashboard | Grid | `grid-rows` / `grid-columns` on a container, `grid-gap`; cells are plain shapes with `|md` text | no edges inside grids |
| Anything "animated": data or traffic moving through the system, calls in order | Animated lines | One board, `style.animated: true` on the connections, numbered edge labels for order | SVG plus a still PNG; see the example below |
| The same system in several stages, and only when asked for a step-by-step walkthrough | Steps walkthrough | `steps: { 1: {...}; 2: {...} }`, each step inherits the previous; render with `--animate-interval` to svg | follow the walkthrough recipe below |
| Alternatives of one baseline (happy path vs error, before vs after) | Scenarios | `scenarios: { error: {...} }` inherits the root board | render one with `--target scenarios.error` or animate |
| Several views of one system (overview, detail) | Layers | `layers: { detail: {...} }` independent boards; `link: layers.detail` from an overview shape drills down in SVG | render `--target layers.detail` |

## When not to use D2

- Charts of numbers (bar, line, pie, timeseries): use a plotting tool or the dataviz skill.
- Gantt charts and timelines: D2 has no timeline shape; mermaid does.
- Pixel-exact UI mockups, maps, floor plans: D2 places shapes for you; it cannot reproduce a layout.
- Mind maps with hundreds of leaves: split into several diagrams or a tree per branch.

## Rules of thumb that keep diagrams readable

- Ten to thirty nodes per board. Beyond that, group into containers, then split into layers.
- Labels are three or four words. Long explanations go into `tooltip` (SVG hover) or a `|md`
  block next to the shape, not into the label.
- Edge labels are verbs or protocols ("enqueue", "gRPC", "POST /orders"), not sentences.
- One direction per diagram. Flows read top-to-bottom or left-to-right; do not mix.
- Group by ownership or deployment boundary, not by shape type. A container called "Databases" is
  rarely useful; "Payments team" or "AWS account" is.
- Distinguish with shape and edge style before colour: `style.stroke-dash` for async or optional,
  `style.multiple: true` for replicas, `style.3d` sparingly. The style file already chose the palette.
- Use a legend (`legend: |md ... | {near: bottom-right}`) only when a style carries meaning
  (dashed = async, for example).
- Prefer `elk` when many edges cross or when the reader expects straight, orthogonal lines
  (architecture, infra). Prefer `dagre` for flows and trees; it is faster and more compact.

## Three small examples

### Request flow (architecture, `direction: right`)

```d2
...@_style

direction: right

user: Customer {shape: person}
web: Web app
api: Orders API {
  handler: Handler
  validator: Validator
  handler -> validator: check
}
db: Postgres {shape: cylinder}
queue: Events {shape: queue}

user -> web: browse
web -> api.handler: POST /orders
api.handler -> db: insert
api.handler -> queue: order.created {style.stroke-dash: 3}
```

### Data model (`sql_table`)

```d2
...@_style

direction: right

users: users {
  shape: sql_table
  id: uuid {constraint: primary_key}
  email: text {constraint: unique}
}
orders: orders {
  shape: sql_table
  id: uuid {constraint: primary_key}
  user_id: uuid {constraint: foreign_key}
  total: numeric
}
orders.user_id -> users.id
```

### Animated flow (one board, the lines move)

```d2
...@_style

direction: down

backend: Backend {
  tokens: Token endpoint
}
phone: Phone {
  cache: Credential cache
  speech: Speech service
}
provider: Speech provider {shape: cloud}

# "<-" keeps Backend on top although the request points up.
phone.cache <- phone.speech: 1 · get credential
backend.tokens <- phone.cache: 2 · mint
backend.tokens -> phone.cache: 3 · credential
phone.cache -> phone.speech: 4 · credential
phone.speech -> provider: 5 · open socket {style.stroke: "#8cc63f"}

(** -> **)[*].style.animated: true
(** <- **)[*].style.animated: true
```

Render `d2 x.d2 x.svg` for the animation and `d2 x.d2 x.png` for the still. One board means one
layout, so nothing can jump, and the SVG stays under 200 KB (a `|md` block adds about 40 KB of
embedded fonts).

## Step-by-step walkthrough (only when asked for one)

A walkthrough is several boards shown one after the other, so everything that differs between
boards shows up as a glitch. The rules that keep it steady:

- **Ghost first.** Put the whole picture on the root board: every shape, and every edge with
  `style.opacity: 0.15` written on the edge itself. Steps only restyle
  (`(a -> b)[0].style.opacity: 1`) and never add anything, so every board has the same layout.
- **Caption** as `caption: |md # ... | {near: top-center}`, re-assigned in each step. A heading
  sizes itself; a `font-size` override would be lost in the steps. Keep it narrower than the
  diagram: a wider caption widens that one board and the picture jumps.
- **Steps inherit everything**, labels and styles included. Switch off what no longer applies
  (`style.animated: false`, a changed label back to its original), above all in the closing step.
- **A highlight must differ from the shape's default fill**: `stored_data` is already pink and
  cylinders orange, so lighting them up in those colours changes nothing.
- **Check every board before animating:** `d2 --target 'steps.2' x.d2 x-step2.png` takes under a
  second. Read each one, confirm they are all the same size, then delete them by exact name (in
  zsh an unmatched glob aborts the whole command).
- **Render** `d2 --animate-interval 3000 x.d2 x.svg`; three seconds gives time to read a caption.

```d2
...@_style

direction: right

caption: |md
  # Cache-aside read
| {near: top-center}

client: Client {shape: person}
api: API
cache: Cache {shape: stored_data}
db: Postgres {shape: cylinder}

# The whole picture is on the root board as a ghost; steps only restyle it, so nothing moves.
client -> api: request {style.opacity: 0.15}
api -> cache: lookup {style.opacity: 0.15}
api -> db: query {style.opacity: 0.15}
client <- api: response {style.opacity: 0.15}

steps: {
  1: {
    caption: |md
      # 1 · The client asks the API
    |
    (client -> api)[0].style.opacity: 1
    (client -> api)[0].style.animated: true
  }
  2: {
    caption: |md
      # 2 · Miss: read the database
    |
    (client -> api)[0].style.animated: false
    (api -> cache)[0].style.opacity: 1
    (api -> db)[0].style.opacity: 1
    (api -> db)[0].style.animated: true
  }
  3: {
    caption: |md
      # 3 · The answer goes back
    |
    (api -> db)[0].style.animated: false
    (client <- api)[0].style.opacity: 1
    (client <- api)[0].style.animated: true
  }
}
```

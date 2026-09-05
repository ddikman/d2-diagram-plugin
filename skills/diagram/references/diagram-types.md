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
| The same system in several stages (build-up, rollout, migration) | Steps animation | `steps: { 1: {...}; 2: {...} }`, each step inherits the previous; render gif or animated svg | see output-formats.md |
| Alternatives of one baseline (happy path vs error, before vs after) | Scenarios | `scenarios: { error: {...} }` inherits the root board | render one with `--target scenarios.error` or animate |
| Several views of one system (overview, detail) | Layers | `layers: { detail: {...} }` independent boards; `link: layers.detail` from an overview shape drills down in SVG | render `--target layers.detail` |
| Data or traffic flowing through a static picture | Animated edges | `style.animated: true` on the connections | SVG only |

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

### Walkthrough as steps (animated)

```d2
...@_style

direction: right

steps: {
  1: {
    client -> api: request
  }
  2: {
    api -> cache: lookup {style.stroke-dash: 3}
  }
  3: {
    api -> db: query
    db -> api: rows
  }
  4: {
    api -> client: response
  }
}
```

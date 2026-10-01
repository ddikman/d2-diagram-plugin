# Which diagram, when

Pick the diagram from the question the reader has, not from the data you happen to have. One
diagram makes one argument; when a request mixes two questions, make two diagrams.

## The shortlist

Nine types answer most questions: my everyday three, then six more worth knowing. Each has a
worked example in this skill's `diagrams/` folder, all of one online shop called Pantry. Read the
matching one before writing: it shows the layout, the highlight and the labels that hold up in the
house style.

"An architecture diagram" names no question. Ask which one it answers: what is in scope (C4
system context), what the parts are (component), where it runs (deployment), or where live
traffic goes (service dependency map).

### My everyday three

**Sequence** · `sequence.d2`
- Shows: actions between people, components or systems over time.
- Use when: walking through a request, an integration or a handshake, call by call.
- Skip when: the order does not matter (component, C4 system context).
- D2: `shape: sequence_diagram`; declare the actors first, in the order they should appear; one
  `a -> b: label` per message, about a dozen at most. The layout engine is ignored.

**Flow** · `flow.d2`
- Shows: decisions and branching.
- Use when: the reader needs the rules: what happens when, and where the paths split.
- Skip when: nothing branches (process).
- D2: `direction: down`; `shape: oval` for start and end, `shape: diamond` for each question with
  its answers on the outgoing edges (`yes` and `no`, or one edge per outcome); dagre.

**Process** · `process.d2`
- Shows: a simple process, left to right.
- Use when: the steps are fixed and their order is the story: fulfilment, onboarding, a release.
- Skip when: something branches (flow) or two parties trade messages (sequence).
- D2: `shape: step` chevrons in a root grid (`grid-rows: 1`) with no edges: the order is the
  picture. Past five steps, `grid-columns: 4` wraps them into rows instead of widening the picture.

### Six more worth knowing

**C4 system context** · `c4-context.d2`
- Shows: your system as one box, among the people and external systems it talks to.
- Use when: onboarding, scoping a project, or telling non-technical people what is in and out of
  scope.
- Skip when: you need to show anything inside the system (component).
- D2: the system is one highlighted shape, `shape: person` for people, external systems dashed
  and pale; `direction: right`.

**Deployment** · `deployment.d2`
- Shows: where software runs: regions, availability zones, clusters, databases, replicas.
- Use when: discussing infrastructure, availability, failover or cost.
- Skip when: the question is how the code is structured (component).
- D2: nested containers for the region and the cluster, `shape: cylinder` for databases,
  `style.multiple: true` with `×3` in the label for replicated services, the zone as a second label
  line (a container per zone once a zone holds more than one thing). `direction: down`: the chain
  from users to replica is too long to run sideways. `label.near: top-left` on the containers
  keeps their labels clear of the incoming edge.

**Component** · `component.d2`
- Shows: the building blocks inside a system and the interfaces between them.
- Use when: defining boundaries and dependencies between modules or services, or checking who
  depends on whom.
- Skip when: you need data-level detail (class) or runtime behaviour (sequence).
- D2: one box per component with the UML component icon in its corner (the example's `component`
  class; copy `_component-icon.svg` from this skill's `diagrams/` folder next to the diagram), the
  interface name as the edge label; a solid edge for a call into the component's own API, dashed
  for a dependency on another's interface (the UML convention); `direction: right`.

**Class** · `class.d2`
- Shows: entities, their fields and methods, and the relationships and cardinality between them.
- Use when: agreeing on a domain model or data model before building.
- Skip when: the audience does not care about the code model; it gets noisy fast. For the tables
  of an existing database, draw an ER diagram (below).
- D2: `shape: class` with `-field: Type` and `+method()`; cardinality as arrowhead labels
  (`source-arrowhead: 1`, `target-arrowhead: "0..*"`); composition as a filled diamond on a `<-`
  edge; inheritance as a hollow triangle. elk, `direction: right`.

**Sitemap** · `sitemap.d2`
- Shows: the page hierarchy of a site or app, including routes.
- Use when: planning navigation and information architecture, or aligning design and engineering
  on screens and URLs.
- Skip when: you need the user's path between screens (flow).
- D2: `--` lines from parent to child (hierarchy, not arrows, so they carry no labels), the route
  of the page under discussion as a second label line; `direction: down`, elk for square tree lines.

**Service dependency map** · `service-dependency-map.d2`
- Shows: live services, the traffic between them, and where errors or latency sit.
- Use when: debugging an incident, finding bottlenecks and blast radius.
- Skip when: you want the intended architecture rather than observed reality (component).
- D2: small `shape: circle` services with the name underneath
  (`label.near: outside-bottom-center`), edges labelled with rates, error rates or latency, the
  failing path highlighted; `direction: right`, dagre. It usually comes from tracing or APM data:
  draw from the numbers I give you, and when I give none, ask for them rather than invent them.

## Beyond the shortlist

| The reader wants to know | Diagram | D2 construct | Layout notes |
|---|---|---|---|
| How the tables of a database relate | ER diagram | `shape: sql_table` per table, `constraint: primary_key` (or `foreign_key`, `unique`), relations `orders.user_id -> users.id` | dagre; `direction: right` for wide schemas |
| Lifecycle, modes, transitions | State diagram | Plain shapes for states, `shape: circle` for initial/final, labelled edges for events, `style.stroke-dash` for optional transitions | dagre, `direction: right` |
| Where something sits in a hierarchy (org, taxonomy, file tree) | Tree | The sitemap recipe: `--` lines from parent to child | elk, `direction: down` |
| Compare options side by side, a matrix, a dashboard | Grid | `grid-rows` / `grid-columns` on a container, `grid-gap`; cells are plain shapes or markdown blocks | no edges inside grids |
| Anything I ask to be "animated": data or traffic moving through the system | Animated lines | One board, `style.animated: true` on the connections, numbered edge labels for order | SVG plus a still PNG; see the example below |
| The same system in several stages, and only when asked for a step-by-step walkthrough | Steps walkthrough | `steps: { 1: {...}; 2: {...} }`, each step inherits the previous; render with `--animate-interval` to svg | follow the walkthrough recipe below |
| Alternatives of one baseline (happy path vs error, before vs after) | Scenarios | `scenarios: { error: {...} }` inherits the root board | render one with `--target scenarios.error` or animate |
| Several views of one system (overview, detail) | Layers | `layers: { detail: {...} }` independent boards; `link: layers.detail` from an overview shape drills down in SVG | render `--target layers.detail` |

## When not to use D2

- Charts of numbers (bar, line, pie, timeseries): use a plotting tool or the dataviz skill.
- Gantt charts and timelines: D2 has no timeline shape; mermaid does.
- Pixel-exact UI mockups, maps, floor plans: D2 places shapes for you; it cannot reproduce a layout.
- Mind maps with hundreds of leaves: split into several diagrams or a tree per branch.

## Rules of thumb that keep diagrams readable

- **Highlight the one thing the diagram is about**, and nothing else: a brick red outline and
  label, `{style.stroke: "#c8401f"; style.font-color: "#c8401f"}`, and the same on the edges of a
  path. On `class` and `sql_table` shapes use `style.fill: "#c8401f"`; there `style.stroke` floods
  the rows.
- **Label every arrow** with a verb, a protocol or a number ("enqueue", "POST /orders", "620 rps"),
  not a sentence. Lines that only show hierarchy (`--` in a tree) need none.
- **One abstraction level per diagram.** The system as one box and its classes do not share a
  picture; draw two and link them.
- **Link the diagram from where it is used**: embed it in the doc, ticket or PR it explains.
- At most about thirty nodes per board. Beyond that, group into containers, then split into layers.
- Labels are three or four words. Long explanations go into `tooltip` (SVG hover) or a `|md`
  block next to the shape, not into the label.
- One direction per diagram. Flows read top-to-bottom or left-to-right; do not mix.
- Group by ownership or deployment boundary, not by shape type. A container called "Databases" is
  rarely useful; "Payments team" or "AWS account" is.
- Distinguish with shape and edge style before colour: `style.stroke-dash` for async or optional,
  `style.multiple: true` for replicas, `style.3d` sparingly. Systems outside our control are dashed
  and pale, `{style.stroke-dash: 5; style.fill: "#fbfaf6"}`. The style file already chose the
  palette.
- A colour that sorts shapes into kinds (added, changed or untouched; one team's or another's)
  gets a small legend built from the same classes as the shapes; see the recipe below. The single
  highlight and dashed externals need none on their own.
- Prefer `elk` when many edges cross or when the reader expects straight, orthogonal lines (class
  diagrams, trees). Prefer `dagre` for flows and small graphs; it is faster and more compact.

## Legend (colour that sorts shapes into kinds)

A colour that marks a kind of shape (what a PR adds or changes, which team owns what, what is
still planned) means nothing until the reader is told. The legend is a small key, a swatch and its
meaning per row, drawn from the same classes as the picture so it cannot drift from it:

- **One class per kind**, named for its meaning, the plain default included. Every class sets
  `style.fill`: a swatch inside the legend otherwise turns the darker teal of nested shapes, not
  the colour of the root shapes it stands for. On a component diagram the shapes take both
  classes, `class: [component; changed]`.
- **Keep it small and quiet**, so it does not compete with the picture: a 24 px swatch per kind
  with its meaning beside it as `shape: text` in 16 px plain, in an untitled container
  (`legend: ""`; the swatches explain themselves) on the paper fill `#f3f1ea` with a 1 px frame.
  Left alone, a container is yellow with a heavy outline and reads as a group.
  `grid-rows`, one per kind, comes before `grid-columns: 2`; the other way round, the swatches
  fill one column and the labels the next.
- **Write it last and leave `near` off.** The layout tucks it into free space beside the first
  row (under the first column in `direction: right`). If it lands against an edge,
  `near: top-right` moves it to the corner outside the picture, which makes the canvas wider and
  taller.
- **Once there is a legend, every style in the picture has a row**, the highlight and dashed
  externals included.

```d2
...@_style

direction: down

classes: {
  added: {style.fill: "#6ccbd8"; style.stroke: "#c8401f"; style.font-color: "#c8401f"}
  changed: {style.fill: "#fbd3c9"}
  untouched: {style.fill: "#6ccbd8"}
  external: {style.stroke-dash: 5; style.fill: "#fbfaf6"}
}

ui: Checkout UI {class: changed}
orders: Orders {class: changed}
giftcards: Gift cards {class: added}
inventory: Inventory {class: untouched}
stripe: Stripe {class: external}

ui -> orders: place order
orders -> giftcards: redeem card
orders -> inventory: reserve
orders -> stripe: charge the rest

# The key, written last and untitled: one row per class, a swatch and its meaning.
legend: "" {
  grid-rows: 4
  grid-columns: 2
  grid-gap: 10
  style: {fill: "#f3f1ea"; stroke-width: 1}
  *.style.font-size: 16
  *.style.bold: false
  added: "" {class: added; width: 24; height: 24}
  added-label: Added {shape: text}
  changed: "" {class: changed; width: 24; height: 24}
  changed-label: Changed {shape: text}
  untouched: "" {class: untouched; width: 24; height: 24}
  untouched-label: Untouched {shape: text}
  external: "" {class: external; width: 24; height: 24}
  external-label: External {shape: text}
}
```

## Animated flow (one board, the lines move)

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

# dagre ranks by the arrowheads: the reply (3) points down, so Backend stays on top.
phone.speech -> phone.cache: 1 · get credential
phone.cache -> backend.tokens: 2 · mint
backend.tokens -> phone.cache: 3 · credential
phone.cache -> phone.speech: 4 · credential
phone.speech -> provider: 5 · open socket {style.stroke: "#8cc63f"}

(** -> **)[*].style.animated: true
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

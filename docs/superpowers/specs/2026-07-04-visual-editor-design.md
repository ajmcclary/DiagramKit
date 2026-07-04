# Visual Flowchart Editor — Design

**Date:** 2026-07-04
**Status:** Approved (brainstorming cycle)
**Scope:** Full visual editing of flowcharts in the DiagramKit sample app —
shapes, connections, colors, labels, subgraphs, icons, images, layout
rearrangement, and themes — with bidirectional sync to Mermaid source.

## Goal

The Visual Editor lets you build and edit flowcharts by clicking — shapes,
connections, colors, labels — without writing syntax. The Mermaid source
updates automatically as you work, and source edits are reflected back on the
canvas. Both editors are always available and stay in sync.

## Current State (what already exists)

The hard infrastructure is already built and tested:

- `DiagramKitInteractive.DiagramEditor` — atomic mutations
  (`perform`/`performFlowchart` → `_commitMutation`), snapshot-based
  undo/redo, export-validated commits, `syncSource()`.
- Existing flowchart mutations: `insertNode`, `insertEdge`,
  `groupIntoSubgraph`, `setEdgeStyle`, plus cross-family `deleteElement`,
  `setLabel`, `setTitle`.
- Sample-app visual canvas (`FlowchartEditCanvas`): tap-select via
  `DiagramBoundsLookup`, double-tap popovers, marquee multi-select,
  drag-to-connect edges, `VisualToolPalette`
  (select/pan/marquee/connector/undo/redo/group).
- Bidirectional sync loop in `LiveEditorStore`: mutation → export →
  `setSource(origin: .mutation)` (suppresses editor re-seed so undo
  survives); source edit → re-parse → editor re-seed with selection
  preserved. **This convention must be preserved.**
- Model completeness: `MermaidGraph` carries `classDefs`,
  `classAssignments`, `nodeStyles`, `linkStyles`; `NodeShape` has ~70 cases
  incl. `icon`/`iconCircle`/`iconRounded`/`iconSquare`/`imageSquare`;
  `MermaidNode.properties.icon` exists; the parser handles v11
  `@{ shape:, icon:, img:, ... }` metadata (`src_flow_metadata.swift`).
- Mermaid flowchart exporter emits classDefs/class/style/linkStyle and 14
  classic shape markers; non-classic shapes currently downgrade with a
  `.lossyTransform(.shapeDowngrade)` diagnostic.
- Theme infrastructure: `ThemeName` catalog in `DiagramKitCommon`,
  frontmatter `theme`/`look` keys parsed (`SharedFrontmatter`), sample-app
  `ThemePicker` (display-only today).
- One layout engine: ported ELK layered (`ElkLayoutOptions`,
  `src_layout_factory.swift`).

## Gaps this design closes

1. No mutations for changing an existing node's shape, colors, border, or
   class assignment (the `NodeEditPopover` shape picker and style chips are
   dead UI).
2. No shape-catalog toolbar (browse basic/process/technical, click to add).
3. No empty-subgraph insertion, no drag-into-boundary membership change, no
   forward ungroup/rename.
4. No icon browser or image-URL nodes.
5. No layout rearrange options.
6. Theme selection does not persist into the source.
7. No right-click context menus.

## Decisions (from brainstorming)

| Question | Decision |
| --- | --- |
| Scope | Everything in the feature spec (all seven clusters) |
| classDef strategy | Deduplicated generated classes (`vs1`, `vs2`, …) shared by identical styles; orphans GC'd |
| Icon vocabulary | Font Awesome only (bundled tables; serializes `fa:<name>`, mermaid-js-portable) |
| Image rendering | Deterministic placeholder in core renderers; async fetch + composite in the view layer only |
| Rearrange "Adaptive" | Same ELK engine with a different option preset; persisted via frontmatter |
| Theme persistence | Written to YAML frontmatter `config.theme` (round-trips); app picker stays as view-only override |
| Platform | macOS sample app this cycle; mutation layer is platform-neutral |
| Drag-to-group | Drop-to-join: release inside a boundary fires a membership mutation; auto-layout recomputes and the node animates to its computed position |
| Architecture | Extend in place: mutations + `StyleClassManager` in `DiagramKitInteractive`, targeted exporter/renderer fixes, all UI in the sample app |

## Section 1 — Mutation layer (`DiagramKitInteractive`)

New `FlowchartMutation` cases, all riding the existing
`performFlowchart → _commitMutation` path (atomic, undo-snapshotted,
export-validated):

| Mutation | Effect |
| --- | --- |
| `setNodeShape(of: DiagramSelection, to: NodeShape)` | Rewrites the node's `shape` |
| `setNodeStyle(of: DiagramSelection, to: NodeStyleSpec)` | Routes through `StyleClassManager` (Section 2) |
| `setNodeIcon(of: DiagramSelection, to: IconSpec?)` | Sets `properties.icon`, icon shape variant, size, label position; `nil` clears |
| `setNodeImage(of: DiagramSelection, to: ImageSpec?)` | Sets image URL, display size, title; shape becomes `imageSquare`; `nil` clears |
| `insertSubgraph(title: String)` | Inserts an empty labeled subgraph |
| `moveToSubgraph(selections: [DiagramSelection], target: String?)` | Re-parents membership; `nil` target = move to root |
| `ungroupSubgraph(id: String)` | Dissolves a subgraph, promoting members to its parent (forward "flatten") |
| `renameSubgraph(id: String, title: String)` | Retitles; stable id preserved |
| `setEdgeArrowheads(edgeId: String?, source: String, target: String, start: ArrowHeadType, end: ArrowHeadType)` | Sets per-end arrowhead types |

New document-level `DiagramMutation` cases (frontmatter writes; flowchart
wired this cycle, mechanism family-neutral):

- `setTheme(ThemeName?)` — writes/clears frontmatter `config.theme`.
- `setLayoutPreset(LayoutPreset)` — `.hierarchical` / `.adaptive` →
  frontmatter `layout:` key.

**`NodeStyleSpec`** (typed style value): optional `fill`, `stroke`,
`textColor` colors + `borderStyle` (`solid` / `dashed` / `thick`), mapping
1:1 onto classDef properties (`fill:`, `stroke:`, `color:`,
`stroke-dasharray:` / `stroke-width:`).

**`IconSpec`**: FA icon name, size (S/M/L → `h` property), background shape
(`icon` / `icon-circle` / `icon-rounded` / `icon-square`), label position
(`pos: t|b`). **`ImageSpec`**: URL, display width/height, optional title.

**Exporter enhancement** (the one substantive model-layer change):
`MermaidFlowchartExport` emits `@{ shape: <name> }` for non-classic
`NodeShape` cases instead of downgrading, and emits `@{ icon:, img:, w:,
h:, pos:, label: }` from `NodeProperties`. This makes the full shape / icon
/ image vocabulary round-trip faithfully and removes the shape-downgrade
lossy path (expected-loss registry shrinks accordingly).

Error contract unchanged: unknown selection → `.elementNotFound`,
non-flowchart payload → `.notAFlowchart`, diagnostics only via the typed
factories per docs/diagnostic-severity-discipline.md.

## Section 2 — `StyleClassManager` (deduplicated classDefs)

A pure, testable helper in `DiagramKitInteractive`. Given
`(MermaidGraph, nodeID, NodeStyleSpec)` it returns an updated graph:

1. **Normalize** the spec to a canonical classDef property map (sorted keys,
   lowercase hex) so equal styles hash equal.
2. **Find-or-create**: reuse an existing generated class (`vs1`, `vs2`, …)
   with the exact property map, else mint the lowest free `vsN` not
   colliding with any user-authored classDef name.
3. **Reassign**: remove the node from its previous *generated* class
   assignment; add `:::vsN`.
4. **Garbage-collect**: delete any generated class with zero remaining
   assignments.

Boundary rules:

- **User-authored classes are never edited or GC'd.** A visual style edit on
  a node styled by a hand-written class moves that node to a generated
  class; the user classDef stays intact for other members.
- **Inline `style A ...`** on a visually edited node migrates to a generated
  class and the inline entry is removed, with an `.informational`
  diagnostic noting the migration.
- **Effective-style resolution** seeds the node menu: inline style →
  assigned classes (last wins, matching mermaid-js) → theme default.
- Naming is deterministic (lowest free index): identical edit sequences
  produce identical source.

Generated-class detection: a classDef is "generated" iff its name matches
`^vs[0-9]+$`. A user who hand-writes a `vs3` class is treated as generated
by this rule; the deterministic-naming and GC semantics still produce valid
output (documented, acceptable).

## Section 3 — Center toolbar & shape catalog (sample app)

New **`CanvasCenterToolbar`** floating bottom-center of
`FlowchartEditCanvas` (existing `VisualToolPalette` stays at left):
**Shapes ▸ · Subgraph · Icon · Image · Rearrange ▸ · Theme ▸**.

**Shape catalog popover** — searchable grid, grouped:

- **Basic** — rectangle, rounded, stadium, circle, double circle, diamond,
  hexagon, ellipse.
- **Process** — cylinder, subroutine, parallelogram / parallelogram-alt,
  trapezoid / trapezoid-alt, document / multi-document, asymmetric, delay,
  display.
- **Technical** — v11 architecture set: cloud, das/queue, cross, fork/join,
  lightning, hourglass/collate, stored data, internal storage, junction,
  and the remaining exporter-faithful `NodeShape` cases.

Cells render true vector previews reusing the shape path builders
(`src_shape_clipping.swift`). Click → `insertNode` with the next free id
and placeholder label; node is auto-selected and the label editor opens
immediately (click, type, done).

**Node menu** — `NodeEditPopover` rebuilt to the full spec surface:

- Shape — current-shape button opening the catalog (fires `setNodeShape`).
- Border — solid / dashed / thick segmented control.
- Border color, Background color, Text color — `ColorPicker` wells + theme-
  harmonized presets, seeded from resolved effective style.
- Label + sub-label (existing), Delete (existing).

All style controls commit via `setNodeStyle` → `StyleClassManager`; the
source diff for a color change is exactly the `:::vsN` assignment plus its
`classDef` line.

**Edge menu** — `EdgeEditPopover` gains start/end arrowhead pickers
(`setEdgeArrowheads`) beside the existing line-style control.

**Right-click context menus** —
node: Edit…, Change shape ▸, Move to subgraph ▸, Delete;
edge: Edit…, Delete;
multi-selection: Group into subgraph…, Delete N elements (one undo group
via existing `beginUndoGrouping`/`endUndoGrouping`);
subgraph: Rename…, Ungroup, Delete;
empty canvas: Add shape ▸, Add subgraph.

## Section 4 — Subgraph UX

- Toolbar **Subgraph** button → `insertSubgraph(title:)` (empty group).
- **Drag-to-join**: dragging a node (select tool) shows a ghost; subgraph
  boundaries highlight on hover. Release inside a boundary →
  `moveToSubgraph`; release on empty canvas from inside a subgraph →
  `moveToSubgraph(target: nil)`. Layout recomputes; the node animates from
  ghost position to its computed position. A drop that changes nothing is a
  no-op (no mutation, no undo entry).
- **Ungroup** promotes children to the parent scope and removes the
  subgraph.

## Section 5 — Icons & images

**Icon browser** (toolbar Icon button): searchable grid over the bundled
Font Awesome tables (`src_font_awesome.swift`), matching name + aliases.
Click → insert node with `@{ icon: "fa:<name>" }`. Node menu icon controls:
size (S/M/L), background shape (bare / circle / rounded / square),
background color (`fill`) and icon color (`color`) via `setNodeStyle`,
label position. CG and SVG
icon-shape rendering completed where gaps exist (FA glyph + background
shape in both renderers).

**Image nodes** (toolbar Image button): sheet with URL, display
width/height, optional title → `A@{ img: "https://…", w: 200, h: 150,
label: "Title" }`. Core renderers draw a deterministic framed placeholder
(photo glyph + title) at the declared size — parse/layout/render stays
offline and snapshot-stable; SVG export emits `<image href>`. The sample-app
canvas fetches asynchronously (in-memory `URLSession` cache) and composites
the bitmap over the placeholder rect on screen. Fetch failure keeps the
placeholder with a small badge. **No network in the core pipeline, ever.**
Mutation-time URL validation checks scheme/shape only — never fetches.

## Section 6 — Rearrange & themes

**Rearrange popover**: two cards with mini schematics.

- **Hierarchical** — current ELK layered defaults (orthogonal routing,
  strict model order). Default; frontmatter omitted unless switching back.
- **Adaptive** — same engine, preset for connection-dense flows: spline
  edge routing, relaxed model-order strategy, balanced compaction.
  Frontmatter `layout: adaptive`.

`ElkLayoutOptions` gains a `preset` parameter;
`FrontmatterBinding+Flowchart` maps the `layout:` key onto it. The choice
round-trips like any other source content. mermaid-js ignores unknown
`layout:` values gracefully (compatibility note).

**Theme picker**: toolbar Theme ▸ shows the `ThemeName` catalog as rendered
swatches. Selection fires `setTheme` → frontmatter `config.theme`. The
pipeline already resolves frontmatter themes at render time. The app-level
`ThemePicker` remains as a view-only override and shows a "source-pinned
theme" indicator when frontmatter wins.

## Section 7 — Error handling & testing

**Error handling**: atomic-commit contract preserved — a failed export
rolls back and surfaces through the existing `RenderFailedSheet` /
`QuickFixCard` paths. Icon names validated against the FA table at
mutation time (typed error; the browser only offers valid names). All new
diagnostics go through the typed factories and the discipline gate.

**Testing**:

- Model tests (swift-testing, `Tests/DiagramKitTests/Interactive/`):
  per-mutation suites following the existing pattern; undo round-trip per
  new mutation; `StyleClassManagerTests` covering dedup, reuse, GC,
  user-class protection, inline-style migration, deterministic naming.
- Round-trip: new corpus entries exercising `@{ shape: }`, icons, images,
  generated classDefs, and frontmatter theme/layout, gated through
  `RoundTripHarness`; shape-downgrade entries pruned from the expected-loss
  registry as the exporter becomes faithful.
- Snapshots: new corpus entries get SVG/image/ASCII baselines via the
  chunked `SNAPSHOT_DIAGRAM_IDS` recording flow.
- Store tests: `LiveEditorStore` wiring tests extended for the new flows.
  Canvas gestures remain untested by automation (consistent with today).

## Section 8 — Delivery decomposition

One spec → six implementation plans, each independently landable on main
(commit-by-commit, no branches, per repo convention):

1. **Styling core** — `setNodeShape` / `setNodeStyle` + `StyleClassManager`
   + exporter `@{ shape: }` & properties emission + rebuilt node menu.
2. **Shape catalog + insert flow** — center toolbar, catalog popover,
   insert-then-name flow.
3. **Subgraph UX** — `insertSubgraph` / `moveToSubgraph` /
   `ungroupSubgraph` / `renameSubgraph`, drag-to-join, right-click context
   menus.
4. **Icons** — browser, `setNodeIcon`, icon-shape render completion.
5. **Images** — `setNodeImage`, placeholder rendering, async view-layer
   fetch + composite.
6. **Rearrange + themes** — `LayoutPreset` + `ElkLayoutOptions` preset,
   frontmatter binding, `setTheme` / `setLayoutPreset`, both pickers.

Order matters: 1 unlocks 2–5 (exporter properties emission and node-menu
scaffolding); 6 is independent after 1's document-mutation plumbing.

## Non-goals (this cycle)

- iOS/iPadOS interaction adaptation (long-press menus, touch targets).
- Extracting the canvas UI into a reusable library target.
- A force-directed layout engine.
- SF Symbols icon vocabulary.
- Free-form node positioning (Mermaid source carries no coordinates;
  layout is always computed).
- Visual editing for families other than flowchart (sequence/gantt keep
  their existing editors).

## Invariant compliance

- No thread pools: all new mutations/export paths use the existing
  `_runOnWorker` / `DiagramWorkerThread` dispatch.
- Fonts registered at pipeline entry (unchanged).
- Two-renderer rule: CG and SVG icon/image/placeholder rendering
  implemented independently; snapshots are the guardrail.
- Typed payloads only; no `Any` casts.
- File-size policy: new files under 500 lines; split proactively
  (`StyleClassManager`, catalog data, toolbar views are separate files).

# treeView synthetic-root bridge — Mermaid ↔ {D2, DOT, PlantUML}

Status: draft (design only — implementation plan to follow).
Closes:
- Wave H deferral noted in [`COVERAGE.md`](../../../COVERAGE.md) — Mermaid ↔
  PlantUML treeView (`treeView × {mermaid↔plantuml}` directed pair).
- Silently-skipping Mermaid ↔ D2 and Mermaid ↔ DOT treeView fixtures present
  since Wave E (`.mermaid` extension not in
  `RoundTripFixtureLoader.sourceExtensions`).
- Underlying export-side bugs against the non-Mermaid root convention exposed
  once those fixtures load.

## Summary

`TreeViewDiagram.root` is overloaded: Mermaid's parser inserts a synthetic
container named `/` at `level: -1` to serve as a parse-time stack anchor
([`src_treeview_parser.swift:80`](../../../Sources/DiagramKitModel/src_treeview_parser.swift)),
and that synthetic container survives into the public payload. D2, DOT, and
PlantUML treeView importers do not use this convention — they set
`root` to the user-visible root at level 0
([`D2TreeViewMapper.swift:49`](../../../Sources/DiagramKitD2/D2TreeViewMapper.swift),
[`DOTTreeViewMapper.swift:48`](../../../Sources/DiagramKitGraphviz/DOTTreeViewMapper.swift),
[`PlantUMLWBSMapper.swift`](../../../Sources/DiagramKitPlantUML/WBS/PlantUMLWBSMapper.swift)).

This spec adopts a **documented canonical convention** for
`TreeViewDiagram.root`, updates the four cross-format exporters to honor it,
and extends the D2 and DOT importers to produce the convention on multi-root
input. The Mermaid parser, `PlantUMLWBSParser`, payload model, public API
surface, and same-format paths for single-root inputs are unchanged. The
Wave H deferral closes; the Mermaid ↔ D2 and Mermaid ↔ DOT cross-format
fixtures stop silently skipping and start round-tripping.

### Behavior change (called out)

Four exporters and two importers change behavior to make the canonical
convention bidirectional. None of the changes alter same-format round-trip
output; all of them fix cross-format round-trip output that is currently
broken (and currently hidden by the silent-skip).

**Exporters** (given a payload whose `root` does not match their importer's
native convention):

- **`MermaidTreeViewExport`** today walks `model.root.children`
  ([`MermaidTreeViewExport.swift:28-33`](../../../Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidTreeViewExport.swift)).
  Given a non-Mermaid payload whose `root` is the real user-visible node,
  this drops the root itself. Fixed below.
- **`D2TreeViewExporter`** today emits `tree.root.name` verbatim
  ([`D2TreeViewExporter.swift:23`](../../../Sources/DiagramKitD2/D2TreeViewExporter.swift)).
  Given a Mermaid payload with synthetic `/`, this emits a literal `/`
  node. Fixed below.
- **`DOTTreeViewExport`** today emits `tree.root.name` verbatim
  ([`DOTTreeViewExport.swift:20`](../../../Sources/DiagramKitGraphviz/DOTTreeViewExport.swift)).
  Same symptom as D2.
- **`PlantUMLTreeViewExporter`** today emits `diagram.root` directly
  ([`PlantUMLTreeViewExporter.swift:70`](../../../Sources/DiagramKitPlantUML/Exporter/PlantUMLTreeViewExporter.swift)).
  Given a Mermaid payload with synthetic `/`, this emits a literal `/`
  root. Fixed below.

**Importers** (D2/DOT only — PlantUML WBS syntax is single-root by grammar):

- **`D2TreeViewMapper`** today refuses multi-root input outright when no
  `treeRoot` marker pins a single root
  ([`D2TreeViewMapper.swift:47-57`](../../../Sources/DiagramKitD2/D2TreeViewMapper.swift)),
  and silently drops orphan zero-in-degree nodes when a marker IS present
  (the `build(rootID, …)` walk at `:75` only reaches the pinned root's
  subtree). Both behaviors are incompatible with the canonical convention.
  Fixed below — multi-root input synthesizes a `/` container at level -1.
- **`DOTTreeViewMapper`** has the same shape
  ([`DOTTreeViewMapper.swift:48-58`](../../../Sources/DiagramKitGraphviz/DOTTreeViewMapper.swift)).
  Same fix.

## Canonical convention

`TreeViewDiagram.root` represents the user-visible root structure with one
sentinel:

> A `root` with `name == "/"` AND `level == -1` is a synthetic multi-root
> container introduced by the Mermaid treeView parser to host two or more
> sibling roots declared at level 0. Its children are the user-visible roots.
> The container itself has no source counterpart.

All other importers produce a `TreeViewDiagram` whose `root` is the actual
user-visible root at level 0 — no synthetic container. Exporters detect the
convention on entry and emit accordingly.

This is documented as a doc-comment on `TreeViewDiagram` and `TreeViewNode`
in [`Sources/DiagramKitModel/src_treeview_types.swift`](../../../Sources/DiagramKitModel/src_treeview_types.swift).
No payload-model change. No public API addition.

## Out of scope

- **No Mermaid parser change.** The synthetic `/` insertion at
  `src_treeview_parser.swift:80` stays. The parser keeps emitting synthetic `/`
  whenever multi-root input is present (and currently also for single-root
  input — this spec does not optimize that away).
- **No payload model change.** No new fields on `TreeViewDiagram` or
  `TreeViewNode`, no new `roots:` array, no new enum case. The convention is
  carried by the existing `root.name == "/" && root.level == -1` pattern.
- **No new public API surface.**
- **No new `DiagnosticCategory` cases.** Reuse `.slotUnsupported`
  ([`DiagnosticCategory.swift`](../../../Sources/DiagramKitCommon/DiagnosticCategory.swift)),
  already used by `D2TreeViewMapper.swift:53` for related root-convention
  mismatches on import.
- **No `PlantUMLWBSParser` change.** WBS syntax permits a single `*` root by
  grammar — the parser stays single-root. (D2 and DOT mappers DO change; see
  §[D2/DOT importer changes](#5-d2treeviewmapperswift--dottreeviewmapperswift).)
- **No general D2/DOT mapper-logic change beyond the multi-root path.** The
  marker-pinning logic, the single-root fallback at
  `D2TreeViewMapper.swift:50`, and the label/edge accumulation stay as today.
- **No same-format Mermaid round-trip change.** Existing
  `mermaid-treeView/01-basic.md` round-trip output is byte-identical
  after this spec (the Mermaid exporter's synthetic-root branch matches
  today's behavior exactly).
- **No optimization of the synthetic-`/`-for-single-root case.** The Mermaid
  parser could in principle elide the synthetic container when only one root
  exists; this spec leaves that for a separate change to keep blast radius
  minimal.

## File-level changes

### 1. `MermaidTreeViewExport.swift`

Add convention detection at entry. Pseudocode:

```swift
let isSynthetic = (model.root.name == "/" && model.root.level == -1)
if isSynthetic {
    // existing behavior: walk root.children
    for child in model.root.children { emit(child, indent: 0) }
} else {
    // new branch: emit root as the first top-level entry, then descend
    emit(model.root, indent: 0)
}
```

Mermaid's flat treeView source syntax represents both single-root and
multi-root inputs natively (one or more top-level entries followed by
indented descendants). No diagnostic emitted in either branch.

### 2. `D2TreeViewExporter.swift`

Add convention detection at entry. Pseudocode:

```swift
let isSynthetic = (tree.root.name == "/" && tree.root.level == -1)
if isSynthetic {
    // forest emission: each child becomes a top-level D2 declaration
    // emitTreeRoot marker fires only for the first child (matches existing
    // single-root path; the importer's rootMarker hint stays meaningful for
    // the first declared root). Additional roots are zero-in-degree by
    // construction, so the importer's existing fallback (first
    // zero-in-degree node) selects the correct first root.
    for (i, child) in tree.root.children.enumerated() {
        if i == 0 { lines.append(D2RecoveryMarker.emitTreeRoot(child.name)) }
        emitNode(child, parent: nil, lines: &lines)
    }
} else {
    // existing behavior: emit root verbatim
    lines.append(D2RecoveryMarker.emitTreeRoot(tree.root.name))
    emitNode(tree.root, parent: nil, lines: &lines)
}
```

D2 supports forest natively (multiple zero-in-degree nodes coexist in a D2
document). No diagnostic emitted — forest emission is structurally lossless.

### 3. `DOTTreeViewExport.swift`

Same shape as D2:

```swift
let isSynthetic = (tree.root.name == "/" && tree.root.level == -1)
if isSynthetic {
    for (i, child) in tree.root.children.enumerated() {
        if i == 0 { lines.append(DOTRecoveryMarker.emitTreeRoot(child.name)) }
        emitNode(child, parent: nil, lines: &lines)
    }
} else {
    lines.append(DOTRecoveryMarker.emitTreeRoot(tree.root.name))
    emitNode(tree.root, parent: nil, lines: &lines)
}
```

DOT supports forest natively (multiple zero-in-degree nodes in a digraph).
No diagnostic emitted.

### 4. `PlantUMLTreeViewExporter.swift`

PlantUML WBS syntax permits exactly one `*` root per `@startwbs` block. The
exporter detects the convention and branches:

```swift
let isSynthetic = (diagram.root.name == "/" && diagram.root.level == -1)
let effectiveRoot: TreeViewNode
let droppedSiblings: [TreeViewNode]
if isSynthetic {
    let children = diagram.root.children
    if children.isEmpty {
        // synthetic with zero children — emit empty @startwbs / @endwbs
        // (degenerate; matches existing empty-tree behavior elsewhere)
        return emitEmpty()
    }
    effectiveRoot = children[0]
    droppedSiblings = Array(children.dropFirst())
} else {
    effectiveRoot = diagram.root
    droppedSiblings = []
}

// emit `* effectiveRoot.name` and descend (existing logic, parameterized)
emit(effectiveRoot, depth: 1)

// emit one diagnostic per dropped sibling
for sibling in droppedSiblings {
    diagnostics.append(.featureDropped(
        .slotUnsupported,
        message: "additional WBS root '\(sibling.name)' dropped " +
                 "(@startwbs supports a single root)"
    ))
}
```

`.featureDropped(.slotUnsupported, …)` matches the existing PlantUML treeView
drop pattern (WBS shape variants `<<arrow>>`/`<<separator>>`/`<<box>>` and
color suffixes already use this category per Wave H).

### 5. `D2TreeViewMapper.swift` / `DOTTreeViewMapper.swift`

The two mappers share the same shape; the change is parallel.

Today, both refuse multi-root and drop orphans (see §[Behavior
change](#behavior-change-called-out)). The fix: when multiple zero-in-degree
roots exist and no marker pins one, produce a canonical synthetic-`/`
payload. Pseudocode (D2; DOT is identical):

```swift
let roots = allNodes.subtracting(hasIncoming)
let rootMarker: String? = /* unchanged scan */

// NEW: structural multi-root takes precedence over the marker, since the
// marker only ever pins one root (and for forest exports, it pins the
// "first" child as an ordering hint, not as a single-root assertion).
if roots.count > 1 {
    // Determine deterministic emission order: alphabetical, but with the
    // marker-pinned root (if any) hoisted to the front so forest-export
    // round-trips preserve first-child ordering.
    var orderedRoots = roots.sorted()
    if let pinned = rootMarker,
       roots.contains(pinned),
       let idx = orderedRoots.firstIndex(of: pinned) {
        orderedRoots.remove(at: idx)
        orderedRoots.insert(pinned, at: 0)
    }
    let synthChildren = orderedRoots.map { build($0, level: 0) }
    let syntheticRoot = TreeViewNode(
        id: nextID, level: -1, name: "/", nodeType: .directory,
        children: synthChildren
    )
    nextID += 1
    allBuilt.append(syntheticRoot)
    return (TreeViewDiagram(root: syntheticRoot, nodes: allBuilt), diagnostics)
}

// EXISTING single-root paths, unchanged below.
if let pinned = rootMarker, allNodes.contains(pinned) {
    let root = build(pinned, level: 0)
    return (TreeViewDiagram(root: root, nodes: allBuilt), diagnostics)
}
if roots.count == 1 {
    let root = build(roots.first!, level: 0)
    return (TreeViewDiagram(root: root, nodes: allBuilt), diagnostics)
}
// roots.isEmpty: existing failure mode — falls back to flowchart
diagnostics.append(.featureDropped(
    .slotUnsupported,
    message: "TreeView requires at least one root; found 0. Falling back to flowchart."
))
return (nil, diagnostics)
```

Notes:

- **Branch order matters.** The multi-root path is checked FIRST. If the
  exporter emitted a forest with a `treeRoot` marker pinning the first
  child, the structural multi-root signal (`roots.count > 1`) wins and
  the multi-root path runs. The marker is then used purely as an
  ordering hint inside that path. The marker-pinned single-root path
  below only fires when structurally there is exactly one zero-in-degree
  node, which is the legitimate single-root case.
- **Pre-existing orphan-drop bug** in the marker-pinned single-root path
  is closed by the branch-order change: any input that previously
  silently dropped orphans (marker pinned + multiple zero-in-degree
  nodes) now lands in the multi-root path instead.
- **Determinism.** Swift `Set` iteration order is not stable across runs,
  so the multi-root path sorts alphabetically. The optional
  marker-driven hoist preserves the first-child order from
  forest-export round-trips. Same-format D2/DOT multi-root inputs
  (which did not previously round-trip at all) become deterministic.
- **Single-root behavior is byte-identical to today.** The two
  single-root branches below the new gate are unchanged from the
  current mapper.
- **`roots.isEmpty`** keeps its existing failure mode (cycles or empty
  graph fall back to flowchart). The multi-root branch is purely
  additive.

#### Why this is in scope

The mapper change is required for the canonical convention to be honest.
Without it, the convention is one-way (Mermaid produces synthetic `/`;
D2/DOT cannot), and Mermaid → D2 → Mermaid multi-root round-trip loses
all roots except the first regardless of any export-side wiring. The
mapper change is also small (~20 added lines per mapper, structurally
parallel) and removes the pre-existing silent orphan-drop bug.

## Test fixtures

### Rename silently-skipping fixtures

| Before | After |
|--------|-------|
| `cross-mermaid-d2-treeView/01-basic.mermaid` | `cross-mermaid-d2-treeView/01-basic.mmd` |
| `cross-mermaid-dot-treeView/01-basic.mermaid` | `cross-mermaid-dot-treeView/01-basic.mmd` |

Rationale: `RoundTripFixtureLoader.sourceExtensions` at
[`Sources/DiagramKitTestSupport/RoundTripFixtureLoader.swift:19`](../../../Sources/DiagramKitTestSupport/RoundTripFixtureLoader.swift)
is the canonical extension table (`md`, `mmd`, `d2`, `dot`, `gv`, `dsl`, `puml`,
`plantuml`). Two outliers are renamed to match; the loader contract is not
relaxed.

Delete the masking comment block at
[`CrossFormatRoundTripTests.swift:837-844`](../../../Tests/DiagramKitTests/RoundTrip/CrossFormatRoundTripTests.swift)
that documents the silent skip.

### New fixtures — single-root coverage

Mermaid ↔ PlantUML treeView pair (closes Wave H deferral):

| Path | Format | Purpose |
|------|--------|---------|
| `cross-mermaid-plantuml-treeView/01-basic.mmd` | Mermaid | Mermaid → PlantUML, single user-visible root |
| `cross-plantuml-mermaid-treeView/01-basic.puml` | PlantUML | PlantUML → Mermaid, single root |

### New fixtures — multi-root coverage

One per cross-format Mermaid-origin direction, plus a same-format multi-root
fixture for D2 and DOT to exercise the new mapper path:

| Path | Format | Demonstrates |
|------|--------|--------------|
| `cross-mermaid-d2-treeView/02-multi-root.mmd` | Mermaid | Synthetic `/` → D2 forest → re-import to synthetic `/` (lossless round-trip) |
| `cross-mermaid-dot-treeView/02-multi-root.mmd` | Mermaid | Synthetic `/` → DOT forest → re-import to synthetic `/` (lossless round-trip) |
| `cross-mermaid-plantuml-treeView/02-multi-root.mmd` | Mermaid | Synthetic `/` → PlantUML `*` root + `.featureDropped` per dropped sibling (lossy) |
| `d2-treeView/02-multi-root.d2` | D2 | Same-format multi-root: forest parses to synthetic `/`, exports as forest |
| `dot-treeView/02-multi-root.dot` | DOT | Same-format multi-root: forest parses to synthetic `/`, exports as forest |

No reverse-direction multi-root cross-format fixture for D2 or DOT — D2/DOT
multi-root inputs go to Mermaid as synthetic `/` (already covered by the
forward direction in symmetric round-trip). No reverse-direction multi-root
fixture for PlantUML WBS — the format cannot produce multi-root payloads.

### Harness registration

Two new test methods in
[`CrossFormatRoundTripTests.swift`](../../../Tests/DiagramKitTests/RoundTrip/CrossFormatRoundTripTests.swift)
follow the existing `:846-866` pattern for D2 ↔ PlantUML treeView:

- `mermaidPlantumlTreeView(fixture:)`
- `plantumlMermaidTreeView(fixture:)`

Existing methods at `:767-787` (Mermaid ↔ D2 treeView) and `:795-815`
(Mermaid ↔ DOT treeView) need **no** `additionalAllowedLosses` change — the
multi-root path is lossless after the mapper change. The new Mermaid →
PlantUML method admits `.syntheticRootFlattened` for the multi-root case
(see §[`RoundTripLoss`](#roundtriploss)).

## Round-trip discipline

### `RoundTripLoss`

Add one case to
[`Sources/DiagramKitTestSupport/RoundTripLoss.swift`](../../../Sources/DiagramKitTestSupport/RoundTripLoss.swift):

```swift
/// Mermaid multi-root treeView input (synthetic `/` container with 2+
/// children) was flattened on export to a format that cannot represent
/// multi-root payloads (currently only PlantUML WBS), dropping all but the
/// first sibling.
case syntheticRootFlattened
```

Naming and shape match existing `.subgraphFlatten` / `.boundaryFlatten` /
`.deploymentShapeFlattened` cases. Triggered exclusively by the multi-root
Mermaid → PlantUML WBS path; the equivalent Mermaid → D2/DOT paths are
**lossless** (forest export + multi-root-aware import). The harness pairs
the loss to `.featureDropped(.slotUnsupported, …)` by typed
`DiagnosticCategory` equality — no keyword matching — matching the
no-keyword-match discipline already used across the round-trip harness.

### Diagnostic discipline

No new `DiagnosticCategory` case. The PlantUML WBS multi-root drop emits
`.featureDropped(.slotUnsupported, message:)` per dropped sibling. `Scripts/check-diagnostic-discipline.sh` requires typed factories — already the case.

### Lossless paths

The following paths emit **no** new `RoundTripLoss` and **no** new
diagnostic:

- Single-root Mermaid ↔ D2: export strips synthetic `/`, emits single child
  with marker; import recognizes single root.
- Multi-root Mermaid ↔ D2: export strips synthetic `/`, emits forest with
  first-child marker; import sees multiple zero-in-degree nodes (no marker
  pin for the multi-root case) and synthesizes a fresh `/` container.
- Single-root Mermaid ↔ DOT: same shape as D2.
- Multi-root Mermaid ↔ DOT: same shape as D2.
- Single-root Mermaid → PlantUML and PlantUML → Mermaid: export strips
  synthetic `/`, emits single child as `*` root; import wraps single root
  unchanged (PlantUML → Mermaid surfaces no synthetic).
- D2 → Mermaid: real root recognized, emitted as top-level entry.
- DOT → Mermaid: same.
- Same-format round-trip for all four formats: no convention crossing for
  single-root inputs; D2/DOT same-format multi-root round-trip is also
  lossless after the mapper change (forest → synthetic `/` → forest).

These are byte-identical or structurally identical round-trips; no harness
allowance is required for them.

## Source paths touched

| Slice | File | Change |
|-------|------|--------|
| Model | `Sources/DiagramKitModel/src_treeview_types.swift` | Doc-comment defining canonical convention on `TreeViewDiagram` + `TreeViewNode` |
| Mermaid exporter | `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidTreeViewExport.swift` | Convention detection branch |
| D2 exporter | `Sources/DiagramKitD2/D2TreeViewExporter.swift` | Convention detection branch (forest emission) |
| D2 importer | `Sources/DiagramKitD2/D2TreeViewMapper.swift` | Multi-root path synthesizes `/` container at level -1; sorted-orphan determinism |
| DOT exporter | `Sources/DiagramKitGraphviz/DOTTreeViewExport.swift` | Convention detection branch (forest emission) |
| DOT importer | `Sources/DiagramKitGraphviz/DOTTreeViewMapper.swift` | Same shape as D2 mapper |
| PlantUML exporter | `Sources/DiagramKitPlantUML/Exporter/PlantUMLTreeViewExporter.swift` | Convention detection + multi-root drop diagnostic |
| Test support | `Sources/DiagramKitTestSupport/RoundTripLoss.swift` | New `.syntheticRootFlattened` case (PlantUML-only trigger) |
| Fixtures (rename) | `Tests/.../cross-mermaid-d2-treeView/01-basic.{mermaid→mmd}` | Unblock silent skip |
| Fixtures (rename) | `Tests/.../cross-mermaid-dot-treeView/01-basic.{mermaid→mmd}` | Unblock silent skip |
| Fixtures (new) | `Tests/.../cross-mermaid-plantuml-treeView/{01-basic.mmd, 02-multi-root.mmd}` | Mermaid ↔ PlantUML pair + multi-root coverage |
| Fixtures (new) | `Tests/.../cross-plantuml-mermaid-treeView/01-basic.puml` | Reverse direction |
| Fixtures (new) | `Tests/.../cross-mermaid-d2-treeView/02-multi-root.mmd` | Multi-root Mermaid → D2 → Mermaid round-trip |
| Fixtures (new) | `Tests/.../cross-mermaid-dot-treeView/02-multi-root.mmd` | Multi-root Mermaid → DOT → Mermaid round-trip |
| Fixtures (new) | `Tests/.../d2-treeView/02-multi-root.d2` | Same-format D2 multi-root |
| Fixtures (new) | `Tests/.../dot-treeView/02-multi-root.dot` | Same-format DOT multi-root |
| Test harness | `Tests/DiagramKitTests/RoundTrip/CrossFormatRoundTripTests.swift` | Two new Mermaid ↔ PlantUML methods; `additionalAllowedLosses` updates for Mermaid → PlantUML method; delete `:837-844` masking comment |

No changes to: Mermaid parser, `PlantUMLWBSParser`, `DiagramKitCommon`,
`DiagnosticCategory`, `TreeViewDiagram` / `TreeViewNode` field set, public
API, parser dispatch, `RoundTripHarness`, or `RoundTripCellRegistry`.

## Discipline gates

Standard set per [CONTRIBUTING.md](../../../CONTRIBUTING.md) and
[CLAUDE.md](../../../CLAUDE.md) — same as Wave H:

- `Scripts/check-file-sizes.sh` — exporter file growth is small (one branch
  each); none expected to cross 500-line warning.
- `Scripts/check-sendable-annotations.sh` — no `@unchecked Sendable` changes.
- `Scripts/check-diagnostic-discipline.sh` — new `.featureDropped` call uses
  typed factory.
- `Scripts/strict-concurrency-check.sh` — no new actor / await surface.
- `Scripts/linux-check.sh` — all touched files are Linux-portable
  (`DiagramKitModel`, `DiagramKitTestSupport`, format slices).
- `Scripts/bootstrap-smoke-check.sh` — full local merge gate.
- Round-trip suite: `swift test --filter RoundTrip`.

## Corpus impact

No corpus entry change. The 424 entries in
`Sources/DiagramKitSample/Resources/test-diagrams.json` already exercise
single-root treeView in all five formats. Multi-root treeView is exercised
only through the new fixtures.

## Closes

[`COVERAGE.md`](../../../COVERAGE.md) updates after closure:

- "Cross-format pairs" line gains `mermaid↔plantuml` to the `treeView` set
  (existing: `{mermaid↔d2, mermaid↔dot, d2↔dot, d2↔plantuml, dot↔plantuml}`
  → adds `mermaid↔plantuml`).
- Round-trip fixture totals: +1 unordered cross-format pair, +2 directed
  pairs; fixture-file delta is +7 new + 2 renames (3 cross-format Mermaid →
  others, 2 reverse direction, 2 same-format D2/DOT multi-root).
- Wave H deferral paragraph removed; replaced with a Wave I closer paragraph
  describing the canonical convention, the D2/DOT importer multi-root
  extension, the silent-skip fix, and the new `.syntheticRootFlattened`
  `RoundTripLoss` case (PlantUML-only trigger).

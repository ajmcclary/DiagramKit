# 2026-05-20 — D2 + DOT coverage expansion (Wave E): architecture, mindmap, treeView

## Summary

Push D2 and DOT coverage from 4/28 to 7/28 in each direction by adding
`architecture`, `mindmap`, and `treeView` per-family mappers and
exporters to both slices. Wave E is the mechanical companion to a
future Wave F (c4 via recovery markers); the two together close every
"possible" cell the doc's [§2 D2 and DOT expansion](../../../COVERAGE.md#2-d2-and-dot-expansion-mostly-mismatch-narrow-opportunities)
flags.

The work is bidirectional (import + export), lossless on same-format
round-trip via comment-encoded recovery markers, and
lossy-with-typed-diagnostics on cross-format paths (`.shapeDowngrade`
only — no new `DiagnosticCategory` cases).

This builds on:

- [`2026-05-19-coverage-expansion-design.md`](2026-05-19-coverage-expansion-design.md)
  (Wave 2 — D2/DOT class/state/er): the per-family mapper + exporter
  layering this spec extends.
- [`2026-05-20-coverage-marker-recovery-design.md`](2026-05-20-coverage-marker-recovery-design.md):
  the comment-encoded recovery-marker pattern and the existing
  `D2RecoveryMarker.scanner` / `DOTRecoveryMarker.scanner` infrastructure.
- [`2026-05-20-import-coverage-residuals-design.md`](2026-05-20-import-coverage-residuals-design.md)
  (Wave D): `ArchitectureServiceKind` and the `.shapeDowngrade` plumbing.

## Matrix delta

Six new cells in each direction, mirrored across import and export:

| Family       | D2 (was → now) | DOT (was → now) |
|--------------|:--------------:|:---------------:|
| architecture | — → ✓          | — → ✓           |
| mindmap      | — → ✓          | — → ✓           |
| treeView     | — → ✓          | — → ✓           |

Totals after Wave E: D2 7/28, DOT 7/28 (was 4/28 each).

## Scope

### In scope

- Three new per-family mappers per slice (six total): D2 architecture,
  D2 mindmap, D2 treeView, DOT architecture, DOT mindmap, DOT treeView.
- Three new per-family exporters per slice (six total).
- Routing-chain extension in `D2Importer` and `GraphvizImporter`:
  marker > Class > ER > State > Architecture > flowchart.
- Six new same-format round-trip fixtures
  (`d2-architecture`, `d2-mindmap`, `d2-treeView`, `dot-architecture`,
  `dot-mindmap`, `dot-treeView`).
- Eighteen new cross-format directed round-trip fixtures:
  `{mermaid↔d2, mermaid↔dot, d2↔dot} × {architecture, mindmap, treeView}`.
- Six new recovery-marker kinds registered with the existing scanners:
  `family`, `arch-icon`, `arch-group`, `tree-root`, `tree-collapsed`,
  `mindmap-icon`.
- COVERAGE.md updates: import + export totals, round-trip table,
  partial-support detail wave-closer reference.

### Out of scope

- c4 for D2 and DOT (deferred to Wave F).
- New `DiagnosticCategory` cases. Reuses existing `.shapeDowngrade`,
  `.slotUnsupported`, `.recoveryMarker`.
- New corpus entries in `Sources/DiagramKitSample/Resources/test-diagrams.json`;
  no new SVG / image / ASCII snapshot baselines.
- New public surface beyond per-family exporter/mapper types
  (which mirror the existing Wave-2 layering).
- Linux-specific behaviour: D2 and DOT are pure-string formats and
  inherit cross-platform parity from `DiagramKitModel`.
- Any other matrix gap (radar, treemap, sankey, …) — out of scope
  per the doc's "deliberate `—`" policy.

## Family detection on import

`D2Importer.swift` and `GraphvizImporter.swift` route by trying
per-family mappers and falling back to the flowchart default. Wave E
extends each chain to:

```
recovery marker (family=architecture|mindmap|treeView)
  > Class
  > ER
  > State
  > Architecture
  > flowchart (default)
```

Detection signals per family:

- **Architecture.** Structural probe in the mapper: returns `nil` unless
  it sees `≥2` nodes with architecture-shape attributes
  (`shape: cloud|database|cylinder|page|queue|...` for D2;
  `shape=cylinder|component|note|folder|...` for DOT) **or** an explicit
  `# diagramkit:family=architecture` (D2) /
  `// diagramkit:family=architecture` (DOT) marker. The high threshold
  biases toward false negatives — falling back to flowchart is safe;
  misidentifying flowchart input as architecture corrupts the payload.
- **Mindmap & treeView.** Both reduce to "directed tree from one root",
  which is also a valid flowchart shape. There is **no structural
  signal** that distinguishes them from a flowchart-shaped tree.
  Detection is **only via a recovery marker** (`# diagramkit:family=mindmap`
  for D2, `// diagramkit:family=mindmap` for DOT — same shape for
  `treeView`). Unmarked tree-shaped input continues to import as a
  flowchart, preserving backward compatibility with the existing
  corpus.

On export: mindmap/treeView always emit a family marker. Architecture
emits a family marker only when the shape map alone wouldn't pass the
≥2-shape probe (e.g. an architecture diagram of two `service`-kind nodes
that map to D2's default rectangle).

## Per-family mapping: architecture

### D2 architecture

D2's shape catalog aligns closely with architecture's icon vocabulary:

| `ArchitectureService.kind` / icon | D2 shape       |
|-----------------------------------|----------------|
| `service` (default)               | `shape: rectangle` (D2 default; emit no `shape:`) |
| `database`                        | `shape: cylinder` |
| `cloud`                           | `shape: cloud`    |
| `queue`                           | `shape: queue`    |
| `storage`                         | `shape: page`     |
| `interface` (Wave 3)              | `shape: circle`   |
| `component` (Wave 3)              | `shape: hexagon`  |

`ArchitectureGroup` → D2 container (`group: { … }`). Edges →
standard D2 `->` / `--`. Icon kinds outside the table (Mermaid
architecture's freeform `icon:` slot) ride through a
`# diagramkit:arch-icon=<key>` marker positioned on the line
immediately after the node declaration.

No `.shapeDowngrade` on D2 export — every kind has a native shape.

### DOT architecture

DOT's shape catalog is narrower; some kinds approximate:

| `ArchitectureService.kind` | DOT attribute(s)             | Lossy? |
|----------------------------|------------------------------|:------:|
| `service` (default)        | `shape=box` (default)        | no  |
| `database`                 | `shape=cylinder`             | no  |
| `cloud`                    | `shape=oval, style=dashed`   | yes |
| `queue`                    | `shape=box3d`                | yes |
| `storage`                  | `shape=folder`               | yes |
| `interface`                | `shape=circle`               | no  |
| `component`                | `shape=component`            | no  |

`ArchitectureGroup` → DOT cluster (`subgraph cluster_<id> { label = "…" }`).
Each approximated kind emits `.lossyTransform(.shapeDowngrade, …)` on
the export step, plus a `// diagramkit:arch-icon=<key>` marker for
lossless DOT same-format round-trip.

DOT cluster attributes (rank, label position, etc.) that have no
architecture counterpart are dropped silently on import per the
established Wave-2 silent-drop policy for foreign-native layout
attrs — not a `.featureDropped` event because no architecture slot
exists to drop into.

## Per-family mapping: mindmap

Both formats project the Mermaid mindmap payload to/from a directed
tree.

**Export.**
- Emit family marker on first nonblank source line.
- Emit nodes as `id: "label"` (D2) or `"id" [label="…"]` (DOT).
- Emit edges parent → child by tree traversal.
- Mindmap node shape map:

| Mindmap shape | D2          | DOT (closest)             | DOT lossy? |
|---------------|-------------|---------------------------|:----------:|
| default       | (none)      | `shape=box` (default)     | no  |
| square        | `shape: rectangle` | `shape=box`        | no  |
| rounded       | `shape: rectangle` + `# diagramkit:mindmap-icon=rounded` | `shape=box, style=rounded` | no (DOT); marker only (D2) |
| circle        | `shape: circle`    | `shape=circle`     | no  |
| bang          | `shape: oval` + `# diagramkit:mindmap-icon=bang` | `shape=oval` + `// diagramkit:mindmap-icon=bang` | yes (both — no native "bang") |
| cloud         | `shape: cloud`     | `shape=oval, style=dashed` | yes (DOT only) |
| hexagon       | `shape: hexagon`   | `shape=hexagon`    | no  |

Per-node icons that are not in the shape table ride on
`# diagramkit:mindmap-icon=<key>` markers.

**Import.** With the family marker present, parse the directed-edge
structure and rebuild the tree:

1. Find roots: nodes with in-degree 0. If exactly one, that's the root.
2. If multiple, use the `# diagramkit:tree-root=<id>` marker if present.
3. If no marker and multiple roots, emit
   `.featureDropped(.slotUnsupported, "mindmap requires single root")`
   and fall back to flowchart for that document.

## Per-family mapping: treeView

Same structural projection as mindmap, with two differences:

- TreeView nodes carry only labels (no shape vocabulary). Export emits
  plain `id: "label"` (D2) / `"id" [label="…"]` (DOT). Import maps any
  shape attributes to flowchart instead and bails.
- TreeView's per-node collapsed flag rides on
  `# diagramkit:tree-collapsed=<id>` markers, one per collapsed node,
  positioned after the node's declaration. Imports without markers
  treat all nodes as expanded.

## Diagnostics

**No new `DiagnosticCategory` cases.** Wave E reuses:

- `.lossyTransform(.shapeDowngrade, …)` — DOT architecture exports for
  `cloud|queue|storage`; DOT mindmap exports for `bang|cloud`; D2
  mindmap exports for `bang`.
- `.informational(.recoveryMarker, …)` — emitted whenever an importer
  consumes a `diagramkit:*` marker to restore canonical state. Same
  category Wave D uses for its existing markers.
- `.featureDropped(.slotUnsupported, …)` — only as a last-resort
  fallback (e.g. mindmap with multiple roots and no `tree-root`
  marker). Not expected in well-formed input.

Pairs to `RoundTripLoss.shapeDowngrade(…)` only. No new
`RoundTripLoss` cases.

## Recovery markers

New marker kinds registered with `D2RecoveryMarker` /
`DOTRecoveryMarker` (existing pre-lexer scanner +
positional-correlation infrastructure, no scanner changes):

| Key                 | Families used     | Purpose                                                  |
|---------------------|-------------------|----------------------------------------------------------|
| `family=<f>`        | all three         | Pins family on tree-shaped input. Always emitted for mindmap/treeView; only when ambiguous for architecture. |
| `arch-icon=<key>`   | architecture      | Carries original architecture icon kind through DOT shape downgrade. |
| `arch-group=<id>`   | architecture      | Pins group id when foreign-format cluster name is ambiguous. |
| `tree-root=<id>`    | mindmap, treeView | Pins root when in-degree alone is ambiguous (multi-root). |
| `tree-collapsed=<id>` | treeView        | Restores TreeView per-node collapsed state. |
| `mindmap-icon=<key>`| mindmap           | Restores per-node icon name not in the shape table. |

Comment syntax: `#` prefix in D2, `//` prefix in DOT. Position:
immediately following the related declaration on the next line (the
existing positional-correlation rule).

## Testing & round-trip discipline

### Same-format fixtures (6 new)

Under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`:

- `d2-architecture/` — must exercise at least one container group +
  one non-default shape.
- `d2-mindmap/` — must exercise at least one non-default node shape
  including `bang` (forces `mindmap-icon` marker round-trip).
- `d2-treeView/` — must include at least one collapsed node.
- `dot-architecture/` — must exercise at least one cluster +
  one shape-downgrade kind (`cloud|queue|storage`) to validate
  `.shapeDowngrade` + `arch-icon` marker round-trip.
- `dot-mindmap/` — must exercise `bang` and `cloud` shapes
  (both force markers + downgrade).
- `dot-treeView/` — must include at least one collapsed node.

### Cross-format directed fixtures (18 new)

For each family `f ∈ {architecture, mindmap, treeView}`:

- `cross-mermaid-d2-<f>` and `cross-d2-mermaid-<f>`
- `cross-mermaid-dot-<f>` and `cross-dot-mermaid-<f>`
- `cross-d2-dot-<f>` and `cross-dot-d2-<f>`

All fixtures use the canonical `RoundTripHarness`. Allowed losses must
be the typed `RoundTripLoss.shapeDowngrade(…)` set; any other loss
fails the test.

### Discipline gates

- `Scripts/check-file-sizes.sh`: new exporter/mapper files are each
  expected under 500 lines. Precedents: `D2ClassExporter.swift` ≈ 430
  lines, `D2ERExporter.swift` ≈ 320 lines, `DOTERExport.swift` ≈ 380
  lines. No allowlist entries expected.
- `Scripts/check-diagnostic-discipline.sh`: continues to enforce typed
  factory usage. No raw `DiagramDiagnostic(severity:message:)` calls.
- `Scripts/check-sendable-annotations.sh`: new files contain no
  `@unchecked Sendable`.
- `Scripts/strict-concurrency-check.sh`: passes (new types are
  `Sendable` value types).
- `Scripts/linux-check.sh`: no platform-gated code added.

## Files

### New files (12)

- `Sources/DiagramKitD2/D2ArchitectureMapper.swift`
- `Sources/DiagramKitD2/D2ArchitectureExporter.swift`
- `Sources/DiagramKitD2/D2MindmapMapper.swift`
- `Sources/DiagramKitD2/D2MindmapExporter.swift`
- `Sources/DiagramKitD2/D2TreeViewMapper.swift`
- `Sources/DiagramKitD2/D2TreeViewExporter.swift`
- `Sources/DiagramKitGraphviz/DOTArchitectureMapper.swift`
- `Sources/DiagramKitGraphviz/DOTArchitectureExport.swift`
- `Sources/DiagramKitGraphviz/DOTMindmapMapper.swift`
- `Sources/DiagramKitGraphviz/DOTMindmapExport.swift`
- `Sources/DiagramKitGraphviz/DOTTreeViewMapper.swift`
- `Sources/DiagramKitGraphviz/DOTTreeViewExport.swift`

### Files to touch (8)

- `Sources/DiagramKitD2/D2Importer.swift` — extend routing chain.
- `Sources/DiagramKitD2/D2Exporter.swift` — dispatch new payload
  families (replaces today's `.unsupported` for these families).
- `Sources/DiagramKitD2/D2RecoveryMarker.swift` — register new marker
  kinds.
- `Sources/DiagramKitGraphviz/GraphvizImporter.swift` — extend routing
  chain symmetrically.
- `Sources/DiagramKitGraphviz/DOTExporter.swift` — dispatch new payload
  families.
- `Sources/DiagramKitGraphviz/DOTRecoveryMarker.swift` — register new
  marker kinds.
- `COVERAGE.md` — update totals (4/28 → 7/28 D2 and DOT, both
  directions), round-trip table (30 → 36 same-format; 40 → 58
  cross-format directed = 20 → 29 unordered), partial-support detail
  wave-closer reference.
- `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/` — add 24
  fixture directories.

### Files explicitly NOT to touch

- Anything c4-related (Wave F).
- The Mermaid importer/exporter for these families (already complete).
- `DiagramDescriptor.swift`, `DiagramRegistry+*.swift`, the umbrella
  module — no new family is being introduced; only new formats for
  existing families.
- `Sources/DiagramKitSample/Resources/test-diagrams.json` — no corpus
  expansion.

## Implementation order

Each step is independently testable and PR-sized:

1. **D2 architecture.** Mapper + exporter + `D2RecoveryMarker`
   `arch-icon` / `arch-group` / `family` registration. Land
   `d2-architecture` same-format fixture green.
2. **DOT architecture.** Mapper + exporter + symmetric
   `DOTRecoveryMarker` updates. Land `dot-architecture` same-format
   fixture green (exercises `.shapeDowngrade`).
3. **Cross-format architecture.** Six cross fixtures
   (`mermaid↔d2`, `mermaid↔dot`, `d2↔dot`).
4. **D2 + DOT mindmap.** Both slices' mappers and exporters paired
   (the `family` and `tree-root`/`mindmap-icon` marker plumbing is
   shared with treeView). Same-format + cross-format fixtures.
5. **D2 + DOT treeView.** Both slices' mappers and exporters paired.
   Same-format + cross-format fixtures.
6. **COVERAGE.md update + wave-closer commit.** Update totals,
   round-trip table, partial-support detail.

Total expected: 6–8 commits, mirroring Wave 2's shape.

## Risks

- **Architecture probe misclassification.** A flowchart of a
  cylindrical machine (`shape: cylinder` on a node) could trip the
  architecture probe. Mitigated by the `≥2 shapes` threshold and
  marker-only escape hatch. Bias toward false negatives is by design.
- **Cluster vs group equivalence in DOT.** DOT clusters carry layout
  attributes architecture groups don't model. Loss is one-way and
  silent per Wave-2 precedent — users opting into architecture-via-DOT
  accept generic-graph projection.
- **Mindmap shape coverage in DOT.** `bang` has no DOT analog →
  always `.shapeDowngrade` + marker recovery. Documented and tested.
- **Multi-root mindmap input.** Marker-less, multi-root input from a
  foreign source falls back to flowchart with
  `.featureDropped(.slotUnsupported, …)`. Acceptable; matches the
  Wave-D pattern for ambiguous ER cardinality.

## Out of scope (deferred)

- **c4 for D2 and DOT** — deferred to Wave F. The recovery-marker
  encoding for C4 view-type, technology, and boundary metadata is
  conceptually distinct enough to warrant its own spec.
- **Other matrix gaps** (radar, treemap, sankey, packet, …) — kept
  as deliberate `—` per the doc.
- **New `DiagnosticCategory` cases** — reusing `.shapeDowngrade`,
  `.slotUnsupported`, `.recoveryMarker`.
- **Linux snapshot baselines** — formats are pure-string; no
  measurement involved.

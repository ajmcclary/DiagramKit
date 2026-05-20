# Foreign-Format Import Coverage — Residual ⚠ Closure — Design

**Date:** 2026-05-20
**Status:** Approved (brainstorm)
**Builds on:** [2026-05-19-coverage-expansion-design.md](2026-05-19-coverage-expansion-design.md)
(closed 2026-05-19) and
[2026-05-20-coverage-marker-recovery-design.md](2026-05-20-coverage-marker-recovery-design.md)
(closed 2026-05-20, Waves A/B/C).
**Source matrix:** [COVERAGE.md](../../../COVERAGE.md).

## Goal

Close every `⚠` cell remaining in the [COVERAGE.md](../../../COVERAGE.md)
**import table**. After the 2026-05-20 recovery-marker work the export table
reached zero `⚠`; the import table still carries nine cells where vanilla
foreign-source input emits `slotUnsupported`, `styleDrop`, or
`diagramFamilyUnsupported` because the foreign feature has no Mermaid landing
slot.

This spec closes those nine cells by wiring foreign-format parsers into slots
that already exist on Mermaid payloads, and by adding a single additive payload
field (`ArchitectureService.Kind`) where a true gap exists.

| Direction | Today | After |
|---|---|---|
| Import table `⚠` count | 9 | **0** |
| Export table `⚠` count | 0 | 0 (unchanged) |

### The 9 cells

| # | Cell | Today's residual loss |
|---|---|---|
| 1 | `classDiagram × D2` (import) | D2 class-applicable attrs (`link`, `tooltip`, `style`, color) dropped as `slotUnsupported` |
| 2 | `classDiagram × DOT` (import) | DOT class-applicable attrs dropped as `slotUnsupported` |
| 3 | `classDiagram × PlantUML` (import) | PlantUML `<<stereotype>>` and `package` blocks surface as `class-unsupported-line` markers |
| 4 | `stateDiagram × D2` (import) | D2 container-as-composite-state dropped, surfaced as `state-parent` marker only |
| 5 | `stateDiagram × DOT` (import) | DOT `subgraph cluster_X` container nesting same disposition |
| 6 | `erDiagram × D2` (import) | D2 edge cardinality decoration dropped, surfaced as `er-cardinality` marker only |
| 7 | `erDiagram × DOT` (import) | DOT edge cardinality (e.g. `crow`/`tee` arrowheads) same disposition |
| 8 | `flowchart × PlantUML` (import; activity dialect) | PlantUML `partition "Name" { … }` dropped as `slotUnsupported` (partition) |
| 9 | `architecture × PlantUML` (import; component dialect) | PlantUML `[component]` vs `interface ()` distinction dropped as `styleDrop` |

### Success bar

A cell counts as closed (`⚠ → ✓`) if:

- the importer for that cell emits no `.lossyTransform`, `.featureDropped`,
  or `.informational` diagnostics on vanilla foreign-source corpus inputs, AND
- `DiagramKitTestSupport.RoundTripHarness` round-trips that cell's new
  fixture (`parse → export → parse → assert structurally equal`) with no
  allowed `RoundTripLoss`.

The retired diagnostic emission sites are **deleted**, not silenced. The Wave
A/B/C recovery markers from 2026-05-20 stay live as round-trip-identity
scaffolding for genuinely unknown lines.

## Scope

Three waves, one per family-group:

| Wave | Cells | Headline change |
|---|---|---|
| 1 — class family | 1, 2, 3 | Wire D2/DOT class attrs into `ClassNode.link/tooltip/styles`; teach PlantUML class parser to natively recognize `<<stereotype>>` and `package` blocks |
| 2 — state + er families | 4, 5, 6, 7 | Route D2/DOT container nesting into `MermaidSubgraph`; route D2/DOT edge cardinality into `ErCardinality` |
| 3 — PlantUML flowchart + architecture | 8, 9 | PlantUML activity `partition` → `MermaidSubgraph`; add `ArchitectureServiceKind` enum and teach component-dialect importer to populate it |

Only Wave 3 introduces a new payload field. All other work is internal wiring.

## Out of Scope

- **New family rows.** Mermaid stays at 28/28 native; no new family × format
  intersections.
- **New public modules.** All work lives in existing
  `DiagramKitD2` / `DiagramKitGraphviz` / `DiagramKitPlantUML` /
  `DiagramKitModel` targets. No new `DiagramKit*` slice.
- **New format slices.** Sixth source format remains out of scope per
  prior specs.
- **D2 features without realistic Mermaid landing.** `style` *blocks* (not
  per-node `style:` attrs — those are in scope), `vars`, `layers`/`scenarios`/
  `steps`, `classes` definitions, `constraint`, `grid-rows`/`grid-columns`,
  `near`, `&filter` selectors, glob patterns, `@import`, var substitution
  continue to emit `slotUnsupported` and stay documented in COVERAGE.md.
- **DOT layout-engine knobs.** `rank`, `splines`, `overlap`, `sep`, `pad`,
  `margin`, `nodesep`, `ranksep`, `compound`, `lhead`, `ltail`, `concentrate`,
  `center`, `resolution`, `page`, `viewport`, `ratio`, `size` continue to
  emit `slotUnsupported`.
- **Mermaid-side recovery markers.** A `%% diagramkit:` scanner for Mermaid
  would round-trip foreign attrs via Mermaid comments but would not close
  the ⚠ on vanilla foreign input — it solves a different problem. Out of
  scope.
- **Foreign-attribute bag.** Adding a generic `foreignAttributes: [String:
  String]` slot to each payload would violate the closed-enum / explicit-field
  typed-payload invariant. Rejected.
- **Corpus growth.** `Sources/DiagramKitSample/Resources/test-diagrams.json`
  stays at 424 entries; image/SVG/ASCII snapshot baselines stay at
  437/437/424. New fixtures live exclusively under
  `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`.

## Invariants Preserved

- **No thread pool.** Parsers and mappers run on the existing
  `DiagramEngine._runOnWorker` 8 MB-stack `Thread`. No new dispatch primitives.
- **No new public surface beyond one additive enum.** Only addition is the
  top-level `ArchitectureServiceKind` enum (`String, Sendable, Equatable,
  CaseIterable`) plus a defaulted `kind` field on `ArchitectureService`.
  The default (`.service`) keeps the existing initializer source-compatible.
- **No new Mermaid family rows.** Mermaid stays at 28/28 native.
- **Linux portability.** All slices touched (`DiagramKitD2`,
  `DiagramKitGraphviz`, `DiagramKitPlantUML`, `DiagramKitModel`) are
  Linux-portable. No new platform-gated code.
- **Strict concurrency.** All new types are `Sendable`. No new
  `@unchecked Sendable` annotations; no allow-list additions in
  `Scripts/check-sendable-annotations.sh`.
- **File-size policy** (500-line warn / 1000-line error per
  `Scripts/check-file-sizes.sh`). Each wave splits a host file if it
  would cross the warn threshold, following the pattern set by
  `DOTMapperDiagnostics.swift` and `D2ClassExporter.swift`.
- **Diagnostic discipline.** Retired emission sites are deleted, not
  silenced. Typed factories
  (`.lossyTransform(.<category>, …)` / `.featureDropped(.<category>, …)` /
  `.informational(.<category>, …)`) remain the only emission surface.
  `Scripts/check-diagnostic-discipline.sh` continues to enforce.
- **Round-trip discipline.** Every new wiring lands a new or extended
  fixture under
  `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`. `RoundTripLoss`
  still admits no `case other(_)`; any genuinely unavoidable loss extends
  the typed enum and pairs to a `DiagnosticCategory`.
- **Recovery markers stay live.** Wave A/B/C markers from
  `2026-05-20-coverage-marker-recovery-design.md` continue to round-trip
  Mermaid → foreign → Mermaid identity for line shapes that fall outside
  the natively-parsed set. They are no longer the primary loss-suppression
  mechanism for the closed cells.

## Architecture

### Module placement

No new files in `DiagramKitCommon`. Each slice grows internal helpers:

```
Sources/DiagramKitD2/
  D2ClassMapper.swift                // existing; gains link/tooltip/style routing
  D2Mapper.swift                     // existing; container nesting → MermaidSubgraph
                                     //          edge cardinality → ErCardinality
  D2ERMapper.swift                   // new; ER-family entry into ErCardinality

Sources/DiagramKitGraphviz/
  DOTMapper.swift                    // existing; class attr routing, container nesting
  DOTClassMapper.swift               // new; record-shape lifting into ClassNode/Member
  DOTERMapper.swift                  // new; arrowhead → ErCardinality
  DOTMapperDiagnostics.swift         // existing; remove now-recognized cases

Sources/DiagramKitPlantUML/
  Class/PlantUMLClassParser.swift    // existing; natively parses <<stereotype>>, package
  Class/PlantUMLClassMapper.swift    // existing; populates ClassNode.annotations/parent
  Activity/PlantUMLActivityParser.swift  // existing; partition → MermaidSubgraph
  Component/PlantUMLComponentParser.swift // existing; emit shape kind on parse
  Component/PlantUMLComponentMapper.swift // existing; route into ArchitectureService.kind

Sources/DiagramKitModel/
  src_architecture_types.swift       // existing; +ArchitectureService.Kind enum +kind field
  src_architecture_renderer.swift    // existing; switch on kind for glyph
```

Whether a new mapper file is split out vs. inlined depends on host file
length at implementation time; the file-size gate decides.

### New payload surface (the only one)

```swift
// Sources/DiagramKitModel/src_architecture_types.swift

public enum ArchitectureServiceKind: String, Sendable, Equatable, CaseIterable {
    case service       // default; today's behavior, no glyph change
    case component     // PlantUML [component] — boxed rectangle glyph
    case interface     // PlantUML () — lollipop / circle glyph
}

public struct ArchitectureService: Sendable, Equatable {
    public var id: String
    public var icon: String?
    public var iconText: String?
    public var title: String?
    public var parentGroupId: String?
    public var kind: ArchitectureServiceKind = .service   // NEW (defaulted)
    public var width: Double = 0
    public var height: Double = 0

    public init(
        id: String,
        icon: String? = nil,
        iconText: String? = nil,
        title: String? = nil,
        parentGroupId: String? = nil,
        kind: ArchitectureServiceKind = .service          // NEW (defaulted)
    ) {
        self.id = id
        self.icon = icon
        self.iconText = iconText
        self.title = title
        self.parentGroupId = parentGroupId
        self.kind = kind
    }
}
```

The defaulted parameter makes every existing call-site
(`ArchitectureService(id: …, icon: …, …)`) compile unchanged. A
`swift build --build-tests` after the edit verifies source compatibility;
any positional-only call-site that the default does not cover gets a
keyword switch in the same commit.

### Per-wave loss-case routing

#### Wave 1 — class family

| Loss-case | Today | After |
|---|---|---|
| D2 class `link` attr | `slotUnsupported` | `ClassNode.link` + `ClassNode.linkTarget` (set from D2 `target` if present) |
| D2 class `tooltip` attr | `slotUnsupported` | `ClassNode.tooltip` |
| D2 class `style: dashed`/`dotted`/`bold` | `slotUnsupported` | `ClassNode.styles` appends the style declaration (use existing `[String]` slot) |
| D2 class color attrs (`stroke`, `fill`) | `slotUnsupported` | `ClassNode.styles` appends `stroke:VALUE` / `fill:VALUE` |
| DOT class `URL`/`href` | `slotUnsupported` | `ClassNode.link` |
| DOT class `tooltip` | `slotUnsupported` | `ClassNode.tooltip` |
| DOT class `style`/`color`/`fillcolor` | `slotUnsupported` | `ClassNode.styles` |
| PlantUML class `<<stereotype>>` | `class-unsupported-line` marker | `ClassNode.annotations` (native parse) |
| PlantUML `package Foo { … }` | `class-unsupported-line` marker | `ClassNode.parent` + emit `ClassNamespace` |
| PlantUML class visibility `+`/`-`/`#`/`~` | already wired (verify) | unchanged |

#### Wave 2 — state + er families

| Loss-case | Today | After |
|---|---|---|
| D2 state container nesting | `state-parent` marker only | Promote container to `MermaidSubgraph`; children point to it via `MermaidNode.parent`. Marker stays as fallback for non-container syntax. |
| DOT `subgraph cluster_X { … }` for state | `state-parent` marker only | Same: `MermaidSubgraph` lifted from `cluster_*` containers. |
| D2 edge cardinality decoration | `er-cardinality` marker | Parse `{1..N}`-style labels (or D2 convention) into `ErRelationship.cardA`/`cardB` typed values. Marker stays for non-recognizable forms. |
| DOT edge cardinality (crow/tee/etc. arrowheads) | `er-cardinality` marker | Parse `arrowtail`/`arrowhead` values into `ErCardinality`. Marker stays for non-recognizable forms. |

#### Wave 3 — PlantUML flowchart + architecture

| Loss-case | Today | After |
|---|---|---|
| PlantUML activity `partition "Name" { … }` | `slotUnsupported` (partition) | Map partition body to a `MermaidSubgraph(id: stableID(…), label: "Name")`. The `activity-partition` recovery marker stays live to round-trip the `partition` keyword on export, but the diagnostic emission goes away. |
| PlantUML `[component]` token | `styleDrop` (component-style) | `ArchitectureService.kind = .component` |
| PlantUML `interface ()` token | `styleDrop` (interface-style) | `ArchitectureService.kind = .interface` |
| PlantUML component `[…]` shape attrs (color, stroke, …) | `styleDrop` | Existing `component-style` recovery marker; remains a documented residual that does **not** prevent cell closure because it round-trips identity. (Vanilla component fixtures without explicit styling close cleanly.) |

### Renderer impact

The new `ArchitectureService.kind` field branches the architecture renderer
glyph selection:

- `.service` — existing path (icon or icon-text).
- `.component` — boxed rectangle with header bar; consistent with PlantUML
  visual.
- `.interface` — small circle (lollipop). Falls back to a service glyph
  with explicit label when the layout is too tight.

Glyph implementations land in
`Sources/DiagramKitModel/src_architecture_renderer.swift` and the
`DiagramKitRenderingCG` mirror (if a Core Graphics path exists).

No existing corpus entry uses `.component` / `.interface`, so SVG/image/ASCII
snapshot baselines stay at 437/437/424. The new glyphs are exercised through
round-trip fixtures only.

## Testing Strategy

Each wave is gated on three checks:

1. **Round-trip harness** (`swift test --filter "RoundTrip"`). One new fixture
   per closed cell:
   - Wave 1: vanilla D2 class with `link`/`tooltip`/`style`; vanilla DOT class
     with `URL`/`tooltip`/`color`; vanilla PlantUML class with `<<interface>>`
     plus a `package` block.
   - Wave 2: vanilla D2 state with nested container; vanilla DOT state with
     `subgraph cluster_X`; vanilla D2 ER with cardinality labels; vanilla DOT
     ER with crow/tee arrowheads.
   - Wave 3: vanilla PlantUML activity with `partition`; vanilla PlantUML
     component with `[component]` and `interface ()`.

2. **Diagnostic-absence assertion.** A swift-testing suite per slice asserts
   `import(...).diagnostics.isEmpty` (or absence of the retired category)
   for the new fixtures. This is the ⚠→✓ gate.

3. **No-regression on closed cells.** The Wave A/B/C recovery markers from
   2026-05-20 still suppress losses on Mermaid → foreign → Mermaid
   round-trips for line shapes outside the natively-parsed set. Existing
   round-trip fixtures stay green.

## Discipline Gates

Each wave's closing commit must pass:

- `swift build` (library + tests)
- `swift test --filter "RoundTrip"`
- `swift test --filter <slice-suite>` for the slice's targeted suite
- `Scripts/check-file-sizes.sh`
- `Scripts/check-sendable-annotations.sh`
- `Scripts/check-diagnostic-discipline.sh`
- `Scripts/strict-concurrency-check.sh`
- `Scripts/linux-check.sh` (skip-with-note if Docker/Podman unavailable
  locally, per [CLAUDE.md](../../../CLAUDE.md) "Discipline Gates")
- `Scripts/bootstrap-smoke-check.sh` before the wave-closing commit

## Documentation Updates per Wave Close

- **[COVERAGE.md](../../../COVERAGE.md):**
  - Flip each closed cell from `⚠` to `✓` in the import table.
  - Update the legend footnote: the "D2/DOT-native features that have no
    Mermaid landing slot" list shrinks to the genuinely out-of-scope
    features documented in §"Out of Scope" above; PlantUML
    component-vs-interface and stereotype/package no longer appear as
    residuals.
  - Update §"Partial-support detail" with a fourth bullet recording this
    spec's closures.
- **[BASELINES.md](../../../BASELINES.md):** update the closing-commit map
  with each wave closer.
- **No [CLAUDE.md](../../../CLAUDE.md) change.** The "Forward Roadmap"
  statement that the active backlog is empty will hold again after this
  spec lands.

## Risk Register

- **Source-compatibility of `ArchitectureService.kind` default.** Swift
  treats a defaulted parameter added to a public `init` as source-compatible.
  `swift build --build-tests` after the edit catches any positional call-site
  the default does not cover. Mitigation: in the same commit, switch any
  failing call-site to keyword form.
- **`ClassNode.styles` semantics divergence between Mermaid-native and
  foreign-import sources.** The existing Mermaid class renderer should treat
  the slot uniformly; if behavior diverges we follow the Mermaid-native shape
  to avoid renderer churn. Verification: existing class snapshots stay green
  under chunked `CorpusSnapshotTests`.
- **PlantUML `package` blocks introducing `ClassNamespace` entries.** Verify
  the class renderer correctly displays packages from imported sources, not
  just Mermaid-native ones. If divergence appears, the wave plan splits
  `PlantUMLClassMapper.swift` to keep it under the 500-line warn threshold
  and reuses existing namespace-rendering code via the Mermaid class
  pipeline.
- **State-container promotion conflicting with `state-parent` markers.** When
  a D2/DOT source has both native container nesting *and* a `state-parent`
  recovery marker, the native nesting wins; the marker becomes redundant and
  suppression continues to apply. Verify by adding a mixed fixture under
  `roundtrip/`.
- **ER cardinality recognition false positives.** D2 edge labels like
  `"{1..N}"` are conventional, not formal. Conservative recognition:
  only consume labels that match a closed grammar (`{`, optional `0`/`1`,
  `..`, optional `N`/`*`/digits, `}`); anything else stays as plain label
  and falls back to the `er-cardinality` recovery marker.

## Wave Order Justification

Wave 1 lands first because the class family has the most touchable surface
(three cells; two formats) and exercises the wiring-only pattern without any
payload changes — it validates the design's smallest-blast-radius claim.
Wave 2 extends that pattern to state + er. Wave 3 introduces the only new
public type (`ArchitectureServiceKind`) and the only renderer change,
which deserves landing last so prior waves' churn doesn't compound with
renderer review.

## References

- [COVERAGE.md](../../../COVERAGE.md) — source matrix.
- [2026-05-19-coverage-expansion-design.md](2026-05-19-coverage-expansion-design.md)
  — Wave 1/2/3 baseline (closed 2026-05-19).
- [2026-05-20-coverage-marker-recovery-design.md](2026-05-20-coverage-marker-recovery-design.md)
  — recovery-marker generalization (closed 2026-05-20).
- [docs/diagnostic-severity-discipline.md](../../diagnostic-severity-discipline.md)
  — typed-factory decision tree.
- [CLAUDE.md](../../../CLAUDE.md) — invariants, discipline gates, file layout.

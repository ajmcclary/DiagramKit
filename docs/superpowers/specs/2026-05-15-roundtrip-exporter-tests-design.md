# Round-trip exporter test suite

**Status:** Design approved, awaiting plan
**Date:** 2026-05-15
**Origin:** REVIEW.md Cross-cutting Observation #1 — "Exporter testing is weaker than parser/renderer testing. The Mermaid/PlantUML exporter bugs above would be caught by any round-trip suite (`parse → export → parse → assert structural equality`). None of these bugs depend on visual fidelity; they would fail purely structural assertions."

## Goal

Stand up a `parse → export → parse → assert structurally equal` discipline across every importer/exporter pair the library ships, in both same-format and cross-format topologies. Catch silent data corruption (the original Critical-tier finding shape) at CI time rather than during ad-hoc review.

The suite is a **gate**, not a sample. It runs on every `bootstrap-smoke-check.sh` invocation and on Linux. Allowed losses are typed, closed, and paired with `.warning`/`.unsupported` diagnostics on the export step that produced them — an exporter that silently drops data fails round-trip even if the structural loss is "expected."

## Scope

### In

- Same-format round-trip for every (importer, exporter) pair where both ship and a family in common exists: 14 cells.
- Cross-format round-trip for every family-intersection cell pair: 8 unordered pairs.
- A typed `RoundTripLoss` taxonomy, closed-set, with payload sufficient to ground assertion failures.
- A `DiagramDocumentDiff` comparator and a `RoundTripHarness` driver in `DiagramKitTestSupport` (Linux-portable).
- Hand-curated fixture corpus under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`, ~3–6 entries per same-format cell.
- Paired-diagnostic contract: every observed loss kind must correspond to a diagnostic emitted by the exporter that produced it.

### Out

- Visual / snapshot equality. Renderer drift remains covered by the existing snapshot suite.
- Coverage of importer-only formats (no paired exporter ⇒ can't round-trip).
- Implicit family conversion across formats. Cells that don't share a family are simply absent from the matrix.
- Diagnostic-severity harmonisation (cross-cutting #2). Paired-diagnostic checking in Phase 4 will surface where the severity choice is inconsistent, but unifying `.info` / `.warning` / `.unsupported` / throw is a follow-up spec.
- New exporter family coverage (Mermaid state/gantt/mindmap are 7A-P1; the spec describes how those cells slot in but doesn't require them to land).

## Cell matrix

### Same-format (14 cells)

| Importer / Exporter | flowchart | sequence | class | ER | C4 | state | mindmap | gantt |
|---|---|---|---|---|---|---|---|---|
| Mermaid | ✓ | ✓ | ✓ | ✓ | ✓ | | | |
| D2 | ✓ | | | | | | | |
| DOT (Graphviz) | ✓ | | | | | | | |
| Structurizr | | | | | ✓ | | | |
| PlantUML | | ✓ | ✓ | | ✓ | ✓ | ✓ | ✓ |

### Cross-format (8 unordered pairs)

Each pair is tested in *both* starting directions — `A→B→A` and `B→A→B` — so the suite has **16 cross-format `@Test`s** (one per ordered direction). Each `@Test` executes one `A→B→A` round-trip end-to-end (parse, export, re-parse via foreign importer, export back via original exporter, re-parse via original importer, compare doc₁ vs doc₃).

| Family | Pairs |
|---|---|
| flowchart | Mermaid↔D2, Mermaid↔DOT, D2↔DOT |
| C4 | Mermaid↔Structurizr, Mermaid↔PlantUML, PlantUML↔Structurizr |
| sequence | Mermaid↔PlantUML |
| class | Mermaid↔PlantUML |

State / mindmap / gantt have only one supporting format each (PlantUML), so they contribute no cross-format cells. ER has only Mermaid.

## Architecture

Three pieces, all in `DiagramKitTestSupport` (the Linux-portable test-support target):

### 1. `RoundTripLoss` — closed enum, one case per allowed loss kind

```swift
public enum RoundTripLoss: Hashable, Sendable, CustomStringConvertible {
    case idSanitization(original: String, sanitized: String)
    case shapeDowngrade(nodeID: String, from: NodeShape, to: NodeShape)
    case subgraphFlatten(subgraphID: String, depth: Int)
    case boundaryFlatten(boundaryID: String, depth: Int)
    case c4SlotDrop(shapeID: String, slot: C4Slot)
    case titleDrop
    case configDrop(key: String)
    case styleDrop(target: String, attribute: String)
    case accessibilityDrop(field: AccessibilityField)
    case anonymousSubgraphRename(old: String, new: String)
    case d2DuplicateOverride(nodeID: String, attribute: String)
}

public enum RoundTripLossKind: String, Hashable, Sendable, CaseIterable {
    case idSanitization, shapeDowngrade, subgraphFlatten, boundaryFlatten
    case c4SlotDrop, titleDrop, configDrop, styleDrop
    case accessibilityDrop, anonymousSubgraphRename, d2DuplicateOverride
}

// Companion enums introduced by this spec; both Sendable + Hashable.
public enum C4Slot: String, Hashable, Sendable { case technology, description }
public enum AccessibilityField: String, Hashable, Sendable { case title, description }
```

`NodeShape` already exists in `DiagramKitModel` (`Sources/DiagramKitModel/src_types.swift:15`). `C4Slot` and `AccessibilityField` are new types this spec adds alongside `RoundTripLoss` in `DiagramKitTestSupport`.

`RoundTripLossKind` is the case-name companion used for cell allow-lists. Comparisons against allow-lists are case-tag only; the payload still surfaces in failure messages.

The enum is the *closed* contract. A comparator that wants to report a new kind of loss must add a case — no `case other(String)` escape hatch. The closed-set invariant is what makes the suite a real gate rather than a permissive log.

### 2. `DiagramDocumentDiff` — pure comparator

```swift
public func compare(_ a: DiagramDocument, _ b: DiagramDocument) -> [RoundTripDelta]

public enum RoundTripDelta: Hashable, Sendable {
    case loss(RoundTripLoss)
    case unexpected(path: String, detail: String)
}
```

The comparator dispatches on `DiagramDocument.payload` and runs per-family logic. Per-family comparators own normalisation policy (ordering, ID lookup, optional-equality semantics). The `unexpected` case is *always* a failure — either a real regression or a taxonomy gap, surfaced through CI rather than swallowed.

The comparator file-size policy: when the per-family logic grows past ~300 lines collectively, split into `DiagramDocumentDiff+Flowchart.swift`, `+Sequence.swift`, etc. The split policy is set up-front so the comparator never crosses the 500-line warn threshold in a single file.

### 3. `RoundTripHarness` — swift-testing-friendly driver

```swift
public struct RoundTripCell<I: DiagramSourceImporter, E: DiagramExporter>: Sendable {
    public let importer: I
    public let exporter: E
    public let family: DiagramType
    public let allowedLosses: Set<RoundTripLossKind>
}

public struct RoundTripFixture: Sendable {
    public let path: String   // relative to Resources/roundtrip/
    public let source: String
    public let additionalAllowedLosses: Set<RoundTripLossKind>
    public let note: String?
}

public func runSameFormatRoundTrip<I, E>(
    cell: RoundTripCell<I, E>,
    fixture: RoundTripFixture,
    file: StaticString = #file,
    line: UInt = #line
) throws

public func runCrossFormatRoundTrip<I1, E1, I2, E2>(
    legA: RoundTripCell<I1, E1>,
    legB: RoundTripCell<I2, E2>,
    fixture: RoundTripFixture,
    file: StaticString = #file,
    line: UInt = #line
) throws
```

`runSameFormatRoundTrip` does:

1. Parse fixture source via `legA.importer` → `doc₁` + `diagnostics₁`.
2. Export `doc₁` via `legA.exporter` → `source₂` + `diagnostics₂`.
3. Re-parse `source₂` via `legA.importer` → `doc₂` + `diagnostics₃`.
4. `compare(doc₁, doc₂)` → `[RoundTripDelta]`.
5. **Allow-list check:** every `RoundTripDelta.loss(_)` kind must be in `cell.allowedLosses ∪ fixture.additionalAllowedLosses`.
6. **Paired-diagnostic check:** every observed loss kind must have a paired `.warning` or `.unsupported` diagnostic in `diagnostics₂` (the export step that produced the loss).
7. **No `.unexpected`:** any `RoundTripDelta.unexpected(_, _)` is a failure.

`runCrossFormatRoundTrip` does `A→exportB→importB→exportA→importA` and applies the same three checks with diagnostics aggregated across both export legs.

The harness imports only the format-neutral targets (`DiagramKitCommon`, `DiagramKitModel`, `DiagramKitImport`, `DiagramKitExport`). The per-format slices (`DiagramKitMermaid`, `DiagramKitD2`, etc.) are imported by the test target that *uses* the harness, not by `DiagramKitTestSupport` itself — so `DiagramKitTestSupport` doesn't accumulate transitive dependencies on every format slice.

### Linux portability

Every target on the path (`DiagramKitTestSupport`, `DiagramKitCommon`, `DiagramKitModel`, `DiagramKitImport`, `DiagramKitExport`, and every format slice) is Linux-portable per `Package.swift`. The suite runs on Linux as well; `Scripts/linux-check.sh` picks it up via the standard `swift test`.

### Strict concurrency

`RoundTripLoss`, `RoundTripDelta`, `RoundTripCell`, `RoundTripFixture`, `RoundTripCellRegistry` are all `Sendable`. The comparator is a pure function. No `@unchecked Sendable` expected; if one becomes necessary, it goes through the project's `check-sendable-annotations.sh` banner discipline.

## Loss-kind taxonomy

The starter taxonomy seeds the enum with kinds intrinsic to the current importer/exporter set. New cases land alongside new fixtures.

### Per-format intrinsic kinds

| Kind | Origin | Cells affected |
|---|---|---|
| `idSanitization(original, sanitized)` | `MermaidExportHelpers.sanitizeIdentifier(_:usedAliases:)`; `StructurizrExporter.uniqueSanitizedAlias` | every Mermaid exporter cell + Structurizr C4 |
| `shapeDowngrade(nodeID, from, to)` | `MermaidFlowchartExport.shapeMarker` (non-flowchart shape input ⇒ rectangle); D2/DOT have narrower shape vocabularies | Mermaid flowchart (rare input); D2/DOT flowchart (any non-trivial input) |
| `subgraphFlatten(subgraphID, depth)` | `FlowchartExportWalker` for sinks that don't set `handlesSubgraphs = true` | D2/DOT flowchart |
| `boundaryFlatten(boundaryID, depth)` | `StructurizrExporter` partition-emit, flattens nested authored boundaries to siblings | Structurizr C4 with nested-boundary fixtures |
| `c4SlotDrop(shapeID, slot)` | C4 shapes vary in technology/description slot availability (`C4ShapeType.hasTechnologySlot`) | Mermaid↔PlantUML / Mermaid↔Structurizr C4 |
| `titleDrop` | exporters that don't emit `DiagramDocument.title` | format-specific; currently empty (Session 2 closed PlantUML sequence title) |
| `configDrop(key)` | frontmatter keys (`useMaxWidth`, `look`, `theme`) not emitted by every format | most cross-format cells |
| `styleDrop(target, attribute)` | Mermaid `classDef` / D2 `style.*` not round-trippable into the other side | all cross-format flowchart cells |
| `accessibilityDrop(field)` | `accTitle` / `accDescr` not emitted by every format | format-specific |
| `anonymousSubgraphRename(old, new)` | Mermaid anonymous-subgraph IDs are positional, regenerate on re-parse | Mermaid flowchart with anonymous subgraphs |
| `d2DuplicateOverride(nodeID, attribute)` | D2 duplicate-node-ID second-occurrence overrides (label/shape/width/height) | D2 flowchart fixtures with intentional duplicates |

### Per-cell expected-loss set

Each cell registers an `allowedLosses: Set<RoundTripLossKind>` in `RoundTripCellRegistry` (Swift declaration, not JSON — case names are the source of truth). A per-fixture override (`additionalAllowedLosses: Set<RoundTripLossKind> = []`) covers the case where one fixture intentionally exercises a kind the cell as a whole does not.

The fixture authoring rule: every fixture either declares no expected losses (happy-path test for the cell), or declares the exact set it expects. The harness asserts the observed loss kind set is a subset of `cell.allowedLosses ∪ fixture.additionalAllowedLosses` AND that every observed kind has a paired `.warning`/`.unsupported` diagnostic on the export step that produced it.

### Unrecognised divergence is always a failure

`RoundTripDelta.unexpected(path:detail:)` means either (a) a real bug — exporter or importer regressed — or (b) the taxonomy needs a new case, a deliberate design call surfaced through CI rather than swallowed by a permissive comparator. There is no skip mechanism for unexpected deltas.

## Fixture organisation

```text
Tests/DiagramKitTests/RoundTrip/
├── RoundTripCellRegistry.swift          # declares every cell + its allowed losses
├── RoundTripFixtures.swift              # registers fixture sources by cell
├── Resources/
│   └── roundtrip/
│       ├── mermaid-flowchart/
│       │   ├── 01-basic.md
│       │   ├── 02-subgraphs-nested.md
│       │   ├── 03-classdef-styled.md
│       │   ├── 04-edge-labels.md
│       │   └── 05-anonymous-subgraphs.md
│       ├── mermaid-sequence/
│       ├── mermaid-class/
│       ├── mermaid-er/
│       ├── mermaid-c4/
│       ├── d2-flowchart/
│       ├── dot-flowchart/
│       ├── structurizr-c4/
│       └── plantuml-{sequence,class,state,mindmap,gantt,c4}/
├── SameFormatRoundTripTests.swift       # one @Suite per format
├── CrossFormatRoundTripTests.swift      # one @Suite per intersection family
└── LossPairingTests.swift               # paired-diagnostic contract probes
```

Fixture format is plain source files (`.md`, `.d2`, `.dot`, `.dsl`, `.puml`). Per-fixture expectations live in a sidecar `.json` only when overrides are needed; absence means "happy path, no losses expected":

```json
{
  "additionalAllowedLosses": ["shapeDowngrade", "configDrop"],
  "note": "Exercises the shape-downgrade path for state shapes inside a flowchart payload."
}
```

The cell-level allowed-loss set comes from `RoundTripCellRegistry`, not from JSON, so the loss-kind enum and the allow-list co-evolve in Swift.

## Test driving

`swift-testing` parameterized over cells, one `@Test` per cell:

```swift
@Suite struct SameFormatRoundTripTests {
    @Test("Mermaid flowchart round-trip", arguments: try fixtures(for: .mermaidFlowchart))
    func mermaidFlowchart(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidFlowchart,
            fixture: fixture
        )
    }
    // … one @Test per same-format cell (14 total)
}

@Suite struct CrossFormatRoundTripTests {
    @Test("Mermaid → D2 → Mermaid (flowchart)", arguments: try fixtures(for: .mermaidD2Flowchart))
    func mermaidD2Flowchart(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidFlowchart,
            legB: RoundTripCellRegistry.d2Flowchart,
            fixture: fixture
        )
    }
    // … one @Test per cross-format pair (8 unordered = 8 @Tests; harness runs A→B→A)
}
```

`RoundTripFixture` is `Sendable` (path + sidecar metadata), so `arguments:` works under strict concurrency. The fixture-loading helper resolves paths through `Bundle.module` against the test target's resource directory (the same mechanism `CorpusEntry` already uses).

### Failure surface

On failure the harness records, in order:

1. Cell identity: `(importer.formatID, exporter.formatID, family)`.
2. Fixture identity: relative path under `Resources/roundtrip/`.
3. The unexpected `RoundTripDelta` rendered via `customDump` (per `pfw-custom-dump`).
4. The exporter's full `[DiagramDiagnostic]` from each export step, so the paired-diagnostic gap is visible immediately.

One fixture per `@Test` invocation rather than batched assertion loops — matches the project's existing parameterized-snapshot pattern and gives a clean cell-grounded failure log.

## Gates and CI

The round-trip suite is its own `swift test --filter` invocation. Added to `Scripts/bootstrap-smoke-check.sh` as a discrete gate line:

```bash
run_gate "round-trip" swift test --filter "RoundTripTests|RoundTrip"
```

The suite is fast (14 same-format `@Test`s + 16 cross-format `@Test`s = 30 `@Test`s × 3–6 fixtures × milliseconds-per-fixture ≈ a few seconds) so it doesn't need chunking. The signal-10 caveat documented for `CorpusSnapshotTests` is renderer-driven; round-trip parameterisation runs against tiny string fixtures, no rendering, well inside the swift-testing safe envelope.

Linux gate (`Scripts/linux-check.sh`) picks up the suite automatically via its standard `swift test`.

## Phasing

Commit-by-commit on `main` (project standing default). TDD where the architecture permits.

| Phase | Lands | Purpose |
|---|---|---|
| 1 | `RoundTripLoss` enum + `DiagramDocumentDiff` skeleton + Mermaid flowchart payload comparator + harness scaffolding + **one** failing-then-passing happy-path fixture (`mermaid-flowchart/01-basic.md`) | Pin the architecture against a real round-trip end-to-end before scaling |
| 2 | Remaining same-format cells, one cell per commit: Mermaid sequence, class, ER, C4; D2 flowchart; DOT flowchart; Structurizr C4; PlantUML × 6 | 13 commits; per-family comparator dispatch arms |
| 3 | Cross-format pairs, one unordered pair per commit (8 commits). Each commit lands *both* direction `@Test`s for its pair (A→B→A and B→A→B) plus their starter fixtures: Mermaid↔D2, Mermaid↔DOT, D2↔DOT, Mermaid↔Structurizr (C4), Mermaid↔PlantUML (C4), PlantUML↔Structurizr (C4), Mermaid↔PlantUML (sequence), Mermaid↔PlantUML (class) | Catches semantic-mismatch bugs (the original C4 slot bug shape) |
| 4 | Stress fixtures and `LossPairingTests` — paired-diagnostic contract probes (every observed loss kind for a cell must correspond to an emitted diagnostic on the export that produced it) | Closes the original review gap: "exporter that silently drops data" cannot pass |
| 5 | `Scripts/bootstrap-smoke-check.sh` adds the round-trip gate line; `CLAUDE.md` "Testing And Snapshots" section gains a round-trip subsection; `ARCHITECTURE.md` references the discipline | Wires the gate; docs sync |

For each new fixture: author the source, run the cell test, observe the loss set, codify it. The first run of a new fixture is *expected* to fail with either an unexpected delta (taxonomy gap) or an unpaired loss (diagnostic gap); the fix is to add a loss kind, add a paired diagnostic emission, or fix the actual export bug. Phase 1's "failing-then-passing" beat establishes the rhythm.

## File size

New files target ≤300 lines each. Cell registry grows with cell count (~22 cells); fixture registration grows with fixture count (~80 fixtures × 1 line each ≈ 80 lines). Comparator splits per family as it grows so no single file crosses the 500-line warn threshold.

## What this spec does not close

- **Diagnostic-severity discipline** (cross-cutting #2, `.info`/`.warning`/`.unsupported`/throw inconsistency). Paired-diagnostic checking in Phase 4 will surface where the severity choice is inconsistent by making "no diagnostic at all" a failure, but unifying *which* severity each slice picks is a follow-up spec.
- **Linux SVG/ASCII entry points** (cross-cutting #5). Separate spec.
- **Generators → separate test target** (Session 3 reclassified). Separate spec.
- **File-size splits over 500 lines**. Separate spec.

## Success criteria

1. Every same-format cell (14) has ≥3 fixtures and passes the gate.
2. Every cross-format ordered direction (16, from 8 unordered pairs × 2 directions) has ≥3 fixtures and passes the gate.
3. The round-trip gate is wired into `bootstrap-smoke-check.sh` and runs on Linux.
4. `RoundTripLoss` is a closed enum; no `case other(_)` exists.
5. Every observed loss in any passing test has a paired `.warning` or `.unsupported` diagnostic on its export step.
6. The eight original Critical-tier exporter bugs (REVIEW.md "Exporters silently corrupt valid input") would be caught by this suite if reintroduced — verified by writing fixtures that exercise each path and confirming they pass cleanly today.

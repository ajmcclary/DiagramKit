# Round-trip Exporter Test Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a `parse → export → parse → assert structural equality` discipline across every importer/exporter pair the library ships, in both same-format (14 cells) and cross-format (8 unordered pairs / 16 ordered directions) topologies. Catch silent data corruption at CI time rather than during ad-hoc review.

**Architecture:** A closed-set `RoundTripLoss` taxonomy + a pure `DiagramDocumentDiff` comparator + a swift-testing-friendly `RoundTripHarness` driver, all in the Linux-portable `DiagramKitTestSupport` target. Hand-curated fixtures under `Tests/DiagramKitTests/RoundTrip/Resources/`. Every observed loss must have a paired `.warning`/`.unsupported` diagnostic on its export step — silent drops fail the gate.

**Tech Stack:** Swift 6 strict concurrency, swift-testing (`@Suite` / `@Test` / `#expect`), `swift-custom-dump`, project's `DiagramKitImport` / `DiagramKitExport` / format slices (`DiagramKitMermaid`, `DiagramKitD2`, `DiagramKitGraphviz`, `DiagramKitStructurizr`, `DiagramKitPlantUML`).

**Spec:** `docs/superpowers/specs/2026-05-15-roundtrip-exporter-tests-design.md`

**Standing project defaults (from CLAUDE.md and project memory):**
- Commit-by-commit on `main`, no worktrees/branches.
- Pair `swift test` with `--filter` always; never run unfiltered.
- Don't re-run tests once a result has been observed.
- Fix pre-existing failures in the same line of work; don't archaeology them via stash.
- `@unchecked Sendable` requires a "Concurrency Contract" banner or allowlist entry.

---

## File Structure

### New files under `Sources/DiagramKitTestSupport/`

| File | Responsibility |
|---|---|
| `RoundTripLoss.swift` | `RoundTripLoss` enum + `RoundTripLossKind` companion + `C4Slot` + `AccessibilityField` |
| `RoundTripDelta.swift` | `RoundTripDelta` enum (`.loss(_)` / `.unexpected(path:detail:)`) |
| `DiagramDocumentDiff.swift` | Top-level `compare(_ a: DiagramDocument, _ b: DiagramDocument) -> [RoundTripDelta]` + payload dispatch |
| `DiagramDocumentDiff+Flowchart.swift` | Per-family arm for `.flowchart` and `.stateDiagram` (both wrap `ParsedGraphModel`) |
| `DiagramDocumentDiff+Sequence.swift` | Per-family arm for `.sequenceDiagram` |
| `DiagramDocumentDiff+Class.swift` | Per-family arm for `.classDiagram` |
| `DiagramDocumentDiff+ER.swift` | Per-family arm for `.erDiagram` |
| `DiagramDocumentDiff+C4.swift` | Per-family arm for `.c4` |
| `DiagramDocumentDiff+Mindmap.swift` | Per-family arm for `.mindmap` |
| `DiagramDocumentDiff+Gantt.swift` | Per-family arm for `.gantt` |
| `RoundTripCell.swift` | `RoundTripCell<I, E>` + `RoundTripFixture` |
| `RoundTripCellRegistry.swift` | Static `let` cell declarations — same-format only |
| `RoundTripHarness.swift` | `runSameFormatRoundTrip` + `runCrossFormatRoundTrip` |
| `RoundTripFixtureLoader.swift` | `fixtures(for:fromRoot:)` — reads `.{md,d2,dot,dsl,puml}` + sidecar `.json` |

Comparator splits per family from the start so no single file crosses the 500-line warn threshold as cells land.

### New files under `Tests/DiagramKitTests/RoundTrip/`

```text
Tests/DiagramKitTests/RoundTrip/
├── SameFormatRoundTripTests.swift     # one @Suite, 14 @Tests (one per cell)
├── CrossFormatRoundTripTests.swift    # one @Suite, 16 @Tests (one per ordered direction)
├── LossPairingTests.swift             # paired-diagnostic contract probes
├── RoundTripCrossRegistry.swift       # cross-format ordered-direction cell declarations
└── Resources/
    └── roundtrip/
        ├── mermaid-flowchart/         # 01-basic.md … 05-anonymous-subgraphs.md (+ sidecars where needed)
        ├── mermaid-sequence/
        ├── mermaid-class/
        ├── mermaid-er/
        ├── mermaid-c4/
        ├── d2-flowchart/
        ├── dot-flowchart/
        ├── structurizr-c4/
        ├── plantuml-sequence/
        ├── plantuml-class/
        ├── plantuml-state/
        ├── plantuml-mindmap/
        ├── plantuml-gantt/
        ├── plantuml-c4/
        ├── cross-mermaid-d2-flowchart/   # one dir per cross-format ordered direction
        ├── cross-d2-mermaid-flowchart/
        ├── cross-mermaid-dot-flowchart/
        ├── cross-dot-mermaid-flowchart/
        ├── cross-d2-dot-flowchart/
        ├── cross-dot-d2-flowchart/
        ├── cross-mermaid-structurizr-c4/
        ├── cross-structurizr-mermaid-c4/
        ├── cross-mermaid-plantuml-c4/
        ├── cross-plantuml-mermaid-c4/
        ├── cross-plantuml-structurizr-c4/
        ├── cross-structurizr-plantuml-c4/
        ├── cross-mermaid-plantuml-sequence/
        ├── cross-plantuml-mermaid-sequence/
        ├── cross-mermaid-plantuml-class/
        └── cross-plantuml-mermaid-class/
```

`RoundTripCrossRegistry.swift` lives in the test target rather than `DiagramKitTestSupport` because cross-format cells reference *two* exporter/importer pairings; the harness already accepts the cross-format shape generically. Keeping cross-format wiring in the test target also avoids leaking format-slice-pair declarations into the test-support library.

### Modified files

| File | Change |
|---|---|
| `Package.swift` | Add `DiagramKitImport` + `DiagramKitExport` to `DiagramKitTestSupport` deps |
| `Scripts/bootstrap-smoke-check.sh` | Add round-trip gate line |
| `CLAUDE.md` | Add "Round-trip discipline" subsection under Testing And Snapshots; bump test source count |
| `ARCHITECTURE.md` | Reference the round-trip gate under the Diagnostics section |

---

## Cell Scaffolding Recipe (read once; tasks T7–T19 follow this shape)

Each same-format cell task lands these four pieces in **one commit**:

1. **A comparator arm** in `DiagramDocumentDiff+<Family>.swift` (creating the file on first use). Pure function `func diffFlowchart(_ a: ParsedGraphModel, _ b: ParsedGraphModel) -> [RoundTripDelta]` (signature varies by family). Returns `.loss(_)` for each categorisable divergence and `.unexpected(path:detail:)` for anything else.

2. **A cell registry entry** in `RoundTripCellRegistry.swift`. Sample shape:

   ```swift
   public static let mermaidFlowchart = RoundTripCell(
       importer: MermaidImporter(),
       exporter: MermaidExporter(),
       family: .flowchart,
       allowedLosses: [.idSanitization, .anonymousSubgraphRename]
   )
   ```

   Cell-specific allowed-loss sets are specified in each cell task below.

3. **Fixtures** under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/<format-family>/`. Naming convention: `NN-name.<ext>` where `NN` is a 2-digit ordinal. Sidecar JSON only when overrides needed:

   ```json
   {
     "additionalAllowedLosses": ["shapeDowngrade"],
     "note": "Exercises shape downgrade for state-shape inside flowchart payload"
   }
   ```

4. **A `@Test`** in `SameFormatRoundTripTests.swift`:

   ```swift
   @Test("Mermaid flowchart round-trip", arguments: try fixtures(for: "mermaid-flowchart"))
   func mermaidFlowchart(fixture: RoundTripFixture) throws {
       try runSameFormatRoundTrip(
           cell: RoundTripCellRegistry.mermaidFlowchart,
           fixture: fixture
       )
   }
   ```

TDD beat for each cell task:
- a. Write the @Test that references the not-yet-declared cell.
- b. Run `swift test --filter "<TestName>"` — expect **compile failure** ("cannot find 'mermaidFlowchart' in type 'RoundTripCellRegistry'").
- c. Land the cell registry entry. Run again — expect **runtime failure** ("no fixtures found for cell").
- d. Add the first fixture file. Run again — expect either pass (happy path) or a categorisable failure listing the observed `[RoundTripDelta]`.
- e. If failure: either (i) add the missing comparator arm logic, (ii) extend the allowed-loss set on the cell, (iii) add a paired diagnostic emission in the exporter, or (iv) fix the actual exporter bug — whichever the failure indicates. The harness's failure surface (rendered via `customDump`) tells the engineer which.
- f. Run again — expect pass. Commit.

Across cells the comparator arm grows monotonically. A single fixture often forces multiple arm cases (e.g., the `mermaid-flowchart/01-basic.md` fixture exercises nodes + edges + labels; `02-subgraphs-nested.md` adds subgraph nesting).

---

## Cross-format Scaffolding Recipe (read once; tasks T20–T27 follow this shape)

Each cross-format pair task lands these in **one commit**:

1. **Two cross-format cell declarations** in `Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift` — one per ordered direction. Sample:

   ```swift
   enum RoundTripCrossRegistry {
       static let mermaidD2Flowchart = (
           legA: RoundTripCellRegistry.mermaidFlowchart,
           legB: RoundTripCellRegistry.d2Flowchart,
           additionalAllowedLosses: Set<RoundTripLossKind>([.subgraphFlatten, .styleDrop])
       )
       static let d2MermaidFlowchart = (
           legA: RoundTripCellRegistry.d2Flowchart,
           legB: RoundTripCellRegistry.mermaidFlowchart,
           additionalAllowedLosses: Set<RoundTripLossKind>([.idSanitization])
       )
   }
   ```

   `additionalAllowedLosses` is *cross-format-pair-specific* and accumulates onto each leg's `cell.allowedLosses`.

2. **Two `@Test`s** in `CrossFormatRoundTripTests.swift`, one per direction:

   ```swift
   @Test("Mermaid → D2 → Mermaid (flowchart)", arguments: try fixtures(for: "cross-mermaid-d2-flowchart"))
   func mermaidD2Flowchart(fixture: RoundTripFixture) throws {
       try runCrossFormatRoundTrip(
           legA: RoundTripCrossRegistry.mermaidD2Flowchart.legA,
           legB: RoundTripCrossRegistry.mermaidD2Flowchart.legB,
           additionalAllowedLosses: RoundTripCrossRegistry.mermaidD2Flowchart.additionalAllowedLosses,
           fixture: fixture
       )
   }
   ```

3. **Fixtures** under `Resources/roundtrip/cross-<legA>-<legB>-<family>/` and `cross-<legB>-<legA>-<family>/`. The source of a fixture is in the *first leg's* format (i.e., the starting format of that direction).

TDD beat is the same as same-format cells.

---

## Tasks

### Task 1: Wire `DiagramKitImport` + `DiagramKitExport` into `DiagramKitTestSupport`

**Files:**
- Modify: `Package.swift:150-154`

The harness needs to reference `DiagramSourceImporter`, `DiagramExporter`, `DiagramImportResult`, `DiagramExportResult`, `DiagramExportError`. Today `DiagramKitTestSupport` only depends on `DiagramKitModel`.

- [ ] **Step 1: Update Package.swift**

Replace the existing block:

```swift
.target(
    name: "DiagramKitTestSupport",
    dependencies: ["DiagramKitModel"],
    swiftSettings: strictConcurrencySettings
),
```

with:

```swift
.target(
    name: "DiagramKitTestSupport",
    dependencies: [
        "DiagramKitCommon",
        "DiagramKitModel",
        "DiagramKitImport",
        "DiagramKitExport"
    ],
    swiftSettings: strictConcurrencySettings
),
```

- [ ] **Step 2: Verify the build still passes**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Package.swift
git commit -m "$(cat <<'EOF'
build(testsupport): add Import + Export deps for round-trip harness

DiagramKitTestSupport needs DiagramSourceImporter / DiagramExporter /
DiagramImportResult / DiagramExportResult to host the round-trip harness
landing in subsequent commits. Linux-portable; no platform gating.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Land `RoundTripLoss` + companion enums

**Files:**
- Create: `Sources/DiagramKitTestSupport/RoundTripLoss.swift`
- Test: `Tests/DiagramKitTests/RoundTrip/RoundTripLossTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/RoundTrip/RoundTripLossTests.swift`:

```swift
import Testing
import DiagramKitTestSupport
import DiagramKitModel

@Suite("RoundTripLoss")
struct RoundTripLossTests {

    @Test("Every RoundTripLoss case maps to a unique RoundTripLossKind")
    func kindMapping() {
        let cases: [(RoundTripLoss, RoundTripLossKind)] = [
            (.idSanitization(original: "a", sanitized: "b"), .idSanitization),
            (.shapeDowngrade(nodeID: "n", from: .rectangle, to: .rectangle), .shapeDowngrade),
            (.subgraphFlatten(subgraphID: "s", depth: 1), .subgraphFlatten),
            (.boundaryFlatten(boundaryID: "b", depth: 1), .boundaryFlatten),
            (.c4SlotDrop(shapeID: "p", slot: .technology), .c4SlotDrop),
            (.titleDrop, .titleDrop),
            (.configDrop(key: "look"), .configDrop),
            (.styleDrop(target: "x", attribute: "fill"), .styleDrop),
            (.accessibilityDrop(field: .title), .accessibilityDrop),
            (.anonymousSubgraphRename(old: "subgraph_0", new: "subgraph_1"), .anonymousSubgraphRename),
            (.d2DuplicateOverride(nodeID: "x", attribute: "label"), .d2DuplicateOverride)
        ]
        for (loss, expectedKind) in cases {
            #expect(loss.kind == expectedKind)
        }
        #expect(Set(cases.map(\.1)).count == RoundTripLossKind.allCases.count,
                "Every RoundTripLossKind must have at least one case covered by the mapping test")
    }

    @Test("RoundTripLoss is Hashable")
    func hashable() {
        let a: RoundTripLoss = .idSanitization(original: "x", sanitized: "y")
        let b: RoundTripLoss = .idSanitization(original: "x", sanitized: "y")
        let c: RoundTripLoss = .idSanitization(original: "x", sanitized: "z")
        #expect(Set([a, b, c]).count == 2)
    }

    @Test("CustomStringConvertible renders payload")
    func description() {
        let loss: RoundTripLoss = .shapeDowngrade(nodeID: "n1", from: .rectangle, to: .rectangle)
        #expect(String(describing: loss).contains("shapeDowngrade"))
        #expect(String(describing: loss).contains("n1"))
    }
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `swift test --filter RoundTripLossTests`
Expected: compile failure — `cannot find 'RoundTripLoss' in scope`.

- [ ] **Step 3: Write `RoundTripLoss.swift`**

Create `Sources/DiagramKitTestSupport/RoundTripLoss.swift`:

```swift
import DiagramKitModel

/// Typed, closed-set categorization of an allowed-by-design divergence between
/// two `DiagramDocument`s produced by a round-trip (parse → export → parse).
///
/// The enum is intentionally *closed* — new lossy round-trip paths must add a
/// case here rather than slipping through a `case other(String)` escape hatch.
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

    public var kind: RoundTripLossKind {
        switch self {
        case .idSanitization: return .idSanitization
        case .shapeDowngrade: return .shapeDowngrade
        case .subgraphFlatten: return .subgraphFlatten
        case .boundaryFlatten: return .boundaryFlatten
        case .c4SlotDrop: return .c4SlotDrop
        case .titleDrop: return .titleDrop
        case .configDrop: return .configDrop
        case .styleDrop: return .styleDrop
        case .accessibilityDrop: return .accessibilityDrop
        case .anonymousSubgraphRename: return .anonymousSubgraphRename
        case .d2DuplicateOverride: return .d2DuplicateOverride
        }
    }

    public var description: String {
        switch self {
        case .idSanitization(let original, let sanitized):
            return "idSanitization(original: \(original), sanitized: \(sanitized))"
        case .shapeDowngrade(let nodeID, let from, let to):
            return "shapeDowngrade(nodeID: \(nodeID), from: \(from), to: \(to))"
        case .subgraphFlatten(let subgraphID, let depth):
            return "subgraphFlatten(subgraphID: \(subgraphID), depth: \(depth))"
        case .boundaryFlatten(let boundaryID, let depth):
            return "boundaryFlatten(boundaryID: \(boundaryID), depth: \(depth))"
        case .c4SlotDrop(let shapeID, let slot):
            return "c4SlotDrop(shapeID: \(shapeID), slot: \(slot))"
        case .titleDrop:
            return "titleDrop"
        case .configDrop(let key):
            return "configDrop(key: \(key))"
        case .styleDrop(let target, let attribute):
            return "styleDrop(target: \(target), attribute: \(attribute))"
        case .accessibilityDrop(let field):
            return "accessibilityDrop(field: \(field))"
        case .anonymousSubgraphRename(let old, let new):
            return "anonymousSubgraphRename(old: \(old), new: \(new))"
        case .d2DuplicateOverride(let nodeID, let attribute):
            return "d2DuplicateOverride(nodeID: \(nodeID), attribute: \(attribute))"
        }
    }
}

/// Case-tag-only companion to `RoundTripLoss` used for per-cell allow-lists.
/// String-raw so `Codable` works for sidecar JSON declaration; `CaseIterable`
/// so coverage assertions can iterate over every kind.
public enum RoundTripLossKind: String, Hashable, Sendable, CaseIterable, Codable {
    case idSanitization, shapeDowngrade, subgraphFlatten, boundaryFlatten
    case c4SlotDrop, titleDrop, configDrop, styleDrop
    case accessibilityDrop, anonymousSubgraphRename, d2DuplicateOverride
}

/// C4 shape slot identifier — used by `RoundTripLoss.c4SlotDrop`. The
/// availability of each slot varies by `C4ShapeType.hasTechnologySlot`.
public enum C4Slot: String, Hashable, Sendable, Codable {
    case technology, description
}

/// Accessibility metadata field — used by `RoundTripLoss.accessibilityDrop`.
public enum AccessibilityField: String, Hashable, Sendable, Codable {
    case title, description
}
```

- [ ] **Step 4: Run to confirm pass**

Run: `swift test --filter RoundTripLossTests`
Expected: 3/3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitTestSupport/RoundTripLoss.swift Tests/DiagramKitTests/RoundTrip/RoundTripLossTests.swift
git commit -m "$(cat <<'EOF'
feat(testsupport): RoundTripLoss closed-set taxonomy

Eleven case kinds covering every intrinsic round-trip loss across
Mermaid / D2 / DOT / Structurizr / PlantUML importers and exporters.
RoundTripLossKind is the case-tag companion used for cell allow-lists;
Codable so sidecar JSON can declare per-fixture overrides. C4Slot and
AccessibilityField land alongside.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Land `RoundTripDelta` + `DiagramDocumentDiff.compare` dispatcher

**Files:**
- Create: `Sources/DiagramKitTestSupport/RoundTripDelta.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift`
- Test: `Tests/DiagramKitTests/RoundTrip/DiagramDocumentDiffTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/RoundTrip/DiagramDocumentDiffTests.swift`:

```swift
import Testing
import DiagramKitTestSupport
import DiagramKitModel

@Suite("DiagramDocumentDiff dispatcher")
struct DiagramDocumentDiffTests {

    @Test("Identical empty flowchart docs produce no deltas")
    func identicalEmptyFlowchart() {
        let model = ParsedGraphModel()
        let a = DiagramDocument(type: .flowchart, payload: .flowchart(model))
        let b = DiagramDocument(type: .flowchart, payload: .flowchart(model))
        #expect(compare(a, b).isEmpty)
    }

    @Test("Mismatched payload types report unexpected delta")
    func mismatchedPayloadTypes() {
        let a = DiagramDocument(type: .flowchart, payload: .flowchart(ParsedGraphModel()))
        let b = DiagramDocument(type: .pie, payload: .pie(PieChart()))
        let deltas = compare(a, b)
        #expect(deltas.count == 1)
        if case .unexpected(let path, _) = deltas[0] {
            #expect(path == "payload.type")
        } else {
            Issue.record("expected .unexpected; got \(deltas[0])")
        }
    }
}
```

(Adjust the `PieChart()` ctor if it requires arguments — read `Sources/DiagramKitModel/src_pie_*.swift` for the actual init signature before writing the test.)

- [ ] **Step 2: Run to confirm failure**

Run: `swift test --filter DiagramDocumentDiffTests`
Expected: compile failure — `cannot find 'compare' in scope`.

- [ ] **Step 3: Write `RoundTripDelta.swift`**

Create `Sources/DiagramKitTestSupport/RoundTripDelta.swift`:

```swift
/// One categorised divergence between two `DiagramDocument`s in a round-trip
/// comparison. `.loss(_)` is an explainable, kind-tagged divergence;
/// `.unexpected(_, _)` is always a test failure (either a real regression or
/// a taxonomy gap surfaced through CI).
public enum RoundTripDelta: Hashable, Sendable, CustomStringConvertible {
    case loss(RoundTripLoss)
    case unexpected(path: String, detail: String)

    public var description: String {
        switch self {
        case .loss(let loss):
            return ".loss(\(loss))"
        case .unexpected(let path, let detail):
            return ".unexpected(path: \(path), detail: \(detail))"
        }
    }
}
```

- [ ] **Step 4: Write `DiagramDocumentDiff.swift`**

Create `Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift`:

```swift
import DiagramKitModel

/// Compares two `DiagramDocument`s and returns the categorised list of
/// divergences. Pure function; thread-safe.
///
/// The dispatcher inspects the payload variant on both sides. When they
/// differ, it emits a single `.unexpected("payload.type", ...)` delta
/// without descending further — different payload variants are by definition
/// not comparable as the same family.
///
/// Per-family arms live in `DiagramDocumentDiff+<Family>.swift`. Each arm
/// returns `[RoundTripDelta]` and is responsible for normalising ordering,
/// resolving renamed identifiers, and emitting `.loss(_)` vs `.unexpected(_)`
/// per the round-trip discipline.
public func compare(_ a: DiagramDocument, _ b: DiagramDocument) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.title != b.title {
        if a.title != nil && b.title == nil {
            deltas.append(.loss(.titleDrop))
        } else {
            deltas.append(.unexpected(
                path: "title",
                detail: "lhs=\(a.title ?? "nil") rhs=\(b.title ?? "nil")"
            ))
        }
    }

    switch (a.payload, b.payload) {
    case (.flowchart(let lhs), .flowchart(let rhs)),
         (.stateDiagram(let lhs), .stateDiagram(let rhs)):
        deltas.append(contentsOf: diffParsedGraphModel(lhs, rhs))
    case (.sequenceDiagram(let lhs), .sequenceDiagram(let rhs)):
        deltas.append(contentsOf: diffSequenceDiagram(lhs, rhs))
    case (.classDiagram(let lhs), .classDiagram(let rhs)):
        deltas.append(contentsOf: diffClassDiagram(lhs, rhs))
    case (.erDiagram(let lhs), .erDiagram(let rhs)):
        deltas.append(contentsOf: diffErDiagram(lhs, rhs))
    case (.c4(let lhs), .c4(let rhs)):
        deltas.append(contentsOf: diffC4Diagram(lhs, rhs))
    case (.mindmap(let lhs), .mindmap(let rhs)):
        deltas.append(contentsOf: diffMindmapDiagram(lhs, rhs))
    case (.gantt(let lhs), .gantt(let rhs)):
        deltas.append(contentsOf: diffGanttDiagram(lhs, rhs))
    default:
        deltas.append(.unexpected(
            path: "payload.type",
            detail: "lhs=\(a.payload.type) rhs=\(b.payload.type)"
        ))
    }

    return deltas
}

// MARK: - Per-family stubs (filled in by subsequent cell tasks)
// Each stub returns `[.unexpected("not-yet-implemented", "<family>")]` until
// its cell task lands the real comparator.

func diffParsedGraphModel(_ a: ParsedGraphModel, _ b: ParsedGraphModel) -> [RoundTripDelta] {
    [.unexpected(path: "flowchart", detail: "not-yet-implemented")]
}

func diffSequenceDiagram(_ a: SequenceDiagram, _ b: SequenceDiagram) -> [RoundTripDelta] {
    [.unexpected(path: "sequence", detail: "not-yet-implemented")]
}

func diffClassDiagram(_ a: ClassDiagram, _ b: ClassDiagram) -> [RoundTripDelta] {
    [.unexpected(path: "class", detail: "not-yet-implemented")]
}

func diffErDiagram(_ a: ErDiagram, _ b: ErDiagram) -> [RoundTripDelta] {
    [.unexpected(path: "er", detail: "not-yet-implemented")]
}

func diffC4Diagram(_ a: C4Diagram, _ b: C4Diagram) -> [RoundTripDelta] {
    [.unexpected(path: "c4", detail: "not-yet-implemented")]
}

func diffMindmapDiagram(_ a: MindmapDiagram, _ b: MindmapDiagram) -> [RoundTripDelta] {
    [.unexpected(path: "mindmap", detail: "not-yet-implemented")]
}

func diffGanttDiagram(_ a: GanttDiagram, _ b: GanttDiagram) -> [RoundTripDelta] {
    [.unexpected(path: "gantt", detail: "not-yet-implemented")]
}
```

The stubs intentionally short-circuit: until each cell task lands its arm, any round-trip test for that family fails loudly with a descriptive `.unexpected`. The `identicalEmptyFlowchart` test in step 1 fails until Task 7 fills in `diffParsedGraphModel`; that's expected and tracked through the cell tasks.

- [ ] **Step 5: Adjust the dispatcher test to match the not-yet-implemented stub**

The `identicalEmptyFlowchart` test fails for now (the stub returns `.unexpected("flowchart", "not-yet-implemented")`). Update the test to assert on dispatcher behaviour only, not flowchart behaviour:

Replace the body of `identicalEmptyFlowchart` with:

```swift
let model = ParsedGraphModel()
let a = DiagramDocument(type: .flowchart, payload: .flowchart(model))
let b = DiagramDocument(type: .flowchart, payload: .flowchart(model))
let deltas = compare(a, b)
// Dispatcher routed correctly to the flowchart arm; the arm currently
// returns a not-yet-implemented stub. Task 7 will flip this assertion.
#expect(deltas.contains { delta in
    if case .unexpected(let path, _) = delta { return path == "flowchart" }
    return false
})
```

- [ ] **Step 6: Run to confirm pass**

Run: `swift test --filter DiagramDocumentDiffTests`
Expected: 2/2 tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitTestSupport/RoundTripDelta.swift Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift Tests/DiagramKitTests/RoundTrip/DiagramDocumentDiffTests.swift
git commit -m "$(cat <<'EOF'
feat(testsupport): RoundTripDelta + DiagramDocumentDiff dispatcher

Top-level compare(_:_:) dispatches on payload variant; per-family arms
live in DiagramDocumentDiff+<Family>.swift and currently return
not-yet-implemented stubs. Each cell task in the round-trip plan replaces
its family's stub with the real comparator. Title-drop handled at the
dispatcher level.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Land `RoundTripCell` + `RoundTripFixture` + Registry skeleton

**Files:**
- Create: `Sources/DiagramKitTestSupport/RoundTripCell.swift`
- Create: `Sources/DiagramKitTestSupport/RoundTripCellRegistry.swift`
- Test: `Tests/DiagramKitTests/RoundTrip/RoundTripCellTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import DiagramKitTestSupport
import DiagramKitImport
import DiagramKitExport
import DiagramKitMermaid

@Suite("RoundTripCell")
struct RoundTripCellTests {

    @Test("Registry exposes mermaidFlowchart cell with correct format identity")
    func mermaidFlowchartCellShape() {
        let cell = RoundTripCellRegistry.mermaidFlowchart
        #expect(cell.importer.formatID == .mermaid)
        #expect(cell.exporter.formatID == .mermaid)
        #expect(cell.family == .flowchart)
        #expect(cell.allowedLosses.contains(.idSanitization))
    }

    @Test("RoundTripFixture default has no additional allowed losses")
    func fixtureDefaults() {
        let fixture = RoundTripFixture(path: "x", source: "graph TD\nA-->B", additionalAllowedLosses: [], note: nil)
        #expect(fixture.additionalAllowedLosses.isEmpty)
        #expect(fixture.note == nil)
    }
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `swift test --filter RoundTripCellTests`
Expected: compile failure — `cannot find 'RoundTripCellRegistry' in scope`.

- [ ] **Step 3: Write `RoundTripCell.swift`**

```swift
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel

/// Static description of a (importer, exporter, family) cell in the
/// round-trip matrix. Allowed losses are case-tag-only — actual `RoundTripLoss`
/// payload is checked against this set via `loss.kind`.
public struct RoundTripCell<I: DiagramSourceImporter, E: DiagramExporter>: Sendable {
    public let importer: I
    public let exporter: E
    public let family: DiagramType
    public let allowedLosses: Set<RoundTripLossKind>

    public init(
        importer: I,
        exporter: E,
        family: DiagramType,
        allowedLosses: Set<RoundTripLossKind>
    ) {
        self.importer = importer
        self.exporter = exporter
        self.family = family
        self.allowedLosses = allowedLosses
    }
}

/// One fixture instance within a cell. `path` is the relative path under
/// `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`. `additionalAllowedLosses`
/// extends the cell's allow-list for this specific fixture (used when a
/// fixture intentionally exercises a lossy path the cell as a whole does not).
public struct RoundTripFixture: Sendable, CustomStringConvertible {
    public let path: String
    public let source: String
    public let additionalAllowedLosses: Set<RoundTripLossKind>
    public let note: String?

    public init(
        path: String,
        source: String,
        additionalAllowedLosses: Set<RoundTripLossKind> = [],
        note: String? = nil
    ) {
        self.path = path
        self.source = source
        self.additionalAllowedLosses = additionalAllowedLosses
        self.note = note
    }

    public var description: String { "RoundTripFixture(\(path))" }
}
```

- [ ] **Step 4: Write `RoundTripCellRegistry.swift` (skeleton with just `mermaidFlowchart`)**

```swift
import DiagramKitImport
import DiagramKitExport
import DiagramKitMermaid
import DiagramKitModel

/// Static declarations for every same-format round-trip cell in the matrix.
/// Cells are added incrementally as the per-family comparator arms land.
public enum RoundTripCellRegistry {
    public static let mermaidFlowchart = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: .flowchart,
        allowedLosses: [.idSanitization, .anonymousSubgraphRename]
    )

    // Subsequent cells declared by later tasks:
    //   mermaidSequence, mermaidClass, mermaidEr, mermaidC4,
    //   d2Flowchart, dotFlowchart, structurizrC4,
    //   plantumlSequence, plantumlClass, plantumlState,
    //   plantumlMindmap, plantumlGantt, plantumlC4
}
```

- [ ] **Step 5: Run to confirm pass**

Run: `swift test --filter RoundTripCellTests`
Expected: 2/2 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitTestSupport/RoundTripCell.swift Sources/DiagramKitTestSupport/RoundTripCellRegistry.swift Tests/DiagramKitTests/RoundTrip/RoundTripCellTests.swift
git commit -m "$(cat <<'EOF'
feat(testsupport): RoundTripCell + RoundTripFixture + registry skeleton

Generic over (importer, exporter) so any DiagramSourceImporter / DiagramExporter
pair can drive a cell. mermaidFlowchart cell declared up-front; remaining
13 same-format cells land via subsequent cell tasks. Per-fixture overrides
via additionalAllowedLosses.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Land `RoundTripHarness` (same-format + cross-format drivers)

**Files:**
- Create: `Sources/DiagramKitTestSupport/RoundTripHarness.swift`
- Test: `Tests/DiagramKitTests/RoundTrip/RoundTripHarnessTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import DiagramKitTestSupport
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport
import DiagramKitMermaid
import Foundation

@Suite("RoundTripHarness")
struct RoundTripHarnessTests {

    @Test("Same-format harness records unexpected delta as failure")
    func unexpectedDeltaThrows() {
        let cell = RoundTripCellRegistry.mermaidFlowchart
        let fixture = RoundTripFixture(path: "synthetic", source: "graph TD\nA-->B")
        // Mermaid flowchart comparator is currently a not-yet-implemented stub.
        // The harness should surface that as a failure rather than swallow it.
        do {
            try runSameFormatRoundTrip(cell: cell, fixture: fixture)
            Issue.record("expected the harness to throw on not-yet-implemented stub")
        } catch let error as RoundTripHarnessError {
            switch error {
            case .unexpectedDelta(let path, _, _):
                #expect(path == "flowchart")
            default:
                Issue.record("expected .unexpectedDelta, got \(error)")
            }
        } catch {
            Issue.record("expected RoundTripHarnessError, got \(error)")
        }
    }
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `swift test --filter RoundTripHarnessTests`
Expected: compile failure — `cannot find 'runSameFormatRoundTrip' in scope`.

- [ ] **Step 3: Write `RoundTripHarness.swift`**

```swift
import DiagramKitCommon
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel

/// Errors thrown by the round-trip harness. The harness converts comparator
/// output and diagnostic-pairing failures into descriptive thrown errors so
/// swift-testing reports them with full context (cell identity, fixture
/// identity, observed deltas, full exporter diagnostic bag).
public enum RoundTripHarnessError: Error, CustomStringConvertible {
    case importFailed(legSummary: String, fixturePath: String, underlying: Error)
    case exportFailed(legSummary: String, fixturePath: String, underlying: Error)
    case unexpectedDelta(path: String, detail: String, context: RoundTripHarnessContext)
    case disallowedLoss(loss: RoundTripLoss, context: RoundTripHarnessContext)
    case unpairedLoss(loss: RoundTripLoss, exportDiagnostics: [DiagramDiagnostic], context: RoundTripHarnessContext)

    public var description: String {
        switch self {
        case .importFailed(let legSummary, let fixturePath, let underlying):
            return "import failed for \(legSummary), fixture=\(fixturePath): \(underlying)"
        case .exportFailed(let legSummary, let fixturePath, let underlying):
            return "export failed for \(legSummary), fixture=\(fixturePath): \(underlying)"
        case .unexpectedDelta(let path, let detail, let context):
            return "unexpected delta at \(path) (\(detail)) in \(context)"
        case .disallowedLoss(let loss, let context):
            return "disallowed loss \(loss) in \(context)"
        case .unpairedLoss(let loss, let diagnostics, let context):
            return """
            unpaired loss \(loss) in \(context):
              export emitted \(diagnostics.count) diagnostics — none matched the loss kind.
              diagnostics=\(diagnostics)
            """
        }
    }
}

public struct RoundTripHarnessContext: CustomStringConvertible, Sendable {
    public let cellSummary: String
    public let fixturePath: String

    public var description: String {
        "cell=\(cellSummary) fixture=\(fixturePath)"
    }
}

/// Runs `parse → export → parse` for one cell + fixture and asserts the
/// round-trip discipline: every observed `RoundTripLoss` kind must be in
/// `cell.allowedLosses ∪ fixture.additionalAllowedLosses`; every observed loss
/// must have a paired `.warning`/`.unsupported` diagnostic on the export step;
/// any `RoundTripDelta.unexpected(_, _)` is a failure.
public func runSameFormatRoundTrip<I, E>(
    cell: RoundTripCell<I, E>,
    fixture: RoundTripFixture
) throws {
    let cellSummary = "(\(cell.importer.formatID.rawValue) ↔ \(cell.exporter.formatID.rawValue), \(cell.family.rawValue))"
    let context = RoundTripHarnessContext(cellSummary: cellSummary, fixturePath: fixture.path)

    let doc1: DiagramDocument
    do {
        doc1 = try cell.importer.parse(fixture.source).document
    } catch {
        throw RoundTripHarnessError.importFailed(legSummary: cellSummary, fixturePath: fixture.path, underlying: error)
    }

    let exported: DiagramExportResult
    do {
        exported = try cell.exporter.export(doc1)
    } catch {
        throw RoundTripHarnessError.exportFailed(legSummary: cellSummary, fixturePath: fixture.path, underlying: error)
    }

    let doc2: DiagramDocument
    do {
        doc2 = try cell.importer.parse(exported.source).document
    } catch {
        throw RoundTripHarnessError.importFailed(legSummary: cellSummary, fixturePath: fixture.path, underlying: error)
    }

    let deltas = compare(doc1, doc2)
    let allowed = cell.allowedLosses.union(fixture.additionalAllowedLosses)

    try enforce(deltas: deltas, allowed: allowed, exportDiagnostics: exported.diagnostics, context: context)
}

/// Runs `parse(legA) → export(legA) → parse(legB) → export(legB) → parse(legA)`
/// and asserts the round-trip discipline against the comparison of doc₁ vs
/// doc₃. Diagnostics from *both* export legs are checked for paired-loss
/// coverage.
public func runCrossFormatRoundTrip<I1, E1, I2, E2>(
    legA: RoundTripCell<I1, E1>,
    legB: RoundTripCell<I2, E2>,
    additionalAllowedLosses: Set<RoundTripLossKind> = [],
    fixture: RoundTripFixture
) throws {
    let cellSummary = "(\(legA.importer.formatID.rawValue) → \(legB.exporter.formatID.rawValue) → \(legA.importer.formatID.rawValue), \(legA.family.rawValue))"
    let context = RoundTripHarnessContext(cellSummary: cellSummary, fixturePath: fixture.path)

    let doc1: DiagramDocument
    do {
        doc1 = try legA.importer.parse(fixture.source).document
    } catch {
        throw RoundTripHarnessError.importFailed(legSummary: cellSummary, fixturePath: fixture.path, underlying: error)
    }

    let exportedB: DiagramExportResult
    do {
        exportedB = try legB.exporter.export(doc1)
    } catch {
        throw RoundTripHarnessError.exportFailed(legSummary: cellSummary, fixturePath: fixture.path, underlying: error)
    }

    let docB: DiagramDocument
    do {
        docB = try legB.importer.parse(exportedB.source).document
    } catch {
        throw RoundTripHarnessError.importFailed(legSummary: cellSummary, fixturePath: fixture.path, underlying: error)
    }

    let exportedA: DiagramExportResult
    do {
        exportedA = try legA.exporter.export(docB)
    } catch {
        throw RoundTripHarnessError.exportFailed(legSummary: cellSummary, fixturePath: fixture.path, underlying: error)
    }

    let doc3: DiagramDocument
    do {
        doc3 = try legA.importer.parse(exportedA.source).document
    } catch {
        throw RoundTripHarnessError.importFailed(legSummary: cellSummary, fixturePath: fixture.path, underlying: error)
    }

    let deltas = compare(doc1, doc3)
    let allowed = legA.allowedLosses
        .union(legB.allowedLosses)
        .union(additionalAllowedLosses)
        .union(fixture.additionalAllowedLosses)

    try enforce(
        deltas: deltas,
        allowed: allowed,
        exportDiagnostics: exportedB.diagnostics + exportedA.diagnostics,
        context: context
    )
}

private func enforce(
    deltas: [RoundTripDelta],
    allowed: Set<RoundTripLossKind>,
    exportDiagnostics: [DiagramDiagnostic],
    context: RoundTripHarnessContext
) throws {
    for delta in deltas {
        switch delta {
        case .unexpected(let path, let detail):
            throw RoundTripHarnessError.unexpectedDelta(path: path, detail: detail, context: context)
        case .loss(let loss):
            if !allowed.contains(loss.kind) {
                throw RoundTripHarnessError.disallowedLoss(loss: loss, context: context)
            }
            if !diagnosticsCover(loss: loss, in: exportDiagnostics) {
                throw RoundTripHarnessError.unpairedLoss(loss: loss, exportDiagnostics: exportDiagnostics, context: context)
            }
        }
    }
}

/// Tests whether the diagnostic bag contains at least one entry that
/// plausibly "explains" this loss. The matcher is keyword-based against
/// `DiagramDiagnostic.message` so exporters can phrase their diagnostics
/// naturally; new loss kinds require extending this table alongside the
/// loss enum case.
func diagnosticsCover(loss: RoundTripLoss, in diagnostics: [DiagramDiagnostic]) -> Bool {
    let relevant = diagnostics.filter {
        $0.severity == .warning || $0.severity == .unsupported
    }
    let keywords: [String]
    switch loss {
    case .idSanitization(let original, _):
        keywords = ["sanitiz", "alias", "renamed", original]
    case .shapeDowngrade(let nodeID, _, _):
        keywords = ["shape", nodeID]
    case .subgraphFlatten(let id, _):
        keywords = ["subgraph", "cluster", id]
    case .boundaryFlatten(let id, _):
        keywords = ["boundary", id]
    case .c4SlotDrop(let id, let slot):
        keywords = [slot.rawValue, id]
    case .titleDrop:
        keywords = ["title"]
    case .configDrop(let key):
        keywords = [key, "config", "frontmatter"]
    case .styleDrop(let target, let attribute):
        keywords = [target, attribute, "style"]
    case .accessibilityDrop(let field):
        keywords = [field.rawValue, "accessib", "accTitle", "accDescr"]
    case .anonymousSubgraphRename:
        // Anonymous subgraph renames are positional artifacts of the parser,
        // not exporter-driven. Exempt from the paired-diagnostic rule.
        return true
    case .d2DuplicateOverride(let id, _):
        keywords = ["duplicate", id]
    }
    return relevant.contains { diagnostic in
        let message = diagnostic.message.lowercased()
        return keywords.contains { message.contains($0.lowercased()) }
    }
}
```

(If `DiagramSourceImporter.parse(_:)` is `throws` and `DiagramImportResult.document` is the property name, this compiles. Verify the exact signatures by reading `Sources/DiagramKitImport/DiagramSourceImporter.swift` and adjust if necessary — `.parse(_:)` may need a different argument label.)

- [ ] **Step 4: Run to confirm pass**

Run: `swift test --filter RoundTripHarnessTests`
Expected: 1/1 test passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitTestSupport/RoundTripHarness.swift Tests/DiagramKitTests/RoundTrip/RoundTripHarnessTests.swift
git commit -m "$(cat <<'EOF'
feat(testsupport): RoundTripHarness drivers + paired-diagnostic gate

runSameFormatRoundTrip drives parse → export → parse and enforces three
checks: every observed loss kind is in the per-cell allow-list, every
observed loss has a paired .warning/.unsupported diagnostic on the export
step, and any .unexpected delta is a failure. runCrossFormatRoundTrip
follows the A→B→A path with diagnostics aggregated across both export
legs. Keyword-driven diagnostic coverage table; anonymous-subgraph
renames are exempt (parser-positional, not exporter-driven).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Land `RoundTripFixtureLoader` + first `mermaid-flowchart/01-basic.md` happy-path fixture

**Files:**
- Create: `Sources/DiagramKitTestSupport/RoundTripFixtureLoader.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-flowchart/01-basic.md`
- Test: `Tests/DiagramKitTests/RoundTrip/RoundTripFixtureLoaderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import DiagramKitTestSupport
import Foundation

@Suite("RoundTripFixtureLoader")
struct RoundTripFixtureLoaderTests {

    @Test("Loads .md fixtures from mermaid-flowchart directory")
    func loadsMermaidFlowchartFixtures() throws {
        let fixtures = try fixtures(for: "mermaid-flowchart", fromRoot: roundTripResourcesRoot())
        #expect(!fixtures.isEmpty, "expected at least 01-basic.md")
        #expect(fixtures.contains { $0.path.hasSuffix("01-basic.md") })
    }

    @Test("Sidecar JSON populates additionalAllowedLosses")
    func sidecarJSON() throws {
        // We synthesise a sidecar at runtime to exercise the loader without
        // committing a sidecar-only fixture. Use the temp dir.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("rt-loader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("foo-flowchart"), withIntermediateDirectories: true)
        try "graph TD\nA-->B".write(
            to: tmp.appendingPathComponent("foo-flowchart/01-basic.md"),
            atomically: true,
            encoding: .utf8
        )
        try #"{"additionalAllowedLosses":["shapeDowngrade"],"note":"test"}"#.write(
            to: tmp.appendingPathComponent("foo-flowchart/01-basic.json"),
            atomically: true,
            encoding: .utf8
        )
        defer { try? FileManager.default.removeItem(at: tmp) }

        let fixtures = try fixtures(for: "foo-flowchart", fromRoot: tmp)
        #expect(fixtures.count == 1)
        #expect(fixtures[0].additionalAllowedLosses == [.shapeDowngrade])
        #expect(fixtures[0].note == "test")
    }
}

/// Resolves the absolute URL of `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`
/// from the location of this test file. Mirrors the projectRoot()-from-#filePath
/// pattern used by CorpusSnapshotTests.
func roundTripResourcesRoot(file: StaticString = #filePath) -> URL {
    URL(fileURLWithPath: "\(file)")
        .deletingLastPathComponent()
        .appendingPathComponent("Resources/roundtrip", isDirectory: true)
}
```

- [ ] **Step 2: Run to confirm failure**

Run: `swift test --filter RoundTripFixtureLoaderTests`
Expected: compile failure — `cannot find 'fixtures' in scope`.

- [ ] **Step 3: Write `RoundTripFixtureLoader.swift`**

```swift
import Foundation

/// Loads round-trip fixtures from a directory. Each fixture source file
/// (.md, .d2, .dot, .dsl, .puml) may optionally have a sidecar .json with
/// the same basename declaring `additionalAllowedLosses` and `note`.
///
/// Returns fixtures sorted by `path` for deterministic test ordering.
public func fixtures(
    for cellDirectory: String,
    fromRoot root: URL
) throws -> [RoundTripFixture] {
    let dir = root.appendingPathComponent(cellDirectory, isDirectory: true)
    let contents = try FileManager.default.contentsOfDirectory(
        at: dir,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    )

    let sourceExtensions: Set<String> = ["md", "mmd", "d2", "dot", "gv", "dsl", "puml", "plantuml"]
    let sources = contents
        .filter { sourceExtensions.contains($0.pathExtension.lowercased()) }
        .sorted { $0.path < $1.path }

    return try sources.map { sourceURL in
        let sidecarURL = sourceURL.deletingPathExtension().appendingPathExtension("json")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let sidecar = try loadSidecar(at: sidecarURL)
        let relativePath = "\(cellDirectory)/\(sourceURL.lastPathComponent)"
        return RoundTripFixture(
            path: relativePath,
            source: source,
            additionalAllowedLosses: sidecar.additionalAllowedLosses,
            note: sidecar.note
        )
    }
}

private struct Sidecar: Decodable {
    let additionalAllowedLosses: Set<RoundTripLossKind>
    let note: String?

    init(additionalAllowedLosses: Set<RoundTripLossKind>, note: String?) {
        self.additionalAllowedLosses = additionalAllowedLosses
        self.note = note
    }

    static let empty = Sidecar(additionalAllowedLosses: [], note: nil)
}

private func loadSidecar(at url: URL) throws -> Sidecar {
    guard FileManager.default.fileExists(atPath: url.path) else {
        return .empty
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Sidecar.self, from: data)
}
```

- [ ] **Step 4: Create `01-basic.md` fixture**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-flowchart/01-basic.md`:

```
graph TD
    A[Start] --> B[Process]
    B --> C[End]
```

- [ ] **Step 5: Run to confirm pass**

Run: `swift test --filter RoundTripFixtureLoaderTests`
Expected: 2/2 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitTestSupport/RoundTripFixtureLoader.swift Tests/DiagramKitTests/RoundTrip/RoundTripFixtureLoaderTests.swift Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-flowchart/01-basic.md
git commit -m "$(cat <<'EOF'
feat(testsupport): RoundTripFixtureLoader + first happy-path fixture

fixtures(for:fromRoot:) walks the cell directory, pairs source files with
optional sidecar JSON for per-fixture allowed-loss overrides, and returns
a deterministically ordered RoundTripFixture array. First fixture
mermaid-flowchart/01-basic.md exercises a three-node linear flow with
labels — happy path, no overrides.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Mermaid flowchart cell — comparator arm + first cell test

**Files:**
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Flowchart.swift`
- Modify: `Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift` (remove the `diffParsedGraphModel` stub)
- Create: `Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift`
- Add: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-flowchart/02-edges-with-labels.md` (one additional fixture for arm coverage)

This is the first cell task — it follows the **Cell Scaffolding Recipe** above. The flowchart comparator handles `ParsedGraphModel` (which is also used by `.stateDiagram` — same arm, two payload arms in the dispatcher already route here).

- [ ] **Step 1: Write the failing `SameFormatRoundTripTests.swift`**

```swift
import Testing
import DiagramKitTestSupport
import Foundation

@Suite("Same-format round-trip")
struct SameFormatRoundTripTests {

    @Test("Mermaid flowchart round-trip", arguments: try fixtures(for: "mermaid-flowchart", fromRoot: roundTripResourcesRoot()))
    func mermaidFlowchart(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidFlowchart,
            fixture: fixture
        )
    }
}

func roundTripResourcesRoot(file: StaticString = #filePath) -> URL {
    URL(fileURLWithPath: "\(file)")
        .deletingLastPathComponent()
        .appendingPathComponent("Resources/roundtrip", isDirectory: true)
}
```

Note: if `RoundTripFixtureLoaderTests.swift` from Task 6 already declares `roundTripResourcesRoot(file:)`, delete the local copy there and have both files import the one in `SameFormatRoundTripTests.swift`. Keep exactly one top-level definition.

- [ ] **Step 2: Run to confirm failure (`unexpected("flowchart", "not-yet-implemented")`)**

Run: `swift test --filter SameFormatRoundTripTests/mermaidFlowchart`
Expected: 1 fixture, failure with `RoundTripHarnessError.unexpectedDelta(path: "flowchart", detail: "not-yet-implemented", …)`.

- [ ] **Step 3: Delete the stub in `DiagramDocumentDiff.swift`**

Remove the lines:

```swift
func diffParsedGraphModel(_ a: ParsedGraphModel, _ b: ParsedGraphModel) -> [RoundTripDelta] {
    [.unexpected(path: "flowchart", detail: "not-yet-implemented")]
}
```

- [ ] **Step 4: Write `DiagramDocumentDiff+Flowchart.swift`**

```swift
import DiagramKitModel

func diffParsedGraphModel(_ a: ParsedGraphModel, _ b: ParsedGraphModel) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    // Build id maps (sanitization may have renamed ids).
    let aNodes = Dictionary(uniqueKeysWithValues: a.nodesInOrder.compactMap { id in
        a.nodes[id].map { (id, $0) }
    })
    let bNodes = Dictionary(uniqueKeysWithValues: b.nodesInOrder.compactMap { id in
        b.nodes[id].map { (id, $0) }
    })

    // 1) Node id symmetry. Renames map across via .idSanitization. Anonymous
    // subgraph renames are tracked separately via .anonymousSubgraphRename.
    deltas.append(contentsOf: diffNodeIDs(a: aNodes, b: bNodes))

    // 2) Per-node label + shape comparison.
    for (id, aNode) in aNodes {
        guard let bNode = bNodes[id] else { continue }
        if aNode.label != bNode.label {
            deltas.append(.unexpected(
                path: "nodes[\(id)].label",
                detail: "lhs=\(aNode.label ?? "nil") rhs=\(bNode.label ?? "nil")"
            ))
        }
        if aNode.shape != bNode.shape {
            deltas.append(.loss(.shapeDowngrade(nodeID: id, from: aNode.shape, to: bNode.shape)))
        }
    }

    // 3) Edge symmetry. Edges are ordered, so compare positionally up to
    // ordering tolerance — sort by (from, to, label) for stability.
    let aEdges = a.edges.sorted { lhs, rhs in
        (lhs.from, lhs.to, lhs.label ?? "") < (rhs.from, rhs.to, rhs.label ?? "")
    }
    let bEdges = b.edges.sorted { lhs, rhs in
        (lhs.from, lhs.to, lhs.label ?? "") < (rhs.from, rhs.to, rhs.label ?? "")
    }
    if aEdges.count != bEdges.count {
        deltas.append(.unexpected(
            path: "edges.count",
            detail: "lhs=\(aEdges.count) rhs=\(bEdges.count)"
        ))
    } else {
        for (i, (ae, be)) in zip(aEdges, bEdges).enumerated() {
            if ae.from != be.from || ae.to != be.to {
                deltas.append(.unexpected(
                    path: "edges[\(i)].endpoints",
                    detail: "lhs=(\(ae.from)→\(ae.to)) rhs=(\(be.from)→\(be.to))"
                ))
            }
            if (ae.label ?? "") != (be.label ?? "") {
                deltas.append(.unexpected(
                    path: "edges[\(i)].label",
                    detail: "lhs=\(ae.label ?? "nil") rhs=\(be.label ?? "nil")"
                ))
            }
        }
    }

    // 4) Subgraphs. Anonymous subgraph ids are positional; emit
    // .anonymousSubgraphRename for the (old → new) pair and continue.
    deltas.append(contentsOf: diffSubgraphs(a: a, b: b))

    return deltas
}

private func diffNodeIDs(a: [String: ParsedGraphNode], b: [String: ParsedGraphNode]) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []
    let onlyA = Set(a.keys).subtracting(b.keys)
    let onlyB = Set(b.keys).subtracting(a.keys)
    // Pair lhs-only with rhs-only via the sanitization rule: same label, same shape.
    var pairedRhs: Set<String> = []
    for aID in onlyA {
        guard let aNode = a[aID] else { continue }
        let match = onlyB.first { bID in
            !pairedRhs.contains(bID)
                && b[bID]?.label == aNode.label
                && b[bID]?.shape == aNode.shape
        }
        if let bID = match {
            deltas.append(.loss(.idSanitization(original: aID, sanitized: bID)))
            pairedRhs.insert(bID)
        } else {
            deltas.append(.unexpected(path: "nodes", detail: "lhs-only id=\(aID)"))
        }
    }
    for bID in onlyB where !pairedRhs.contains(bID) {
        deltas.append(.unexpected(path: "nodes", detail: "rhs-only id=\(bID)"))
    }
    return deltas
}

private func diffSubgraphs(a: ParsedGraphModel, b: ParsedGraphModel) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []
    if a.subgraphIds.count != b.subgraphIds.count {
        deltas.append(.unexpected(
            path: "subgraphs.count",
            detail: "lhs=\(a.subgraphIds.count) rhs=\(b.subgraphIds.count)"
        ))
        return deltas
    }
    for (aID, bID) in zip(a.subgraphIds, b.subgraphIds) where aID != bID {
        let isAnonymous = aID.hasPrefix("subgraph_") && bID.hasPrefix("subgraph_")
        if isAnonymous {
            deltas.append(.loss(.anonymousSubgraphRename(old: aID, new: bID)))
        } else {
            deltas.append(.unexpected(
                path: "subgraphs",
                detail: "lhs id=\(aID) rhs id=\(bID)"
            ))
        }
    }
    return deltas
}
```

(Property names like `nodesInOrder`, `subgraphIds`, `ParsedGraphNode.label`/`shape` must match what `ParsedGraphModel` actually exposes. Read `Sources/DiagramKitModel/Types.swift` and `src_types.swift` before writing this file and adjust property names to match. The above sketch reflects the typical shape.)

- [ ] **Step 5: Add a second fixture exercising the edge-label arm**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-flowchart/02-edges-with-labels.md`:

```
graph LR
    A[Source] -->|forward| B[Destination]
    B -->|return| A
```

- [ ] **Step 6: Run and iterate until pass**

Run: `swift test --filter SameFormatRoundTripTests/mermaidFlowchart`
Expected on first attempt: a mix of pass/fail. For each failure:
- `.unexpected` ⇒ either fix a property-name mismatch in the comparator or add a comparator arm for the divergence.
- `.disallowedLoss` ⇒ extend `RoundTripCellRegistry.mermaidFlowchart.allowedLosses` if the loss is structurally intentional.
- `.unpairedLoss` ⇒ add a `.warning` diagnostic emission in the relevant exporter slice (`Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidFlowchartExport.swift`) so the exporter announces the loss.

Iterate until both fixtures pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift Sources/DiagramKitTestSupport/DiagramDocumentDiff+Flowchart.swift Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-flowchart/
git commit -m "$(cat <<'EOF'
feat(testsupport): Mermaid flowchart round-trip cell + comparator

DiagramDocumentDiff+Flowchart implements ParsedGraphModel comparison —
node id symmetry via sanitization pairing, label + shape + edge endpoint
+ edge label structural checks, subgraph id positional check with
.anonymousSubgraphRename loss for positional id drift. Two fixtures
(01-basic, 02-edges-with-labels) green; cell allowed losses are
.idSanitization + .anonymousSubgraphRename per the registry skeleton.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Tasks 8–19: Remaining same-format cells (one commit each)

Each cell task follows the **Cell Scaffolding Recipe**. For each cell below, the task lands the comparator arm (or extends it), the cell registry entry, ≥3 fixtures (the listed ones), and one `@Test` in `SameFormatRoundTripTests.swift`. Same-format `RoundTripCellRegistry` entries appear in registry order. The TDD beat is identical: write the @Test, run to see failure, land the cell + comparator + fixtures, iterate to green, commit.

For each cell the engineer must, *before* writing the comparator file:
1. Read `Sources/DiagramKitModel/src_<family>_*.swift` to learn the payload type's actual property names and identity model.
2. Read the exporter source under `Sources/DiagramKit<Format>/Exporter/` and the importer source under `Sources/DiagramKit<Format>/` to learn which losses the exporter intentionally introduces and which diagnostics it currently emits.

If the round-trip surfaces a *lossy path with no emitted diagnostic*, that is the original review's "exporter silently drops data" shape — fix the exporter to emit the diagnostic *in the same commit* (don't add the loss to the cell allow-list and call it done).

---

#### Task 8: Mermaid sequence cell

**Cell registry entry:**

```swift
public static let mermaidSequence = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: .sequenceDiagram,
    allowedLosses: [.idSanitization]
)
```

**Comparator arm — `DiagramDocumentDiff+Sequence.swift`:** compares `SequenceDiagram` actor list (order-insensitive by id after sanitization pairing), `messages` (order-sensitive — sequence order is semantically meaningful), `notes`, `activations`, `links`, `properties`, `details`, and `destroyed` actors. Title at the document level is handled by the dispatcher.

**Fixtures (`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-sequence/`):**
- `01-basic.md` — two actors, one message:
  ```
  sequenceDiagram
      Alice->>Bob: Hello
      Bob-->>Alice: Hi
  ```
- `02-participants-and-notes.md` — explicit `participant` declarations + a `Note over` block.
- `03-loops-and-alt.md` — `loop`/`alt`/`else`/`end` control flow.

**Per-fixture overrides:** none.

**@Test:**

```swift
@Test("Mermaid sequence round-trip", arguments: try fixtures(for: "mermaid-sequence", fromRoot: roundTripResourcesRoot()))
func mermaidSequence(fixture: RoundTripFixture) throws {
    try runSameFormatRoundTrip(cell: RoundTripCellRegistry.mermaidSequence, fixture: fixture)
}
```

**Commit message:**

```
feat(testsupport): Mermaid sequence round-trip cell + comparator

Actor/message/note/activation comparison; sequence order treated as
semantically significant. Three fixtures: basic two-actor exchange,
participant declarations + notes, loop/alt/else control flow.
```

---

#### Task 9: Mermaid class cell

**Cell registry entry:**

```swift
public static let mermaidClass = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: .classDiagram,
    allowedLosses: [.idSanitization]
)
```

**Comparator arm — `DiagramDocumentDiff+Class.swift`:** compares `ClassDiagram.classes` (by id, with sanitization pairing), `relationships`, `namespaces`, `notes`, `direction` (now a typed `ClassDirection` enum per Session 2's `7bdd439`).

**Fixtures (`mermaid-class/`):**
- `01-basic.md` — two classes + an association.
- `02-inheritance-and-stereotypes.md` — `<<interface>>` annotation, `<|--`, members + methods.
- `03-namespaces.md` — `namespace { … }` block.

**Per-fixture overrides:** none.

**Commit message:**

```
feat(testsupport): Mermaid class round-trip cell + comparator

Class/relationship/namespace/note comparison; ClassDirection enum
checked directly (typed since Session 2). Three fixtures covering basic
association, inheritance + stereotypes + members, and namespace blocks.
```

---

#### Task 10: Mermaid ER cell

**Cell registry entry:**

```swift
public static let mermaidEr = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: .erDiagram,
    allowedLosses: [.idSanitization, .accessibilityDrop]
)
```

`.accessibilityDrop` because some Mermaid ER frontmatter / `accTitle`/`accDescr` paths are documented as lossy.

**Comparator arm — `DiagramDocumentDiff+ER.swift`:** compares `ErDiagram.entities` (with attributes, including PK/FK markers, types, comments), `relationships` (cardinality + label), `config` (the `ErDiagramConfig` plumbed through in Session 12's `cdfcf3c`), `accTitle`, `accDescr`, `diagramTitle`.

**Fixtures (`mermaid-er/`):**
- `01-basic.md` — two entities + one relationship.
- `02-attributes-and-keys.md` — entities with attributes including PK/FK and type modifiers.
- `03-md-parent-marker.md` — exercises the parent-cardinality path (closed by Session 2's `e2b9d57`).

**Per-fixture overrides:** none.

**Commit message:**

```
feat(testsupport): Mermaid ER round-trip cell + comparator

Entity/attribute/relationship/config comparison; accessibility-drop in
cell allow-list. Three fixtures: basic two-entity, attributes with PK/FK
markers, MD_PARENT cardinality.
```

---

#### Task 11: Mermaid C4 cell

**Cell registry entry:**

```swift
public static let mermaidC4 = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: .c4,
    allowedLosses: [.idSanitization, .boundaryFlatten]
)
```

`.boundaryFlatten` is *intentional* per Structurizr round-trip — both Mermaid and Structurizr flatten nested authored boundaries to siblings in some configurations.

**Comparator arm — `DiagramDocumentDiff+C4.swift`:** compares `C4Diagram.shapes` (with `C4ShapeType`, technology/description slots gated by `hasTechnologySlot`), `relationships`, `boundaries` (with `C4BoundaryOrigin` from Session 6's `81ddf33`), tags. The comparator surfaces `c4SlotDrop` when one side has a populated slot and the other doesn't.

**Fixtures (`mermaid-c4/`):**
- `01-context.md` — `Person` + `System` + `Rel`.
- `02-container.md` — `Container_Boundary { … }` + multiple containers.
- `03-named-args.md` — exercises the `$boundary=`/`$tags=` post-paren syntax closed by Session 9 (`4e2a6e3`).

**Per-fixture overrides:** none.

**Commit message:**

```
feat(testsupport): Mermaid C4 round-trip cell + comparator

C4 shape/relationship/boundary comparison; tech/description slot checking
via C4ShapeType.hasTechnologySlot; boundary-flatten in cell allow-list.
Three fixtures: Context, Container_Boundary, named-arg post-paren syntax
(Session 9 regression coverage).
```

---

#### Task 12: D2 flowchart cell

**Cell registry entry:**

```swift
public static let d2Flowchart = RoundTripCell(
    importer: D2Importer(),
    exporter: D2Exporter(),
    family: .flowchart,
    allowedLosses: [.subgraphFlatten, .styleDrop, .shapeDowngrade, .d2DuplicateOverride]
)
```

**Comparator arm:** reuses `diffParsedGraphModel` from Task 7. No new file needed; only the cell entry + fixtures + @Test land in this commit.

**Fixtures (`d2-flowchart/`):**
- `01-basic.d2` — three nodes + two edges.
- `02-shapes.d2` — exercises D2's shape vocabulary (covers shape-downgrade pairing).
- `03-styles.d2` — fill/stroke/font attributes (covers `styleDrop`).

**Per-fixture overrides:** none.

**Commit message:**

```
feat(testsupport): D2 flowchart round-trip cell

Reuses ParsedGraphModel comparator from Task 7. Cell allow-list covers
subgraph flatten (per FlowchartExportWalker subgraph-drop diagnostic
since Session 2's 5efa83f), style drop, shape downgrade, and D2
duplicate-node override (per upsertNode diagnostics).
```

---

#### Task 13: DOT flowchart cell

**Cell registry entry:**

```swift
public static let dotFlowchart = RoundTripCell(
    importer: GraphvizImporter(),
    exporter: DOTExporter(),
    family: .flowchart,
    allowedLosses: [.subgraphFlatten, .styleDrop, .shapeDowngrade]
)
```

**Comparator arm:** reuses `diffParsedGraphModel`. Only cell entry + fixtures + @Test land.

**Fixtures (`dot-flowchart/`):**
- `01-basic.dot` — three nodes + two directed edges.
- `02-clusters.dot` — `subgraph cluster_a { … }` (exercises subgraph-flatten).
- `03-html-labels.dot` — `label=<<TABLE>…</TABLE>>` (exercises the HTML-label path closed by `9dd168a`; sidecar JSON declares `additionalAllowedLosses: ["styleDrop"]`).

**Per-fixture overrides:**
- `03-html-labels.json`:
  ```json
  {"additionalAllowedLosses": ["styleDrop"], "note": "HTML labels fall back to node id with .unsupported diagnostic"}
  ```

**Commit message:**

```
feat(testsupport): DOT flowchart round-trip cell

Reuses ParsedGraphModel comparator. Cell allow-list covers cluster
flatten, style drop, and shape downgrade. HTML-label fixture exercises
the path closed by 9dd168a with a per-fixture styleDrop override.
```

---

#### Task 14: Structurizr C4 cell

**Cell registry entry:**

```swift
public static let structurizrC4 = RoundTripCell(
    importer: StructurizrImporter(),
    exporter: StructurizrExporter(),
    family: .c4,
    allowedLosses: [.idSanitization, .boundaryFlatten]
)
```

**Comparator arm:** reuses `diffC4Diagram` from Task 11.

**Fixtures (`structurizr-c4/`):**
- `01-basic.dsl` — workspace { model { … } views { systemContext s … } }.
- `02-groups.dsl` — `group "label" { … }` block (exercises Session 6's `81ddf33` end-to-end).
- `03-nested-groups.dsl` — nested groups (exercises `boundaryFlatten` warning per Session 6 plan).

**Per-fixture overrides:**
- `03-nested-groups.json`:
  ```json
  {"additionalAllowedLosses": ["boundaryFlatten"], "note": "Nested authored groups flatten to siblings with .warning"}
  ```

**Commit message:**

```
feat(testsupport): Structurizr C4 round-trip cell

Reuses C4 comparator from Task 11. Cell allow-list covers idSanitization
+ boundaryFlatten. Three fixtures: basic workspace, single group block
(Session 6 end-to-end), nested groups (boundary-flatten warning path).
```

---

#### Task 15: PlantUML sequence cell

**Cell registry entry:**

```swift
public static let plantumlSequence = RoundTripCell(
    importer: PlantUMLImporter(),
    exporter: PlantUMLExporter(),
    family: .sequenceDiagram,
    allowedLosses: [.idSanitization]
)
```

**Comparator arm:** reuses `diffSequenceDiagram` from Task 8.

**Fixtures (`plantuml-sequence/`):**
- `01-basic.puml` — two actors, two messages.
- `02-title-and-participants.puml` — `title <text>` (regression coverage for Session 2's `5ef689f` title round-trip) + explicit `participant` declarations.
- `03-quotes-and-escapes.puml` — message labels containing `"`, `\`, and `:` (regression for Session 2's escape fix).

**Per-fixture overrides:** none.

**Commit message:**

```
feat(testsupport): PlantUML sequence round-trip cell

Reuses sequence comparator from Task 8. Three fixtures: basic exchange,
title + participants (Session 2 round-trip regression), and label
quote/colon/backslash escape (Session 2 escape regression).
```

---

#### Task 16: PlantUML class cell

**Cell registry entry:**

```swift
public static let plantumlClass = RoundTripCell(
    importer: PlantUMLImporter(),
    exporter: PlantUMLExporter(),
    family: .classDiagram,
    allowedLosses: [.idSanitization]
)
```

**Comparator arm:** reuses `diffClassDiagram` from Task 9.

**Fixtures (`plantuml-class/`):**
- `01-basic.puml` — two classes + association.
- `02-inheritance.puml` — `Parent <|-- Child` with members.
- `03-block-comment.puml` — `/' … '/` multi-line comment (regression for Session 2's `5ef689f` block-comment handling).

**Per-fixture overrides:** none.

**Commit message:**

```
feat(testsupport): PlantUML class round-trip cell

Reuses class comparator from Task 9. Three fixtures including block-
comment fixture (Session 2 regression coverage for /' ... '/ handling).
```

---

#### Task 17: PlantUML state cell

**Cell registry entry:**

```swift
public static let plantumlState = RoundTripCell(
    importer: PlantUMLImporter(),
    exporter: PlantUMLExporter(),
    family: .stateDiagram,
    allowedLosses: [.idSanitization]
)
```

**Comparator arm:** reuses `diffParsedGraphModel` from Task 7 (state diagrams use the same payload).

**Fixtures (`plantuml-state/`):**
- `01-basic.puml` — two states + transition.
- `02-pseudostates.puml` — `[*] -> state` (regression coverage for Session 2's `a13b67c` pseudostate restoration via `NodeShape.stateStart`/`stateEnd`).
- `03-customer-start.puml` — a legitimately named `customer_start` state (regression for the original Critical bug — `restorePseudostate` previously rewrote anything ending in `_start`/`_end`).

**Per-fixture overrides:** none.

**Commit message:**

```
feat(testsupport): PlantUML state round-trip cell

Reuses ParsedGraphModel comparator. Three fixtures: basic transition,
explicit pseudostates [*] (Session 2 regression), and customer_start
state name (original Critical bug regression — restorePseudostate must
not rewrite legitimately-named ids ending in _start/_end).
```

---

#### Task 18: PlantUML mindmap cell

**Cell registry entry:**

```swift
public static let plantumlMindmap = RoundTripCell(
    importer: PlantUMLImporter(),
    exporter: PlantUMLExporter(),
    family: .mindmap,
    allowedLosses: [.idSanitization]
)
```

**Comparator arm — `DiagramDocumentDiff+Mindmap.swift`:** compares `MindmapDiagram` root + tree of child nodes. Tree comparison is structural — depth-first traversal with per-node label + style checks.

**Fixtures (`plantuml-mindmap/`):**
- `01-basic.puml` — root + two children.
- `02-deep.puml` — 4-level deep tree.
- `03-style.puml` — `+`/`-` markers for left/right side (covers `styleDrop` if applicable).

**Per-fixture overrides:** if exporting drops the side marker, add `{"additionalAllowedLosses": ["styleDrop"]}` to `03-style.json`.

**Commit message:**

```
feat(testsupport): PlantUML mindmap round-trip cell + comparator

DiagramDocumentDiff+Mindmap compares root + tree-of-children with
depth-first structural traversal. Three fixtures: basic root + 2
children, 4-level deep tree, +/- side markers.
```

---

#### Task 19: PlantUML gantt cell

**Cell registry entry:**

```swift
public static let plantumlGantt = RoundTripCell(
    importer: PlantUMLImporter(),
    exporter: PlantUMLExporter(),
    family: .gantt,
    allowedLosses: [.idSanitization, .configDrop]
)
```

**Comparator arm — `DiagramDocumentDiff+Gantt.swift`:** compares `GanttDiagram.tasks` (id, label, start, duration, dependencies), `sections`, `axisFormat`, `excludeDates`, `today`.

**Fixtures (`plantuml-gantt/`):**
- `01-basic.puml` — three tasks in a single section.
- `02-dependencies.puml` — tasks with `after task1`.
- `03-axis-format.puml` — explicit `dateFormat`/`axisFormat` (covers `configDrop`).

**Per-fixture overrides:** none (`configDrop` already in cell allow-list).

**Commit message:**

```
feat(testsupport): PlantUML gantt round-trip cell + comparator

DiagramDocumentDiff+Gantt compares tasks + dependencies + sections +
axis config. configDrop in cell allow-list since axisFormat / dateFormat
do not consistently round-trip.
```

---

#### Task 20: PlantUML C4 cell

**Cell registry entry:**

```swift
public static let plantumlC4 = RoundTripCell(
    importer: PlantUMLImporter(),
    exporter: PlantUMLExporter(),
    family: .c4,
    allowedLosses: [.idSanitization, .boundaryFlatten]
)
```

**Comparator arm:** reuses `diffC4Diagram` from Task 11.

**Fixtures (`plantuml-c4/`):**
- `01-context.puml` — `Person`, `System`, `Rel`.
- `02-container.puml` — `Container_Boundary` block.
- `03-tech-slot.puml` — shape with technology slot present (regression for `8546f81` C4 slot semantics).

**Per-fixture overrides:** none.

**Commit message:**

```
feat(testsupport): PlantUML C4 round-trip cell

Reuses C4 comparator from Task 11. Three fixtures: Context, Container_
Boundary, tech-slot regression (8546f81 cross-format slot semantics).
```

---

### Tasks 21–28: Cross-format pairs (one commit per unordered pair)

Each cross-format pair lands two `@Test`s (one per ordered direction) in `CrossFormatRoundTripTests.swift`, two entries in `RoundTripCrossRegistry.swift`, and fixtures in both direction-specific resource directories. Follows the **Cross-format Scaffolding Recipe**.

For each pair the engineer must:
1. Read both leg's importer and exporter to learn the format-specific lossy paths *that surface only when the foreign format is the middle leg*. The intermediate format's narrower vocabulary is usually the source of additional losses.
2. Author *symmetric* fixture pairs where possible — a Mermaid source whose D2-foreign round-trip exercises the same shape as a D2 source whose Mermaid-foreign round-trip would.

---

#### Task 21: Mermaid↔D2 (flowchart)

**Registry entries (`RoundTripCrossRegistry.swift`):**

```swift
enum RoundTripCrossRegistry {
    static let mermaidD2Flowchart = (
        legA: RoundTripCellRegistry.mermaidFlowchart,
        legB: RoundTripCellRegistry.d2Flowchart,
        additionalAllowedLosses: Set<RoundTripLossKind>([.subgraphFlatten, .styleDrop, .shapeDowngrade])
    )
    static let d2MermaidFlowchart = (
        legA: RoundTripCellRegistry.d2Flowchart,
        legB: RoundTripCellRegistry.mermaidFlowchart,
        additionalAllowedLosses: Set<RoundTripLossKind>([.idSanitization, .shapeDowngrade])
    )
    // remaining entries added by subsequent cross-format tasks
}
```

**@Tests in `CrossFormatRoundTripTests.swift`:**

```swift
@Suite("Cross-format round-trip")
struct CrossFormatRoundTripTests {

    @Test("Mermaid → D2 → Mermaid (flowchart)", arguments: try fixtures(for: "cross-mermaid-d2-flowchart", fromRoot: roundTripResourcesRoot()))
    func mermaidD2Flowchart(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCrossRegistry.mermaidD2Flowchart.legA,
            legB: RoundTripCrossRegistry.mermaidD2Flowchart.legB,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidD2Flowchart.additionalAllowedLosses,
            fixture: fixture
        )
    }

    @Test("D2 → Mermaid → D2 (flowchart)", arguments: try fixtures(for: "cross-d2-mermaid-flowchart", fromRoot: roundTripResourcesRoot()))
    func d2MermaidFlowchart(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCrossRegistry.d2MermaidFlowchart.legA,
            legB: RoundTripCrossRegistry.d2MermaidFlowchart.legB,
            additionalAllowedLosses: RoundTripCrossRegistry.d2MermaidFlowchart.additionalAllowedLosses,
            fixture: fixture
        )
    }
}
```

**Fixtures:**
- `cross-mermaid-d2-flowchart/01-basic.md` — three nodes, two edges.
- `cross-mermaid-d2-flowchart/02-labels.md` — labelled edges.
- `cross-mermaid-d2-flowchart/03-subgraph.md` — single subgraph (exercises subgraph-flatten).
- `cross-d2-mermaid-flowchart/01-basic.d2`, `02-labels.d2`, `03-styled.d2` — mirror fixtures.

**Commit message:**

```
feat(tests): Mermaid↔D2 flowchart cross-format round-trip cells

Two @Tests (M→D2→M, D2→M→D2) + RoundTripCrossRegistry entries; 6
fixtures total (3 per direction). Exercises subgraph-flatten,
shape-downgrade, style-drop, and id-sanitization paths.
```

---

#### Task 22: Mermaid↔DOT (flowchart)

Shape mirrors Task 21 with `dot` substituted for `d2`. Allow-list for either direction: `[.subgraphFlatten, .styleDrop, .shapeDowngrade, .idSanitization]`. Fixtures in `cross-mermaid-dot-flowchart/` and `cross-dot-mermaid-flowchart/`.

**Commit message:**

```
feat(tests): Mermaid↔DOT flowchart cross-format round-trip cells
```

---

#### Task 23: D2↔DOT (flowchart)

Shape mirrors Task 21. Allow-list: `[.subgraphFlatten, .styleDrop, .shapeDowngrade]`. Fixtures in `cross-d2-dot-flowchart/` and `cross-dot-d2-flowchart/`.

**Commit message:**

```
feat(tests): D2↔DOT flowchart cross-format round-trip cells
```

---

#### Task 24: Mermaid↔Structurizr (C4)

Allow-list for either direction: `[.idSanitization, .boundaryFlatten, .c4SlotDrop, .configDrop]`. Fixtures: a flat-emit Person + System + Rel set (start from Mermaid) and a `group "label" { … }` workspace (start from Structurizr). Mirror direction-specific edge cases under `cross-mermaid-structurizr-c4/` and `cross-structurizr-mermaid-c4/`.

**Commit message:**

```
feat(tests): Mermaid↔Structurizr C4 cross-format round-trip cells

Exercises Session 6's group { ... } round-trip end-to-end through the
foreign format, including the Mermaid $boundary= named-arg path closed
by Session 9 (4e2a6e3).
```

---

#### Task 25: Mermaid↔PlantUML (C4)

Allow-list: `[.idSanitization, .c4SlotDrop, .configDrop]`. Fixtures cover Context/Container/Deployment at the intersection of Mermaid C4 and PlantUML C4 syntax.

**Commit message:**

```
feat(tests): Mermaid↔PlantUML C4 cross-format round-trip cells

Exercises C4 tech-vs-description slot semantics across both formats
(8546f81 regression: third positional arg ordering must not swap).
```

---

#### Task 26: PlantUML↔Structurizr (C4)

Allow-list: `[.idSanitization, .boundaryFlatten, .c4SlotDrop]`. Fixtures cover the common shape vocabulary.

**Commit message:**

```
feat(tests): PlantUML↔Structurizr C4 cross-format round-trip cells
```

---

#### Task 27: Mermaid↔PlantUML (sequence)

Allow-list: `[.idSanitization, .configDrop]`. Fixtures cover basic exchanges + control flow that both formats support.

**Commit message:**

```
feat(tests): Mermaid↔PlantUML sequence cross-format round-trip cells
```

---

#### Task 28: Mermaid↔PlantUML (class)

Allow-list: `[.idSanitization]`. Fixtures cover the common subset (classes, members, relationships, inheritance).

**Commit message:**

```
feat(tests): Mermaid↔PlantUML class cross-format round-trip cells
```

---

### Task 29: `LossPairingTests` — paired-diagnostic contract probes

**Files:**
- Create: `Tests/DiagramKitTests/RoundTrip/LossPairingTests.swift`

The harness's paired-diagnostic check already enforces this contract at the per-fixture level, but a dedicated suite gives the contract its own test bed for the explicit happy-path cases (and surfaces failures quickly when an exporter changes its diagnostic phrasing). Each `@Test` here constructs a synthetic input designed to force a specific loss kind, then asserts:

1. The export emits a diagnostic whose `severity` is `.warning` or `.unsupported`.
2. `diagnosticsCover(loss:in:)` returns `true` against that bag for the expected loss.

- [ ] **Step 1: Write the tests**

```swift
import Testing
import DiagramKitTestSupport
import DiagramKitMermaid
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

@Suite("Loss pairing")
struct LossPairingTests {

    @Test("Mermaid flowchart export emits an id-sanitization warning when input has non-[A-Za-z0-9_-] ids")
    func mermaidIDSanitizationPaired() throws {
        let source = "graph TD\n  \"a b\"[Label] --> c"
        let doc = try MermaidImporter().parse(source).document
        let result = try MermaidExporter().export(doc)
        let loss = RoundTripLoss.idSanitization(original: "a b", sanitized: "a_b")
        #expect(diagnosticsCover(loss: loss, in: result.diagnostics),
                "diagnostics did not cover idSanitization loss: \(result.diagnostics)")
    }

    @Test("D2 flowchart export emits a subgraph-flatten warning when input has subgraphs")
    func d2SubgraphFlattenPaired() throws {
        let source = "graph TD\n  subgraph s1[Group]\n    A-->B\n  end"
        let doc = try MermaidImporter().parse(source).document
        let result = try D2Exporter().export(doc)
        let loss = RoundTripLoss.subgraphFlatten(subgraphID: "s1", depth: 1)
        #expect(diagnosticsCover(loss: loss, in: result.diagnostics))
    }

    @Test("DOT flowchart export emits a subgraph-flatten warning when input has subgraphs")
    func dotSubgraphFlattenPaired() throws {
        let source = "graph TD\n  subgraph s1[Group]\n    A-->B\n  end"
        let doc = try MermaidImporter().parse(source).document
        let result = try DOTExporter().export(doc)
        let loss = RoundTripLoss.subgraphFlatten(subgraphID: "s1", depth: 1)
        #expect(diagnosticsCover(loss: loss, in: result.diagnostics))
    }

    @Test("Structurizr C4 export emits a boundary-flatten warning when input has nested authored boundaries")
    func structurizrBoundaryFlattenPaired() throws {
        // Build a C4Diagram with nested boundaries (origin: .authored).
        // Concrete construction depends on C4Diagram init shape — read
        // Sources/DiagramKitModel/src_c4_types.swift before writing.
        let nested = """
        C4Context
            Boundary(outer, "Outer") {
                Boundary(inner, "Inner") {
                    Person(p, "User")
                }
            }
        """
        let doc = try MermaidImporter().parse(nested).document
        let result = try StructurizrExporter().export(doc)
        let loss = RoundTripLoss.boundaryFlatten(boundaryID: "inner", depth: 2)
        #expect(diagnosticsCover(loss: loss, in: result.diagnostics))
    }

    @Test("Mermaid flowchart export emits a shape-downgrade warning when input has non-flowchart node shapes")
    func mermaidShapeDowngradePaired() throws {
        // Build a ParsedGraphModel with a state-family node shape inside
        // .flowchart payload. Closed by Session 3's 6a793c3 (shapeMarker
        // returns lossy flag; emit loops .warning per lossy node).
        var model = ParsedGraphModel()
        // Construction details depend on ParsedGraphModel API; verify by
        // reading Sources/DiagramKitModel/src_types.swift.
        // The expected shape: appendNode with a non-flowchart NodeShape value.
        // For now mark this test as a stub if construction is non-trivial.
        let _ = model
        // TODO at implementation time: complete the model construction so the
        // test exercises the shape-downgrade path emitted by 6a793c3.
        try #require(Bool(false), "complete model construction at implementation time")
    }
}
```

The shape-downgrade test is intentionally left with a `#require(Bool(false))` placeholder: the implementer must read `ParsedGraphModel`'s actual mutation API before filling in the body. (`TODO` placeholders are normally a plan failure — in this case the placeholder is wrapped in a `#require(Bool(false))` so the test will *deliberately fail* until completed, surfacing the gap rather than silently passing.)

- [ ] **Step 2: Run and complete the shape-downgrade body**

Run: `swift test --filter LossPairingTests`
Expected: 4 pass, 1 fail (the shape-downgrade placeholder).

Open `Sources/DiagramKitModel/src_types.swift`, locate `ParsedGraphModel`'s mutation API, then complete `mermaidShapeDowngradePaired` to construct a model with a non-flowchart shape and assert the export emits the `shapeDowngrade` diagnostic from `6a793c3`.

- [ ] **Step 3: Run to confirm full pass**

Run: `swift test --filter LossPairingTests`
Expected: 5/5 tests pass.

- [ ] **Step 4: Commit**

```bash
git add Tests/DiagramKitTests/RoundTrip/LossPairingTests.swift
git commit -m "$(cat <<'EOF'
test(roundtrip): paired-diagnostic contract probes

Five synthetic-input probes that pin the diagnostic surface of each
intrinsic loss kind: Mermaid id-sanitization, D2/DOT subgraph-flatten,
Structurizr boundary-flatten, Mermaid shape-downgrade. The
diagnosticsCover(loss:in:) helper from the harness is now exercised
directly so exporter diagnostic-phrasing changes show up here.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 30: Wire the gate + docs sync

**Files:**
- Modify: `Scripts/bootstrap-smoke-check.sh`
- Modify: `CLAUDE.md`
- Modify: `ARCHITECTURE.md`

- [ ] **Step 1: Add the round-trip gate to `bootstrap-smoke-check.sh`**

Read the existing script structure (it uses a `run_gate` helper). Add a new line *before* the snapshot suite line:

```bash
run_gate "round-trip" swift test --filter "RoundTripTests|SameFormatRoundTripTests|CrossFormatRoundTripTests|LossPairingTests|RoundTripLossTests|RoundTripCellTests|RoundTripHarnessTests|RoundTripFixtureLoaderTests|DiagramDocumentDiffTests"
```

(Or simpler if the existing filter patterns support it: `--filter "RoundTrip"`.)

- [ ] **Step 2: Add Round-trip subsection to `CLAUDE.md`**

Find the `## Testing And Snapshots` section. Add after the bullet list a new paragraph:

```markdown
**Round-trip discipline.** Beyond snapshot equality, every importer/exporter pair
the library ships is gated on `parse → export → parse → assert structurally
equal` via the `DiagramKitTestSupport.RoundTripHarness`. Same-format (14 cells)
and cross-format (8 unordered pairs / 16 ordered directions) cover every
intersecting family. Allowed losses are typed and closed — `RoundTripLoss`
admits no `case other(_)`, and every observed loss must have a paired
`.warning`/`.unsupported` diagnostic on the export step that produced it.
Fixtures live under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`.
Run with `swift test --filter "RoundTrip"`.
```

Bump the test source count at the bottom of the section to reflect the new files (verify the actual count with `find Tests/DiagramKitTests -name "*.swift" | wc -l`).

- [ ] **Step 3: Add Round-trip note to `ARCHITECTURE.md`**

Find the Diagnostics paragraph (added in Session 10). Append:

```markdown
Round-trip discipline (`DiagramKitTestSupport.RoundTripHarness`) cross-references
this diagnostic surface: an exporter that introduces a structural loss without
emitting a paired `.warning` or `.unsupported` diagnostic fails the round-trip
gate. See `docs/superpowers/specs/2026-05-15-roundtrip-exporter-tests-design.md`.
```

- [ ] **Step 4: Run the full round-trip filter to confirm the gate works end-to-end**

Run: `swift test --filter "RoundTrip"`
Expected: every cell + harness + loss + comparator + fixture-loader test passes (count varies — 14 same-format cells × 3+ fixtures + 16 cross-format @Tests × 3+ fixtures + 5 loss-pairing + harness/loader/loss unit tests).

- [ ] **Step 5: Run `bootstrap-smoke-check.sh`'s new gate line in isolation**

Run: `bash Scripts/bootstrap-smoke-check.sh` *or* just the round-trip gate's equivalent invocation if the full smoke-check is too long.
Expected: gate line reports success.

- [ ] **Step 6: Commit**

```bash
git add Scripts/bootstrap-smoke-check.sh CLAUDE.md ARCHITECTURE.md
git commit -m "$(cat <<'EOF'
build(gate),docs(claude,architecture): wire round-trip discipline

Adds round-trip gate line to bootstrap-smoke-check.sh; CLAUDE.md gains
a Round-trip discipline paragraph under Testing And Snapshots; ARCHITECTURE.md
Diagnostics paragraph references the paired-diagnostic enforcement.
Test source count bumped.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

Checked the plan against the spec:

1. **Spec coverage** — every spec section maps to one or more tasks:
   - Architecture (RoundTripLoss / RoundTripDelta / DiagramDocumentDiff / RoundTripCell / RoundTripFixture / RoundTripHarness): Tasks 2–6.
   - Linux portability: Task 1 wires the dependencies; nothing in the plan introduces a platform gate.
   - Strict concurrency: Sendable annotations are in every type definition; no `@unchecked` needed.
   - Loss-kind taxonomy (11 cases): fully enumerated in Task 2's RoundTripLoss.swift.
   - Same-format cells (14): Tasks 7 (Mermaid flowchart), 8–20 (remaining 13 cells, one task each).
   - Cross-format cells (8 unordered pairs / 16 ordered directions): Tasks 21–28 (one pair per task).
   - Paired-diagnostic contract: enforced inside `runSameFormatRoundTrip`/`runCrossFormatRoundTrip` (Task 5) and exercised directly by Task 29.
   - Gate placement (`bootstrap-smoke-check.sh`): Task 30.
   - Docs sync (CLAUDE.md + ARCHITECTURE.md): Task 30.
   - Fixture organisation under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`: Tasks 6, 7, 8–28.

2. **Placeholder scan** — no "TBD" / "implement later" / unimplemented step shells. One `TODO`-shaped construct exists *deliberately* in Task 29 (the shape-downgrade probe wraps the unfinished work in `#require(Bool(false))` so the test fails until completed, surfacing the gap; this is a documented exception inside the task itself).

3. **Type consistency** — names used across tasks:
   - `RoundTripLoss`, `RoundTripLossKind`, `RoundTripDelta`, `RoundTripCell`, `RoundTripFixture`, `RoundTripCellRegistry`, `RoundTripCrossRegistry`, `RoundTripHarnessError`, `RoundTripHarnessContext` — consistent across Tasks 2–30.
   - `compare(_:_:)`, `diffParsedGraphModel`, `diffSequenceDiagram`, `diffClassDiagram`, `diffErDiagram`, `diffC4Diagram`, `diffMindmapDiagram`, `diffGanttDiagram` — consistent.
   - `runSameFormatRoundTrip`, `runCrossFormatRoundTrip` — consistent.
   - `fixtures(for:fromRoot:)`, `roundTripResourcesRoot(file:)` — consistent.
   - Cell static names (`mermaidFlowchart`, `mermaidSequence`, `mermaidClass`, `mermaidEr`, `mermaidC4`, `d2Flowchart`, `dotFlowchart`, `structurizrC4`, `plantumlSequence`, `plantumlClass`, `plantumlState`, `plantumlMindmap`, `plantumlGantt`, `plantumlC4`) — consistent.

4. **Note on per-family-property names** — the comparator arms reference `ParsedGraphModel.nodesInOrder`, `.edges`, `.subgraphIds`, `ParsedGraphNode.label`/`.shape`, plus payload types like `SequenceDiagram`, `ClassDiagram`, `ErDiagram`, `C4Diagram`, `MindmapDiagram`, `GanttDiagram`. These reflect the typical shape but **the implementer must read each payload type's source in `Sources/DiagramKitModel/` before writing the arm** and adjust property names where the actual API diverges. Flagged inline in Tasks 5 and 7.

5. **Scope/decomposition** — 30 tasks, each producing one commit on `main`. The plan deliberately mirrors the spec's commit map. If 30 commits feels long for a single execution session, the natural break point is after Task 20 (all same-format cells green); Tasks 21–28 (cross-format) can run as a follow-up session against the green baseline.

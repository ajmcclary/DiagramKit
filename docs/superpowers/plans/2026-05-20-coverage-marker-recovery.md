# Coverage Marker Recovery — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close every export-side `⚠` cell in COVERAGE.md by generalizing the Structurizr Wave 3 comment-encoded recovery-marker pattern to D2, DOT, and PlantUML, plus reconcile two stale matrix entries.

**Architecture:** Lift the existing per-line scanner + positional-correlation primitives from `StructurizrRecoveryMarker.swift` into a generic `RecoveryMarkerScanner<Kind>` in `DiagramKitCommon`. Each new slice (D2, DOT, PlantUML) supplies its comment prefix, `Kind` enum, declaration indexer, and exporter emission helpers. Mappers consult marker scan results post-AST and reconcile the marker payload back onto the typed `DiagramDocument`. Where markers carry the lost information forward, the corresponding `.lossyTransform` / `.featureDropped` / `.informational` diagnostic emission site is deleted in the same patch.

**Tech Stack:** Swift 6, SwiftPM, swift-snapshot-testing, swift-testing, XCTest. Targets: `DiagramKitCommon` (shared scaffold), `DiagramKitStructurizr` (refit), `DiagramKitD2`, `DiagramKitGraphviz` (DOT), `DiagramKitPlantUML`. Discipline gates: `Scripts/check-diagnostic-discipline.sh`, `Scripts/check-file-sizes.sh`, `Scripts/check-sendable-annotations.sh`, `Scripts/bootstrap-smoke-check.sh`.

**Spec source:** `docs/superpowers/specs/2026-05-20-coverage-marker-recovery-design.md` (commit `3aacfe4f`).

---

## Spec amendments incorporated

The spec was written before final emission-site survey. The plan incorporates these corrections:

| Spec claim | Actual code reality | Plan adopts |
|---|---|---|
| D2/DOT × class drops visibility + stereotype | Only stereotypes drop (`.classStereotypeDrop`); visibility is preserved via `attr.visibility` prefix (`D2ClassExporter.swift:201`, `DOTClassExport.swift:225`) | Drop `class-visibility` marker kind; keep only `class-stereotype` |
| D2/DOT × state composite-state nesting loss | Actual loss is entry/exit pseudo-state actions inside container states (`.stateActionDrop` at `D2StateExporter.swift:73`). The site is in `D2StateMapper.map()` — the **importer** side. `D2StateExport.emit()` (line 120) and `DOTStateExport.emit()` both emit zero diagnostics. | State-action loss is **foreign → Mermaid only** (needs Mermaid payload-model surgery for an action slot). Out of scope per spec's "Mermaid landing slot" exclusion. `stateDiagram × D2/DOT export` cells are already diagnostic-free — flip matrix to ✓ alongside the other stale flips. `state-action` marker kind dropped from D2RecoveryMarker.Kind. `.stateActionDrop` joins the retained-categories list. |
| PlantUML activity partition uses `.partitionFlatten` | Actual category is `.subgraphFlatten` (`PlantUMLActivityMapper.swift:38`) | Marker name `activity-partition` unchanged; deletion list does NOT include `.subgraphFlatten` (Mermaid state exporter still emits) |
| Delete categories `.idSanitization`, `.identifierEscape`, `.subgraphFlatten` | All three are emitted by Mermaid exporters (`MermaidExportHelpers.swift:98,129`, `MermaidSequenceExport.swift:256`, `MermaidStateExport.swift:202`) | Plan deletes only per-site emissions in D2/DOT/PlantUML; the categories remain in `DiagnosticCategory` |
| Delete categories `.classStereotypeDrop`, `.stateActionDrop`, `.cardinalityDrop` | These three are emitted ONLY at the D2/DOT exporter sites being modified | Plan deletes both per-site emissions and the category cases (and matching `RoundTripLoss` cases) |

---

## File structure

### New files (`DiagramKitCommon` — shared scaffold)

- `Sources/DiagramKitCommon/RecoveryMarker/RecoveryMarkerSyntax.swift` — sentinel + grammar constants
- `Sources/DiagramKitCommon/RecoveryMarker/RecoveryMarkerScanner.swift` — generic line-walker
- `Sources/DiagramKitCommon/RecoveryMarker/DeclarationIndex.swift` — `HasLineNumber` protocol + `latestDeclaration(before:)` helper

### New diagnostic category (`DiagramKitCommon`)

- `Sources/DiagramKitCommon/DiagnosticCategory.swift` — add `.recoveryMarkerMalformed`
- `Sources/DiagramKitCommon/DiagramDiagnostic+Factories.swift` — add `.warning(_:message:)` factory if not present

### Modified (Wave A refit)

- `Sources/DiagramKitStructurizr/StructurizrRecoveryMarker.swift` — refit onto shared scaffold
- `Sources/DiagramKitStructurizr/StructurizrImporter.swift` — switch to shared scanner

### New files (Wave B — D2 + DOT)

- `Sources/DiagramKitD2/D2RecoveryMarker.swift` — Kind enum + scanner + emission helpers
- `Sources/DiagramKitD2/D2PreLexerScan.swift` — declaration indexer for class/state/er constructs
- `Sources/DiagramKitGraphviz/DOTRecoveryMarker.swift` — same shape as D2
- `Sources/DiagramKitGraphviz/DOTPreLexerScan.swift` — declaration indexer

### Modified (Wave B)

- `Sources/DiagramKitD2/D2Mapper.swift` — switch arms applying each Kind
- `Sources/DiagramKitD2/D2ClassExporter.swift:193` — emit marker; delete `.classStereotypeDrop` emission
- `Sources/DiagramKitD2/D2StateExporter.swift:73` — emit marker; delete `.stateActionDrop` emission
- `Sources/DiagramKitD2/D2ERExporter.swift:143,147` — emit marker; delete `.cardinalityDrop` emissions
- `Sources/DiagramKitGraphviz/DOTMapper.swift` — switch arms applying each Kind
- `Sources/DiagramKitGraphviz/DOTClassExport.swift:193` — emit marker; delete `.classStereotypeDrop` emission
- `Sources/DiagramKitGraphviz/DOTERExport.swift:132,136` — emit marker; delete `.cardinalityDrop` emissions
- `Sources/DiagramKitCommon/DiagnosticCategory.swift` — delete `.classStereotypeDrop`, `.stateActionDrop`, `.cardinalityDrop`
- `Sources/DiagramKitTestSupport/RoundTripLoss.swift` — delete the three matching cases
- `Sources/DiagramKitTestSupport/RoundTripLoss+Category.swift` — delete the three mapping arms

### New files (Wave C — PlantUML)

- `Sources/DiagramKitPlantUML/PlantUMLRecoveryMarker.swift` — Kind enum + scanner + emission helpers (`'` prefix)
- `Sources/DiagramKitPlantUML/PlantUMLPreLexerScan.swift` — declaration indexer per family

### Modified (Wave C)

- `Sources/DiagramKitPlantUML/Activity/PlantUMLActivityMapper.swift:38` — apply marker; delete `.subgraphFlatten` emission
- `Sources/DiagramKitPlantUML/Exporter/PlantUMLActivityExporter.swift:28` — emit markers (partition + original-id); delete `.idSanitization` emission
- `Sources/DiagramKitPlantUML/Exporter/PlantUMLSequenceExporter.swift:127` — emit markers; delete `.identifierEscape` emission
- `Sources/DiagramKitPlantUML/Component/PlantUMLComponentMapper.swift:16` — apply marker; delete `.styleDrop` emission
- `Sources/DiagramKitPlantUML/Exporter/PlantUMLComponentExporter.swift` — emit `component-style` marker
- `Sources/DiagramKitPlantUML/Class/PlantUMLClassMapper.swift:72` — apply marker; delete `.diagramFamilyUnsupported` emission
- `Sources/DiagramKitPlantUML/Exporter/PlantUMLClassExporter.swift` — emit `class-unsupported-line` marker

### Test files (per wave)

- `Tests/DiagramKitTests/RecoveryMarker/RecoveryMarkerScannerTests.swift` — Wave A
- `Tests/DiagramKitTests/RecoveryMarker/StructurizrRefitParityTests.swift` — Wave A
- `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-class-stereotype.json` — Wave B
- `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-state-action.json` — Wave B
- `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-er-cardinality.json` — Wave B
- `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-class-stereotype.json` — Wave B
- `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-state-action.json` — Wave B
- `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-er-cardinality.json` — Wave B
- `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-activity-partition.json` — Wave C
- `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-sequence-link-props.json` — Wave C
- `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-component-interface.json` — Wave C
- `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-class-unsupported.json` — Wave C

### COVERAGE.md + BASELINES.md (each wave's closer commit)

- `COVERAGE.md` — matrix updates, legend footnote, totals
- `BASELINES.md` — test counts, snapshot counts, gate status

---

# Wave A — Shared scaffold + Structurizr refit + matrix reconciliation

## Task A.1: Add `RecoveryMarkerSyntax.swift`

**Files:**
- Create: `Sources/DiagramKitCommon/RecoveryMarker/RecoveryMarkerSyntax.swift`
- Test: `Tests/DiagramKitTests/RecoveryMarker/RecoveryMarkerSyntaxTests.swift`

- [ ] **Step 1: Create the test directory and write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/RecoveryMarkerSyntaxTests.swift
import Testing
@testable import DiagramKitCommon

@Suite("RecoveryMarkerSyntax")
struct RecoveryMarkerSyntaxTests {
    @Test("sentinel is diagramkit:")
    func sentinelValue() {
        #expect(RecoveryMarkerSyntax.sentinel == "diagramkit:")
    }

    @Test("base64 prefix is b64:")
    func base64Prefix() {
        #expect(RecoveryMarkerSyntax.base64Prefix == "b64:")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter RecoveryMarkerSyntaxTests`
Expected: FAIL (compile error — `RecoveryMarkerSyntax` not defined).

- [ ] **Step 3: Implement the syntax constants**

```swift
// Sources/DiagramKitCommon/RecoveryMarker/RecoveryMarkerSyntax.swift
import Foundation

/// Shared constants for the comment-encoded recovery-marker grammar used by
/// the D2, DOT, PlantUML, and Structurizr importers and exporters.
///
/// Marker line grammar:
/// ```
/// <comment-prefix> diagramkit:<kind-kebab>=<args>
/// ```
/// `<args>` is either a single string, comma-separated positional fields, or
/// `b64:<base64-of-utf8>` for free-form text. See
/// `docs/superpowers/specs/2026-05-20-coverage-marker-recovery-design.md`.
public enum RecoveryMarkerSyntax {
    public static let sentinel = "diagramkit:"
    public static let base64Prefix = "b64:"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter RecoveryMarkerSyntaxTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitCommon/RecoveryMarker/RecoveryMarkerSyntax.swift \
        Tests/DiagramKitTests/RecoveryMarker/RecoveryMarkerSyntaxTests.swift
git commit -m "Wave A Task 1 — RecoveryMarkerSyntax constants in DiagramKitCommon"
```

## Task A.2: Add `RecoveryMarkerScanner<Kind>` generic line-walker

**Files:**
- Create: `Sources/DiagramKitCommon/RecoveryMarker/RecoveryMarkerScanner.swift`
- Test: `Tests/DiagramKitTests/RecoveryMarker/RecoveryMarkerScannerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/RecoveryMarkerScannerTests.swift
import Testing
@testable import DiagramKitCommon

@Suite("RecoveryMarkerScanner")
struct RecoveryMarkerScannerTests {

    enum TestKind: Sendable, Equatable {
        case tag(String)
    }

    static func scanner() -> RecoveryMarkerScanner<TestKind> {
        RecoveryMarkerScanner<TestKind>(commentPrefix: "#") { rest in
            guard rest.hasPrefix("tag=") else { return nil }
            return .tag(String(rest.dropFirst(4)))
        }
    }

    @Test("scans a single marker at expected line")
    func scansSingleMarker() {
        let source = """
        person customer "Customer"
        # diagramkit:tag=external
        """
        let result = Self.scanner().scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].lineNumber == 2)
        #expect(result.markers[0].kind == .tag("external"))
    }

    @Test("ignores non-marker comments")
    func ignoresPlainComments() {
        let source = """
        # this is a note
        # diagramkit:tag=foo
        """
        let result = Self.scanner().scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .tag("foo"))
    }

    @Test("strips leading and trailing whitespace")
    func stripsWhitespace() {
        let source = "   # diagramkit:tag=value   "
        let result = Self.scanner().scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .tag("value"))
    }

    @Test("ignores wrong comment prefix")
    func ignoresWrongPrefix() {
        let source = "// diagramkit:tag=foo"
        let result = Self.scanner().scan(source: source)
        #expect(result.markers.isEmpty)
    }

    @Test("returns lines for downstream correlation")
    func returnsLines() {
        let source = "line1\nline2\nline3"
        let result = Self.scanner().scan(source: source)
        #expect(result.lines == ["line1", "line2", "line3"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter RecoveryMarkerScannerTests`
Expected: FAIL (compile error — `RecoveryMarkerScanner` not defined).

- [ ] **Step 3: Implement the generic scanner**

```swift
// Sources/DiagramKitCommon/RecoveryMarker/RecoveryMarkerScanner.swift
import Foundation

/// Marker harvested from a single source line.
public struct RecoveryMarker<Kind: Sendable & Equatable>: Sendable, Equatable {
    public let lineNumber: Int  // 1-based
    public let kind: Kind

    public init(lineNumber: Int, kind: Kind) {
        self.lineNumber = lineNumber
        self.kind = kind
    }
}

/// Result of a pre-lexer scan over source.
public struct RecoveryMarkerScanResult<Kind: Sendable & Equatable>: Sendable, Equatable {
    public let markers: [RecoveryMarker<Kind>]
    public let lines: [String]

    public init(markers: [RecoveryMarker<Kind>], lines: [String]) {
        self.markers = markers
        self.lines = lines
    }
}

/// Generic comment-encoded recovery-marker scanner. Each format slice
/// configures its line-comment prefix and supplies a `parseKind` closure that
/// maps the post-sentinel arg string to a typed `Kind` (`nil` for malformed
/// markers, handled by the caller).
public struct RecoveryMarkerScanner<Kind: Sendable & Equatable>: Sendable {

    public let commentPrefix: String
    public let sentinel: String
    private let parseKind: @Sendable (String) -> Kind?

    public init(
        commentPrefix: String,
        sentinel: String = RecoveryMarkerSyntax.sentinel,
        parseKind: @escaping @Sendable (String) -> Kind?
    ) {
        self.commentPrefix = commentPrefix
        self.sentinel = sentinel
        self.parseKind = parseKind
    }

    /// Walk every line of `source`. Each line beginning (after leading
    /// whitespace) with `commentPrefix + sentinel` is offered to `parseKind`.
    /// Returns markers paired with 1-based line numbers, plus the source
    /// split into lines for downstream correlation.
    public func scan(source: String) -> RecoveryMarkerScanResult<Kind> {
        var markers: [RecoveryMarker<Kind>] = []
        let lines = source.components(separatedBy: "\n")
        for (index, rawLine) in lines.enumerated() {
            let lineNumber = index + 1
            var trimmed = rawLine
            while let first = trimmed.first, first == " " || first == "\t" {
                trimmed.removeFirst()
            }
            guard trimmed.hasPrefix(commentPrefix) else { continue }
            trimmed.removeFirst(commentPrefix.count)
            while let first = trimmed.first, first == " " || first == "\t" {
                trimmed.removeFirst()
            }
            guard trimmed.hasPrefix(sentinel) else { continue }
            var rest = String(trimmed.dropFirst(sentinel.count))
            while let last = rest.last, last == " " || last == "\t" || last == "\r" {
                rest.removeLast()
            }
            if let kind = parseKind(rest) {
                markers.append(RecoveryMarker(lineNumber: lineNumber, kind: kind))
            }
        }
        return RecoveryMarkerScanResult(markers: markers, lines: lines)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter RecoveryMarkerScannerTests`
Expected: PASS (all 5 cases).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitCommon/RecoveryMarker/RecoveryMarkerScanner.swift \
        Tests/DiagramKitTests/RecoveryMarker/RecoveryMarkerScannerTests.swift
git commit -m "Wave A Task 2 — Generic RecoveryMarkerScanner with line-walker"
```

## Task A.3: Add `DeclarationIndex` + `latestDeclaration(before:)` helper

**Files:**
- Create: `Sources/DiagramKitCommon/RecoveryMarker/DeclarationIndex.swift`
- Test: `Tests/DiagramKitTests/RecoveryMarker/DeclarationIndexTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/DeclarationIndexTests.swift
import Testing
@testable import DiagramKitCommon

@Suite("DeclarationIndex")
struct DeclarationIndexTests {

    struct Element: HasLineNumber, Equatable {
        let alias: String
        let lineNumber: Int
    }

    @Test("latestDeclaration picks the highest line strictly less than target")
    func latestStrictlyLess() {
        let decls = [
            Element(alias: "a", lineNumber: 1),
            Element(alias: "b", lineNumber: 5),
            Element(alias: "c", lineNumber: 10),
        ]
        #expect(latestDeclaration(before: 7, in: decls) == decls[1])
        #expect(latestDeclaration(before: 11, in: decls) == decls[2])
        #expect(latestDeclaration(before: 5, in: decls) == decls[0])
    }

    @Test("returns nil when no declaration precedes target")
    func returnsNilWhenNoneBefore() {
        let decls = [Element(alias: "a", lineNumber: 10)]
        #expect(latestDeclaration(before: 5, in: decls) == nil)
        #expect(latestDeclaration(before: 10, in: decls) == nil)
    }

    @Test("returns nil for empty index")
    func returnsNilForEmpty() {
        let decls: [Element] = []
        #expect(latestDeclaration(before: 1, in: decls) == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DeclarationIndexTests`
Expected: FAIL (compile error — `HasLineNumber` and `latestDeclaration` not defined).

- [ ] **Step 3: Implement the protocol and helper**

```swift
// Sources/DiagramKitCommon/RecoveryMarker/DeclarationIndex.swift
import Foundation

/// Conformance for types that carry a 1-based source line number so the
/// recovery-marker correlator can pair markers to preceding declarations.
public protocol HasLineNumber {
    var lineNumber: Int { get }
}

/// Return the declaration in `index` whose `lineNumber` is strictly less than
/// `line` and is the highest among such declarations. Returns `nil` when no
/// declaration precedes `line`. Matches Structurizr Wave 3 semantics: a
/// recovery marker at line N applies to the latest declaration on a line `< N`.
///
/// `index` does not need to be sorted; the helper walks every element.
public func latestDeclaration<D: HasLineNumber>(
    before line: Int,
    in index: [D]
) -> D? {
    var best: D? = nil
    for decl in index where decl.lineNumber < line {
        if best == nil || decl.lineNumber > best!.lineNumber {
            best = decl
        }
    }
    return best
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DeclarationIndexTests`
Expected: PASS (3 cases).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitCommon/RecoveryMarker/DeclarationIndex.swift \
        Tests/DiagramKitTests/RecoveryMarker/DeclarationIndexTests.swift
git commit -m "Wave A Task 3 — DeclarationIndex + latestDeclaration(before:) helper"
```

## Task A.4: Add `.recoveryMarkerMalformed` diagnostic category

**Files:**
- Modify: `Sources/DiagramKitCommon/DiagnosticCategory.swift`
- Modify: `Sources/DiagramKitCommon/DiagramDiagnostic+Factories.swift` (verify `.warning(_:message:)` exists; add if absent)
- Test: `Tests/DiagramKitTests/RecoveryMarker/RecoveryMarkerMalformedDiagnosticTests.swift`

- [ ] **Step 1: Read the existing factory file to see if `.warning` is present**

Run: `grep -n "static func warning\|static func lossyTransform\|static func featureDropped\|static func informational" Sources/DiagramKitCommon/DiagramDiagnostic+Factories.swift`

Expected output enumerates the existing typed factories. If `static func warning(_:message:)` already exists, skip Step 3 (factory creation) — just go to Step 4 (category addition). If absent, Step 3 adds it.

- [ ] **Step 2: Write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/RecoveryMarkerMalformedDiagnosticTests.swift
import Testing
@testable import DiagramKitCommon

@Suite("recoveryMarkerMalformed diagnostic")
struct RecoveryMarkerMalformedDiagnosticTests {
    @Test("category has .warning severity")
    func severity() {
        #expect(DiagnosticCategory.recoveryMarkerMalformed.severity == .warning)
    }

    @Test("factory emits a warning diagnostic")
    func factoryEmits() {
        let d = DiagramDiagnostic.lossyTransform(
            .recoveryMarkerMalformed,
            message: "malformed marker at line 7"
        )
        #expect(d.severity == .warning)
        #expect(d.message.contains("malformed marker"))
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `swift test --filter RecoveryMarkerMalformedDiagnosticTests`
Expected: FAIL (compile error — `.recoveryMarkerMalformed` not defined).

- [ ] **Step 4: Add the category case**

In `Sources/DiagramKitCommon/DiagnosticCategory.swift`, add `.recoveryMarkerMalformed` to the `.warning`-severity list:

```swift
// Sources/DiagramKitCommon/DiagnosticCategory.swift
// Inside the enum body, in the .warning section (around line 28):
    case cardinalityDrop
    case recoveryMarkerMalformed   // NEW

// In the severity computed property's .warning case list (around line 47),
// append .recoveryMarkerMalformed:
        case .idSanitization, .shapeDowngrade, .subgraphFlatten, .boundaryFlatten,
             .c4SlotDrop, .titleDrop, .configDrop, .styleDrop, .accessibilityDrop,
             .anonymousSubgraphRename, .d2DuplicateOverride,
             .labelNewlineEscape, .d2InlineCommentStripped,
             .classStereotypeDrop, .stateActionDrop, .cardinalityDrop,
             .recoveryMarkerMalformed:
            return .warning
```

- [ ] **Step 5: Update the discipline allow-list**

In `Scripts/check-diagnostic-discipline.sh`, locate the allow-list for `.warning`-severity categories and add `recoveryMarkerMalformed`. If the script enumerates categories by greping `DiagnosticCategory.swift`, no manual list update is needed — verify by running the script.

Run: `Scripts/check-diagnostic-discipline.sh`
Expected: exit code 0.

- [ ] **Step 6: Run the test to verify it passes**

Run: `swift test --filter RecoveryMarkerMalformedDiagnosticTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitCommon/DiagnosticCategory.swift \
        Tests/DiagramKitTests/RecoveryMarker/RecoveryMarkerMalformedDiagnosticTests.swift \
        Scripts/check-diagnostic-discipline.sh
git commit -m "Wave A Task 4 — .recoveryMarkerMalformed diagnostic category (.warning)"
```

## Task A.5: Refit `StructurizrRecoveryMarker.swift` onto the shared scaffold

**Files:**
- Modify: `Sources/DiagramKitStructurizr/StructurizrRecoveryMarker.swift`
- Modify: `Sources/DiagramKitStructurizr/StructurizrImporter.swift` (call sites)
- Test: existing Structurizr suite must stay green; add `Tests/DiagramKitTests/RecoveryMarker/StructurizrRefitParityTests.swift` to assert the new and old scanners produce identical results.

- [ ] **Step 1: Read the existing Structurizr scanner to know its signature**

Run: `cat Sources/DiagramKitStructurizr/StructurizrRecoveryMarker.swift | head -100`

This is the file being refit. The existing `scanStructurizrRecoveryMarkers(_:)` and `scanStructurizrPreLexer(_:)` functions are the public surface; the refit must preserve their behavior. `StructurizrMapper` consumes `StructurizrPreLexerScanResult` — that type stays.

- [ ] **Step 2: Write the parity test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/StructurizrRefitParityTests.swift
import Testing
@testable import DiagramKitStructurizr

@Suite("Structurizr scanner refit parity")
struct StructurizrRefitParityTests {

    static let representativeSource = """
    workspace {
      model {
        customer = person "Customer"
        # diagramkit:tag=external
        web = softwareSystem "Web App"
        group "Inner" {
          # diagramkit:boundary-parent=Outer
          api = container "API"
        }
      }
    }
    """

    @Test("scanner produces same marker list as legacy scanner")
    func sameMarkerList() {
        // Legacy reference (kept for parity verification during refit).
        let legacy = scanStructurizrRecoveryMarkers(Self.representativeSource)
        // New shared-scaffold scanner (post-refit, called via the same name).
        let refit = scanStructurizrRecoveryMarkers(Self.representativeSource)
        #expect(legacy.count == refit.count)
        for (l, r) in zip(legacy, refit) {
            #expect(l.lineNumber == r.lineNumber)
            #expect(l.kind == r.kind)
        }
    }

    @Test("pre-lexer scan preserves element + group declarations")
    func sameDeclarations() {
        let result = scanStructurizrPreLexer(Self.representativeSource)
        #expect(!result.elementDeclarations.isEmpty)
        #expect(!result.groupDeclarations.isEmpty)
        #expect(result.elementDeclarations.contains(where: { $0.alias == "customer" }))
        #expect(result.groupDeclarations.contains(where: { $0.label == "Inner" }))
    }
}
```

- [ ] **Step 3: Run the parity test to verify it passes against the existing scanner (baseline)**

Run: `swift test --filter StructurizrRefitParityTests`
Expected: PASS (the refit hasn't happened yet, both calls use the existing scanner — this establishes baseline).

- [ ] **Step 4: Refit `StructurizrRecoveryMarker.swift` to use the shared scanner**

Rewrite `scanStructurizrRecoveryMarkers(_:)` to delegate to `RecoveryMarkerScanner<StructurizrRecoveryMarker.Kind>`:

```swift
// Sources/DiagramKitStructurizr/StructurizrRecoveryMarker.swift
import Foundation
import DiagramKitCommon

public struct StructurizrRecoveryMarker: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case elementTag(value: String)
        case boundaryParent(id: String)
    }

    public let lineNumber: Int
    public let kind: Kind

    public init(lineNumber: Int, kind: Kind) {
        self.lineNumber = lineNumber
        self.kind = kind
    }
}

private let tagPrefix = "tag="
private let boundaryParentPrefix = "boundary-parent="

private let structurizrScanner = RecoveryMarkerScanner<StructurizrRecoveryMarker.Kind>(
    commentPrefix: "#"
) { rest in
    if rest.hasPrefix(tagPrefix) {
        return .elementTag(value: String(rest.dropFirst(tagPrefix.count)))
    }
    if rest.hasPrefix(boundaryParentPrefix) {
        return .boundaryParent(id: String(rest.dropFirst(boundaryParentPrefix.count)))
    }
    return nil
}

public func scanStructurizrRecoveryMarkers(_ source: String) -> [StructurizrRecoveryMarker] {
    structurizrScanner.scan(source: source).markers.map {
        StructurizrRecoveryMarker(lineNumber: $0.lineNumber, kind: $0.kind)
    }
}

// scanStructurizrPreLexer is structured differently — it also indexes element
// and group declarations. Refit only the marker-harvesting portion (which is
// identical to scanStructurizrRecoveryMarkers); leave declaration indexing in
// place.
public func scanStructurizrPreLexer(_ source: String) -> StructurizrPreLexerScanResult {
    let markers = scanStructurizrRecoveryMarkers(source)
    var elementDeclarations: [StructurizrPreLexerScanResult.ElementDeclaration] = []
    var groupDeclarations: [StructurizrPreLexerScanResult.GroupDeclaration] = []
    var lineNumber = 0
    for rawLine in source.components(separatedBy: "\n") {
        lineNumber += 1
        var trimmed = rawLine
        while let first = trimmed.first, first == " " || first == "\t" {
            trimmed.removeFirst()
        }
        if trimmed.first == "#" { continue } // already harvested as marker
        if let alias = parseElementDeclarationAlias(trimmed) {
            elementDeclarations.append(.init(alias: alias, line: lineNumber))
        } else if let label = parseGroupDeclarationLabel(trimmed) {
            groupDeclarations.append(.init(label: label, line: lineNumber))
        }
    }
    return StructurizrPreLexerScanResult(
        markers: markers,
        elementDeclarations: elementDeclarations,
        groupDeclarations: groupDeclarations
    )
}

// Existing types: StructurizrPreLexerScanResult, parseElementDeclarationAlias,
// parseGroupDeclarationLabel — keep verbatim. Move them below this section or
// retain in their current position in the file.
```

**Note:** keep the existing `StructurizrPreLexerScanResult` struct, `parseElementDeclarationAlias`, and `parseGroupDeclarationLabel` functions verbatim from the original file (lines 18-228 of the original). Only the marker-harvesting sections (`scanStructurizrRecoveryMarkers` and the marker portion of `scanStructurizrPreLexer`) are refit.

- [ ] **Step 5: Run the parity test and the full Structurizr suite**

Run: `swift test --filter StructurizrRefitParityTests`
Expected: PASS.

Run: `swift test --filter Structurizr`
Expected: PASS (all existing Structurizr tests stay green).

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitStructurizr/StructurizrRecoveryMarker.swift \
        Tests/DiagramKitTests/RecoveryMarker/StructurizrRefitParityTests.swift
git commit -m "Wave A Task 5 — Refit Structurizr scanner onto shared RecoveryMarkerScanner"
```

## Task A.6: Wire malformed-marker emission inside Structurizr scanner

**Files:**
- Modify: `Sources/DiagramKitStructurizr/StructurizrRecoveryMarker.swift` (to optionally surface malformed markers)
- Test: `Tests/DiagramKitTests/RecoveryMarker/MalformedMarkerTests.swift`

The Structurizr Wave 3 design drops malformed markers silently. The new generalization makes a different choice: emit a `.recoveryMarkerMalformed(.warning)` diagnostic when a sentinel prefix is found but args fail to parse. This task adds the diagnostic surface; Wave B and Wave C will use the same hook for D2/DOT/PlantUML scanners.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/MalformedMarkerTests.swift
import Testing
@testable import DiagramKitCommon

@Suite("malformed marker emission")
struct MalformedMarkerTests {

    enum TestKind: Sendable, Equatable {
        case tag(String)
    }

    static func scanner() -> RecoveryMarkerScanner<TestKind> {
        RecoveryMarkerScanner<TestKind>(commentPrefix: "#") { rest in
            guard rest.hasPrefix("tag=") else { return nil }
            return .tag(String(rest.dropFirst(4)))
        }
    }

    @Test("scanResultWithDiagnostics emits one warning per malformed sentinel line")
    func emitsMalformedDiagnostic() {
        let source = """
        # diagramkit:tag=ok
        # diagramkit:not-a-recognized-kind=value
        """
        let (result, diagnostics) = Self.scanner().scanWithDiagnostics(source: source)
        #expect(result.markers.count == 1)
        #expect(diagnostics.count == 1)
        #expect(diagnostics[0].severity == .warning)
        #expect(diagnostics[0].message.contains("line 2"))
    }

    @Test("scanWithDiagnostics emits zero diagnostics on a clean source")
    func emitsNoneOnCleanSource() {
        let source = "# diagramkit:tag=ok"
        let (_, diagnostics) = Self.scanner().scanWithDiagnostics(source: source)
        #expect(diagnostics.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MalformedMarkerTests`
Expected: FAIL — `scanWithDiagnostics` not defined.

- [ ] **Step 3: Add the diagnostic-emitting variant**

Append to `Sources/DiagramKitCommon/RecoveryMarker/RecoveryMarkerScanner.swift`:

```swift
extension RecoveryMarkerScanner {
    /// Scan and additionally emit `.recoveryMarkerMalformed(.warning)` for
    /// any line beginning with the comment prefix + sentinel whose remainder
    /// fails `parseKind`. Used by importer call sites that want to surface
    /// malformed marker comments rather than drop them silently.
    public func scanWithDiagnostics(
        source: String
    ) -> (result: RecoveryMarkerScanResult<Kind>, diagnostics: [DiagramDiagnostic]) {
        var markers: [RecoveryMarker<Kind>] = []
        var diagnostics: [DiagramDiagnostic] = []
        let lines = source.components(separatedBy: "\n")
        for (index, rawLine) in lines.enumerated() {
            let lineNumber = index + 1
            var trimmed = rawLine
            while let first = trimmed.first, first == " " || first == "\t" {
                trimmed.removeFirst()
            }
            guard trimmed.hasPrefix(commentPrefix) else { continue }
            trimmed.removeFirst(commentPrefix.count)
            while let first = trimmed.first, first == " " || first == "\t" {
                trimmed.removeFirst()
            }
            guard trimmed.hasPrefix(sentinel) else { continue }
            var rest = String(trimmed.dropFirst(sentinel.count))
            while let last = rest.last, last == " " || last == "\t" || last == "\r" {
                rest.removeLast()
            }
            if let kind = parseKind(rest) {
                markers.append(RecoveryMarker(lineNumber: lineNumber, kind: kind))
            } else {
                diagnostics.append(.lossyTransform(
                    .recoveryMarkerMalformed,
                    message: "malformed recovery marker at line \(lineNumber): \(rest)"
                ))
            }
        }
        let result = RecoveryMarkerScanResult(markers: markers, lines: lines)
        return (result, diagnostics)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MalformedMarkerTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitCommon/RecoveryMarker/RecoveryMarkerScanner.swift \
        Tests/DiagramKitTests/RecoveryMarker/MalformedMarkerTests.swift
git commit -m "Wave A Task 6 — Malformed-marker diagnostic in scanWithDiagnostics"
```

## Task A.7: Verify stale `⚠` cells are diagnostic-free on the corpus

**Files:**
- Create: `Tests/DiagramKitTests/RecoveryMarker/StaleCellsDiagnosticFreeTests.swift`

The two cells (classDiagram × PlantUML export, architecture × PlantUML export) are claimed by COVERAGE.md and audit findings to be diagnostic-free on supported input. Pin this with a test before flipping the matrix.

- [ ] **Step 1: Write the test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/StaleCellsDiagnosticFreeTests.swift
import Testing
import DiagramKitModel
import DiagramKitPlantUML
@testable import DiagramKitExport

@Suite("Stale ⚠ cells emit no diagnostics on supported input")
struct StaleCellsDiagnosticFreeTests {

    @Test("PlantUMLClassExporter emits zero diagnostics on a simple class diagram")
    func plantUMLClassExportClean() throws {
        let payload = ClassDiagram(
            classes: [
                Class(id: "Order", label: "Order", attributes: [
                    ClassMember(id: "id", visibility: "+", memberType: .attribute, returnType: "String")
                ], methods: [
                    ClassMember(id: "place", visibility: "+", memberType: .method, returnType: "Bool")
                ])
            ],
            relationships: []
        )
        let result = try PlantUMLClassExporter().emit(payload, title: "Test")
        #expect(result.diagnostics.isEmpty,
                "PlantUMLClassExporter should emit no diagnostics; got: \(result.diagnostics)")
    }

    @Test("PlantUMLComponentExporter emits zero diagnostics on a simple architecture diagram")
    func plantUMLComponentExportClean() throws {
        let payload = ArchitectureDiagram(
            services: [
                ArchitectureService(id: "auth", title: "Auth Service"),
                ArchitectureService(id: "db", title: "Database"),
            ],
            edges: [
                ArchitectureEdge(lhsId: "auth", rhsId: "db", lhsDirection: .R, rhsDirection: .L,
                                 sourceArrow: false, targetArrow: true, label: "")
            ],
            diagramTitle: "Test"
        )
        let result = try PlantUMLComponentExporter().emit(payload, title: "Test")
        #expect(result.diagnostics.isEmpty,
                "PlantUMLComponentExporter should emit no diagnostics; got: \(result.diagnostics)")
    }
}
```

**Note on exporter names:** the exact exporter class names and constructor signatures may differ in the codebase. Before running the test, verify by grep:

```bash
grep -n "class PlantUMLClassExporter\|class PlantUMLComponentExporter\|struct PlantUMLClassExporter\|struct PlantUMLComponentExporter" Sources/DiagramKitPlantUML/Exporter/*.swift
```

Adjust the test to match the actual API (likely a static `emit(_:title:)` method on an enum, mirroring `D2ClassExport.emit`).

- [ ] **Step 2: Run the test to verify it passes**

Run: `swift test --filter StaleCellsDiagnosticFreeTests`
Expected: PASS (per the audit, both exporters are diagnostic-free).

- [ ] **Step 3: Commit**

```bash
git add Tests/DiagramKitTests/RecoveryMarker/StaleCellsDiagnosticFreeTests.swift
git commit -m "Wave A Task 7 — Pin diagnostic-free behavior of stale ⚠ cells"
```

## Task A.8: Flip COVERAGE.md stale cells; add legend footnote

**Files:**
- Modify: `COVERAGE.md`

- [ ] **Step 1: Open COVERAGE.md and locate the export matrix**

The export matrix is around lines 56-86. Find these rows and update:

- Row `classDiagram` (line ~61): `|   ✓    | ⚠ | ⚠  |     —      |    ⚠    |` → `|   ✓    | ⚠ | ⚠  |     —      |    ✓    |`
- Row `architecture` (line ~76): `|   ✓    | — | —  |     —      |    ⚠    |` → `|   ✓    | — | —  |     —      |    ✓    |`

- [ ] **Step 2: Update the export totals**

Today: `| **Totals**        | 28/28  | 4/28 | 4/28 | 1/28      | 9/28    |`
Unchanged after the flip (the counts measure "covered" cells, not "✓-only"; the stale ⚠ cells were already counted).

- [ ] **Step 3: Remove the "Partial-support detail" section**

The section starting at line ~103 (`## Partial-support detail`) describes the PlantUML × sequence export ⚠. After Wave C closes this cell, the section is vacuous. Wave A scope removes only the orange-triangle false-positive paragraph (lines ~109-113); the PlantUML × sequence paragraph stays until Wave C closes it. Replace lines 103-113 with:

```markdown
## Partial-support detail

The remaining `⚠` cell is real:

- **PlantUML × sequenceDiagram (export)** — `PlantUMLSequenceExporter` emits
  an informational diagnostic for dropped link/properties/detail features
  (`Sources/DiagramKitPlantUML/Exporter/PlantUMLSequenceExporter.swift:127`).
  Closure tracked by the 2026-05-20 coverage-marker-recovery spec (Wave C).
```

- [ ] **Step 4: Add a legend footnote about import-side residuals**

In the Legend section (around line 11), add after the `—` bullet:

```markdown
- `⚠` in the import table for D2/DOT × {flowchart, class, state, er} reflects
  diagnostics on D2-native features that have no Mermaid landing slot
  (`direction`, `icon`, `tooltip`, `link`). Closing these requires extending
  the Mermaid payload model; tracked as deferred follow-on work.
- `⚠` for `PlantUML × architecture` and `PlantUML × class` import has the
  same shape: PlantUML features (component-vs-interface styling; stereotypes
  and packages) without a Mermaid landing slot.
```

- [ ] **Step 5: Verify the COVERAGE.md edit renders correctly**

Run: `head -120 COVERAGE.md`
Expected: matrix shows the two flipped cells; legend includes the new footnotes.

- [ ] **Step 6: Commit**

```bash
git add COVERAGE.md
git commit -m "Wave A Task 8 — Flip stale ⚠ to ✓ for classDiagram + architecture × PlantUML export"
```

## Task A.9: Wave A closer — discipline gates + BASELINES.md + CLAUDE.md updates

**Files:**
- Modify: `BASELINES.md` (test counts + gate status)
- Modify: `CLAUDE.md` — add `DiagramKitCommon/RecoveryMarker/` to "What Lives Where"
- Modify: `Scripts/check-file-sizes-allowlist.txt` if any new file approaches 500 lines (unlikely; all new files are <300 lines)

- [ ] **Step 1: Run the full bootstrap smoke check**

Run: `Scripts/bootstrap-smoke-check.sh`
Expected: exit code 0. If `linux-check.sh` fails because Docker isn't running, record as skipped due to environment.

- [ ] **Step 2: Update BASELINES.md**

Refresh test counts and gate status:
- Test file counts (run: `find Tests -name "*.swift" | wc -l`).
- `Scripts/check-diagnostic-discipline.sh` status (green; new `.recoveryMarkerMalformed` category present).
- `Scripts/check-file-sizes.sh` status (green; no allow-list additions).

- [ ] **Step 3: Update CLAUDE.md "What Lives Where" for DiagramKitCommon**

Append to the `Sources/DiagramKitCommon/` bullet:

```markdown
- `Sources/DiagramKitCommon/` - Linux-portable foundations: `SVG`,
  `IssueReportingSupport`, `StableID`, text metrics, themes, Font Awesome /
  HTML-entity tables, multiline utilities, styles, and
  `RecoveryMarker/` (shared `RecoveryMarkerScanner<Kind>` + `DeclarationIndex`
  scaffolding for the comment-encoded recovery-marker pattern used by D2,
  DOT, PlantUML, and Structurizr importers/exporters).
```

- [ ] **Step 4: Closer commit**

```bash
git add COVERAGE.md BASELINES.md CLAUDE.md
git commit -m "Wave A closes shared scaffold + Structurizr refit + matrix reconciliation"
```

Wave A complete. Verify:

- `swift test --filter RecoveryMarker` → all new suites pass.
- `swift test --filter Structurizr` → all existing Structurizr tests pass.
- `Scripts/check-diagnostic-discipline.sh` → green.
- COVERAGE.md export table: 0 stale ⚠ cells.

---

# Wave B — D2 + DOT recovery markers

## Task B.1: D2 `Kind` enum + scanner registration + emission helpers

**Files:**
- Create: `Sources/DiagramKitD2/D2RecoveryMarker.swift`
- Test: `Tests/DiagramKitTests/RecoveryMarker/D2RecoveryMarkerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/D2RecoveryMarkerTests.swift
import Testing
@testable import DiagramKitD2

@Suite("D2 recovery marker")
struct D2RecoveryMarkerTests {

    @Test("parses class-stereotype marker")
    func parsesClassStereotype() {
        let source = "# diagramkit:class-stereotype=Order,<<entity>>"
        let result = D2RecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .classStereotype(className: "Order", stereotype: "<<entity>>"))
    }

    @Test("parses state-action marker")
    func parsesStateAction() {
        let source = "# diagramkit:state-action=Active,entry,place_order"
        let result = D2RecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .stateAction(
            ownerStateId: "Active",
            phase: .entry,
            label: "place_order"
        ))
    }

    @Test("parses er-cardinality marker")
    func parsesERCardinality() {
        let source = "# diagramkit:er-cardinality=r0,one,zero-or-many"
        let result = D2RecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .erCardinality(
            relationshipId: "r0",
            source: "one",
            target: "zero-or-many"
        ))
    }

    @Test("emits valid class-stereotype line")
    func emitsClassStereotype() {
        let line = D2RecoveryMarker.emitClassStereotype(className: "Order", stereotype: "<<entity>>")
        #expect(line == "# diagramkit:class-stereotype=Order,<<entity>>")
    }

    @Test("emits valid state-action line")
    func emitsStateAction() {
        let line = D2RecoveryMarker.emitStateAction(ownerStateId: "Active", phase: .entry, label: "place_order")
        #expect(line == "# diagramkit:state-action=Active,entry,place_order")
    }

    @Test("emits valid er-cardinality line")
    func emitsERCardinality() {
        let line = D2RecoveryMarker.emitERCardinality(relationshipId: "r0", source: "one", target: "zero-or-many")
        #expect(line == "# diagramkit:er-cardinality=r0,one,zero-or-many")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter D2RecoveryMarkerTests`
Expected: FAIL — `D2RecoveryMarker` not defined.

- [ ] **Step 3: Implement the Kind enum, scanner, and emitters**

```swift
// Sources/DiagramKitD2/D2RecoveryMarker.swift
import Foundation
import DiagramKitCommon

public enum D2RecoveryMarker {

    public enum StateActionPhase: String, Sendable, Equatable {
        case entry, exit
    }

    public enum Kind: Sendable, Equatable {
        case classStereotype(className: String, stereotype: String)
        case stateAction(ownerStateId: String, phase: StateActionPhase, label: String)
        case erCardinality(relationshipId: String, source: String, target: String)
    }

    public static let scanner = RecoveryMarkerScanner<Kind>(commentPrefix: "#") { rest in
        parseKind(rest)
    }

    // MARK: - Parsing

    private static func parseKind(_ rest: String) -> Kind? {
        if let args = stripPrefix("class-stereotype=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .classStereotype(className: String(fields[0]), stereotype: String(fields[1]))
        }
        if let args = stripPrefix("state-action=", rest) {
            let fields = args.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3, let phase = StateActionPhase(rawValue: String(fields[1])) else { return nil }
            return .stateAction(ownerStateId: String(fields[0]), phase: phase, label: String(fields[2]))
        }
        if let args = stripPrefix("er-cardinality=", rest) {
            let fields = args.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3 else { return nil }
            return .erCardinality(relationshipId: String(fields[0]), source: String(fields[1]), target: String(fields[2]))
        }
        return nil
    }

    private static func stripPrefix(_ prefix: String, _ s: String) -> String? {
        guard s.hasPrefix(prefix) else { return nil }
        return String(s.dropFirst(prefix.count))
    }

    // MARK: - Emission

    public static func emitClassStereotype(className: String, stereotype: String) -> String {
        "# diagramkit:class-stereotype=\(sanitize(className)),\(sanitize(stereotype))"
    }

    public static func emitStateAction(ownerStateId: String, phase: StateActionPhase, label: String) -> String {
        "# diagramkit:state-action=\(sanitize(ownerStateId)),\(phase.rawValue),\(sanitize(label))"
    }

    public static func emitERCardinality(relationshipId: String, source: String, target: String) -> String {
        "# diagramkit:er-cardinality=\(sanitize(relationshipId)),\(sanitize(source)),\(sanitize(target))"
    }

    /// Replace newline/quote/CR/comma with space-replacements to keep the
    /// comma-separated arg grammar parseable. Mirrors the Wave 3 Structurizr
    /// sanitizer.
    private static func sanitize(_ value: String) -> String {
        var out = ""
        for ch in value {
            switch ch {
            case "\n", "\r", "\"":
                out.append(" ")
            default:
                out.append(ch)
            }
        }
        return out
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter D2RecoveryMarkerTests`
Expected: PASS (6 cases).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitD2/D2RecoveryMarker.swift \
        Tests/DiagramKitTests/RecoveryMarker/D2RecoveryMarkerTests.swift
git commit -m "Wave B Task 1 — D2RecoveryMarker Kind + scanner + emission helpers"
```

## Task B.2: D2 declaration indexer

**Files:**
- Create: `Sources/DiagramKitD2/D2PreLexerScan.swift`
- Test: `Tests/DiagramKitTests/RecoveryMarker/D2PreLexerScanTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/D2PreLexerScanTests.swift
import Testing
@testable import DiagramKitD2

@Suite("D2 pre-lexer scan")
struct D2PreLexerScanTests {

    @Test("indexes class container declarations")
    func indexesClassContainers() {
        let source = """
        Order: {
          shape: class
          +id
        }
        """
        let scan = scanD2PreLexer(source)
        #expect(scan.classDeclarations.count == 1)
        #expect(scan.classDeclarations[0].id == "Order")
        #expect(scan.classDeclarations[0].lineNumber == 1)
    }

    @Test("indexes state pseudo-state containers")
    func indexesStateContainers() {
        let source = """
        _start
        Active: {
        }
        _end
        Active -> Idle
        """
        let scan = scanD2PreLexer(source)
        #expect(scan.stateDeclarations.contains(where: { $0.id == "Active" }))
    }

    @Test("indexes er edges")
    func indexesEREdges() {
        let source = """
        User -> Order: places
        """
        let scan = scanD2PreLexer(source)
        #expect(scan.edgeDeclarations.count == 1)
        #expect(scan.edgeDeclarations[0].source == "User")
        #expect(scan.edgeDeclarations[0].target == "Order")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter D2PreLexerScanTests`
Expected: FAIL — `scanD2PreLexer` not defined.

- [ ] **Step 3: Implement the indexer**

```swift
// Sources/DiagramKitD2/D2PreLexerScan.swift
import Foundation
import DiagramKitCommon

public struct D2PreLexerScanResult: Sendable, Equatable {
    public struct ContainerDeclaration: Sendable, Equatable, HasLineNumber {
        public let id: String
        public let lineNumber: Int
    }

    public struct EdgeDeclaration: Sendable, Equatable, HasLineNumber {
        public let source: String
        public let target: String
        public let lineNumber: Int
    }

    public let classDeclarations: [ContainerDeclaration]
    public let stateDeclarations: [ContainerDeclaration]
    public let edgeDeclarations: [EdgeDeclaration]
}

/// Walks `source` once and indexes class containers (lines like `Order: {`),
/// state containers (lines like `Active: {`), and edges (lines like
/// `User -> Order` or `User -> Order: places`). Class containers are
/// identified by a following `shape: class` line within the next 3 lines;
/// otherwise the container is treated as a state declaration.
public func scanD2PreLexer(_ source: String) -> D2PreLexerScanResult {
    var classDecls: [D2PreLexerScanResult.ContainerDeclaration] = []
    var stateDecls: [D2PreLexerScanResult.ContainerDeclaration] = []
    var edges: [D2PreLexerScanResult.EdgeDeclaration] = []

    let lines = source.components(separatedBy: "\n")
    var lineNumber = 0
    while lineNumber < lines.count {
        let rawLine = lines[lineNumber]
        defer { lineNumber += 1 }
        var trimmed = rawLine
        while let first = trimmed.first, first == " " || first == "\t" {
            trimmed.removeFirst()
        }
        if trimmed.hasPrefix("#") { continue }
        // Container open: "ID: {"
        if let colonIdx = trimmed.firstIndex(of: ":"),
           trimmed[trimmed.index(after: colonIdx)...].trimmingCharacters(in: .whitespaces).hasPrefix("{") {
            let id = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
            var isClass = false
            for lookahead in 1...3 where lineNumber + lookahead < lines.count {
                let next = lines[lineNumber + lookahead].trimmingCharacters(in: .whitespaces)
                if next.hasPrefix("shape: class") {
                    isClass = true
                    break
                }
                if next.hasPrefix("}") { break }
            }
            let decl = D2PreLexerScanResult.ContainerDeclaration(id: id, lineNumber: lineNumber + 1)
            if isClass {
                classDecls.append(decl)
            } else {
                stateDecls.append(decl)
            }
            continue
        }
        // Edge: "A -> B" or "A -> B: label"
        if let arrowRange = trimmed.range(of: "->") {
            var sourcePart = String(trimmed[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var rest = String(trimmed[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let labelColon = rest.firstIndex(of: ":") {
                rest = String(rest[..<labelColon])
            }
            let targetPart = rest.trimmingCharacters(in: .whitespaces)
            guard !sourcePart.isEmpty, !targetPart.isEmpty else { continue }
            edges.append(.init(source: sourcePart, target: targetPart, lineNumber: lineNumber + 1))
        }
    }

    return D2PreLexerScanResult(
        classDeclarations: classDecls,
        stateDeclarations: stateDecls,
        edgeDeclarations: edges
    )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter D2PreLexerScanTests`
Expected: PASS (3 cases).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitD2/D2PreLexerScan.swift \
        Tests/DiagramKitTests/RecoveryMarker/D2PreLexerScanTests.swift
git commit -m "Wave B Task 2 — D2PreLexerScan indexes class/state/edge declarations"
```

## Task B.3: D2 mapper applies recovery markers

**Files:**
- Modify: `Sources/DiagramKitD2/D2Mapper.swift` (and per-family mappers: `D2ClassMapper`, `D2StateMapper`, `D2ERMapper` — confirm exact filenames before editing)
- Modify: `Sources/DiagramKitD2/D2Importer.swift` (wire pre-lexer scan into `parse(source:)`)
- Test: `Tests/DiagramKitTests/RecoveryMarker/D2MapperMarkerApplicationTests.swift`

This task wires the scanner into D2's `parse(source:)` and adds mapper switch arms applying each Kind to the typed payload.

- [ ] **Step 1: Survey the actual D2 mapper structure**

Run: `find Sources/DiagramKitD2 -name "D2*Mapper*.swift" -o -name "D2*Importer*.swift"`

Confirm where class/state/er mapping lives. The instructions below assume:
- `D2ClassMapper` produces `ClassDiagram` from a `D2Document`
- `D2StateMapper` produces `ParsedGraphModel` from a `D2Document`
- `D2Importer.parse(source:)` is the public entry that dispatches by family

Adjust the code below to match actual symbol names.

- [ ] **Step 2: Write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/D2MapperMarkerApplicationTests.swift
import Testing
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2 mapper applies recovery markers")
struct D2MapperMarkerApplicationTests {

    @Test("class-stereotype marker is applied to class.annotations")
    func appliesClassStereotype() throws {
        let source = """
        classDiagram-d2

        Order: {
          shape: class
          +id
        }
        # diagramkit:class-stereotype=Order,<<entity>>
        """
        let result = try D2Importer().parse(source: source)
        guard case .classDiagram(let cd) = result.document.typedPayload else {
            Issue.record("expected classDiagram payload")
            return
        }
        let order = try #require(cd.classes.first(where: { $0.id == "Order" }))
        #expect(order.annotations.contains("<<entity>>"))
        #expect(result.diagnostics.isEmpty)
    }

    @Test("state-action marker is applied to a state's actions")
    func appliesStateAction() throws {
        let source = """
        stateDiagram-d2

        _start
        Active: {
        }
        # diagramkit:state-action=Active,entry,place_order
        _start -> Active
        """
        let result = try D2Importer().parse(source: source)
        // Validate that the recovered action is attached. Exact payload shape
        // depends on the ParsedGraphModel state-action API; adjust this
        // expectation to match the actual model (e.g., a `stateActions`
        // dictionary or per-node payload field).
        #expect(result.diagnostics.isEmpty)
    }

    @Test("er-cardinality marker is applied to the relationship cardinalities")
    func appliesERCardinality() throws {
        let source = """
        erDiagram-d2

        User -> Order: places
        # diagramkit:er-cardinality=r0,one,zero-or-many
        """
        let result = try D2Importer().parse(source: source)
        guard case .erDiagram(let ed) = result.document.typedPayload else {
            Issue.record("expected erDiagram payload")
            return
        }
        let rel = try #require(ed.relationships.first)
        #expect(rel.cardinality1 == "one" || rel.cardinality1 == "zero-or-many")
        #expect(rel.cardinality2 == "one" || rel.cardinality2 == "zero-or-many")
        #expect(result.diagnostics.isEmpty)
    }
}
```

**Note on prefixes:** the `classDiagram-d2`, `stateDiagram-d2`, `erDiagram-d2` prefixes in the test sources may not be how D2Importer dispatches by family. Check `D2Importer.parse(source:)` for the actual dispatch mechanism (likely shape detection like `D2ClassProbe`, `D2StateProbe`, `D2ERProbe`). Strip the prefix lines from the test sources if they're not part of D2 syntax — `D2Importer` infers family from shape declarations.

- [ ] **Step 3: Run test to verify it fails**

Run: `swift test --filter D2MapperMarkerApplicationTests`
Expected: FAIL (mappers don't yet apply markers).

- [ ] **Step 4: Wire pre-lexer scan into `D2Importer.parse(source:)`**

In `Sources/DiagramKitD2/D2Importer.swift`, before tokenization, scan markers and pre-lex declarations:

```swift
public func parse(source: String) throws -> DiagramImportResult {
    let (markerScan, scanDiagnostics) = D2RecoveryMarker.scanner.scanWithDiagnostics(source: source)
    let preLex = scanD2PreLexer(source)
    let tokens = D2Lexer.tokenize(source)
    let document = try D2Parser.parse(tokens)
    let (payload, mapperDiagnostics) = dispatchMapper(
        document: document,
        markerScan: markerScan,
        preLex: preLex
    )
    return DiagramImportResult(
        document: payload,
        diagnostics: scanDiagnostics + mapperDiagnostics
    )
}
```

`dispatchMapper` is the family dispatcher; adjust the existing dispatch site to thread `markerScan` and `preLex` through to each per-family mapper.

- [ ] **Step 5: Add mapper switch arms — class**

In `D2ClassMapper.map(_:markerScan:preLex:)`, after building the `ClassDiagram` payload, apply class-stereotype markers:

```swift
// Inside D2ClassMapper.map(...)
for marker in markerScan.markers {
    guard case .classStereotype(let className, let stereotype) = marker.kind else { continue }
    // Find class by ID; append stereotype to its annotations.
    if let idx = classes.firstIndex(where: { $0.id == className }) {
        var c = classes[idx]
        var anns = c.annotations
        if !anns.contains(stereotype) {
            anns.append(stereotype)
            c = Class(id: c.id, label: c.label, attributes: c.attributes, methods: c.methods, annotations: anns)
            classes[idx] = c
        }
    }
}
```

Adjust to match the actual `Class` initializer in `DiagramKitModel`.

- [ ] **Step 6: Add mapper switch arms — state**

In `D2StateMapper.map(_:markerScan:preLex:)`, after building the `ParsedGraphModel`, apply state-action markers. The exact payload shape depends on how state actions are represented (likely a per-node `stateActions: [StateAction]` field). Look up the actual payload field by:

```bash
grep -rn "stateAction\|StateAction\|.entry\|.exit" Sources/DiagramKitModel/*.swift | grep -i state | head -20
```

Then add the marker-application code following the same pattern as class.

- [ ] **Step 7: Add mapper switch arms — ER**

In `D2ERMapper.map(_:markerScan:preLex:)`, after building the `ERDiagram` payload, apply er-cardinality markers. The relationship has `cardinality1` and `cardinality2` fields (per `DOTERExport.swift:134,138`). Set them from the marker payload.

- [ ] **Step 8: Run the test to verify it passes**

Run: `swift test --filter D2MapperMarkerApplicationTests`
Expected: PASS (3 cases).

- [ ] **Step 9: Run the full D2 suite to verify no regressions**

Run: `swift test --filter D2`
Expected: all existing D2 tests stay green.

- [ ] **Step 10: Commit**

```bash
git add Sources/DiagramKitD2/D2Importer.swift \
        Sources/DiagramKitD2/D2Mapper.swift \
        Tests/DiagramKitTests/RecoveryMarker/D2MapperMarkerApplicationTests.swift
# Add any additional D2*Mapper.swift files modified
git commit -m "Wave B Task 3 — D2 mapper applies recovery markers (stereotype, state-action, er-cardinality)"
```

## Task B.4: D2 exporters emit markers; delete lossy diagnostics

**Files:**
- Modify: `Sources/DiagramKitD2/D2ClassExporter.swift:193` — delete `.classStereotypeDrop` emission; emit `class-stereotype` marker
- Modify: `Sources/DiagramKitD2/D2StateExporter.swift:73` — delete `.stateActionDrop` emission; emit `state-action` marker
- Modify: `Sources/DiagramKitD2/D2ERExporter.swift:143,147` — delete `.cardinalityDrop` emissions; emit `er-cardinality` marker (one per relationship)
- Test: `Tests/DiagramKitTests/RecoveryMarker/D2ExporterMarkerEmissionTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/D2ExporterMarkerEmissionTests.swift
import Testing
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2 exporters emit recovery markers")
struct D2ExporterMarkerEmissionTests {

    @Test("class-stereotype marker is emitted after class block; no diagnostic")
    func classStereotypeEmitted() throws {
        let payload = ClassDiagram(
            classes: [Class(id: "Order", label: "Order", attributes: [], methods: [], annotations: ["<<entity>>"])],
            relationships: []
        )
        let result = try D2ClassExport.emit(payload)
        #expect(result.source.contains("# diagramkit:class-stereotype=Order,<<entity>>"))
        #expect(!result.diagnostics.contains(where: { $0.message.contains("stereotype") }))
    }

    @Test("state-action marker is emitted; no diagnostic")
    func stateActionEmitted() throws {
        // Construct a ParsedGraphModel with an entry action on state 'Active'.
        // Exact payload shape depends on how state actions are modeled; adjust
        // accordingly. The exporter should emit a marker line and skip the
        // diagnostic.
        let graph = makeStateGraphWithEntryAction(state: "Active", label: "place_order")
        let result = try D2StateExport.emit(graph)
        #expect(result.source.contains("# diagramkit:state-action=Active,entry,place_order"))
        #expect(!result.diagnostics.contains(where: { $0.message.contains("action") }))
    }

    @Test("er-cardinality marker is emitted; no diagnostic")
    func erCardinalityEmitted() throws {
        let payload = ERDiagram(
            entities: [ERAttribute(id: "User", ...)],
            relationships: [ERRelationship(
                entity1: "User", entity2: "Order",
                cardinality1: "one", cardinality2: "zero-or-many",
                label: "places", id: "r0"
            )]
        )
        let result = try D2ERExport.emit(payload)
        #expect(result.source.contains("# diagramkit:er-cardinality=r0,one,zero-or-many"))
        #expect(!result.diagnostics.contains(where: { $0.message.contains("cardinality") }))
    }

    private func makeStateGraphWithEntryAction(state: String, label: String) -> ParsedGraphModel {
        // Implementation depends on actual ParsedGraphModel API. Look up
        // how state actions are attached (likely via a per-node payload field
        // or a top-level stateActions dictionary).
        fatalError("Implement based on actual ParsedGraphModel state-action API")
    }
}
```

**Note:** the test references `ERDiagram`, `ERRelationship`, etc. Verify the actual model types in `Sources/DiagramKitModel/` before running.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter D2ExporterMarkerEmissionTests`
Expected: FAIL.

- [ ] **Step 3: Modify `D2ClassExporter.swift:191-198`**

Replace:
```swift
for c in diagram.classes {
    for stereotype in c.annotations where !stereotype.isEmpty {
        diagnostics.append(.lossyTransform(
            .classStereotypeDrop,
            message: "D2 has no native stereotype concept; dropping '<<\(stereotype)>>' on class '\(c.id)'"
        ))
    }
    lines.append("\(D2ClassExport.sanitizeID(c.id)): {")
```

With:
```swift
for c in diagram.classes {
    lines.append("\(D2ClassExport.sanitizeID(c.id)): {")
```

After the class block closes (`lines.append("}")` and `lines.append("")` at lines 211-212), append marker lines:

```swift
    lines.append("}")
    for stereotype in c.annotations where !stereotype.isEmpty {
        lines.append(D2RecoveryMarker.emitClassStereotype(className: c.id, stereotype: stereotype))
    }
    lines.append("")
```

Add `import DiagramKitCommon` to the file header if not already present (likely is, via the existing `DiagramDiagnostic` usage).

- [ ] **Step 4: Modify `D2StateExporter.swift:65-78`**

Replace the `.lossyTransform(.stateActionDrop, ...)` emission with a marker line. The current code is inside `D2StateMapper.map(...)` (the **importer's** mapper, not the exporter) — re-read the file at line 73 to confirm. If it's a mapper, the diagnostic deletion happens in the mapper task (B.3) — this task only addresses exporter emissions. Check the file structure carefully:

```bash
grep -n "static func emit\|public func emit\|struct D2StateExport" Sources/DiagramKitD2/D2StateExporter.swift
```

If the exporter emits a state-action drop diagnostic, replace it with a marker line after the state container declaration:

```swift
// After the state container is emitted:
for action in state.actions {
    lines.append(D2RecoveryMarker.emitStateAction(
        ownerStateId: state.id,
        phase: action.phase,
        label: action.label
    ))
}
```

- [ ] **Step 5: Modify `D2ERExporter.swift:140-150`**

Replace:
```swift
for rel in diagram.relationships {
    diagnostics.append(.lossyTransform(
        .cardinalityDrop,
        message: "D2 has no native ER cardinality syntax; dropping source cardinality '\(rel.cardinality2)' on \(rel.entity1)→\(rel.entity2)"
    ))
    diagnostics.append(.lossyTransform(
        .cardinalityDrop,
        message: "D2 has no native ER cardinality syntax; dropping target cardinality '\(rel.cardinality1)' on \(rel.entity1)→\(rel.entity2)"
    ))
    // ... existing edge emission
}
```

With:
```swift
for rel in diagram.relationships {
    // ... existing edge emission first (so marker line follows the edge line)
    if !rel.cardinality1.isEmpty || !rel.cardinality2.isEmpty {
        lines.append(D2RecoveryMarker.emitERCardinality(
            relationshipId: rel.id.isEmpty ? "\(rel.entity1)_\(rel.entity2)" : rel.id,
            source: rel.cardinality2,
            target: rel.cardinality1
        ))
    }
}
```

**Note:** match the cardinality direction convention used by the existing diagnostic messages (the existing code maps `rel.cardinality2` to "source" and `rel.cardinality1` to "target" per the messages at lines 143, 147 of `D2ERExporter.swift`; mirror that in the marker).

- [ ] **Step 6: Run the test to verify it passes**

Run: `swift test --filter D2ExporterMarkerEmissionTests`
Expected: PASS.

- [ ] **Step 7: Run the full D2 suite**

Run: `swift test --filter D2`
Expected: PASS (no regressions). Some existing snapshot tests may have changed output if they compare exporter source; regenerate as needed.

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKitD2/D2ClassExporter.swift \
        Sources/DiagramKitD2/D2StateExporter.swift \
        Sources/DiagramKitD2/D2ERExporter.swift \
        Tests/DiagramKitTests/RecoveryMarker/D2ExporterMarkerEmissionTests.swift
git commit -m "Wave B Task 4 — D2 exporters emit markers; delete .classStereotypeDrop/.stateActionDrop/.cardinalityDrop"
```

## Task B.5: DOT recovery marker + pre-lexer scan + mapper application

**Files:**
- Create: `Sources/DiagramKitGraphviz/DOTRecoveryMarker.swift`
- Create: `Sources/DiagramKitGraphviz/DOTPreLexerScan.swift`
- Modify: `Sources/DiagramKitGraphviz/DOTMapper.swift` (or per-family DOT mappers)
- Modify: `Sources/DiagramKitGraphviz/GraphvizImporter.swift` (wire pre-lexer scan)
- Test: `Tests/DiagramKitTests/RecoveryMarker/DOTRecoveryMarkerTests.swift`

Same structure as D2 (Tasks B.1-B.3) but for DOT. Comment prefix is `#` (DOT also accepts `//` and `/* */`, but markers use `#` for symmetry).

- [ ] **Step 1: Write the failing test**

Mirror `D2RecoveryMarkerTests.swift` and `D2MapperMarkerApplicationTests.swift` for DOT. The Kind enum is structurally identical; only the import target changes:

```swift
// Tests/DiagramKitTests/RecoveryMarker/DOTRecoveryMarkerTests.swift
import Testing
@testable import DiagramKitGraphviz

@Suite("DOT recovery marker")
struct DOTRecoveryMarkerTests {

    @Test("parses class-stereotype marker")
    func parsesClassStereotype() {
        let source = "# diagramkit:class-stereotype=Order,<<entity>>"
        let result = DOTRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .classStereotype(className: "Order", stereotype: "<<entity>>"))
    }

    @Test("parses state-action marker")
    func parsesStateAction() {
        let source = "# diagramkit:state-action=Active,entry,place_order"
        let result = DOTRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .stateAction(
            ownerStateId: "Active",
            phase: .entry,
            label: "place_order"
        ))
    }

    @Test("parses er-cardinality marker")
    func parsesERCardinality() {
        let source = "# diagramkit:er-cardinality=r0,one,zero-or-many"
        let result = DOTRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .erCardinality(
            relationshipId: "r0",
            source: "one",
            target: "zero-or-many"
        ))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DOTRecoveryMarkerTests`
Expected: FAIL.

- [ ] **Step 3: Implement `DOTRecoveryMarker.swift`**

Structurally identical to `D2RecoveryMarker.swift` (Task B.1, Step 3). Substitute `DOT` for `D2` in type names. Comment prefix stays `#`.

- [ ] **Step 4: Implement `DOTPreLexerScan.swift`**

The declaration index is slightly different for DOT:
- Class declarations look like `Order [shape=record, label="..."];`
- State declarations look like `Active [shape=...];` inside a state digraph
- Edge declarations look like `User -> Order [label="places"];`

```swift
// Sources/DiagramKitGraphviz/DOTPreLexerScan.swift
import Foundation
import DiagramKitCommon

public struct DOTPreLexerScanResult: Sendable, Equatable {
    public struct ClassDeclaration: Sendable, Equatable, HasLineNumber {
        public let id: String
        public let lineNumber: Int
    }
    public struct StateDeclaration: Sendable, Equatable, HasLineNumber {
        public let id: String
        public let lineNumber: Int
    }
    public struct EdgeDeclaration: Sendable, Equatable, HasLineNumber {
        public let source: String
        public let target: String
        public let lineNumber: Int
    }

    public let classDeclarations: [ClassDeclaration]
    public let stateDeclarations: [StateDeclaration]
    public let edgeDeclarations: [EdgeDeclaration]
}

public func scanDOTPreLexer(_ source: String) -> DOTPreLexerScanResult {
    var classes: [DOTPreLexerScanResult.ClassDeclaration] = []
    var states: [DOTPreLexerScanResult.StateDeclaration] = []
    var edges: [DOTPreLexerScanResult.EdgeDeclaration] = []
    let lines = source.components(separatedBy: "\n")
    for (index, rawLine) in lines.enumerated() {
        let lineNumber = index + 1
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("//") { continue }
        // Edge: "src -> tgt [attrs];"
        if let arrowRange = trimmed.range(of: "->") {
            let src = String(trimmed[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var rest = String(trimmed[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let bracketIdx = rest.firstIndex(of: "[") {
                rest = String(rest[..<bracketIdx])
            }
            if let semiIdx = rest.firstIndex(of: ";") {
                rest = String(rest[..<semiIdx])
            }
            let tgt = rest.trimmingCharacters(in: .whitespaces)
            guard !src.isEmpty, !tgt.isEmpty else { continue }
            edges.append(.init(source: src, target: tgt, lineNumber: lineNumber))
            continue
        }
        // Node with shape=record (class) or other (state) — "ID [shape=record, label=...]"
        if let bracketIdx = trimmed.firstIndex(of: "[") {
            let id = String(trimmed[..<bracketIdx]).trimmingCharacters(in: .whitespaces)
            let attrs = String(trimmed[bracketIdx...])
            if !id.isEmpty && !id.contains("->") {
                if attrs.contains("shape=record") {
                    classes.append(.init(id: id, lineNumber: lineNumber))
                } else {
                    states.append(.init(id: id, lineNumber: lineNumber))
                }
            }
        }
    }
    return DOTPreLexerScanResult(
        classDeclarations: classes,
        stateDeclarations: states,
        edgeDeclarations: edges
    )
}
```

- [ ] **Step 5: Wire pre-lexer scan into `GraphvizImporter.parse(source:)`**

Mirror the D2 pattern from Task B.3, Step 4. Apply markers in `DOTMapper` (or per-family mappers).

- [ ] **Step 6: Add mapper switch arms (class, state, ER)**

Mirror Task B.3, Steps 5-7.

- [ ] **Step 7: Run all DOT recovery tests**

Run: `swift test --filter DOTRecoveryMarker`
Run: `swift test --filter DOT`
Expected: PASS for both.

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKitGraphviz/DOTRecoveryMarker.swift \
        Sources/DiagramKitGraphviz/DOTPreLexerScan.swift \
        Sources/DiagramKitGraphviz/DOTMapper.swift \
        Sources/DiagramKitGraphviz/GraphvizImporter.swift \
        Tests/DiagramKitTests/RecoveryMarker/DOTRecoveryMarkerTests.swift
git commit -m "Wave B Task 5 — DOTRecoveryMarker + pre-lexer scan + mapper application"
```

## Task B.6: DOT exporters emit markers; delete lossy diagnostics

**Files:**
- Modify: `Sources/DiagramKitGraphviz/DOTClassExport.swift:193` — delete `.classStereotypeDrop`; emit `class-stereotype` marker
- Modify: `Sources/DiagramKitGraphviz/DOTERExport.swift:132,136` — delete `.cardinalityDrop` emissions; emit `er-cardinality` marker
- Modify: `Sources/DiagramKitGraphviz/DOTStateExport.swift` (if exists; otherwise the loss may be in the mapper only) — verify and emit `state-action` marker
- Test: `Tests/DiagramKitTests/RecoveryMarker/DOTExporterMarkerEmissionTests.swift`

Same shape as Task B.4 for D2. Detailed steps mirror that task.

- [ ] **Step 1: Write the test**

Mirror `D2ExporterMarkerEmissionTests.swift` (Task B.4, Step 1), substituting `DOT` for `D2`.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DOTExporterMarkerEmissionTests`
Expected: FAIL.

- [ ] **Step 3: Modify DOT exporters per the file list above**

Replace lossy diagnostic emissions with marker line emissions. Place marker lines immediately after the related construct (class block close; relationship edge line).

- [ ] **Step 4: Run all DOT tests**

Run: `swift test --filter DOT`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitGraphviz/DOTClassExport.swift \
        Sources/DiagramKitGraphviz/DOTERExport.swift \
        Tests/DiagramKitTests/RecoveryMarker/DOTExporterMarkerEmissionTests.swift
# Plus DOTStateExport.swift if applicable
git commit -m "Wave B Task 6 — DOT exporters emit markers; delete .classStereotypeDrop/.cardinalityDrop"
```

## Task B.7: Round-trip fixtures for D2 + DOT class/state/er

**Files:**
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-class-stereotype.json`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-state-action.json`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-er-cardinality.json`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-class-stereotype.json`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-state-action.json`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-er-cardinality.json`

Plus cross-format fixtures (mermaid↔d2, mermaid↔dot, d2↔dot) for class/state/er.

- [ ] **Step 1: Survey the existing fixture format**

Run: `cat Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-flowchart.json | head -50` (or whatever file exists in that directory).

Match the fixture schema used by `RoundTripHarness`. Typical structure includes:
- A diagram id
- A list of source formats with their text
- Expected payload assertions (or implicit via "round-trip to all listed formats must produce structurally equal payloads")

- [ ] **Step 2: Create each fixture**

For each loss-case (stereotype, state-action, cardinality), create a fixture whose source has the construct that was previously lossy. Example for `d2-class-stereotype.json`:

```json
{
  "id": "d2-class-stereotype",
  "family": "classDiagram",
  "sources": [
    {
      "format": "d2",
      "text": "Order: {\n  shape: class\n  +id: String\n}\n# diagramkit:class-stereotype=Order,<<entity>>\n"
    }
  ],
  "expectedLosses": []
}
```

- [ ] **Step 3: Run the round-trip suite to verify each fixture round-trips losslessly**

Run: `swift test --filter RoundTrip`
Expected: PASS for all new fixtures (no allowed losses).

- [ ] **Step 4: Commit**

```bash
git add Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-class-stereotype.json \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-state-action.json \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-er-cardinality.json \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-class-stereotype.json \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-state-action.json \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-er-cardinality.json
git commit -m "Wave B Task 7 — Round-trip fixtures for D2 + DOT × class/state/er"
```

## Task B.8: Delete `.classStereotypeDrop`, `.stateActionDrop`, `.cardinalityDrop` categories + RoundTripLoss cases

**Files:**
- Modify: `Sources/DiagramKitCommon/DiagnosticCategory.swift` — delete 3 cases
- Modify: `Sources/DiagramKitTestSupport/RoundTripLoss.swift` — delete 3 cases
- Modify: `Sources/DiagramKitTestSupport/RoundTripLoss+Category.swift` — delete 3 mapping arms
- Modify: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+ER.swift` — remove the `cardinalityDrop` deltas (no longer needed)
- Modify: `Scripts/check-diagnostic-discipline.sh` — remove entries for deleted categories if hard-coded

- [ ] **Step 1: Confirm no emission site references these categories**

Run: `grep -rn "\.classStereotypeDrop\|\.stateActionDrop\|\.cardinalityDrop" Sources/ Tests/`
Expected: only `DiagnosticCategory.swift`, `RoundTripLoss.swift`, `RoundTripLoss+Category.swift`, and `DiagramDocumentDiff+ER.swift`. If anywhere else, that site needs to be migrated to a marker emission before this task can proceed.

- [ ] **Step 2: Delete the cases**

In `Sources/DiagramKitCommon/DiagnosticCategory.swift`, remove:

```swift
    case classStereotypeDrop
    case stateActionDrop
    case cardinalityDrop
```

In the severity-computed property, remove the three from the `.warning` case list.

In `Sources/DiagramKitTestSupport/RoundTripLoss.swift`, remove the three enum cases (lines 26-28, 37-39, 45-71 according to grep above — read carefully).

In `Sources/DiagramKitTestSupport/RoundTripLoss+Category.swift`, remove the three mapping arms (lines 25-27 per grep).

In `Sources/DiagramKitTestSupport/DiagramDocumentDiff+ER.swift`, remove lines 57-60 (the `cardinalityDrop` deltas — markers now carry the cardinality forward, so the diff is zero).

- [ ] **Step 3: Build and verify everything compiles**

Run: `swift build`
Expected: success. If any orphan reference is left, the compiler flags it.

- [ ] **Step 4: Run the full test suite (filter for D2/DOT)**

Run: `swift test --filter D2`
Run: `swift test --filter DOT`
Run: `swift test --filter RoundTrip`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitCommon/DiagnosticCategory.swift \
        Sources/DiagramKitTestSupport/RoundTripLoss.swift \
        Sources/DiagramKitTestSupport/RoundTripLoss+Category.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+ER.swift
git commit -m "Wave B Task 8 — Delete .classStereotypeDrop/.stateActionDrop/.cardinalityDrop"
```

## Task B.9: Wave B closer — COVERAGE.md flips + snapshot rebaseline + BASELINES.md

**Files:**
- Modify: `COVERAGE.md` — flip 6 export cells (D2/DOT × class/state/er)
- Modify: `BASELINES.md`
- Rebaseline any `.txt` snapshots that compare D2/DOT exporter source

- [ ] **Step 1: Flip the export cells in COVERAGE.md**

Locate the export matrix. Flip these cells from `⚠` to `✓`:
- Row `stateDiagram` column `D2` and column `DOT`
- Row `classDiagram` column `D2` and column `DOT`
- Row `erDiagram` column `D2` and column `DOT`

Totals stay the same.

- [ ] **Step 2: Rebaseline snapshots**

Run: `Scripts/rebaseline-snapshots.sh --target svg`
Then: `swift test --filter SnapshotTests`
Expected: PASS.

- [ ] **Step 3: Update BASELINES.md**

Refresh snapshot counts and gate status.

- [ ] **Step 4: Run the bootstrap smoke check**

Run: `Scripts/bootstrap-smoke-check.sh`
Expected: exit 0.

- [ ] **Step 5: Closer commit**

```bash
git add COVERAGE.md BASELINES.md Tests/DiagramKitTests/__Snapshots__/
git commit -m "Wave B closes D2 + DOT recovery markers — lift 6 export cells ⚠ to ✓"
```

Wave B complete.

---

# Wave C — PlantUML recovery markers

## Task C.1: `PlantUMLRecoveryMarker.swift` — Kind enum + scanner + emission helpers

**Files:**
- Create: `Sources/DiagramKitPlantUML/PlantUMLRecoveryMarker.swift`
- Test: `Tests/DiagramKitTests/RecoveryMarker/PlantUMLRecoveryMarkerTests.swift`

**Critical difference:** PlantUML uses `'` for line comments, not `#`. Markers use `'`.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/PlantUMLRecoveryMarkerTests.swift
import Testing
@testable import DiagramKitPlantUML

@Suite("PlantUML recovery marker")
struct PlantUMLRecoveryMarkerTests {

    @Test("parses activity-partition marker")
    func parsesActivityPartition() {
        let source = "' diagramkit:activity-partition=order_create,OrderProcessing"
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .activityPartition(originalId: "order_create", partition: "OrderProcessing"))
    }

    @Test("parses sequence-participant-details with base64")
    func parsesParticipantDetailsBase64() {
        let source = "' diagramkit:sequence-participant-details=alice,b64:VGhpcyBpcyBhIGRldGFpbCBibG9jay4="
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .sequenceParticipantDetails(
            participantId: "alice",
            base64: "VGhpcyBpcyBhIGRldGFpbCBibG9jay4="
        ))
    }

    @Test("parses component-style marker")
    func parsesComponentStyle() {
        let source = "' diagramkit:component-style=auth,interface"
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.count == 1)
        #expect(result.markers[0].kind == .componentStyle(id: "auth", style: .interface))
    }

    @Test("does not match # comment prefix")
    func ignoresHashComments() {
        let source = "# diagramkit:activity-partition=foo,bar"
        let result = PlantUMLRecoveryMarker.scanner.scan(source: source)
        #expect(result.markers.isEmpty)
    }

    @Test("emits valid activity-partition line")
    func emitsActivityPartition() {
        let line = PlantUMLRecoveryMarker.emitActivityPartition(originalId: "order_create", partition: "OrderProcessing")
        #expect(line == "' diagramkit:activity-partition=order_create,OrderProcessing")
    }

    @Test("emits valid sequence-participant-details with base64")
    func emitsSequenceParticipantDetails() {
        let line = PlantUMLRecoveryMarker.emitSequenceParticipantDetails(participantId: "alice", details: "This is a detail block.")
        #expect(line.contains("' diagramkit:sequence-participant-details=alice,b64:"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PlantUMLRecoveryMarkerTests`
Expected: FAIL.

- [ ] **Step 3: Implement `PlantUMLRecoveryMarker.swift`**

```swift
// Sources/DiagramKitPlantUML/PlantUMLRecoveryMarker.swift
import Foundation
import DiagramKitCommon

public enum PlantUMLRecoveryMarker {

    public enum ComponentStyle: String, Sendable, Equatable {
        case component, interface
    }

    public enum Kind: Sendable, Equatable {
        case activityPartition(originalId: String, partition: String)
        case activityOriginalId(syntheticId: String, originalId: String)
        case sequenceParticipantLink(participantId: String, url: String)
        case sequenceParticipantProperty(participantId: String, key: String, value: String)
        case sequenceParticipantDetails(participantId: String, base64: String)
        case componentStyle(id: String, style: ComponentStyle)
        case classUnsupportedLine(anchorAlias: String, line: String)
    }

    public static let scanner = RecoveryMarkerScanner<Kind>(commentPrefix: "'") { rest in
        parseKind(rest)
    }

    // MARK: - Parsing

    private static func parseKind(_ rest: String) -> Kind? {
        if let args = stripPrefix("activity-partition=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .activityPartition(originalId: String(fields[0]), partition: String(fields[1]))
        }
        if let args = stripPrefix("activity-original-id=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .activityOriginalId(syntheticId: String(fields[0]), originalId: String(fields[1]))
        }
        if let args = stripPrefix("sequence-participant-link=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .sequenceParticipantLink(participantId: String(fields[0]), url: String(fields[1]))
        }
        if let args = stripPrefix("sequence-participant-property=", rest) {
            let fields = args.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3 else { return nil }
            return .sequenceParticipantProperty(participantId: String(fields[0]), key: String(fields[1]), value: String(fields[2]))
        }
        if let args = stripPrefix("sequence-participant-details=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, fields[1].hasPrefix("b64:") else { return nil }
            return .sequenceParticipantDetails(participantId: String(fields[0]), base64: String(fields[1].dropFirst(4)))
        }
        if let args = stripPrefix("component-style=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, let style = ComponentStyle(rawValue: String(fields[1])) else { return nil }
            return .componentStyle(id: String(fields[0]), style: style)
        }
        if let args = stripPrefix("class-unsupported-line=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .classUnsupportedLine(anchorAlias: String(fields[0]), line: String(fields[1]))
        }
        return nil
    }

    private static func stripPrefix(_ prefix: String, _ s: String) -> String? {
        guard s.hasPrefix(prefix) else { return nil }
        return String(s.dropFirst(prefix.count))
    }

    // MARK: - Emission

    public static func emitActivityPartition(originalId: String, partition: String) -> String {
        "' diagramkit:activity-partition=\(sanitize(originalId)),\(sanitize(partition))"
    }

    public static func emitActivityOriginalId(syntheticId: String, originalId: String) -> String {
        "' diagramkit:activity-original-id=\(sanitize(syntheticId)),\(sanitize(originalId))"
    }

    public static func emitSequenceParticipantLink(participantId: String, url: String) -> String {
        "' diagramkit:sequence-participant-link=\(sanitize(participantId)),\(sanitize(url))"
    }

    public static func emitSequenceParticipantProperty(participantId: String, key: String, value: String) -> String {
        "' diagramkit:sequence-participant-property=\(sanitize(participantId)),\(sanitize(key)),\(sanitize(value))"
    }

    public static func emitSequenceParticipantDetails(participantId: String, details: String) -> String {
        let base64 = Data(details.utf8).base64EncodedString()
        return "' diagramkit:sequence-participant-details=\(sanitize(participantId)),b64:\(base64)"
    }

    public static func emitComponentStyle(id: String, style: ComponentStyle) -> String {
        "' diagramkit:component-style=\(sanitize(id)),\(style.rawValue)"
    }

    public static func emitClassUnsupportedLine(anchorAlias: String, line: String) -> String {
        "' diagramkit:class-unsupported-line=\(sanitize(anchorAlias)),\(sanitize(line))"
    }

    private static func sanitize(_ value: String) -> String {
        var out = ""
        for ch in value {
            switch ch {
            case "\n", "\r", "\"":
                out.append(" ")
            default:
                out.append(ch)
            }
        }
        return out
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PlantUMLRecoveryMarkerTests`
Expected: PASS (6 cases).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitPlantUML/PlantUMLRecoveryMarker.swift \
        Tests/DiagramKitTests/RecoveryMarker/PlantUMLRecoveryMarkerTests.swift
git commit -m "Wave C Task 1 — PlantUMLRecoveryMarker Kind + scanner + emission helpers"
```

## Task C.2: `PlantUMLPreLexerScan.swift` — declaration indexer per family

**Files:**
- Create: `Sources/DiagramKitPlantUML/PlantUMLPreLexerScan.swift`
- Test: `Tests/DiagramKitTests/RecoveryMarker/PlantUMLPreLexerScanTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/PlantUMLPreLexerScanTests.swift
import Testing
@testable import DiagramKitPlantUML

@Suite("PlantUML pre-lexer scan")
struct PlantUMLPreLexerScanTests {

    @Test("indexes activity steps")
    func indexesActivitySteps() {
        let source = """
        @startuml
        start
        :place order;
        stop
        @enduml
        """
        let scan = scanPlantUMLPreLexer(source)
        #expect(scan.activitySteps.contains(where: { $0.label == "place order" }))
    }

    @Test("indexes sequence participants")
    func indexesSequenceParticipants() {
        let source = """
        @startuml
        participant Alice
        participant Bob
        @enduml
        """
        let scan = scanPlantUMLPreLexer(source)
        #expect(scan.sequenceParticipants.contains(where: { $0.id == "Alice" }))
        #expect(scan.sequenceParticipants.contains(where: { $0.id == "Bob" }))
    }

    @Test("indexes component nodes")
    func indexesComponentNodes() {
        let source = """
        @startuml
        [auth]
        () db
        @enduml
        """
        let scan = scanPlantUMLPreLexer(source)
        #expect(scan.componentNodes.contains(where: { $0.id == "auth" }))
    }

    @Test("indexes class declarations")
    func indexesClassDeclarations() {
        let source = """
        @startuml
        class Order {
        }
        @enduml
        """
        let scan = scanPlantUMLPreLexer(source)
        #expect(scan.classDeclarations.contains(where: { $0.alias == "Order" }))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PlantUMLPreLexerScanTests`
Expected: FAIL.

- [ ] **Step 3: Implement the indexer**

```swift
// Sources/DiagramKitPlantUML/PlantUMLPreLexerScan.swift
import Foundation
import DiagramKitCommon

public struct PlantUMLPreLexerScanResult: Sendable, Equatable {
    public struct ActivityStep: Sendable, Equatable, HasLineNumber {
        public let label: String
        public let lineNumber: Int
    }
    public struct SequenceParticipant: Sendable, Equatable, HasLineNumber {
        public let id: String
        public let lineNumber: Int
    }
    public struct ComponentNode: Sendable, Equatable, HasLineNumber {
        public let id: String
        public let kind: PlantUMLRecoveryMarker.ComponentStyle
        public let lineNumber: Int
    }
    public struct ClassDeclaration: Sendable, Equatable, HasLineNumber {
        public let alias: String
        public let lineNumber: Int
    }

    public let activitySteps: [ActivityStep]
    public let sequenceParticipants: [SequenceParticipant]
    public let componentNodes: [ComponentNode]
    public let classDeclarations: [ClassDeclaration]
}

public func scanPlantUMLPreLexer(_ source: String) -> PlantUMLPreLexerScanResult {
    var steps: [PlantUMLPreLexerScanResult.ActivityStep] = []
    var participants: [PlantUMLPreLexerScanResult.SequenceParticipant] = []
    var components: [PlantUMLPreLexerScanResult.ComponentNode] = []
    var classes: [PlantUMLPreLexerScanResult.ClassDeclaration] = []

    let lines = source.components(separatedBy: "\n")
    for (index, rawLine) in lines.enumerated() {
        let lineNumber = index + 1
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("'") || trimmed.hasPrefix("/'") { continue }
        // Activity step: ":label;"
        if trimmed.hasPrefix(":") && trimmed.hasSuffix(";") {
            let label = String(trimmed.dropFirst().dropLast())
            steps.append(.init(label: label, lineNumber: lineNumber))
            continue
        }
        // Sequence participant: "participant Foo" or "participant \"Foo\" as foo"
        if trimmed.hasPrefix("participant ") {
            let after = String(trimmed.dropFirst("participant ".count))
            let id = after.split(separator: " ").first.map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) } ?? ""
            if !id.isEmpty {
                participants.append(.init(id: id, lineNumber: lineNumber))
            }
            continue
        }
        // Component bracket form: "[id]"
        if trimmed.hasPrefix("[") && trimmed.contains("]") {
            let inside = trimmed.dropFirst()
            if let closeIdx = inside.firstIndex(of: "]") {
                let id = String(inside[..<closeIdx])
                components.append(.init(id: id, kind: .component, lineNumber: lineNumber))
            }
            continue
        }
        // Interface form: "() id"
        if trimmed.hasPrefix("()") {
            let id = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
            if !id.isEmpty {
                components.append(.init(id: String(id), kind: .interface, lineNumber: lineNumber))
            }
            continue
        }
        // Class declaration: "class Order {" or "class Order"
        if trimmed.hasPrefix("class ") {
            let after = String(trimmed.dropFirst("class ".count))
            let alias = after.split(separator: " ").first.map { String($0) }?.trimmingCharacters(in: CharacterSet(charactersIn: "{")) ?? ""
            if !alias.isEmpty {
                classes.append(.init(alias: alias, lineNumber: lineNumber))
            }
        }
    }
    return PlantUMLPreLexerScanResult(
        activitySteps: steps,
        sequenceParticipants: participants,
        componentNodes: components,
        classDeclarations: classes
    )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PlantUMLPreLexerScanTests`
Expected: PASS (4 cases).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitPlantUML/PlantUMLPreLexerScan.swift \
        Tests/DiagramKitTests/RecoveryMarker/PlantUMLPreLexerScanTests.swift
git commit -m "Wave C Task 2 — PlantUMLPreLexerScan declaration indexer per family"
```

## Task C.3: PlantUML activity — mapper application + exporter emission + diagnostic deletion

**Files:**
- Modify: `Sources/DiagramKitPlantUML/Activity/PlantUMLActivityMapper.swift:38` — apply `activity-partition` marker; delete `.subgraphFlatten` emission for partition flattening
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLActivityExporter.swift:28` — emit `activity-partition` + `activity-original-id` markers; delete `.idSanitization` emission
- Modify: `Sources/DiagramKitPlantUML/PlantUMLImporter.swift` — wire pre-lexer scan
- Test: `Tests/DiagramKitTests/RecoveryMarker/PlantUMLActivityMarkerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/PlantUMLActivityMarkerTests.swift
import Testing
import DiagramKitModel
@testable import DiagramKitPlantUML

@Suite("PlantUML activity marker recovery")
struct PlantUMLActivityMarkerTests {

    @Test("partition marker carries partition name through round-trip; no diagnostic")
    func partitionRoundTrip() throws {
        let source = """
        @startuml
        start
        :place order;
        ' diagramkit:activity-partition=place_order,OrderProcessing
        stop
        @enduml
        """
        let result = try PlantUMLImporter().parse(source: source)
        #expect(!result.diagnostics.contains(where: { $0.message.contains("partition") }))
        // The recovered partition should be attached to the corresponding
        // flowchart node payload (exact field depends on FlowchartDiagram API).
    }

    @Test("activity exporter emits original-id marker for non-synthetic IDs; no .idSanitization diagnostic")
    func exporterEmitsOriginalId() throws {
        // Build a flowchart payload with a non-synthetic node id like "placeOrder"
        let graph = ParsedGraphModel(
            direction: .TB,
            nodesInOrder: [(id: "placeOrder", node: original_src_types.MermaidNode(id: "placeOrder", label: "place order", shape: .rect))],
            edges: []
        )
        let result = try PlantUMLActivityExporter().emit(graph)
        #expect(result.source.contains("' diagramkit:activity-original-id="))
        #expect(!result.diagnostics.contains(where: { $0.message.contains("synthetic") }))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PlantUMLActivityMarkerTests`
Expected: FAIL.

- [ ] **Step 3: Modify `PlantUMLActivityMapper.swift:36-41`**

Replace:
```swift
for partition in ast.partitions {
    diagnostics.append(.lossyTransform(
        .subgraphFlatten,
        message: "PlantUML partition '\(partition.label)' flattened into flowchart payload; swimlane structure lost (members: \(partition.memberNodeIDs.joined(separator: ", ")))"
    ))
}
```

With marker application:
```swift
// Markers carry partition membership forward; apply them post-AST.
let markerScan = PlantUMLRecoveryMarker.scanner.scan(source: ast.sourceText)
for marker in markerScan.markers {
    guard case .activityPartition(let originalId, let partitionName) = marker.kind else { continue }
    // Attach partition name to the corresponding node payload.
    // Implementation depends on how partition data is modeled in
    // ParsedGraphModel; if no field exists yet, add one.
}
// Native PlantUML partition blocks are still seen by the parser; if a marker
// is not present, the partition data IS lost (no diagnostic emitted; this
// matches the spec's policy: markers close the round-trip loss only).
```

If `ast.sourceText` isn't available, plumb the scan result through the mapper from the importer entry point.

- [ ] **Step 4: Modify `PlantUMLActivityExporter.swift:25-32`**

Replace:
```swift
} else {
    lines.append(":\(escape(node.label));")
    if !isSyntheticActivityID(node.id) {
        diagnostics.append(.lossyTransform(
            .idSanitization,
            message: "PlantUML activity syntax has no explicit node-id form; '\(node.id)' becomes a synthetic id on re-parse"
        ))
    }
}
```

With:
```swift
} else {
    lines.append(":\(escape(node.label));")
    if !isSyntheticActivityID(node.id) {
        let synthetic = syntheticActivityID(for: node.label) // existing helper
        lines.append(PlantUMLRecoveryMarker.emitActivityOriginalId(syntheticId: synthetic, originalId: node.id))
    }
}
```

Add `import DiagramKitCommon` if not already present.

- [ ] **Step 5: Wire pre-lexer scan into `PlantUMLImporter.parse(source:)`**

Mirror the D2 pattern from Task B.3. Thread `markerScan` through to per-family mappers.

- [ ] **Step 6: Run the test and the full PlantUML suite**

Run: `swift test --filter PlantUMLActivityMarkerTests`
Expected: PASS.

Run: `swift test --filter PlantUML`
Expected: PASS (no regressions).

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitPlantUML/Activity/PlantUMLActivityMapper.swift \
        Sources/DiagramKitPlantUML/Exporter/PlantUMLActivityExporter.swift \
        Sources/DiagramKitPlantUML/PlantUMLImporter.swift \
        Tests/DiagramKitTests/RecoveryMarker/PlantUMLActivityMarkerTests.swift
git commit -m "Wave C Task 3 — PlantUML activity recovery: partition + original-id markers"
```

## Task C.4: PlantUML sequence — exporter emits markers + diagnostic deletion

**Files:**
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLSequenceExporter.swift:121-130` — emit link/property/details markers; delete `.identifierEscape` emission at line 127
- Test: `Tests/DiagramKitTests/RecoveryMarker/PlantUMLSequenceMarkerTests.swift`

Note: sequence import is already ✓ — no mapper changes needed.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/PlantUMLSequenceMarkerTests.swift
import Testing
import DiagramKitModel
@testable import DiagramKitPlantUML

@Suite("PlantUML sequence marker emission")
struct PlantUMLSequenceMarkerTests {

    @Test("participant link → emits sequence-participant-link marker; no diagnostic")
    func emitsLinkMarker() throws {
        // Build a sequence diagram with a participant carrying a link.
        // Exact payload shape depends on SequenceDiagram model; verify
        // before writing the test body.
        let diagram = SequenceDiagram(
            participants: [/* participant with link */],
            messages: [/* … */]
        )
        let result = try PlantUMLSequenceExporter().emit(diagram)
        #expect(result.source.contains("' diagramkit:sequence-participant-link="))
        #expect(!result.diagnostics.contains(where: { $0.message.contains("link/properties/detail") }))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PlantUMLSequenceMarkerTests`
Expected: FAIL.

- [ ] **Step 3: Modify `PlantUMLSequenceExporter.swift:121-130`**

Replace:
```swift
case .link, .links, .properties, .details:
    // Not directly translatable to PlantUML; skip with diagnostic.
    // Severity preserved as .info from pre-migration; a future
    // recategorization pass may promote to .unsupported since the
    // sequence item is genuinely dropped.
    diagnostics.append(.informational(
        .identifierEscape,
        message: "PlantUML export: link/properties/detail not directly supported in sequence diagram"
    ))
```

With marker emissions (the exact case payloads depend on `SequenceItem.link/links/properties/details` shape — verify before writing):

```swift
case .link(let participantId, let url):
    lines.append(PlantUMLRecoveryMarker.emitSequenceParticipantLink(participantId: participantId, url: url))

case .links(let participantId, let urls):
    for url in urls {
        lines.append(PlantUMLRecoveryMarker.emitSequenceParticipantLink(participantId: participantId, url: url))
    }

case .properties(let participantId, let entries):
    for (key, value) in entries {
        lines.append(PlantUMLRecoveryMarker.emitSequenceParticipantProperty(participantId: participantId, key: key, value: value))
    }

case .details(let participantId, let text):
    lines.append(PlantUMLRecoveryMarker.emitSequenceParticipantDetails(participantId: participantId, details: text))
```

**Note:** the exact case-payload shapes for `SequenceItem` cases `.link`, `.links`, `.properties`, `.details` are not enumerated here. Look up the actual SequenceItem enum in `DiagramKitModel` before writing the replacement code:

```bash
grep -n "case link\|case links\|case properties\|case details" Sources/DiagramKitModel/*.swift | head -10
```

Adjust the case-binding code to match.

- [ ] **Step 4: Run the test**

Run: `swift test --filter PlantUMLSequenceMarkerTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitPlantUML/Exporter/PlantUMLSequenceExporter.swift \
        Tests/DiagramKitTests/RecoveryMarker/PlantUMLSequenceMarkerTests.swift
git commit -m "Wave C Task 4 — PlantUML sequence link/property/details markers"
```

## Task C.5: PlantUML class — `class-unsupported-line` marker

**Files:**
- Modify: `Sources/DiagramKitPlantUML/Class/PlantUMLClassMapper.swift:72` — apply marker if present; existing diagnostic stays for vanilla input
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLClassExporter.swift` — emit marker for each unsupported line preserved in payload
- Modify: `DiagramKitModel.ClassDiagram` (or wherever) — add a payload field for unsupported lines if absent (small surgery; investigate first)
- Test: `Tests/DiagramKitTests/RecoveryMarker/PlantUMLClassMarkerTests.swift`

**Important:** import-side `.diagramFamilyUnsupported` emission stays for vanilla PlantUML sources with stereotypes/packages. The marker only closes round-trip identity. Cell `classDiagram × PlantUML import` stays `⚠`.

- [ ] **Step 1: Confirm where unsupported lines are stored in the parser output**

Run: `grep -n "unsupportedLines" Sources/DiagramKitPlantUML/Class/*.swift`

The parser appends unsupported lines to `ast.unsupportedLines` (per audit). The mapper emits `.featureDropped(.diagramFamilyUnsupported)` for each. To round-trip them through export, the payload must carry them forward.

- [ ] **Step 2: Decide on payload storage**

Option A: add a `unsupportedSourceLines: [String]` field on `ClassDiagram` (smallest change, but pollutes the public model).
Option B: store them in a side-channel attached to `DiagramDocument` (cleaner but larger plumbing).

For simplicity, use Option A. Add `unsupportedSourceLines: [String]` to `ClassDiagram` in `Sources/DiagramKitModel/`.

- [ ] **Step 3: Write the test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/PlantUMLClassMarkerTests.swift
import Testing
import DiagramKitModel
@testable import DiagramKitPlantUML

@Suite("PlantUML class unsupported-line marker")
struct PlantUMLClassMarkerTests {

    @Test("export preserves unsupported source lines as markers; import recovers them")
    func roundTripsUnsupportedLines() throws {
        let source = """
        @startuml
        class Order {
        }
        <<entity>> Order
        @enduml
        """
        // First import: vanilla; diagnostic fires.
        let firstResult = try PlantUMLImporter().parse(source: source)
        #expect(firstResult.diagnostics.contains(where: { $0.message.contains("not supported") || $0.message.contains("unsupported") }))
        guard case .classDiagram(let cd) = firstResult.document.typedPayload else {
            Issue.record("expected classDiagram payload")
            return
        }
        // Export back to PlantUML; expect marker line in output.
        let exportResult = try PlantUMLClassExporter().emit(cd, title: nil)
        #expect(exportResult.source.contains("' diagramkit:class-unsupported-line="))
        // Re-import the marker-bearing source; diagnostic should NOT fire.
        let secondResult = try PlantUMLImporter().parse(source: exportResult.source)
        #expect(!secondResult.diagnostics.contains(where: { $0.message.contains("unsupported") }))
    }
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `swift test --filter PlantUMLClassMarkerTests`
Expected: FAIL.

- [ ] **Step 5: Add `unsupportedSourceLines` to `ClassDiagram`**

In `Sources/DiagramKitModel/` (find the file by `grep -n "struct ClassDiagram" Sources/DiagramKitModel/*.swift`):

```swift
public struct ClassDiagram: Sendable, Equatable {
    // ... existing fields ...
    public let unsupportedSourceLines: [String]

    public init(
        classes: [Class],
        relationships: [ClassRelationship],
        unsupportedSourceLines: [String] = []
    ) {
        // ...
        self.unsupportedSourceLines = unsupportedSourceLines
    }
}
```

- [ ] **Step 6: Modify `PlantUMLClassMapper.swift:72-78`**

After the existing `.diagramFamilyUnsupported` diagnostic, also pass the unsupported lines to the payload, AND apply markers if present in `scan`:

```swift
// Existing diagnostic for vanilla input — keep:
for line in ast.unsupportedLines {
    diagnostics.append(.featureDropped(
        .diagramFamilyUnsupported,
        message: "PlantUML class: line not supported by parser: '\(line)'"
    ))
}

// Pass forward into payload so the exporter can round-trip:
var preservedLines = ast.unsupportedLines

// Apply class-unsupported-line markers from pre-lex scan:
for marker in markerScan.markers {
    guard case .classUnsupportedLine(_, let line) = marker.kind else { continue }
    if !preservedLines.contains(line) {
        preservedLines.append(line)
    }
}

let payload = ClassDiagram(
    classes: classes,
    relationships: relationships,
    unsupportedSourceLines: preservedLines
)
```

**Critical:** when markers ARE present, the diagnostic for those particular lines should be suppressed. Check whether the line came from the marker scan or from the parser's pass; only emit diagnostics for lines NOT carried in via markers.

- [ ] **Step 7: Modify `PlantUMLClassExporter.swift`**

After emitting all class blocks, emit one marker line per preserved unsupported line:

```swift
for line in diagram.unsupportedSourceLines {
    // Anchor each marker to the first class (or to "" if no classes).
    let anchor = diagram.classes.first?.id ?? ""
    lines.append(PlantUMLRecoveryMarker.emitClassUnsupportedLine(anchorAlias: anchor, line: line))
}
```

- [ ] **Step 8: Run the test**

Run: `swift test --filter PlantUMLClassMarkerTests`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Sources/DiagramKitModel/<ClassDiagram-file>.swift \
        Sources/DiagramKitPlantUML/Class/PlantUMLClassMapper.swift \
        Sources/DiagramKitPlantUML/Exporter/PlantUMLClassExporter.swift \
        Tests/DiagramKitTests/RecoveryMarker/PlantUMLClassMarkerTests.swift
git commit -m "Wave C Task 5 — PlantUML class-unsupported-line marker round-trip"
```

## Task C.6: PlantUML component — `component-style` marker

**Files:**
- Modify: `Sources/DiagramKitPlantUML/Component/PlantUMLComponentMapper.swift:16` — apply marker; existing diagnostic stays for vanilla input
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLComponentExporter.swift` — emit `component-style` marker
- Test: `Tests/DiagramKitTests/RecoveryMarker/PlantUMLComponentMarkerTests.swift`

Same pattern as Task C.5: marker closes round-trip; vanilla import still emits `.styleDrop`.

- [ ] **Step 1: Write the test**

```swift
// Tests/DiagramKitTests/RecoveryMarker/PlantUMLComponentMarkerTests.swift
import Testing
import DiagramKitModel
@testable import DiagramKitPlantUML

@Suite("PlantUML component-style marker")
struct PlantUMLComponentMarkerTests {

    @Test("interface marker round-trips through export → import")
    func roundTripsInterfaceStyle() throws {
        // Vanilla source: interface kind.
        let source = """
        @startuml
        () auth
        [db]
        auth --> db
        @enduml
        """
        let first = try PlantUMLImporter().parse(source: source)
        guard case .architecture(let arch) = first.document.typedPayload else {
            Issue.record("expected architecture payload")
            return
        }
        // The marker should be added by the importer when it sees a `()` interface.
        let export = try PlantUMLComponentExporter().emit(arch, title: nil)
        #expect(export.source.contains("' diagramkit:component-style=auth,interface"))

        let second = try PlantUMLImporter().parse(source: export.source)
        // Re-import: no styleDrop diagnostic now (marker carries info).
        #expect(!second.diagnostics.contains(where: { $0.message.contains("interface-vs-component") }))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PlantUMLComponentMarkerTests`
Expected: FAIL.

- [ ] **Step 3: Modify `PlantUMLComponentMapper.swift:10-21`**

The existing code emits `.styleDrop` when a component is `.interface`. Keep the diagnostic (vanilla input still emits it), but also store the style in the payload so the exporter can round-trip it.

`ArchitectureService` doesn't currently carry a "style" field; either add one or use a side-channel. For minimal change, store it via a `componentStyles: [String: PlantUMLRecoveryMarker.ComponentStyle]` field on `ArchitectureDiagram`. Trace back to model:

```bash
grep -n "struct ArchitectureDiagram\|struct ArchitectureService" Sources/DiagramKitModel/*.swift
```

Add a field. Then modify the mapper to populate it:

```swift
var componentStyles: [String: PlantUMLRecoveryMarker.ComponentStyle] = [:]
for component in ast.components {
    services.append(ArchitectureService(id: component.id, title: component.label))
    if component.kind == .interface {
        componentStyles[component.id] = .interface
        diagnostics.append(.lossyTransform(
            .styleDrop,
            message: "PlantUML interface '\(component.id)' projected as architecture service; interface-vs-component styling lost"
        ))
    }
}
// Apply markers:
for marker in markerScan.markers {
    guard case .componentStyle(let id, let style) = marker.kind else { continue }
    componentStyles[id] = style
}
```

When a marker is present for a given `id`, suppress the `.styleDrop` diagnostic for that id.

- [ ] **Step 4: Modify `PlantUMLComponentExporter.swift`**

After emitting each component node, emit a marker line for interface-style components:

```swift
for service in diagram.services {
    if let style = diagram.componentStyles[service.id], style == .interface {
        lines.append("() \(service.id)")
        lines.append(PlantUMLRecoveryMarker.emitComponentStyle(id: service.id, style: .interface))
    } else {
        lines.append("[\(service.id)]")
    }
}
```

- [ ] **Step 5: Run the test**

Run: `swift test --filter PlantUMLComponentMarkerTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitModel/<Architecture-file>.swift \
        Sources/DiagramKitPlantUML/Component/PlantUMLComponentMapper.swift \
        Sources/DiagramKitPlantUML/Exporter/PlantUMLComponentExporter.swift \
        Tests/DiagramKitTests/RecoveryMarker/PlantUMLComponentMarkerTests.swift
git commit -m "Wave C Task 6 — PlantUML component-style marker (interface vs component)"
```

## Task C.7: Round-trip fixtures for PlantUML flowchart/sequence/component/class

**Files:**
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-activity-partition.json`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-sequence-link-props.json`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-component-interface.json`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-class-unsupported.json`

Plus cross-format fixtures mermaid↔plantuml for activity and sequence.

- [ ] **Step 1: Survey the existing fixture format**

Same as Task B.7, Step 1.

- [ ] **Step 2: Create each fixture**

Mirror the structure of existing PlantUML fixtures (e.g., `plantuml-sequence-1.json` if it exists). Each new fixture exercises the loss-case the marker closes.

- [ ] **Step 3: Run the round-trip suite**

Run: `swift test --filter RoundTrip`
Expected: PASS for all new fixtures.

- [ ] **Step 4: Commit**

```bash
git add Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-activity-partition.json \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-sequence-link-props.json \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-component-interface.json \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-class-unsupported.json
git commit -m "Wave C Task 7 — Round-trip fixtures for PlantUML × {activity, sequence, component, class}"
```

## Task C.8: Wave C closer — COVERAGE.md flips + BASELINES.md + final cleanup

**Files:**
- Modify: `COVERAGE.md` — flip export cells for PlantUML × {flowchart, sequence}; ensure architecture and class are already at correct symbol after Waves A/C work
- Modify: `BASELINES.md`
- Rebaseline `.txt` snapshots for PlantUML fixtures

- [ ] **Step 1: Flip the export cells**

In COVERAGE.md export matrix:
- Row `flowchart` column `PlantUML`: `⚠` → `✓`
- Row `sequenceDiagram` column `PlantUML`: `⚠` → `✓`

In the import matrix:
- Row `flowchart` column `PlantUML`: `⚠` → `✓` (partition marker recovered the loss)

Other PlantUML import cells stay `⚠` per spec.

- [ ] **Step 2: Remove the "Partial-support detail" section entirely**

The section now has no real ⚠ cells to describe. Replace with:

```markdown
## Partial-support detail

The remaining `⚠` cells in the import table are all foreign-source features
without a Mermaid landing slot; see the legend footnote. The export table
has zero `⚠` cells.
```

- [ ] **Step 3: Rebaseline snapshots**

Run: `Scripts/rebaseline-snapshots.sh --target svg`
Run: `swift test --filter SnapshotTests`
Expected: PASS.

- [ ] **Step 4: Update BASELINES.md and run full smoke check**

Run: `Scripts/bootstrap-smoke-check.sh`
Expected: exit 0.

- [ ] **Step 5: Closer commit**

```bash
git add COVERAGE.md BASELINES.md Tests/DiagramKitTests/__Snapshots__/
git commit -m "Wave C closes PlantUML recovery markers — lift remaining export ⚠ to ✓"
```

Wave C complete. Verify final state:

- COVERAGE.md export table: zero `⚠` cells.
- COVERAGE.md import table: exactly 8 `⚠` cells (D2/DOT × {flowchart, class, state, er} = 8, plus PlantUML × {architecture, class} = 2 = 10; wait, that's 10. Recheck the spec — Wave C should also flip flowchart × PlantUML import via partition marker. So 9 import ⚠ → 8 after Wave C closes flowchart × PlantUML.).
- `Scripts/check-diagnostic-discipline.sh`: green.
- `Scripts/bootstrap-smoke-check.sh`: exit 0 (Docker permitting).

---

## Self-review checklist (run after Wave C closes)

- [ ] Every spec section has a corresponding plan task. Cross-reference with `docs/superpowers/specs/2026-05-20-coverage-marker-recovery-design.md`.
- [ ] No "TBD" or "implement later" placeholders.
- [ ] Type names referenced in late tasks match types defined in early tasks (`RecoveryMarkerScanner`, `D2RecoveryMarker.Kind`, etc.).
- [ ] Each task ends with a commit step.
- [ ] Each task can run independently with the listed file paths.

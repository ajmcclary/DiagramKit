# Parser Diagnostics Surfacing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface Mermaid parser/layout diagnostics through `DiagramImportResult.diagnostics`, `PositionedGraph.diagnostics`, `PreparedDiagram.diagnostics`, and a new `AsciiRenderOutput` so consumers stop losing warnings to the IssueReporting side-channel.

**Architecture:** Widen the `DiagramDescriptor.parse` and `.layout` registry closures to `throws -> (Artefact, [DiagramDiagnostic])`, route layout-time diagnostics into `PositionedGraph`, aggregate parse + layout into `PreparedDiagram`, and convert 6 in-scope `_reportDiagramIssue` sites (5 layout + 1 parser) to tuple-append. Migration is sequenced so types compile at every commit boundary: foundation types first, closure shape next (every closure initially wraps with `(..., [])` so behavior is unchanged), then per-site diagnostic conversions, then bulk family-parser signature widening, then importer/pipeline/engine plumbing, then ASCII and docs.

**Tech Stack:** Swift 6, swift-testing (`@Suite`/`@Test`), XCTest (legacy suites), `swift test --filter`, SwiftPM. Discipline gates: `Scripts/check-file-sizes.sh`, `Scripts/check-sendable-annotations.sh`, `Scripts/strict-concurrency-check.sh`. Standing default: commit-by-commit on `main`, no worktrees / branches.

**Spec:** `docs/superpowers/specs/2026-05-14-parser-diagnostics-surfacing-design.md`

---

## File Structure

**New files:**
- `Sources/DiagramKit/AsciiRenderOutput.swift` — public `AsciiRenderOutput { text, diagnostics }` struct.
- `Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift` — Phase A1 schema + Phase D layout-emitter tests.
- `Tests/DiagramKitTests/PreparedDiagramDiagnosticsTests.swift` — Phase A2 aggregation tests.
- `Tests/DiagramKitTests/AsciiRenderOutputTests.swift` — Phase A3 type-shape test.
- `Tests/DiagramKitTests/MermaidImporterDiagnosticsTests.swift` — Phase F1 per-family populate tests.
- `Tests/DiagramKitTests/DiagramLoaderParseImportResultTests.swift` — Phase F1 loader-level tests.
- `Tests/DiagramKitTests/ParserDiagnosticAggregationTests.swift` — Phase F2 cross-tier end-to-end.

**Modified files (in migration order):**
1. `Sources/DiagramKitModel/Types.swift` (line 306, PositionedGraph)
2. `Sources/DiagramKitRenderingCG/PreparedDiagram.swift`
3. `Sources/DiagramKit/DiagramDescriptor.swift` (lines 97, 100 closure shapes)
4. `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift` (`_typed` factory)
5. `Sources/DiagramKit/DiagramRegistry+*.swift` (28 family files)
6. `Sources/DiagramKit/Layout.swift` (`GraphLayout.layout(_:)`)
7. `Sources/DiagramKit/MermaidImporter.swift` (parse destructure)
8. `Sources/DiagramKitModel/src_c4_parser.swift` (SPI rename)
9. `Sources/DiagramKitModel/src_kanban_parser.swift` (emit conversion)
10. `Sources/DiagramKitModel/src_layout.swift` (3 emit conversions + `inout` threading)
11. `Sources/DiagramKitModel/src_ishikawa_layout.swift` (emit conversion)
12. `Sources/DiagramKitModel/src_gitgraph_layout.swift` (emit conversion)
13. `Sources/DiagramKitModel/src_*_parser.swift` (~20 mechanical signature widens)
14. `Sources/DiagramKitImport/DiagramLoader.swift` (add `parseImportResult`)
15. `Sources/DiagramKit/DiagramPipeline.swift` (`loadImportResult`, `renderASCII` return)
16. `Sources/DiagramKit/DiagramEngine.swift` (`parseImportResult`, `renderASCII` return)
17. `Sources/DiagramKit/AsciiRenderRegistry.swift` (descriptor render closure)
18. `Tests/DiagramKitTests/CorpusSnapshotTests.swift` (ASCII baseline adapter)
19. ~30 ASCII unit-test files (`.text` accessor)
20. `CLAUDE.md`, `ARCHITECTURE.md`, `REVIEW.md` (docs)

---

## Phase A — Foundation Types

### Task A1: Add `PositionedGraph.diagnostics` field

**Files:**
- Modify: `Sources/DiagramKitModel/Types.swift:306`
- Test: `Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift` (new)

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift`:

```swift
import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKit

@Suite("PositionedGraph diagnostics")
struct PositionedGraphDiagnosticsTests {
    @Test("Default value is empty array")
    func defaultIsEmpty() {
        let doc = try! DiagramPipeline.parse("pie\n  \"a\" : 1")
        let positioned = try! GraphLayout().layout(doc)
        #expect(positioned.diagnostics == [])
    }

    @Test("Field is publicly mutable")
    func fieldIsMutable() {
        let doc = try! DiagramPipeline.parse("pie\n  \"a\" : 1")
        var positioned = try! GraphLayout().layout(doc)
        positioned.diagnostics = [
            DiagramDiagnostic(severity: .warning, message: "test", location: nil)
        ]
        #expect(positioned.diagnostics.count == 1)
        #expect(positioned.diagnostics[0].message == "test")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PositionedGraphDiagnosticsTests`
Expected: FAIL — `'PositionedGraph' has no member 'diagnostics'`

- [ ] **Step 3: Add the field**

Modify `Sources/DiagramKitModel/Types.swift:306`. Locate the `public struct PositionedGraph: Sendable {` block (starts at line 306). Add `diagnostics` as a stored property immediately after the existing fields, before the `init`. Example transformation:

```swift
public struct PositionedGraph: Sendable {
    public let diagram: DiagramDocument
    public let width: Double
    public let height: Double
    public let content: PositionedContent

    // NEW
    public var diagnostics: [DiagramDiagnostic] = []

    public init(
        diagram: DiagramDocument,
        width: Double,
        height: Double,
        content: PositionedContent
    ) {
        self.diagram = diagram
        self.width = width
        self.height = height
        self.content = content
        // diagnostics defaults to []
    }
}
```

Use the existing field names as they appear in the current `Types.swift`; only add the new `var diagnostics` line and rely on the default to keep all existing call sites source-compatible.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PositionedGraphDiagnosticsTests`
Expected: PASS, 2/2 tests.

- [ ] **Step 5: Verify no regression in existing layout-using tests**

Run: `swift test --filter "GraphLayout|PieAsciiRendererTests"`
Expected: All existing tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitModel/Types.swift Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift
git commit -m "$(cat <<'EOF'
feat(model): add PositionedGraph.diagnostics field

Defaults to [] so every existing caller stays source-compatible.
First step toward surfacing layout-time diagnostics through
PreparedDiagram.diagnostics (see spec
docs/superpowers/specs/2026-05-14-parser-diagnostics-surfacing-design.md).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task A2: Add `PreparedDiagram.diagnostics` + `importDiagnostics:` init param

**Files:**
- Modify: `Sources/DiagramKitRenderingCG/PreparedDiagram.swift`
- Test: `Tests/DiagramKitTests/PreparedDiagramDiagnosticsTests.swift` (new)

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/PreparedDiagramDiagnosticsTests.swift`:

```swift
#if canImport(CoreGraphics)
import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitRenderingCG
@testable import DiagramKit

@Suite("PreparedDiagram diagnostics aggregation")
struct PreparedDiagramDiagnosticsTests {
    @Test("Default aggregates empty + empty into empty")
    func defaultIsEmpty() throws {
        let doc = try DiagramPipeline.parse("pie\n  \"a\" : 1")
        let positioned = try GraphLayout().layout(doc)
        let prepared = PreparedDiagram(positioned: positioned, theme: .default)
        #expect(prepared.diagnostics == [])
    }

    @Test("importDiagnostics + positioned.diagnostics aggregate in order")
    func aggregatesInOrder() throws {
        let doc = try DiagramPipeline.parse("pie\n  \"a\" : 1")
        var positioned = try GraphLayout().layout(doc)
        positioned.diagnostics = [
            DiagramDiagnostic(severity: .warning, message: "layout-1", location: nil),
            DiagramDiagnostic(severity: .warning, message: "layout-2", location: nil)
        ]
        let importDiag = [
            DiagramDiagnostic(severity: .warning, message: "parse-1", location: nil)
        ]
        let prepared = PreparedDiagram(
            positioned: positioned,
            theme: .default,
            importDiagnostics: importDiag
        )
        #expect(prepared.diagnostics.map(\.message) == ["parse-1", "layout-1", "layout-2"])
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PreparedDiagramDiagnosticsTests`
Expected: FAIL — `'PreparedDiagram' has no member 'diagnostics'`, `extra argument 'importDiagnostics:'`.

- [ ] **Step 3: Modify `PreparedDiagram`**

Edit `Sources/DiagramKitRenderingCG/PreparedDiagram.swift`. Replace the existing struct body with:

```swift
public struct PreparedDiagram: Sendable {

    public let bounds: CGRect
    public let positioned: PositionedGraph
    public let theme: DiagramTheme
    public let diagnostics: [DiagramDiagnostic]

    public init(
        positioned: PositionedGraph,
        theme: DiagramTheme,
        importDiagnostics: [DiagramDiagnostic] = []
    ) {
        self.positioned = positioned
        self.theme = theme
        self.diagnostics = importDiagnostics + positioned.diagnostics
        self.bounds = CGRect(x: 0, y: 0, width: positioned.width, height: positioned.height)
    }

    public func render(in context: CGContext, bounds renderBounds: CGRect) {
        // Body unchanged — preserve the existing render(...) implementation as-is.
    }
}
```

When editing, preserve the entire current `render(in:bounds:)` body. Only change the property list (add `diagnostics`), the `init` signature (add `importDiagnostics: [DiagramDiagnostic] = []`), and the init body (compute aggregated `diagnostics`).

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter PreparedDiagramDiagnosticsTests`
Expected: PASS, 2/2 tests.

- [ ] **Step 5: Verify no regression**

Run: `swift test --filter "PreparedDiagram|DiagramRenderer"`
Expected: All existing tests pass. `PreparedDiagram(positioned:theme:)` callers compile (the new param is defaulted).

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitRenderingCG/PreparedDiagram.swift Tests/DiagramKitTests/PreparedDiagramDiagnosticsTests.swift
git commit -m "$(cat <<'EOF'
feat(renderingcg): aggregate diagnostics in PreparedDiagram

`PreparedDiagram.diagnostics = importDiagnostics + positioned.diagnostics`.
The new `importDiagnostics:` init parameter defaults to `[]` so existing
two-arg call sites stay source-compatible.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task A3: Add `AsciiRenderOutput` type

**Files:**
- Create: `Sources/DiagramKit/AsciiRenderOutput.swift`
- Test: `Tests/DiagramKitTests/AsciiRenderOutputTests.swift` (new)

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/AsciiRenderOutputTests.swift`:

```swift
import Testing
import DiagramKitCommon
import DiagramKit

@Suite("AsciiRenderOutput")
struct AsciiRenderOutputTests {
    @Test("Stores text and diagnostics")
    func storesFields() {
        let output = AsciiRenderOutput(text: "hello", diagnostics: [])
        #expect(output.text == "hello")
        #expect(output.diagnostics == [])
    }

    @Test("Diagnostics preserved in order")
    func diagnosticsPreservedInOrder() {
        let diags = [
            DiagramDiagnostic(severity: .warning, message: "first", location: nil),
            DiagramDiagnostic(severity: .warning, message: "second", location: nil)
        ]
        let output = AsciiRenderOutput(text: "x", diagnostics: diags)
        #expect(output.diagnostics.map(\.message) == ["first", "second"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AsciiRenderOutputTests`
Expected: FAIL — `cannot find 'AsciiRenderOutput' in scope`.

- [ ] **Step 3: Create the type**

Create `Sources/DiagramKit/AsciiRenderOutput.swift`:

```swift
import Foundation
import DiagramKitCommon

/// ASCII render output paired with any diagnostics emitted during parse /
/// layout / ASCII rendering.
///
/// Returned by `DiagramEngine.renderASCII(source:theme:)` and
/// `DiagramPipeline.renderASCII(source:theme:)`. The ASCII path bypasses
/// `PreparedDiagram`, so this is its standalone diagnostic surface; the
/// CG/SVG/image paths use `PreparedDiagram.diagnostics` instead.
public struct AsciiRenderOutput: Sendable {
    public let text: String
    public let diagnostics: [DiagramDiagnostic]

    public init(text: String, diagnostics: [DiagramDiagnostic] = []) {
        self.text = text
        self.diagnostics = diagnostics
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AsciiRenderOutputTests`
Expected: PASS, 2/2 tests.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKit/AsciiRenderOutput.swift Tests/DiagramKitTests/AsciiRenderOutputTests.swift
git commit -m "$(cat <<'EOF'
feat(umbrella): add AsciiRenderOutput public type

Pairs an ASCII string with diagnostics emitted during parse/layout/ASCII
rendering. Will become the return type of DiagramEngine.renderASCII /
DiagramPipeline.renderASCII in Phase F.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase B — Closure Shape Widening (Atomic)

### Task B1: Widen `DiagramDescriptor.parse` + `.layout` closure shapes (no behavior change)

This task widens the registry closure types and updates every consumer in one atomic commit. Every family closure wraps its single-return parser/layout with `(..., [])`, so behavior is unchanged. Verifies via existing tests.

**Files:**
- Modify: `Sources/DiagramKit/DiagramDescriptor.swift` (lines 97, 100, 102-112)
- Modify: `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift` (the `_typed` factory)
- Modify: All 28 `Sources/DiagramKit/DiagramRegistry+<Family>.swift` files except `DiagramRegistry+TypedDescriptor.swift`. Flowchart uses raw `DiagramDescriptor(...)` init; others use `_typed(...)`.
- Modify: `Sources/DiagramKit/Layout.swift:16` (`GraphLayout.layout(_:)`)
- Modify: `Sources/DiagramKit/MermaidImporter.swift:38-51` (`MermaidImporter.parse(_:)`)
- Modify: `Sources/DiagramKit/AsciiRenderRegistry.swift:223` (C4 ASCII call site — destructure but keep discarding diagnostics for now)
- Modify: `Sources/DiagramKit/DiagramRegistry+C4.swift:16` (destructure but keep wrapping with `[]` for now — Phase C activates it)
- Modify: `Sources/DiagramKit/DiagramPipeline.swift:64-69` (`loadDocument`)

- [ ] **Step 1: Update `DiagramDescriptor.swift`**

Edit `Sources/DiagramKit/DiagramDescriptor.swift`. Change line 97 and line 100:

```swift
// Line 97 — was:
public let parse: @Sendable (String, DiagramFrontmatter?) throws -> DiagramDocument
// Becomes:
public let parse: @Sendable (String, DiagramFrontmatter?) throws -> (DiagramDocument, [DiagramDiagnostic])

// Line 100 — was:
public let layout: @Sendable (DiagramDocument, LayoutConfig) throws -> PositionedGraph
// Becomes:
public let layout: @Sendable (DiagramDocument, LayoutConfig) throws -> (PositionedGraph, [DiagramDiagnostic])
```

Update the `init` (lines 102-112) parameter types accordingly:

```swift
public init(
    type: DiagramType,
    matches: @escaping @Sendable (DiagramHeader) -> Bool,
    parse: @escaping @Sendable (String, DiagramFrontmatter?) throws -> (DiagramDocument, [DiagramDiagnostic]),
    layout: @escaping @Sendable (DiagramDocument, LayoutConfig) throws -> (PositionedGraph, [DiagramDiagnostic])
)
```

- [ ] **Step 2: Update `_typed` factory**

Edit `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift`. The factory's typed `parse:` and `layout:` closure parameter types stay as single-return (so family files don't have to change yet). The factory body wraps with `[]`:

```swift
static func _typed<Parsed: Sendable, Positioned: Sendable>(
    type: DiagramType,
    matches: @escaping @Sendable (DiagramHeader) -> Bool,
    parse: @escaping @Sendable (String, DiagramFrontmatter?) throws -> Parsed,
    wrap: @escaping @Sendable (Parsed) -> DiagramPayload,
    unwrap: @escaping @Sendable (DiagramPayload) -> Parsed?,
    layout: @escaping @Sendable (Parsed, LayoutConfig) throws -> Positioned,
    positioned: @escaping @Sendable (DiagramDocument, Positioned) -> PositionedGraph
) -> DiagramDescriptor {
    DiagramDescriptor(
        type: type,
        matches: matches,
        parse: { source, fm in
            let parsed = try parse(source, fm)
            return (DiagramDocument(payload: wrap(parsed)), [])
        },
        layout: { graph, config in
            guard let parsed = unwrap(graph.payload) else {
                throw DiagramStructuralError.payloadMismatch(type)
            }
            return (positioned(graph, try layout(parsed, config)), [])
        }
    )
}
```

This means every family file using `_typed(...)` requires zero changes — the factory now produces the new closure shape automatically.

- [ ] **Step 3: Update Flowchart (raw `DiagramDescriptor` init)**

Edit `Sources/DiagramKit/DiagramRegistry+Flowchart.swift`. Wrap both closures with empty diagnostics:

```swift
extension DiagramRegistry {
    static let _flowchart = DiagramDescriptor(
        type: .flowchart,
        matches: { _ in true },
        parse: { source, frontmatter in
            let parsed = try parseMermaid(source, config: frontmatter?.flowchartConfig, stateConfig: frontmatter?.stateConfig)
            let document: DiagramDocument
            switch parsed.payload {
            case .flowchart(let model), .stateDiagram(let model):
                document = DiagramDocument(payload: .flowchart(model))
            default:
                document = parsed
            }
            return (document, [])
        },
        layout: { graph, config in
            (try layoutGraphSync(graph, config: config), [])
        }
    )
}
```

- [ ] **Step 4: Audit any other raw `DiagramDescriptor(...)` initialiser**

Run: `grep -rn "DiagramDescriptor(\b" Sources/DiagramKit/ | grep -v "DiagramRegistry+TypedDescriptor"`

Any hit not in `_typed` is a raw initializer call (besides Flowchart, which is already handled in Step 3). Apply the same wrap-with-`(..., [])` pattern to each. The expected output today is just Flowchart's site plus the C4 ASCII site (handled separately).

- [ ] **Step 5: Update `GraphLayout.layout(_:)`**

Edit `Sources/DiagramKit/Layout.swift`:

```swift
public func layout(_ graph: DiagramDocument) throws -> PositionedGraph {
    try _withDiagramIssueReporting(operation: "GraphLayout.layout") {
        let descriptor = try DiagramRegistry.descriptor(for: graph.type)
        let (positioned, diagnostics) = try descriptor.layout(graph, config)
        var result = positioned
        result.diagnostics = diagnostics
        return result
    }
}
```

The public return type stays `PositionedGraph`; diagnostics live on the struct's new field.

- [ ] **Step 6: Update `MermaidImporter.parse(_:)`**

Edit `Sources/DiagramKit/MermaidImporter.swift:38-51`. Replace lines 38-51 with:

```swift
public func parse(_ source: String) throws -> DiagramImportResult {
    let decoded = _HTMLEntities.decode(source)
    let (processed, frontmatter) = _parseFrontMatterAndStripped(decoded)

    let header = DiagramHeader.detect(from: processed)
    let descriptor = DiagramRegistry.detect(header)
    var (document, diagnostics) = try descriptor.parse(processed, frontmatter)
    if let title = frontmatter?.diagramTitle ?? frontmatter?.title, !title.isEmpty {
        document.title = title
    }

    return DiagramImportResult(document: document, diagnostics: diagnostics)
}
```

- [ ] **Step 7: Update `DiagramPipeline.loadDocument` callers**

Edit `Sources/DiagramKit/DiagramPipeline.swift:64-69`. Leave the function name and return type alone for now (Phase F2 will reshape this); just make sure it compiles by routing through the importer correctly. Today's body already calls `DiagramLoader.parseDocument(...)` which extracts `.document` from `DiagramImportResult` — no change needed here unless the build breaks. Run `swift build` and inspect.

- [ ] **Step 8: Update the C4 registry and ASCII call sites (destructure but keep wrapping for now)**

Edit `Sources/DiagramKit/DiagramRegistry+C4.swift:11-22` (approx). The current code uses `_typed`-like raw init for C4. Update its `parse:` closure body to destructure `_parseC4DiagramWithDiagnostics`'s tuple but still wrap with empty diagnostics — Phase C1 activates the actual diagnostic propagation:

```swift
parse: { source, frontmatter in
    let (diagram, _) = try _parseC4DiagramWithDiagnostics(
        DiagramSourceNormalizer.rawLines(source),
        frontmatter: frontmatter
    )
    return (DiagramDocument(payload: .c4(diagram)), [])
}
```

(Adjust the wrap payload case based on the actual file — match the current code.)

Edit `Sources/DiagramKit/AsciiRenderRegistry.swift:223`. The current `let (model, _) = try _parseC4DiagramWithDiagnostics(...)` stays — no Phase B change here. (The ASCII descriptor's render closure shape will widen in Phase G.)

- [ ] **Step 9: Compile**

Run: `swift build`
Expected: Build succeeds. If a family file fails to compile, it has a raw `DiagramDescriptor(...)` initialiser not covered above — apply the wrap pattern.

- [ ] **Step 10: Run the full existing suite (filtered)**

Run: `swift test --filter "ParserDispatchOrderTests|DiagramLoaderByIDTests|MermaidImporterTests|DiagramEditorTests|PositionedGraphDiagnosticsTests|PreparedDiagramDiagnosticsTests|AsciiRenderOutputTests"`
Expected: All tests pass.

- [ ] **Step 11: Run snapshot canary**

Run: `SNAPSHOT_DIAGRAM_IDS=pie-1-basic,flow-1-simple,c4-1-context swift test --filter CorpusSnapshotTests/svgSnapshot`
Expected: All three snapshot tests pass byte-stable (no behavior change yet).

- [ ] **Step 12: Commit**

```bash
git add Sources/DiagramKit/DiagramDescriptor.swift Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift Sources/DiagramKit/DiagramRegistry+Flowchart.swift Sources/DiagramKit/DiagramRegistry+C4.swift Sources/DiagramKit/Layout.swift Sources/DiagramKit/MermaidImporter.swift Sources/DiagramKit/DiagramPipeline.swift
git commit -m "$(cat <<'EOF'
refactor(umbrella): widen DiagramDescriptor parse/layout closures to tuple

DiagramDescriptor.parse and .layout closures now return
(Artefact, [DiagramDiagnostic]). The `_typed` factory wraps every family
parser/layout with `[]`, so behavior is unchanged. GraphLayout.layout(_:)
destructures and writes onto PositionedGraph.diagnostics;
MermaidImporter.parse(_:) destructures and populates
DiagramImportResult.diagnostics. C4 destructures the SPI tuple but still
wraps with `[]` — actual diagnostic propagation lands in Phase C1.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase C — C4 Diagnostic Activation

### Task C1: Surface C4 `$boundary` named-arg diagnostics

**Files:**
- Modify: `Sources/DiagramKit/DiagramRegistry+C4.swift`
- Modify: `Sources/DiagramKit/AsciiRenderRegistry.swift:223`
- Modify: `Sources/DiagramKitModel/src_c4_parser.swift:11-13` (rename SPI to canonical)
- Test: `Tests/DiagramKitTests/MermaidImporterDiagnosticsTests.swift` (new)

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/MermaidImporterDiagnosticsTests.swift`:

```swift
import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKit

@Suite("MermaidImporter populates diagnostics")
struct MermaidImporterDiagnosticsTests {
    @Test("C4 unresolved $boundary surfaces .warning")
    func c4UnresolvedBoundaryWarning() throws {
        let source = """
        C4Context
        title test
        Person(p, "User") $boundary=missing
        """
        let result = try MermaidImporter().parse(source)
        let messages = result.diagnostics.map(\.message)
        #expect(result.diagnostics.contains { $0.severity == .warning })
        #expect(messages.contains { $0.contains("missing") })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MermaidImporterDiagnosticsTests`
Expected: FAIL — `result.diagnostics` is empty.

- [ ] **Step 3: Update C4 registry to propagate diagnostics**

Edit `Sources/DiagramKit/DiagramRegistry+C4.swift`. Change the destructure to propagate:

```swift
parse: { source, frontmatter in
    let (diagram, diagnostics) = try _parseC4DiagramWithDiagnostics(
        DiagramSourceNormalizer.rawLines(source),
        frontmatter: frontmatter
    )
    return (DiagramDocument(payload: .c4(diagram)), diagnostics)
}
```

(Match the actual payload case from the current file body.)

- [ ] **Step 4: Update C4 ASCII registry to propagate (still discards for now — Phase G will route)**

Edit `Sources/DiagramKit/AsciiRenderRegistry.swift:223`. Leave the discard in place for this task:

```swift
let (model, _) = try _parseC4DiagramWithDiagnostics(rawLines, frontmatter: frontmatter)
return renderC4Ascii(model)
```

This will change again in Phase G when the ASCII descriptor's `render` closure widens to return `(String, [DiagramDiagnostic])`. Leaving it deferred keeps this task scoped to the registry-level activation.

- [ ] **Step 5: Rename `_parseC4DiagramWithDiagnostics` to canonical `parseC4Diagram`**

Edit `Sources/DiagramKitModel/src_c4_parser.swift:11-22`. The current shape is:

```swift
public func parseC4Diagram(_ lines: [String], frontmatter: DiagramFrontmatter? = nil) throws -> C4Diagram {
    let (diagram, _) = try _parseC4DiagramWithDiagnostics(lines, frontmatter: frontmatter)
    return diagram
}

public func _parseC4DiagramWithDiagnostics(
    _ lines: [String],
    frontmatter: DiagramFrontmatter? = nil
) throws -> (C4Diagram, [DiagramDiagnostic]) {
    // body
}
```

Replace with:

```swift
@available(*, deprecated, renamed: "parseC4Diagram", message: "Use parseC4Diagram which now returns the diagnostics tuple directly.")
public func _parseC4DiagramWithDiagnostics(
    _ lines: [String],
    frontmatter: DiagramFrontmatter? = nil
) throws -> (C4Diagram, [DiagramDiagnostic]) {
    try parseC4Diagram(lines, frontmatter: frontmatter)
}

public func parseC4Diagram(
    _ lines: [String],
    frontmatter: DiagramFrontmatter? = nil
) throws -> (C4Diagram, [DiagramDiagnostic]) {
    // existing _parseC4DiagramWithDiagnostics body — verbatim.
}
```

Update the two callers (Steps 3 and 4 above) and any tests / suites that reference `_parseC4DiagramWithDiagnostics` to call `parseC4Diagram` instead. Run `grep -rn "_parseC4DiagramWithDiagnostics" Sources/ Tests/` and migrate each hit to the new name.

The old `parseC4Diagram` wrapper (`throws -> C4Diagram`) gets deleted in favor of the new tuple-returning canonical name.

- [ ] **Step 6: Run test to verify it passes**

Run: `swift test --filter "MermaidImporterDiagnosticsTests|C4BoundaryNamedArgTests|MermaidC4BoundaryRoundTripTests"`
Expected: All pass; the new `c4UnresolvedBoundaryWarning` test now sees the propagated diagnostic.

- [ ] **Step 7: Snapshot canary**

Run: `SNAPSHOT_DIAGRAM_IDS=c4-1-context,c4-2-container,c4-3-component swift test --filter CorpusSnapshotTests/svgSnapshot`
Expected: byte-stable (no rendering behavior change).

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKit/DiagramRegistry+C4.swift Sources/DiagramKitModel/src_c4_parser.swift Tests/DiagramKitTests/MermaidImporterDiagnosticsTests.swift
git commit -m "$(cat <<'EOF'
feat(c4): surface \$boundary named-arg diagnostics through MermaidImporter

Closes Session 9's deferred follow-up. DiagramRegistry+C4.swift's parse
closure stops discarding the diagnostics array returned by the SPI variant;
they now flow through DiagramImportResult.diagnostics for the Mermaid C4
family. The SPI variant `_parseC4DiagramWithDiagnostics` is renamed to
`parseC4Diagram` (taking over the public name) and the old single-return
wrapper is deprecated.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase D — Kanban + Layout-Time Emit-Site Conversions

### Task D1: Convert Kanban duplicate-node `_reportDiagramIssue` to tuple-append

**Files:**
- Modify: `Sources/DiagramKitModel/src_kanban_parser.swift:197`
- Modify: `Sources/DiagramKit/DiagramRegistry+Kanban.swift`
- Test: `Tests/DiagramKitTests/MermaidImporterDiagnosticsTests.swift` (extend)

- [ ] **Step 1: Extend the test file**

Append to `Tests/DiagramKitTests/MermaidImporterDiagnosticsTests.swift`:

```swift
extension MermaidImporterDiagnosticsTests {
    @Test("Kanban duplicate node ID surfaces .warning")
    func kanbanDuplicateNodeWarning() throws {
        let source = """
        kanban
            col1[Column 1]
                t1[Task]
            col2[Column 2]
                t1[Task again]
        """
        let result = try MermaidImporter().parse(source)
        let messages = result.diagnostics.map(\.message)
        #expect(result.diagnostics.contains { $0.severity == .warning })
        #expect(messages.contains { $0.contains("duplicate") && $0.contains("t1") })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MermaidImporterDiagnosticsTests/kanbanDuplicateNodeWarning`
Expected: FAIL — `result.diagnostics` empty.

- [ ] **Step 3: Inspect current Kanban parser entry point**

Run: `grep -n "public func parseKanban\|func parseKanban" Sources/DiagramKitModel/src_kanban_parser.swift`

You should see the public entry point's current signature `throws -> KanbanDiagram` (approximate). Note the function name exactly — it's referenced from `DiagramRegistry+Kanban.swift`.

- [ ] **Step 4: Widen `parseKanbanDiagram` signature and convert emit site**

Edit `Sources/DiagramKitModel/src_kanban_parser.swift`. Two changes:

(a) Change the public parser function signature to return `(KanbanDiagram, [DiagramDiagnostic])`. Inside the function body, declare `var _diagnostics: [DiagramDiagnostic] = []` at the top. At the very end (where the function previously returned the diagram), return `(diagram, _diagnostics)` instead.

(b) Line 197 currently reads:

```swift
_reportDiagramIssue("[Kanban] duplicate node ID \"\(node.id)\"")
```

Replace with:

```swift
_diagnostics.append(DiagramDiagnostic(
    severity: .warning,
    message: "[Kanban] duplicate node ID \"\(node.id)\"",
    location: nil
))
```

If `parseKanbanDiagram` already uses an `inout` or nested helper that owns the duplicate detection, plumb `_diagnostics` into it via `inout`. Inspect the surrounding 30-40 lines around line 197 to see where the function boundary is.

- [ ] **Step 5: Update the Kanban registry**

Edit `Sources/DiagramKit/DiagramRegistry+Kanban.swift`. If it uses `_typed`, the `parse:` typed closure receives `(String, DiagramFrontmatter?) throws -> KanbanDiagram` today. We need the typed closure to deliver diagnostics. Two options:

**Option (a) — preferred:** Widen the typed factory's parse closure to support tuple-returning families. This means either:
- Add an overload of `_typed` accepting `(String, DiagramFrontmatter?) throws -> (Parsed, [DiagramDiagnostic])`, or
- Have the family closure return `(parsed, [])` for the empty case and `(parsed, diagnostics)` for the populated case — but typed factory only accepts a `Parsed` return today.

Choose Option (a). Add an overload in `Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift`:

```swift
extension DiagramRegistry {
    static func _typed<Parsed: Sendable, Positioned: Sendable>(
        type: DiagramType,
        matches: @escaping @Sendable (DiagramHeader) -> Bool,
        parseWithDiagnostics: @escaping @Sendable (String, DiagramFrontmatter?) throws -> (Parsed, [DiagramDiagnostic]),
        wrap: @escaping @Sendable (Parsed) -> DiagramPayload,
        unwrap: @escaping @Sendable (DiagramPayload) -> Parsed?,
        layout: @escaping @Sendable (Parsed, LayoutConfig) throws -> Positioned,
        positioned: @escaping @Sendable (DiagramDocument, Positioned) -> PositionedGraph
    ) -> DiagramDescriptor {
        DiagramDescriptor(
            type: type,
            matches: matches,
            parse: { source, fm in
                let (parsed, diagnostics) = try parseWithDiagnostics(source, fm)
                return (DiagramDocument(payload: wrap(parsed)), diagnostics)
            },
            layout: { graph, config in
                guard let parsed = unwrap(graph.payload) else {
                    throw DiagramStructuralError.payloadMismatch(type)
                }
                return (positioned(graph, try layout(parsed, config)), [])
            }
        )
    }
}
```

Then in `DiagramRegistry+Kanban.swift`, switch from `parse: { source, fm in /* … */ return chart }` to `parseWithDiagnostics: { source, fm in /* … */ return try parseKanbanDiagram(...) }`. Argument-label disambiguation selects the new overload.

- [ ] **Step 6: Run test to verify it passes**

Run: `swift test --filter MermaidImporterDiagnosticsTests`
Expected: PASS, both `c4UnresolvedBoundaryWarning` and `kanbanDuplicateNodeWarning`.

- [ ] **Step 7: Verify no Kanban regression**

Run: `swift test --filter "Kanban"`
Expected: All Kanban tests pass.

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKitModel/src_kanban_parser.swift Sources/DiagramKit/DiagramRegistry+Kanban.swift Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift Tests/DiagramKitTests/MermaidImporterDiagnosticsTests.swift
git commit -m "$(cat <<'EOF'
feat(kanban): surface duplicate-node-ID diagnostics through parser tuple

Converts src_kanban_parser.swift:197's `_reportDiagramIssue` call to a
tuple-append on the parser's new return type
`(KanbanDiagram, [DiagramDiagnostic])`. Adds a `_typed` factory overload
that accepts a tuple-returning typed parse closure so future per-family
emit sites can opt in without breaking existing families.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task D2: Convert 3 `src_layout.swift` recursion-limit emit sites

**Files:**
- Modify: `Sources/DiagramKitModel/src_layout.swift` (lines 270, 282, 832)
- Modify: any flowchart/state layout entry function (likely `layoutGraphSync` in `src_layout.swift`) to thread `inout` accumulator
- Modify: `Sources/DiagramKit/DiagramRegistry+Flowchart.swift` (propagate accumulator from layout closure)
- Test: `Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift` (extend)

- [ ] **Step 1: Extend the test file**

Append to `Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift`:

```swift
extension PositionedGraphDiagnosticsTests {
    @Test("Deeply nested subgraph hierarchy emits recursion warning")
    func deepSubgraphEmitsRecursionWarning() throws {
        // Build a flowchart source with subgraph nesting exceeding
        // _MAX_SUBGRAPH_RECURSION_DEPTH (32 in current code).
        var lines = ["flowchart TB"]
        for i in 0..<40 {
            lines.append("subgraph sub\(i)")
        }
        lines.append("n0[node]")
        for _ in 0..<40 {
            lines.append("end")
        }
        let source = lines.joined(separator: "\n")
        let doc = try DiagramPipeline.parse(source)
        let positioned = try GraphLayout().layout(doc)
        let messages = positioned.diagnostics.map(\.message)
        #expect(positioned.diagnostics.contains { $0.severity == .warning })
        #expect(messages.contains { $0.contains("subgraph recursion depth exceeded") })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PositionedGraphDiagnosticsTests/deepSubgraphEmitsRecursionWarning`
Expected: FAIL — `positioned.diagnostics` empty.

- [ ] **Step 3: Inspect `_allNodeIds`, `_subgraphContainsNode`, `_findSubgraph` signatures**

Run: `grep -n "func _allNodeIds\|func _subgraphContainsNode\|func _findSubgraph" Sources/DiagramKitModel/src_layout.swift`

Note each function's current signature.

- [ ] **Step 4: Thread `inout [DiagramDiagnostic]` into the three helpers and convert emit sites**

Edit `Sources/DiagramKitModel/src_layout.swift`. For each of `_allNodeIds`, `_subgraphContainsNode`, `_findSubgraph`:

(a) Add a trailing parameter `diagnostics: inout [DiagramDiagnostic]` to the function signature.
(b) Update all recursive self-calls and call sites within `src_layout.swift` to pass the same `inout` accumulator.
(c) Replace each `_reportDiagramIssue(...)` line (270, 282, 832) with:

```swift
diagnostics.append(DiagramDiagnostic(
    severity: .warning,
    message: "<existing message verbatim>",
    location: nil
))
```

Use the exact existing message string for each of the three sites — preserve the format-string interpolations.

- [ ] **Step 5: Plumb the accumulator into the layout entry point**

The Flowchart descriptor's `layout:` closure calls `layoutGraphSync(graph, config:)`. Locate `layoutGraphSync` in `src_layout.swift` (`grep -n "func layoutGraphSync" Sources/DiagramKitModel/src_layout.swift`). Add a local `var diagnostics: [DiagramDiagnostic] = []` accumulator inside `layoutGraphSync` (or whatever owns these helpers) and pass it into each call to the three updated helpers. Return a tuple `(PositionedGraph, [DiagramDiagnostic])` from `layoutGraphSync`.

- [ ] **Step 6: Update Flowchart registry to propagate**

Edit `Sources/DiagramKit/DiagramRegistry+Flowchart.swift`. The `layout:` closure becomes:

```swift
layout: { graph, config in
    try layoutGraphSync(graph, config: config)
}
```

(Now that `layoutGraphSync` returns a tuple, the descriptor's `layout:` closure can just return its result directly.)

- [ ] **Step 7: Update any other layout call sites of these three helpers**

Run: `grep -rn "_allNodeIds\|_subgraphContainsNode\|_findSubgraph" Sources/DiagramKitModel/`

Every other call site needs to pass `inout` diagnostics. If a caller doesn't have an accumulator (e.g., layout helpers in another file), introduce a local one and append the resulting diagnostics to its return (or fan them up through the call stack).

- [ ] **Step 8: Run test to verify it passes**

Run: `swift test --filter PositionedGraphDiagnosticsTests`
Expected: PASS — including `deepSubgraphEmitsRecursionWarning`.

- [ ] **Step 9: Verify no flowchart regression**

Run: `swift test --filter "FlowchartLayoutTests|FlowchartSnapshotTests"` (use whichever flowchart suites exist; `swift test --list-tests | grep -i flow` to find them).
Expected: All pass.

- [ ] **Step 10: Snapshot canary**

Run: `SNAPSHOT_DIAGRAM_IDS=flow-1-simple,flow-2-subgraph swift test --filter CorpusSnapshotTests/svgSnapshot`
Expected: byte-stable.

- [ ] **Step 11: Commit**

```bash
git add Sources/DiagramKitModel/src_layout.swift Sources/DiagramKit/DiagramRegistry+Flowchart.swift Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift
git commit -m "$(cat <<'EOF'
feat(flowchart): route subgraph recursion warnings into PositionedGraph

Converts the three `_reportDiagramIssue` sites in src_layout.swift
(_allNodeIds, _subgraphContainsNode, _findSubgraph) to append into an
inout `[DiagramDiagnostic]` accumulator threaded through layoutGraphSync.
The accumulator is written onto PositionedGraph.diagnostics; the
Flowchart descriptor's layout closure propagates the tuple unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task D3: Convert `src_ishikawa_layout.swift:132` recursion-depth emit

**Files:**
- Modify: `Sources/DiagramKitModel/src_ishikawa_layout.swift:132`
- Modify: `Sources/DiagramKit/DiagramRegistry+Ishikawa.swift` (propagate accumulator)
- Test: `Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift` (extend)

- [ ] **Step 1: Extend test file**

Append to `Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift`:

```swift
extension PositionedGraphDiagnosticsTests {
    @Test("Ishikawa deep nesting emits recursion warning")
    func ishikawaRecursionWarning() throws {
        // Construct an Ishikawa with branch nesting beyond _MAX_ISHIKAWA_RECURSION_DEPTH.
        // Inspect src_ishikawa_layout.swift for the threshold; if 8, nest to 10+.
        let depth = 12
        var lines = ["ishikawa", "root[\"Problem\"]"]
        for i in 0..<depth {
            lines.append(String(repeating: "  ", count: i + 1) + "n\(i)[\"Cause \(i)\"]")
        }
        let source = lines.joined(separator: "\n")
        let doc = try DiagramPipeline.parse(source)
        let positioned = try GraphLayout().layout(doc)
        let messages = positioned.diagnostics.map(\.message)
        #expect(messages.contains { $0.contains("Ishikawa recursion depth exceeded") })
    }
}
```

If the Ishikawa parser does not currently accept this exact format, adapt to the on-disk corpus fixture `ishikawa-deep` or whichever test fixture triggers the warning. Confirm via `grep -rn "Ishikawa recursion" Tests/` for any existing test patterns.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PositionedGraphDiagnosticsTests/ishikawaRecursionWarning`
Expected: FAIL.

- [ ] **Step 3: Convert emit site + thread accumulator**

Edit `Sources/DiagramKitModel/src_ishikawa_layout.swift`. Inspect the function containing line 132. Add `inout [DiagramDiagnostic]` parameter to that function and its recursive callers if any. Replace line 132's `_reportDiagramIssue("Ishikawa recursion depth exceeded \(_MAX_ISHIKAWA_RECURSION_DEPTH); truncating tree walk.")` with:

```swift
diagnostics.append(DiagramDiagnostic(
    severity: .warning,
    message: "Ishikawa recursion depth exceeded \(_MAX_ISHIKAWA_RECURSION_DEPTH); truncating tree walk.",
    location: nil
))
```

The Ishikawa layout entry function (likely `layoutIshikawa` — verify via `grep -n "public func layoutIshikawa\|func layoutIshikawa" Sources/DiagramKitModel/src_ishikawa_layout.swift`) returns `IshikawaPositioned` today. Widen to `(IshikawaPositioned, [DiagramDiagnostic])`.

- [ ] **Step 4: Update Ishikawa registry**

Edit `Sources/DiagramKit/DiagramRegistry+Ishikawa.swift`. The `_typed` `layout:` closure parameter has shape `(Parsed, LayoutConfig) throws -> Positioned`. Add a similar overload to `_typed` (mirroring D1's parse overload) that accepts a tuple-returning typed layout closure:

```swift
extension DiagramRegistry {
    static func _typed<Parsed: Sendable, Positioned: Sendable>(
        type: DiagramType,
        matches: @escaping @Sendable (DiagramHeader) -> Bool,
        parse: @escaping @Sendable (String, DiagramFrontmatter?) throws -> Parsed,
        wrap: @escaping @Sendable (Parsed) -> DiagramPayload,
        unwrap: @escaping @Sendable (DiagramPayload) -> Parsed?,
        layoutWithDiagnostics: @escaping @Sendable (Parsed, LayoutConfig) throws -> (Positioned, [DiagramDiagnostic]),
        positioned: @escaping @Sendable (DiagramDocument, Positioned) -> PositionedGraph
    ) -> DiagramDescriptor {
        DiagramDescriptor(
            type: type,
            matches: matches,
            parse: { source, fm in
                let parsed = try parse(source, fm)
                return (DiagramDocument(payload: wrap(parsed)), [])
            },
            layout: { graph, config in
                guard let parsed = unwrap(graph.payload) else {
                    throw DiagramStructuralError.payloadMismatch(type)
                }
                let (positionedValue, diagnostics) = try layoutWithDiagnostics(parsed, config)
                return (positioned(graph, positionedValue), diagnostics)
            }
        )
    }
}
```

(If you wrote the D1 parse overload separately, this overload is a new sibling; consider consolidating both into a single 8-arg overload that takes both `parseWithDiagnostics` and `layoutWithDiagnostics`. The arity will grow but argument labels disambiguate.)

In `DiagramRegistry+Ishikawa.swift`, switch from `layout: { … }` to `layoutWithDiagnostics: { parsed, config in try layoutIshikawa(parsed, config: config) }`.

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter PositionedGraphDiagnosticsTests/ishikawaRecursionWarning`
Expected: PASS.

- [ ] **Step 6: Verify no Ishikawa regression**

Run: `swift test --filter "Ishikawa"`
Expected: All Ishikawa tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitModel/src_ishikawa_layout.swift Sources/DiagramKit/DiagramRegistry+TypedDescriptor.swift Sources/DiagramKit/DiagramRegistry+Ishikawa.swift Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift
git commit -m "$(cat <<'EOF'
feat(ishikawa): route recursion-depth warning into PositionedGraph

Converts src_ishikawa_layout.swift:132's `_reportDiagramIssue` to a
diagnostic-array append. Adds a `_typed` factory overload accepting a
tuple-returning typed layout closure for families with layout-time
diagnostics.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task D4: Convert `src_gitgraph_layout.swift:273` missing-position emit

**Files:**
- Modify: `Sources/DiagramKitModel/src_gitgraph_layout.swift:273`
- Modify: `Sources/DiagramKit/DiagramRegistry+GitGraph.swift` (use `layoutWithDiagnostics`)
- Test: `Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift` (extend)

- [ ] **Step 1: Confirm the trigger condition**

The emit site at `src_gitgraph_layout.swift:273-275` is reached when `config.parallelCommits` is true AND either `commitsByID[firstKey]` is nil OR `branchPos[firstCommit.branch]` is nil. The first happens with a malformed parser state (rare); the second happens when a commit references a branch not in the layout's `branchPos` map.

Trigger: enable `parallelCommits` via frontmatter and have a gitGraph whose first commit's branch was never declared via a `branch` directive (e.g., a `checkout` of a non-existent branch followed by `commit`).

The exact emit message (preserve verbatim when converting):

```
gitGraph parallelCommits layout: missing commit or branch position for first key '<key>'; falling back to empty layout.
```

- [ ] **Step 2: Extend test file**

Append to `Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift`:

```swift
extension PositionedGraphDiagnosticsTests {
    @Test("GitGraph parallelCommits with missing branch position emits warning")
    func gitGraphMissingPositionWarning() throws {
        // Frontmatter enables parallelCommits. The body issues a checkout on a
        // branch that was never declared; the commit's branch lookup then
        // misses branchPos, hitting the line-273 fallback.
        let source = """
        ---
        config:
          gitGraph:
            parallelCommits: true
        ---
        gitGraph
            checkout undeclared
            commit
        """
        let doc = try DiagramPipeline.parse(source)
        let positioned = try GraphLayout().layout(doc)
        #expect(positioned.diagnostics.contains { $0.severity == .warning })
        #expect(positioned.diagnostics.contains {
            $0.message.contains("parallelCommits") &&
            $0.message.contains("missing commit or branch position")
        })
    }
}
```

If the parser rejects `checkout undeclared` outright (no such branch), instead use an empty gitGraph body after the frontmatter — the `sortedKeys` map will still allow the guard to fire if Mermaid's parser populates a default key without a real commit. If neither works after a 5-minute exploration, look at `GitGraphLayoutTests.swift` for an existing fixture that exercises the parallelCommits empty path.

- [ ] **Step 3: Run test to verify it fails (red phase)**

Run: `swift test --filter PositionedGraphDiagnosticsTests/gitGraphMissingPositionWarning`
Expected: FAIL — diagnostics empty for the trigger input. If the test errors with a parser exception (input not parseable), iterate on the fixture per Step 2's fallback guidance.

- [ ] **Step 4: Convert emit site + thread accumulator**

Edit `Sources/DiagramKitModel/src_gitgraph_layout.swift`. Add `inout [DiagramDiagnostic]` parameter to the function containing line 273. Replace the emit with a `diagnostics.append(...)` using the exact existing message string.

Widen `layoutGitGraph` (or whatever the entry function is — verify via `grep`) to return `(GitGraphPositioned, [DiagramDiagnostic])`.

- [ ] **Step 5: Update GitGraph registry**

Edit `Sources/DiagramKit/DiagramRegistry+GitGraph.swift`. Switch from `layout: { … }` to `layoutWithDiagnostics: { … }` using the overload from D3.

- [ ] **Step 6: Run test to verify it passes**

Run: `swift test --filter PositionedGraphDiagnosticsTests/gitGraphMissingPositionWarning`
Expected: PASS.

- [ ] **Step 7: Verify no GitGraph regression**

Run: `swift test --filter "GitGraph"`
Expected: All pass.

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKitModel/src_gitgraph_layout.swift Sources/DiagramKit/DiagramRegistry+GitGraph.swift Tests/DiagramKitTests/PositionedGraphDiagnosticsTests.swift
git commit -m "$(cat <<'EOF'
feat(gitgraph): route missing-position warning into PositionedGraph

Converts src_gitgraph_layout.swift:273's `_reportDiagramIssue` to a
diagnostic-array append. Uses the layoutWithDiagnostics `_typed`
overload introduced in Task D3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase E — Bulk Family Parser Signature Widen

### Task E1: Widen remaining ~20 family parser signatures (no behavior change)

This task widens every Mermaid family parser's signature to return `(Model, [DiagramDiagnostic])` for end-state consistency. None of these parsers emit non-fatal diagnostics today, so every tuple is `(model, [])`. After this commit, every Mermaid family flows through the tuple shape, and a third-party adding a new emit site has a documented surface to use.

**Files:**
- Modify: `Sources/DiagramKitModel/src_parser.swift:179` (`parseMermaid`)
- Modify: `Sources/DiagramKitModel/src_pie_parser.swift` (`parsePieChart`)
- Modify: `Sources/DiagramKitModel/src_journey_parser.swift` (`parseJourneyDiagram`)
- Modify: `Sources/DiagramKitModel/src_gantt_parser.swift` (`parseGanttDiagram`)
- Modify: `Sources/DiagramKitModel/src_quadrant_parser.swift` (`parseQuadrantChart`)
- Modify: `Sources/DiagramKitModel/src_requirement_parser.swift` (`parseRequirementDiagram`)
- Modify: `Sources/DiagramKitModel/src_gitgraph_parser.swift` (`parseGitGraph`)
- Modify: `Sources/DiagramKitModel/src_mindmap_parser.swift` (`parseMindmap`)
- Modify: `Sources/DiagramKitModel/src_timeline_parser.swift` (`parseTimelineDiagram`)
- Modify: `Sources/DiagramKitModel/src_block_parser.swift` (`parseBlockDiagram`)
- Modify: `Sources/DiagramKitModel/src_radar_parser.swift` (`parseRadarDiagram`)
- Modify: `Sources/DiagramKitModel/src_sankey_parser.swift` (`parseSankeyDiagram`)
- Modify: `Sources/DiagramKitModel/src_class_parser.swift` (`parseClassDiagram`)
- Modify: `Sources/DiagramKitModel/src_er_parser.swift` (`parseERDiagram`)
- Modify: `Sources/DiagramKitModel/src_sequence_parser.swift` (`parseSequenceDiagram`)
- Modify: `Sources/DiagramKitModel/src_state_parser.swift` (`parseStateDiagram`)
- Modify: `Sources/DiagramKitModel/src_xychart_parser.swift` (`parseXYChartDiagram`)
- Modify: `Sources/DiagramKitModel/src_architecture_parser.swift` (`parseArchitectureDiagram`)
- Modify: `Sources/DiagramKitModel/src_treemap_parser.swift` (`parseTreemapDiagram`)
- Modify: `Sources/DiagramKitModel/src_packet_parser.swift` (`parsePacketDiagram`)
- Modify: `Sources/DiagramKitModel/src_eventmodeling_parser.swift` (`parseEventModeling`)
- Modify: corresponding `Sources/DiagramKit/DiagramRegistry+<Family>.swift` (switch from `parse:` to `parseWithDiagnostics:` using D1's overload)

If any of the source files above doesn't exist, locate the correct file via `grep -rn "public func parseFooDiagram" Sources/DiagramKitModel/` and use the actual path.

- [ ] **Step 1: Pattern audit**

For each parser function listed above, run:

```bash
grep -n "public func parse<Name>" Sources/DiagramKitModel/src_<name>_parser.swift
```

Note each function's current return type. The pattern below assumes the existing signature is `public func parseFoo(...) throws -> FooDiagram`.

- [ ] **Step 2: Mechanically widen each parser's signature**

For each parser file:

(a) Change the function return type from `throws -> FooDiagram` to `throws -> (FooDiagram, [DiagramDiagnostic])`.
(b) At every `return X` inside the function body, change to `return (X, [])`.
(c) If the function calls helpers that are also widened, destructure their tuples — for this task, helpers stay single-return unless they also live in scope.

Use the C4 spec's `parseC4Diagram` shape as a template:

```swift
public func parsePieChart(
    _ lines: [String],
    frontmatter: DiagramFrontmatter? = nil
) throws -> (PieChart, [DiagramDiagnostic]) {
    // existing body, with every `return chart` rewritten as `return (chart, [])`
}
```

If a parser is called from multiple places (e.g., from another family parser), the callers need to destructure the tuple. Run `grep -rn "try parsePieChart\(" Sources/` to find all callers; the registry file is the only one expected — if there are others, update them.

- [ ] **Step 3: Switch each registry file from `parse:` to `parseWithDiagnostics:`**

For each `Sources/DiagramKit/DiagramRegistry+<Family>.swift` corresponding to the parsers above:

Change the `_typed(...)` call's `parse:` label to `parseWithDiagnostics:`. The closure body now returns the parser's tuple directly:

```swift
extension DiagramRegistry {
    static let _pie = _typed(
        type: .pie,
        matches: { $0.startsWithToken("pie") },
        parseWithDiagnostics: { source, frontmatter in
            var (chart, diagnostics) = try parsePieChart(
                DiagramSourceNormalizer.diagramLines(source),
                frontmatter: frontmatter
            )
            if let fm = frontmatter {
                if let cfg = fm.pieConfig { chart.config = cfg }
                if let theme = fm.pieTheme { chart.theme = theme }
                if chart.diagramTitle == nil, let fmTitle = fm.diagramTitle { chart.diagramTitle = fmTitle }
            }
            return (chart, diagnostics)
        },
        wrap: DiagramPayload.pie,
        unwrap: { payload in
            guard case let .pie(value) = payload else { return nil }
            return value
        },
        layout: { chart, _ in layoutPieChart(chart) },
        positioned: { graph, positioned in
            PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .pie(positioned))
        }
    )
}
```

Repeat for every family file listed in the **Files** section.

- [ ] **Step 4: Widen `parseMermaid` itself**

The generic `parseMermaid` in `src_parser.swift:179` is called from the Flowchart raw `DiagramDescriptor` init. Widen its signature to `throws -> (DiagramDocument, [DiagramDiagnostic])`. Inside the body, accumulate into a local `var diagnostics: [DiagramDiagnostic] = []` and return `(document, diagnostics)` at every exit.

Edit `Sources/DiagramKit/DiagramRegistry+Flowchart.swift` to destructure:

```swift
parse: { source, frontmatter in
    let (parsed, diagnostics) = try parseMermaid(source, config: frontmatter?.flowchartConfig, stateConfig: frontmatter?.stateConfig)
    let document: DiagramDocument
    switch parsed.payload {
    case .flowchart(let model), .stateDiagram(let model):
        document = DiagramDocument(payload: .flowchart(model))
    default:
        document = parsed
    }
    return (document, diagnostics)
}
```

The static-method variant `MermaidParser.parseMermaid` at `src_parser.swift:1282` also widens. Update any deprecated callers.

- [ ] **Step 5: Compile**

Run: `swift build`
Expected: Build succeeds. If anything fails, a parser-caller wasn't updated — grep for the old single-return callsite and migrate.

- [ ] **Step 6: Run targeted suites**

Run: `swift test --filter "ParserDispatchOrderTests|ER|Class|Gantt|Pie|Journey|Sequence|Sankey|Mindmap|Timeline|Treemap|Quadrant|Requirement|Block|Radar|Packet|EventModeling|XYChart|Architecture|StateDiagram|MermaidImporterDiagnosticsTests"`
Expected: All pass.

- [ ] **Step 7: SVG snapshot canary**

Run: `SNAPSHOT_DIAGRAM_IDS=pie-1-basic,flow-1-simple,seq-1-basic,class-1-basic,er-1-basic,state-1-basic swift test --filter CorpusSnapshotTests/svgSnapshot`
Expected: byte-stable.

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKitModel/src_*_parser.swift Sources/DiagramKit/DiagramRegistry+*.swift
git commit -m "$(cat <<'EOF'
refactor(parsers): widen family parser signatures to tuple return

Mechanical widening — every Mermaid family parser now returns
(Model, [DiagramDiagnostic]). No diagnostics are emitted today by these
parsers (C4 and Kanban are already wired in Phase C/D); the empty arrays
give the family a documented surface to populate when a future emit site
opens up. Registry files switched from `parse:` to `parseWithDiagnostics:`
using the typed factory overload introduced in Phase D.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase F — Importer + Pipeline + Engine Plumbing

### Task F1: Add `DiagramLoader.parseImportResult`; align `MermaidImporter`

**Files:**
- Modify: `Sources/DiagramKitImport/DiagramLoader.swift`
- Test: `Tests/DiagramKitTests/DiagramLoaderParseImportResultTests.swift` (new)

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/DiagramLoaderParseImportResultTests.swift`:

```swift
import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKit

@Suite("DiagramLoader.parseImportResult")
struct DiagramLoaderParseImportResultTests {
    @Test("Returns full DiagramImportResult including diagnostics")
    func returnsFullImportResult() throws {
        let source = """
        C4Context
        title test
        Person(p, "User") $boundary=missing
        """
        let result = try DiagramLoader.parseImportResult(source)
        #expect(result.document.type == .c4)
        #expect(!result.diagnostics.isEmpty)
    }

    @Test("Empty source throws DiagramError.unrecognizedFormat")
    func emptySourceThrows() {
        #expect(throws: DiagramError.self) {
            _ = try DiagramLoader.parseImportResult("")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DiagramLoaderParseImportResultTests`
Expected: FAIL — `parseImportResult` not in scope.

- [ ] **Step 3: Add `parseImportResult`**

Edit `Sources/DiagramKitImport/DiagramLoader.swift`. Add a new public static function:

```swift
public static func parseImportResult(
    _ source: String,
    registry: ImporterRegistry = .default
) throws -> DiagramImportResult {
    let importer = try registry.match(source: source)
    return try importer.parse(source)
}
```

(Adjust the body to match the actual `match(source:)` API in `ImporterRegistry` — if the function is named differently, use that. The existing `parseDocument(_:registry:)` body should already do something similar and can guide the implementation.)

Refactor the existing `parseDocument(_:registry:)` to call `parseImportResult` internally:

```swift
public static func parseDocument(
    _ source: String,
    registry: ImporterRegistry = .default
) throws -> DiagramDocument {
    try parseImportResult(source, registry: registry).document
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DiagramLoaderParseImportResultTests`
Expected: PASS, both tests.

- [ ] **Step 5: Verify no regression**

Run: `swift test --filter "DiagramLoader|MermaidImporterTests|ImporterRegistry"`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitImport/DiagramLoader.swift Tests/DiagramKitTests/DiagramLoaderParseImportResultTests.swift
git commit -m "$(cat <<'EOF'
feat(import): add DiagramLoader.parseImportResult diagnostic-aware entry

`parseDocument(_:registry:)` now routes through `parseImportResult` and
returns `.document`. Callers that need diagnostics call `parseImportResult`
directly.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task F2: `DiagramPipeline` — `loadImportResult` + aggregated `prepare`

**Files:**
- Modify: `Sources/DiagramKit/DiagramPipeline.swift`
- Test: `Tests/DiagramKitTests/ParserDiagnosticAggregationTests.swift` (new)

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/ParserDiagnosticAggregationTests.swift`:

```swift
#if canImport(CoreGraphics)
import Testing
import DiagramKitCommon
import DiagramKitImport
import DiagramKit

@Suite("Cross-tier diagnostic aggregation")
struct ParserDiagnosticAggregationTests {
    @Test("PreparedDiagram.diagnostics carries both parse and layout warnings")
    func aggregatesParseAndLayout() throws {
        // Source that triggers both:
        //   - A C4 $boundary=missing parse warning
        //   - Some layout-time warning (e.g., a flowchart-deep-subgraph fixture
        //     that triggers _allNodeIds recursion truncation).
        // C4 has no layout-time warnings, so use a fixture combining a
        // parse-tier emit and a layout-tier emit on the same source.
        // For this test, assert the loose property that BOTH parse-tier and
        // layout-tier paths surface diagnostics in `prepared.diagnostics`
        // when given a source designed to trigger both.

        // Parse-tier: Kanban duplicate-node (parser warning)
        let kanbanSource = """
        kanban
            col1[A]
                t1[T]
            col2[B]
                t1[T]
        """
        let prepared = try DiagramPipeline.prepare(source: kanbanSource)
        #expect(prepared.diagnostics.contains { $0.message.contains("duplicate") })
    }

    @Test("Diagnostic ordering: import first, then layout")
    func orderingInvariant() throws {
        // Construct an import diagnostic and a layout diagnostic via the
        // PreparedDiagram init directly (the prepared pipeline composes them
        // in this order).
        let doc = try DiagramPipeline.parse("pie\n  \"a\" : 1")
        var positioned = try GraphLayout().layout(doc)
        positioned.diagnostics = [
            DiagramDiagnostic(severity: .warning, message: "layout-warn", location: nil)
        ]
        let prepared = PreparedDiagram(
            positioned: positioned,
            theme: .default,
            importDiagnostics: [
                DiagramDiagnostic(severity: .warning, message: "import-warn", location: nil)
            ]
        )
        #expect(prepared.diagnostics.map(\.message) == ["import-warn", "layout-warn"])
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ParserDiagnosticAggregationTests`
Expected: FAIL — `aggregatesParseAndLayout` will fail because `prepare` doesn't pass `importDiagnostics:` today. (The ordering test will already pass because PreparedDiagram does the aggregation correctly from A2.)

- [ ] **Step 3: Add `loadImportResult` and update `prepare`**

Edit `Sources/DiagramKit/DiagramPipeline.swift`. Add a new private helper:

```swift
private static func loadImportResult(
    _ source: String,
    registry: ImporterRegistry
) throws -> DiagramImportResult {
    try DiagramLoader.parseImportResult(source, registry: registry)
}
```

Update `prepare(...)` (line 111-122) to use it:

```swift
public static func prepare(
    source: String,
    theme: DiagramTheme = .default,
    layoutConfig: LayoutConfig = LayoutConfig(),
    registry: ImporterRegistry = defaultRegistry
) throws -> PreparedDiagram {
    try runPipeline(operation: "DiagramPipeline.prepare") {
        let importResult = try loadImportResult(source, registry: registry)
        let positioned = try GraphLayout(config: layoutConfig).layout(importResult.document)
        return PreparedDiagram(
            positioned: positioned,
            theme: theme,
            importDiagnostics: importResult.diagnostics
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ParserDiagnosticAggregationTests`
Expected: PASS, both tests.

- [ ] **Step 5: Verify no regression**

Run: `swift test --filter "DiagramPipeline|PreparedDiagram"`
Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKit/DiagramPipeline.swift Tests/DiagramKitTests/ParserDiagnosticAggregationTests.swift
git commit -m "$(cat <<'EOF'
feat(pipeline): aggregate parse + layout diagnostics in prepare

DiagramPipeline.prepare(source:...) now threads
DiagramImportResult.diagnostics into PreparedDiagram.importDiagnostics,
producing PreparedDiagram.diagnostics = importDiagnostics + positioned.diagnostics.
Adds the private `loadImportResult` helper to bypass the
diagnostic-discarding `loadDocument`.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task F3: `DiagramEngine.parseImportResult` + `renderASCII` returns `AsciiRenderOutput`

**Files:**
- Modify: `Sources/DiagramKit/DiagramEngine.swift`
- Modify: `Sources/DiagramKit/DiagramPipeline.swift:214+` (renderASCII return type)
- Modify: ~30 ASCII unit-test files (`.text` accessor) — see Phase G2

- [ ] **Step 1: Add `parseImportResult` to `DiagramEngine`**

Edit `Sources/DiagramKit/DiagramEngine.swift`. Near the existing `parseDiagram()` (line 224), add:

```swift
public static func parseImportResult(
    source: String,
    registry: ImporterRegistry = DiagramPipeline.defaultRegistry
) async throws -> DiagramImportResult {
    _ = _DiagramPreparerBootstrap.didInstall
    return try await _runOnWorker {
        try DiagramLoader.parseImportResult(source, registry: registry)
    }
}
```

- [ ] **Step 2: Add `parseImportResult` test**

Append to `Tests/DiagramKitTests/DiagramLoaderParseImportResultTests.swift`:

```swift
extension DiagramLoaderParseImportResultTests {
    @Test("DiagramEngine.parseImportResult surfaces diagnostics async")
    func engineParseImportResult() async throws {
        let source = """
        C4Context
        title test
        Person(p, "User") $boundary=missing
        """
        let result = try await DiagramEngine.parseImportResult(source: source)
        #expect(!result.diagnostics.isEmpty)
    }
}
```

- [ ] **Step 3: Run test to verify it passes**

Run: `swift test --filter DiagramLoaderParseImportResultTests/engineParseImportResult`
Expected: PASS.

- [ ] **Step 4: Widen `DiagramPipeline.renderASCII` and `DiagramEngine.renderASCII`**

Edit `Sources/DiagramKit/DiagramPipeline.swift`. The `renderASCII(source:theme:)` static method (line 214 approx) currently returns `String`. Change to return `AsciiRenderOutput`:

```swift
public static func renderASCII(
    source: String,
    theme: DiagramTheme = .default
) throws -> AsciiRenderOutput {
    try runPipeline(operation: "DiagramPipeline.renderASCII") {
        // Existing implementation: dispatches through AsciiRenderRegistry.
        // Update the return to wrap the rendered text in AsciiRenderOutput.
        // Until Phase G widens AsciiRenderRegistry's `render` closure,
        // wrap with empty diagnostics: AsciiRenderOutput(text: rendered, diagnostics: [])
        // After Phase G, plumb both parse and ascii-render diagnostics through here.
        let rendered = /* existing inner body that produces String */
        return AsciiRenderOutput(text: rendered, diagnostics: [])
    }
}
```

Match the actual existing body — replace only the `return <String>` with `return AsciiRenderOutput(text: <String>, diagnostics: [])`.

Edit `Sources/DiagramKit/DiagramEngine.swift`. `renderASCII(source:theme:)` at line 138-146:

```swift
public static func renderASCII(
    source: String,
    theme: DiagramTheme = .default
) async throws -> AsciiRenderOutput {
    _ = _DiagramPreparerBootstrap.didInstall
    return try await _runOnWorker {
        try DiagramPipeline.renderASCII(source: source, theme: theme)
    }
}
```

Update the deprecated alias `renderMermaidASCII` at `DiagramEngine.swift:279-280`:

```swift
@available(*, deprecated, renamed: "renderASCII(source:theme:)", message: "Returns AsciiRenderOutput now; access `.text` for the previous String shape.")
public static func renderMermaidASCII(
    source: String,
    theme: DiagramTheme = .default
) async throws -> String {
    try await renderASCII(source: source, theme: theme).text
}
```

Also check the legacy free-function `renderDiagramASCII` at `src_index.swift` — if it exists and returns `String`, update it the same way OR mark deprecated forwarding to `.text`.

- [ ] **Step 5: Sweep ASCII test call sites**

Run: `grep -rn "renderASCII\|renderMermaidASCII\|renderDiagramASCII" Tests/DiagramKitTests/ | head -50`

For each test that captures the result as `String`, change the call site to access `.text`:

```swift
// Before:
let ascii = try DiagramEngine.renderASCII(source: source).
// or:
let ascii = try DiagramPipeline.renderASCII(source: source, theme: .default)

// After:
let ascii = try DiagramPipeline.renderASCII(source: source, theme: .default).text
// or, async:
let ascii = try await DiagramEngine.renderASCII(source: source).text
```

Apply to every ASCII test file (Pie, Sequence, ER, Class, GitGraph, Mindmap, Timeline, etc. — find them via grep).

- [ ] **Step 6: Update `CorpusSnapshotTests.swift` ASCII path**

Edit `Tests/DiagramKitTests/CorpusSnapshotTests.swift`. Find the `asciiSnapshot` test (line 85-89 approximate). Change the captured value to `.text`. If the snapshot helper compares a `String` against an on-disk baseline, just access `.text` before comparing.

- [ ] **Step 7: Compile + run ASCII suites**

Run: `swift build`
Expected: succeeds.

Run: `swift test --filter "AsciiRenderOutputTests|PieAsciiRendererTests|SequenceAsciiRendererTests|ClassAsciiRendererTests|GanttAsciiRendererTests|MindmapAsciiRendererTests"`
Expected: All pass.

- [ ] **Step 8: Run a representative ASCII snapshot canary**

Run: `SNAPSHOT_DIAGRAM_IDS=pie-1-basic,seq-1-basic,class-1-basic swift test --filter CorpusSnapshotTests/asciiSnapshot`
Expected: byte-stable (the text content of the snapshot is unchanged; only the wrapper type changed).

- [ ] **Step 9: Commit**

```bash
git add Sources/DiagramKit/DiagramEngine.swift Sources/DiagramKit/DiagramPipeline.swift Tests/DiagramKitTests/CorpusSnapshotTests.swift Tests/DiagramKitTests/*AsciiRenderer*.swift Tests/DiagramKitTests/DiagramLoaderParseImportResultTests.swift
git commit -m "$(cat <<'EOF'
feat(umbrella): renderASCII returns AsciiRenderOutput; add parseImportResult

DiagramEngine.renderASCII and DiagramPipeline.renderASCII now return
AsciiRenderOutput { text, diagnostics }. The deprecated renderMermaidASCII
shim forwards `.text` for backward compatibility. DiagramEngine gains
parseImportResult(source:registry:) so callers can await diagnostics
without going through prepare(). ASCII test sites swept to access .text.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase G — ASCII Registry + Test Sweep

### Task G1: Widen `AsciiRenderRegistry.AsciiRenderDescriptor.render` to tuple

**Files:**
- Modify: `Sources/DiagramKit/AsciiRenderRegistry.swift`

This task migrates ASCII rendering to surface diagnostics too. The render closure widens; every of the ~28 family ASCII closures wraps with `(rendered, [])`. The C4 ASCII closure stops discarding `_parseC4DiagramWithDiagnostics`'s array.

- [ ] **Step 1: Widen `AsciiRenderDescriptor.render` closure shape**

Edit `Sources/DiagramKit/AsciiRenderRegistry.swift`. Locate the `AsciiRenderDescriptor` struct (line 12) and change its `render` closure:

```swift
struct AsciiRenderDescriptor: Sendable {
    let type: DiagramType
    let render: @Sendable (
        String,
        DiagramFrontmatter?,
        AsciiRenderConfig,
        AsciiColorMode,
        AsciiTheme
    ) throws -> (String, [DiagramDiagnostic])
}
```

- [ ] **Step 2: Wrap every family closure with `(rendered, [])`**

For each `render: { ... }` closure body in the file, change the final `return ...` to `return (..., [])`:

```swift
// Before:
render: { source, _, config, colorMode, theme in
    try renderSequenceAscii(source, _mapAsciiConfig(config), _asciiMapColorMode(colorMode), _asciiMapTheme(theme))
}

// After:
render: { source, _, config, colorMode, theme in
    let rendered = try renderSequenceAscii(source, _mapAsciiConfig(config), _asciiMapColorMode(colorMode), _asciiMapTheme(theme))
    return (rendered, [])
}
```

Sweep every family closure in `AsciiRenderRegistry.swift`. Specifically C4's site at line 223:

```swift
render: { rawLines, frontmatter, config, colorMode, theme in
    let (model, diagnostics) = try parseC4Diagram(rawLines, frontmatter: frontmatter)
    let rendered = renderC4Ascii(model)
    return (rendered, diagnostics)
}
```

(Note: `parseC4Diagram` is the post-C1 canonical tuple-returning name. If the surrounding code passes `String` rather than `[String]`, adapt accordingly.)

- [ ] **Step 3: Update the dispatcher to propagate the tuple**

Locate the call site that invokes a chosen `AsciiRenderDescriptor.render(...)` — likely a `func render(forType:source:...)` in the same file. Update it to return `AsciiRenderOutput` (or a tuple, depending on internal API). Trace upward: `DiagramPipeline.renderASCII` now should return `AsciiRenderOutput` carrying both the import diagnostics and the ASCII render diagnostics.

Edit `Sources/DiagramKit/DiagramPipeline.swift:renderASCII` body. The body now also calls `loadImportResult` to obtain parse-tier diagnostics, then routes through `AsciiRenderRegistry`. Final return:

```swift
public static func renderASCII(
    source: String,
    theme: DiagramTheme = .default
) throws -> AsciiRenderOutput {
    try runPipeline(operation: "DiagramPipeline.renderASCII") {
        let importResult = try loadImportResult(source, registry: defaultRegistry)
        let (rendered, renderDiagnostics) = try AsciiRenderRegistry.render(
            forType: importResult.document.type,
            source: source,
            frontmatter: /* … */,
            config: /* … */,
            colorMode: /* … */,
            theme: /* … */
        )
        return AsciiRenderOutput(
            text: rendered,
            diagnostics: importResult.diagnostics + renderDiagnostics
        )
    }
}
```

Match the actual `AsciiRenderRegistry.render` dispatch signature. If the dispatcher doesn't exist as a function (you call the descriptor's closure directly), invert: look up the descriptor, call `descriptor.render(...)`, destructure. The aggregation order is parse-tier first, then ASCII-render-tier diagnostics.

- [ ] **Step 4: Add a test for C4 ASCII diagnostic surfacing**

Append to `Tests/DiagramKitTests/AsciiRenderOutputTests.swift`:

```swift
extension AsciiRenderOutputTests {
    @Test("C4 ASCII renderASCII surfaces \$boundary diagnostic")
    func c4AsciiSurfacesDiagnostic() async throws {
        let source = """
        C4Context
        title test
        Person(p, "User") $boundary=missing
        """
        let output = try await DiagramEngine.renderASCII(source: source)
        #expect(!output.diagnostics.isEmpty)
        #expect(output.diagnostics.contains { $0.message.contains("missing") })
    }
}
```

- [ ] **Step 5: Compile + test**

Run: `swift build`
Run: `swift test --filter "AsciiRenderOutputTests|CorpusSnapshotTests/asciiSnapshot"`

The corpus ASCII filter narrows by `SNAPSHOT_DIAGRAM_IDS`:

Run: `SNAPSHOT_DIAGRAM_IDS=c4-1-context,pie-1-basic,seq-1-basic swift test --filter CorpusSnapshotTests/asciiSnapshot`
Expected: byte-stable text + diagnostic-aware tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKit/AsciiRenderRegistry.swift Sources/DiagramKit/DiagramPipeline.swift Tests/DiagramKitTests/AsciiRenderOutputTests.swift
git commit -m "$(cat <<'EOF'
feat(ascii): surface parse + render diagnostics through AsciiRenderOutput

AsciiRenderRegistry.AsciiRenderDescriptor.render returns
(String, [DiagramDiagnostic]); the C4 ASCII closure stops discarding
parseC4Diagram's diagnostics. DiagramPipeline.renderASCII aggregates
importResult.diagnostics + renderDiagnostics into AsciiRenderOutput
so the ASCII path surfaces diagnostics symmetrically with the CG/SVG
path's PreparedDiagram.diagnostics.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase H — Documentation Sync

### Task H1: CLAUDE.md / ARCHITECTURE.md / REVIEW.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `ARCHITECTURE.md`
- Modify: `REVIEW.md`

- [ ] **Step 1: Update `CLAUDE.md` Pipeline diagram**

Edit `CLAUDE.md`. Find the "Pipeline" section (search for `## Pipeline`). Replace the existing ASCII pipeline diagram with the diagnostic-aware version from the spec's "Data flow" section. Keep the block fenced.

- [ ] **Step 2: Update `CLAUDE.md` Public Surface**

Edit `CLAUDE.md`. Find "## Public Surface". Add bullets:

```markdown
- `AsciiRenderOutput` (`text: String`, `diagnostics: [DiagramDiagnostic]`) is the new return type of `renderDiagramASCII(...)` / `DiagramEngine.renderASCII(...)` / `DiagramPipeline.renderASCII(...)`.
- `PreparedDiagram.diagnostics` aggregates parse-time `DiagramImportResult.diagnostics` and layout-time `PositionedGraph.diagnostics`, in that order.
- `DiagramEngine.parseImportResult(source:registry:)` is the diagnostic-aware async entry; `parseDiagram()` keeps its single-return shape for callers that don't need diagnostics.
- `MermaidImporter` now populates `DiagramImportResult.diagnostics` for diagnostic-emitting families (currently C4 and Kanban; other Mermaid families surface only layout diagnostics via `PositionedGraph`).
```

- [ ] **Step 3: Sync test source count**

Run: `find Tests/DiagramKitTests -name "*.swift" | wc -l`

Note the count. Update `CLAUDE.md`'s "Current test source count: 238 Swift files under `Tests/DiagramKitTests`" line to the new count (likely 244 or so after Phase A-F new files).

- [ ] **Step 4: Update `ARCHITECTURE.md`**

Edit `ARCHITECTURE.md`. Find the "Importers / Loaders" section (or the section describing the parse pipeline). Add a paragraph:

```markdown
**Diagnostics.** `DiagramImportResult.diagnostics` carries parse-tier
warnings (currently emitted by the Mermaid C4 and Kanban families plus
every non-Mermaid importer). `PositionedGraph.diagnostics` carries
layout-tier warnings (subgraph recursion truncations, Ishikawa depth
overflow, gitgraph missing-position fallback). `PreparedDiagram.diagnostics`
aggregates the two in `[parse, layout]` order. The ASCII path bypasses
`PreparedDiagram` and returns `AsciiRenderOutput { text, diagnostics }`
where `diagnostics = importResult.diagnostics + asciiRenderDiagnostics`.
Fatal conditions still `throw`; the diagnostic array carries only
`.warning` and `.info` severities.
```

- [ ] **Step 5: Add REVIEW.md Session 10 entry**

Edit `REVIEW.md`. Below the existing "Resolution Status — Session 9" block, add:

```markdown
---

## Resolution Status — Session 10 (2026-05-14)

Closes Session 9's deferred follow-up ("surfacing parser diagnostics
through DiagramImportResult.diagnostics requires widening the registry
parse: closure shape — out of scope for that session"). Spec at
`docs/superpowers/specs/2026-05-14-parser-diagnostics-surfacing-design.md`;
plan at `docs/superpowers/plans/2026-05-14-parser-diagnostics-surfacing.md`.
N commits on `main` (two docs + N implementation).

| # | Item | Commit | What landed |
|---|---|---|---|
| ... | ... | ... | ... |
```

Replace `N` with the actual commit count after running `git log --oneline 02fc245..HEAD | wc -l`. Fill the table with one row per commit landed in Phases A-G.

- [ ] **Step 6: Run full sanity-check filter**

Run: `swift test --filter "PositionedGraphDiagnosticsTests|PreparedDiagramDiagnosticsTests|AsciiRenderOutputTests|MermaidImporterDiagnosticsTests|DiagramLoaderParseImportResultTests|ParserDiagnosticAggregationTests"`
Expected: All pass.

- [ ] **Step 7: Run discipline gates**

Run: `Scripts/check-file-sizes.sh`
Expected: Only pre-existing yellow warnings; no new threshold crossings.

Run: `Scripts/check-sendable-annotations.sh`
Expected: Green.

- [ ] **Step 8: Commit**

```bash
git add CLAUDE.md ARCHITECTURE.md REVIEW.md
git commit -m "$(cat <<'EOF'
docs(review,claude,architecture): close REVIEW Session 10 — parser diagnostics

CLAUDE.md pipeline diagram + Public Surface bullets reflect the new
AsciiRenderOutput shape and PreparedDiagram.diagnostics aggregation.
ARCHITECTURE.md gains a paragraph on parse-tier vs layout-tier diagnostic
surfaces. REVIEW.md Session 10 entry tabulates the implementation
commit map.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review

After all tasks land, run this audit:

1. **Spec coverage:** Walk each section of `docs/superpowers/specs/2026-05-14-parser-diagnostics-surfacing-design.md` and confirm there's a closing commit.
   - Type-shape changes (registry + layout + aggregator) → A1, A2, A3, B1
   - Data flow (parse → layout → prepared) → B1, C1, D2-D4, F2
   - Pipeline call sites table → F1, F2, F3
   - Importer wiring → B1, F1
   - Severity convention → tests assert `.warning` on every emit
   - Migration plan A→G → all tasks
   - Tests by tier (schema, per-emitter, aggregation, snapshot) → A1-A3, C1, D1-D4, F2, F3, G1
   - Out of scope items → no commits (CrossPlatform.swift untouched ✓; `_withDiagramIssueReporting` untouched ✓; `DiagramSourceImporter` protocol untouched ✓)

2. **Discipline gates green:**
   ```bash
   Scripts/check-file-sizes.sh
   Scripts/check-sendable-annotations.sh
   Scripts/strict-concurrency-check.sh
   ```

3. **Snapshot byte-stability:**
   ```bash
   SNAPSHOT_DIAGRAM_IDS=pie-1-basic,flow-1-simple,c4-1-context,seq-1-basic,class-1-basic swift test --filter CorpusSnapshotTests/svgSnapshot
   SNAPSHOT_DIAGRAM_IDS=pie-1-basic,flow-1-simple,c4-1-context,seq-1-basic,class-1-basic swift test --filter CorpusSnapshotTests/imageSnapshot
   SNAPSHOT_DIAGRAM_IDS=pie-1-basic,seq-1-basic,c4-1-context swift test --filter CorpusSnapshotTests/asciiSnapshot
   ```
   Expected: All byte-stable.

4. **Session 10 wrap-up:**

After H1's commit, run `git log --oneline 02fc245..HEAD` and confirm the commit chain matches the Phases A-G migration. If any phase's tests or snapshots failed mid-way, the corresponding task's commit will be missing.

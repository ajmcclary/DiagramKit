# Mermaid Exporter Completion — Wave 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land Mermaid-source exporters for 9 flat-text-DSL families
(`pie`, `sankey`, `packet`, `journey`, `timeline`, `kanban`, `mindmap`,
`treemap`, `gitGraph`), wiring each into the existing
`RoundTripHarness`. Wave 1 closes 9 of the 21 backlog families.

**Architecture:** One file per family under
`Sources/DiagramKitMermaid/Exporter/MermaidExport/`, mirroring the
existing 7 exporters. Dispatch added to `MermaidExporter.export(_:)`
arm by arm; the umbrella `default: .unsupportedDiagram` fall-through
remains until Wave 3. Round-trip discipline is the primary
acceptance gate via two `.md` fixtures per family, structural diff
via per-family `DiagramDocumentDiff+<Family>.swift`, and a new corpus
round-trip suite that exercises every supported family across all
397 Mermaid corpus entries.

**Tech Stack:** Swift 6, SwiftPM,
[swift-testing](https://github.com/swiftlang/swift-testing) for new
tests (XCTest for legacy ones), `DiagramKitTestSupport.RoundTripHarness`,
`Scripts/check-diagnostic-discipline.sh`,
`Scripts/check-file-sizes.sh`.

**Source spec:**
[docs/superpowers/specs/2026-05-19-mermaid-exporter-completion-design.md](../specs/2026-05-19-mermaid-exporter-completion-design.md)
(commit `34705b4`).

---

## File Structure

**Files created (Wave 1):**

```
Sources/DiagramKitMermaid/Exporter/MermaidExport/
  MermaidPieExport.swift           # Task 1
  MermaidSankeyExport.swift        # Task 2
  MermaidPacketExport.swift        # Task 3
  MermaidJourneyExport.swift       # Task 4
  MermaidTimelineExport.swift      # Task 5
  MermaidKanbanExport.swift        # Task 6
  MermaidMindmapExport.swift       # Task 7
  MermaidTreemapExport.swift       # Task 8
  MermaidGitGraphExport.swift      # Task 9

Sources/DiagramKitTestSupport/
  DiagramDocumentDiff+Pie.swift          # Task 1
  DiagramDocumentDiff+Sankey.swift       # Task 2
  DiagramDocumentDiff+Packet.swift       # Task 3
  DiagramDocumentDiff+Journey.swift      # Task 4
  DiagramDocumentDiff+Timeline.swift     # Task 5
  DiagramDocumentDiff+Kanban.swift       # Task 6
  DiagramDocumentDiff+Treemap.swift      # Task 8
  DiagramDocumentDiff+GitGraph.swift     # Task 9
  # Mindmap (Task 7) already has DiagramDocumentDiff+Mindmap.swift

Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/
  mermaid-pie/01-basic.md, 02-show-data.md
  mermaid-sankey/01-basic.md, 02-quoted.md
  mermaid-packet/01-basic.md, 02-multibyte.md
  mermaid-journey/01-basic.md, 02-multi-section.md
  mermaid-timeline/01-basic.md, 02-multi-period.md
  mermaid-kanban/01-basic.md, 02-metadata.md
  mermaid-mindmap/01-basic.md, 02-nested.md
  mermaid-treemap/01-basic.md, 02-nested-values.md
  mermaid-gitgraph/01-basic.md, 02-branches.md

Tests/DiagramKitTests/RoundTrip/
  CorpusRoundTripTests.swift       # Task 10
```

**Files modified (Wave 1):**

```
Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift     # +9 case arms, +9 supportedDiagramTypes
Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidExportHelpers.swift  # +section helper (Task 5), +indent helper (Task 8)
Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift      # +8 case arms (mindmap arm already exists)
Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift  # +9 cells
Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift  # +9 @Test methods
```

---

## Task Ordering Rationale

Tasks 1–3 (pie, sankey, packet) introduce the per-family contract
shape on minimal payloads. Tasks 4–5 (journey, timeline) introduce the
section-transition pattern, with Task 5 extracting the
`emitSectionedItems` helper as the second caller. Tasks 6–8 (kanban,
mindmap, treemap) introduce nested-tree emission, with Task 8
extracting the `emitIndentedTree` helper as the second tree caller.
Task 9 (gitGraph) introduces statement-enum dispatch. Task 10 adds the
corpus regression suite. Task 11 closes Wave 1 with discipline gates.

---

## Task 1: Pie Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidPieExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Pie.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-pie/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-pie/02-show-data.md`
- Modify: `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift`
- Modify: `Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift`
- Modify: `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift`
- Modify: `Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift`

- [ ] **Step 1.1: Add fixture `01-basic.md`**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-pie/01-basic.md`:

```
pie title Browsers
    "Chrome" : 60
    "Firefox" : 30
    "Safari" : 10
```

- [ ] **Step 1.2: Stub the exporter file**

Create `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidPieExport.swift`:

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `pie` source from a `PieChart`.
///
/// Lossless: header → optional `showData` → optional title → optional
/// accessibility metadata → quoted section labels with numeric values.
enum MermaidPieExport {

    static func emit(_ model: PieChart) throws -> DiagramExportResult {
        // Minimal stub: enable RED → GREEN flow in Step 1.7 / 1.8.
        return DiagramExportResult(source: "pie\n", diagnostics: [])
    }
}
```

- [ ] **Step 1.3: Wire dispatch arm**

In `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift`, add
`.pie` to `supportedDiagramTypes` and add a `case` arm in the
`export(_:)` switch (insert directly above the existing
`.stateDiagram` case). The set initializer becomes:

```swift
public let supportedDiagramTypes: Set<DiagramType> = [
    .flowchart,
    .sequenceDiagram,
    .classDiagram,
    .erDiagram,
    .c4,
    .gantt,
    .stateDiagram,
    .pie,             // wave 1
]
```

And the switch gains:

```swift
case .pie(let model):
    result = try MermaidPieExport.emit(model)
```

- [ ] **Step 1.4: Create the diff arm**

Create `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Pie.swift`:

```swift
import DiagramKitModel

func diffPieChart(_ a: PieChart, _ b: PieChart) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "pie.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.showData != b.showData {
        deltas.append(.unexpected(
            path: "pie.showData",
            detail: "lhs=\(a.showData) rhs=\(b.showData)"
        ))
    }
    if a.sections.count != b.sections.count {
        deltas.append(.unexpected(
            path: "pie.sections.count",
            detail: "lhs=\(a.sections.count) rhs=\(b.sections.count)"
        ))
        return deltas
    }
    for (i, (lhs, rhs)) in zip(a.sections, b.sections).enumerated() {
        if lhs.label != rhs.label {
            deltas.append(.unexpected(
                path: "pie.sections[\(i)].label",
                detail: "lhs=\(lhs.label) rhs=\(rhs.label)"
            ))
        }
        if lhs.value != rhs.value {
            deltas.append(.unexpected(
                path: "pie.sections[\(i)].value",
                detail: "lhs=\(lhs.value) rhs=\(rhs.value)"
            ))
        }
    }
    return deltas
}
```

In `Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift`, add a
new `case` arm to the `compare(_:_:)` switch (insert above the existing
`.mindmap` arm):

```swift
case (.pie(let lhs), .pie(let rhs)):
    deltas.append(contentsOf: diffPieChart(lhs, rhs))
```

- [ ] **Step 1.5: Register the round-trip cell**

In `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift`, add
below `mermaidState`:

```swift
static let mermaidPie = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: DiagramType.pie,
    allowedLosses: []
)
```

- [ ] **Step 1.6: Register the test method**

In `Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift`,
add inside `struct SameFormatRoundTripTests`:

```swift
@Test(
    "Mermaid pie round-trip",
    arguments: try fixtures(for: "mermaid-pie", fromRoot: roundTripResourcesRoot())
)
func mermaidPie(fixture: RoundTripFixture) throws {
    try runSameFormatRoundTrip(
        cell: RoundTripCellRegistry.mermaidPie,
        fixture: fixture
    )
}
```

- [ ] **Step 1.7: Run test to confirm RED**

Run: `swift test --filter SameFormatRoundTripTests/mermaidPie`
Expected: FAIL. The stub returns just `"pie\n"`, so structural diff
will report mismatched `sections.count`.

- [ ] **Step 1.8: Implement the emit body**

Replace the stub `emit` in `MermaidPieExport.swift` with:

```swift
static func emit(_ model: PieChart) throws -> DiagramExportResult {
    var lines: [String] = []
    var diagnostics: [DiagramDiagnostic] = []

    // Header carries `showData` and inline title.
    var header = "pie"
    if model.showData {
        header += " showData"
    }
    if let title = model.diagramTitle, !title.isEmpty {
        header += " title \(MermaidPieExport.singleLine(title))"
    }
    lines.append(header)

    if let accTitle = model.accTitle, !accTitle.isEmpty {
        lines.append("    accTitle: \(MermaidPieExport.singleLine(accTitle))")
    }
    if let accDescr = model.accDescr, !accDescr.isEmpty {
        if accDescr.contains("\n") {
            lines.append("    accDescr: {")
            for sub in accDescr.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("        \(sub)")
            }
            lines.append("    }")
        } else {
            lines.append("    accDescr: \(accDescr)")
        }
    }

    for section in model.sections {
        let (quoted, qDiags) = MermaidExportHelpers.quote(section.label)
        diagnostics.append(contentsOf: qDiags)
        lines.append("    \(quoted) : \(formatNumber(section.value))")
    }

    let source = lines.joined(separator: "\n") + "\n"
    return DiagramExportResult(source: source, diagnostics: diagnostics)
}

private static func singleLine(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\r\n", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
}

private static func formatNumber(_ value: Double) -> String {
    if value.rounded() == value && abs(value) < 1e15 {
        return String(Int64(value))
    }
    return String(value)
}
```

- [ ] **Step 1.9: Run test to confirm GREEN**

Run: `swift test --filter SameFormatRoundTripTests/mermaidPie`
Expected: PASS for `01-basic.md`.

- [ ] **Step 1.10: Add fixture `02-show-data.md`**

Create
`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-pie/02-show-data.md`:

```
pie showData title Quarterly revenue
    "Q1" : 12345
    "Q2" : 18000
    "Q3" : 15600
    "Q4" : 22100
```

- [ ] **Step 1.11: Run test to confirm 02 GREEN**

Run: `swift test --filter SameFormatRoundTripTests/mermaidPie`
Expected: PASS for both fixtures.

- [ ] **Step 1.12: Run discipline gates**

```bash
Scripts/check-diagnostic-discipline.sh
Scripts/check-file-sizes.sh
```
Expected: both exit 0.

- [ ] **Step 1.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidPieExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Pie.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-pie/

git commit -m "$(cat <<'EOF'
Add Mermaid pie exporter

Wave 1 of the Mermaid exporter completion spec. Lossless re-emission
from PieChart: header + optional showData + title + accessibility
metadata + quoted section labels with numeric values.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Sankey Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidSankeyExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Sankey.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-sankey/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-sankey/02-quoted.md`
- Modify: `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift`
- Modify: `Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift`
- Modify: `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift`
- Modify: `Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift`

- [ ] **Step 2.1: Add fixture `01-basic.md`**

```
sankey-beta

A,B,5
B,C,5
A,C,3
```

- [ ] **Step 2.2: Stub the exporter**

Create `MermaidSankeyExport.swift`:

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `sankey-beta` source from a `SankeyDiagram`.
///
/// CSV body with RFC 4180 quoting for fields containing `,`, `"`, or
/// newlines. Lossless for nodes, links, and title; non-default
/// diagram config survives via frontmatter only and is not re-emitted
/// (matches the Gantt config policy).
enum MermaidSankeyExport {

    static func emit(_ model: SankeyDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "sankey-beta\n", diagnostics: [])
    }
}
```

- [ ] **Step 2.3: Wire dispatch arm**

In `MermaidExporter.swift`, append `.sankey` to `supportedDiagramTypes`
and insert above `default:`:

```swift
case .sankey(let model):
    result = try MermaidSankeyExport.emit(model)
```

- [ ] **Step 2.4: Create the diff arm**

`Sources/DiagramKitTestSupport/DiagramDocumentDiff+Sankey.swift`:

```swift
import DiagramKitModel

func diffSankeyDiagram(_ a: SankeyDiagram, _ b: SankeyDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "sankey.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }

    // Links carry source/target/value; nodes are derived from link
    // endpoints and order can vary, so compare on the link triple set.
    let lhsTriples = Set(a.links.map { "\($0.source.id)|\($0.target.id)|\($0.value)" })
    let rhsTriples = Set(b.links.map { "\($0.source.id)|\($0.target.id)|\($0.value)" })
    if lhsTriples != rhsTriples {
        let onlyLhs = lhsTriples.subtracting(rhsTriples).sorted()
        let onlyRhs = rhsTriples.subtracting(lhsTriples).sorted()
        deltas.append(.unexpected(
            path: "sankey.links",
            detail: "onlyLhs=\(onlyLhs.joined(separator: ";")) onlyRhs=\(onlyRhs.joined(separator: ";"))"
        ))
    }
    return deltas
}
```

In `DiagramDocumentDiff.swift`, add to the switch:

```swift
case (.sankey(let lhs), .sankey(let rhs)):
    deltas.append(contentsOf: diffSankeyDiagram(lhs, rhs))
```

- [ ] **Step 2.5: Register cell**

```swift
static let mermaidSankey = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: DiagramType.sankey,
    allowedLosses: []
)
```

- [ ] **Step 2.6: Register test**

```swift
@Test(
    "Mermaid sankey round-trip",
    arguments: try fixtures(for: "mermaid-sankey", fromRoot: roundTripResourcesRoot())
)
func mermaidSankey(fixture: RoundTripFixture) throws {
    try runSameFormatRoundTrip(
        cell: RoundTripCellRegistry.mermaidSankey,
        fixture: fixture
    )
}
```

- [ ] **Step 2.7: Run test, confirm RED**

Run: `swift test --filter SameFormatRoundTripTests/mermaidSankey`
Expected: FAIL on `sankey.links` (zero links emitted).

- [ ] **Step 2.8: Implement emit**

Replace the stub `emit` with:

```swift
static func emit(_ model: SankeyDiagram) throws -> DiagramExportResult {
    var lines: [String] = ["sankey-beta", ""]
    var diagnostics: [DiagramDiagnostic] = []

    if let title = model.diagramTitle, !title.isEmpty {
        // Mermaid sankey has no native title syntax; surface via the
        // umbrella frontmatter path. Mark as `.featureDropped` here so
        // the umbrella exporter's `prependingDocumentTitle` is the
        // only emitter of the title.
        // (No diagnostic needed: the umbrella exporter re-attaches
        // the document-level title via frontmatter, which IS the
        // round-trip path for sankey titles.)
    }

    for link in model.links {
        let s = csvField(link.source.rawID)
        let t = csvField(link.target.rawID)
        let v = formatNumber(link.value)
        lines.append("\(s),\(t),\(v)")
    }

    let source = lines.joined(separator: "\n") + "\n"
    return DiagramExportResult(source: source, diagnostics: diagnostics)
}

/// RFC 4180 quoting: wrap in `"..."` and double internal `"` if the
/// field contains `,`, `"`, `\n`, or leading/trailing whitespace.
private static func csvField(_ raw: String) -> String {
    let needsQuoting = raw.contains(",")
        || raw.contains("\"")
        || raw.contains("\n")
        || raw.contains("\r")
        || raw.hasPrefix(" ")
        || raw.hasSuffix(" ")
    if !needsQuoting { return raw }
    let escaped = raw.replacingOccurrences(of: "\"", with: "\"\"")
    return "\"\(escaped)\""
}

private static func formatNumber(_ value: Double) -> String {
    if value.rounded() == value && abs(value) < 1e15 {
        return String(Int64(value))
    }
    return String(value)
}
```

- [ ] **Step 2.9: Run test, confirm GREEN**

Run: `swift test --filter SameFormatRoundTripTests/mermaidSankey`
Expected: PASS.

- [ ] **Step 2.10: Add fixture `02-quoted.md`**

```
sankey-beta

"Wages, salaries",Income,40
"Capital gains",Income,15
Income,"Taxes, federal",20
Income,"Living expenses",30
Income,Savings,5
```

- [ ] **Step 2.11: Run test, confirm GREEN**

Run: `swift test --filter SameFormatRoundTripTests/mermaidSankey`
Expected: PASS for both fixtures.

- [ ] **Step 2.12: Discipline gates**

```bash
Scripts/check-diagnostic-discipline.sh
Scripts/check-file-sizes.sh
```
Expected: both exit 0.

- [ ] **Step 2.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidSankeyExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Sankey.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-sankey/

git commit -m "$(cat <<'EOF'
Add Mermaid sankey exporter

Wave 1: CSV body with RFC 4180 quoting for fields containing comma /
quote / newline / leading-or-trailing space. Lossless on links and
node ids; title rides the umbrella frontmatter path.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Packet Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidPacketExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Packet.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-packet/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-packet/02-multibyte.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 3.1: Add fixture `01-basic.md`**

```
packet-beta
0-7: "Source Port"
8-15: "Destination Port"
```

- [ ] **Step 3.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `packet-beta` source from a `PacketDiagram`.
///
/// Lossless: rows flatten to a single sorted sequence of
/// `start-end: "label"` lines.
enum MermaidPacketExport {

    static func emit(_ model: PacketDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "packet-beta\n", diagnostics: [])
    }
}
```

- [ ] **Step 3.3: Wire dispatch**

`.packet` to `supportedDiagramTypes`; switch arm:

```swift
case .packet(let model):
    result = try MermaidPacketExport.emit(model)
```

- [ ] **Step 3.4: Diff arm**

`Sources/DiagramKitTestSupport/DiagramDocumentDiff+Packet.swift`:

```swift
import DiagramKitModel

func diffPacketDiagram(_ a: PacketDiagram, _ b: PacketDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "packet.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }

    // Flatten rows; the parser may re-pack into rows differently
    // (config.bitsPerRow controls re-packing), but the block sequence
    // must match.
    let lhs = a.rows.flatMap { $0 }
    let rhs = b.rows.flatMap { $0 }
    if lhs.count != rhs.count {
        deltas.append(.unexpected(
            path: "packet.blocks.count",
            detail: "lhs=\(lhs.count) rhs=\(rhs.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(lhs, rhs).enumerated() {
        if l.start != r.start || l.end != r.end || l.label != r.label {
            deltas.append(.unexpected(
                path: "packet.blocks[\(i)]",
                detail: "lhs=\(l.start)-\(l.end):'\(l.label)' rhs=\(r.start)-\(r.end):'\(r.label)'"
            ))
        }
    }
    return deltas
}
```

Add to `DiagramDocumentDiff.swift` switch:

```swift
case (.packet(let lhs), .packet(let rhs)):
    deltas.append(contentsOf: diffPacketDiagram(lhs, rhs))
```

- [ ] **Step 3.5: Register cell**

```swift
static let mermaidPacket = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: DiagramType.packet,
    allowedLosses: []
)
```

- [ ] **Step 3.6: Register test**

```swift
@Test(
    "Mermaid packet round-trip",
    arguments: try fixtures(for: "mermaid-packet", fromRoot: roundTripResourcesRoot())
)
func mermaidPacket(fixture: RoundTripFixture) throws {
    try runSameFormatRoundTrip(
        cell: RoundTripCellRegistry.mermaidPacket,
        fixture: fixture
    )
}
```

- [ ] **Step 3.7: Run test, confirm RED**

Run: `swift test --filter SameFormatRoundTripTests/mermaidPacket`
Expected: FAIL on `packet.blocks.count`.

- [ ] **Step 3.8: Implement emit**

```swift
static func emit(_ model: PacketDiagram) throws -> DiagramExportResult {
    var lines: [String] = ["packet-beta"]
    var diagnostics: [DiagramDiagnostic] = []

    let blocks = model.rows
        .flatMap { $0 }
        .sorted { $0.start < $1.start }
    for block in blocks {
        let range = block.start == block.end
            ? "\(block.start)"
            : "\(block.start)-\(block.end)"
        let (quoted, qDiags) = MermaidExportHelpers.quote(block.label)
        diagnostics.append(contentsOf: qDiags)
        lines.append("\(range): \(quoted)")
    }

    let source = lines.joined(separator: "\n") + "\n"
    return DiagramExportResult(source: source, diagnostics: diagnostics)
}
```

- [ ] **Step 3.9: Run test, confirm GREEN**

Expected: PASS.

- [ ] **Step 3.10: Add fixture `02-multibyte.md`**

```
packet-beta
0-15: "Source Port"
16-31: "Destination Port"
32-63: "Sequence Number"
64-95: "Ack Number"
96-99: "Data Offset"
100: "Reserved"
```

- [ ] **Step 3.11: Run test**

Expected: PASS for both fixtures.

- [ ] **Step 3.12: Discipline gates**

```bash
Scripts/check-diagnostic-discipline.sh
Scripts/check-file-sizes.sh
```

- [ ] **Step 3.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidPacketExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Packet.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-packet/

git commit -m "$(cat <<'EOF'
Add Mermaid packet exporter

Wave 1: rows flatten to start-end: "label" lines, sorted by start
bit. Single-bit blocks (start == end) emit as bare integer.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Journey Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidJourneyExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Journey.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-journey/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-journey/02-multi-section.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 4.1: Add fixture `01-basic.md`**

```
journey
    title My day
    section Morning
      Wake up: 5: Me
      Coffee: 3: Me
```

- [ ] **Step 4.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `journey` source from a `JourneyDiagram`.
///
/// Lossless: title → accessibility metadata → tasks grouped under
/// their `section` field with section transitions emitted as
/// `section <name>` lines. Empty section (`""`) emits raw tasks
/// without a `section` header.
enum MermaidJourneyExport {

    static func emit(_ model: JourneyDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "journey\n", diagnostics: [])
    }
}
```

- [ ] **Step 4.3: Wire dispatch**

`.journey` to `supportedDiagramTypes`; switch arm:

```swift
case .journey(let model):
    result = try MermaidJourneyExport.emit(model)
```

- [ ] **Step 4.4: Diff arm**

```swift
import DiagramKitModel

func diffJourneyDiagram(_ a: JourneyDiagram, _ b: JourneyDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.title != b.title {
        deltas.append(.unexpected(
            path: "journey.title",
            detail: "lhs=\(a.title ?? "nil") rhs=\(b.title ?? "nil")"
        ))
    }
    if a.tasks.count != b.tasks.count {
        deltas.append(.unexpected(
            path: "journey.tasks.count",
            detail: "lhs=\(a.tasks.count) rhs=\(b.tasks.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.tasks, b.tasks).enumerated() {
        if l.section != r.section || l.task != r.task || l.score != r.score || l.people != r.people {
            deltas.append(.unexpected(
                path: "journey.tasks[\(i)]",
                detail: "lhs=[\(l.section)]\(l.task):\(l.score):\(l.people) rhs=[\(r.section)]\(r.task):\(r.score):\(r.people)"
            ))
        }
    }
    return deltas
}
```

Add to `DiagramDocumentDiff.swift`:

```swift
case (.journey(let lhs), .journey(let rhs)):
    deltas.append(contentsOf: diffJourneyDiagram(lhs, rhs))
```

- [ ] **Step 4.5: Register cell**

```swift
static let mermaidJourney = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: DiagramType.journey,
    allowedLosses: []
)
```

- [ ] **Step 4.6: Register test**

```swift
@Test(
    "Mermaid journey round-trip",
    arguments: try fixtures(for: "mermaid-journey", fromRoot: roundTripResourcesRoot())
)
func mermaidJourney(fixture: RoundTripFixture) throws {
    try runSameFormatRoundTrip(
        cell: RoundTripCellRegistry.mermaidJourney,
        fixture: fixture
    )
}
```

- [ ] **Step 4.7: Run test, confirm RED**

Expected: FAIL on `journey.tasks.count`.

- [ ] **Step 4.8: Implement emit (local section transition)**

```swift
static func emit(_ model: JourneyDiagram) throws -> DiagramExportResult {
    var lines: [String] = ["journey"]
    var diagnostics: [DiagramDiagnostic] = []

    if let title = model.title, !title.isEmpty {
        lines.append("    title \(singleLine(title))")
    }
    if let accTitle = model.accTitle, !accTitle.isEmpty {
        lines.append("    accTitle: \(singleLine(accTitle))")
    }
    if let accDescr = model.accDescr, !accDescr.isEmpty {
        if accDescr.contains("\n") {
            lines.append("    accDescr: {")
            for sub in accDescr.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("        \(sub)")
            }
            lines.append("    }")
        } else {
            lines.append("    accDescr: \(accDescr)")
        }
    }

    var currentSection: String? = nil
    for task in model.tasks {
        if task.section != currentSection {
            if !task.section.isEmpty {
                lines.append("    section \(singleLine(task.section))")
            }
            currentSection = task.section
        }
        let people = task.people.joined(separator: ",")
        lines.append("      \(singleLine(task.task)): \(task.score): \(people)")
    }

    let source = lines.joined(separator: "\n") + "\n"
    return DiagramExportResult(source: source, diagnostics: diagnostics)
}

private static func singleLine(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\r\n", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
}
```

- [ ] **Step 4.9: Run test, confirm GREEN**

Expected: PASS.

- [ ] **Step 4.10: Add fixture `02-multi-section.md`**

```
journey
    title End-to-end day
    section Work
      Standup: 3: Team
      Code review: 4: Self,Reviewer
      Lunch: 5: Self
    section Evening
      Workout: 4: Self
      Dinner: 5: Family
      Read: 5: Self
```

- [ ] **Step 4.11: Run test**

Expected: PASS for both fixtures.

- [ ] **Step 4.12: Discipline gates**

- [ ] **Step 4.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidJourneyExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Journey.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-journey/

git commit -m "$(cat <<'EOF'
Add Mermaid journey exporter

Wave 1: tasks grouped under their section field via lazy section-line
transitions. Empty-section tasks emit raw without a section header.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Timeline Exporter (extracts section helper)

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidTimelineExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Timeline.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-timeline/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-timeline/02-multi-period.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`,
  `MermaidExportHelpers.swift`, `MermaidJourneyExport.swift`

- [ ] **Step 5.1: Add fixture `01-basic.md`**

```
timeline
    title History of Social Media
    2002 : LinkedIn
    2004 : Facebook
    2005 : Youtube
    2006 : Twitter
```

- [ ] **Step 5.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `timeline` source from a `TimelineDiagram`.
///
/// Lossless: title → accessibility metadata → tasks grouped under
/// their section field, with each task's events emitted on the same
/// line joined by `:` separators. Section transitions follow the
/// same lazy pattern as the journey exporter.
enum MermaidTimelineExport {

    static func emit(_ model: TimelineDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "timeline\n", diagnostics: [])
    }
}
```

- [ ] **Step 5.3: Wire dispatch**

`.timeline` to `supportedDiagramTypes`; switch arm:

```swift
case .timeline(let model):
    result = try MermaidTimelineExport.emit(model)
```

- [ ] **Step 5.4: Diff arm**

```swift
import DiagramKitModel

func diffTimelineDiagram(_ a: TimelineDiagram, _ b: TimelineDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "timeline.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.tasks.count != b.tasks.count {
        deltas.append(.unexpected(
            path: "timeline.tasks.count",
            detail: "lhs=\(a.tasks.count) rhs=\(b.tasks.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.tasks, b.tasks).enumerated() {
        if l.section != r.section || l.text != r.text {
            deltas.append(.unexpected(
                path: "timeline.tasks[\(i)]",
                detail: "lhs=[\(l.section)]\(l.text) rhs=[\(r.section)]\(r.text)"
            ))
        }
        if l.events.count != r.events.count {
            deltas.append(.unexpected(
                path: "timeline.tasks[\(i)].events.count",
                detail: "lhs=\(l.events.count) rhs=\(r.events.count)"
            ))
            continue
        }
        for (j, (le, re)) in zip(l.events, r.events).enumerated() {
            if le.text != re.text {
                deltas.append(.unexpected(
                    path: "timeline.tasks[\(i)].events[\(j)]",
                    detail: "lhs=\(le.text) rhs=\(re.text)"
                ))
            }
        }
    }
    return deltas
}
```

Add to `DiagramDocumentDiff.swift`:

```swift
case (.timeline(let lhs), .timeline(let rhs)):
    deltas.append(contentsOf: diffTimelineDiagram(lhs, rhs))
```

- [ ] **Step 5.5: Register cell**

```swift
static let mermaidTimeline = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: DiagramType.timeline,
    allowedLosses: []
)
```

- [ ] **Step 5.6: Register test**

```swift
@Test(
    "Mermaid timeline round-trip",
    arguments: try fixtures(for: "mermaid-timeline", fromRoot: roundTripResourcesRoot())
)
func mermaidTimeline(fixture: RoundTripFixture) throws {
    try runSameFormatRoundTrip(
        cell: RoundTripCellRegistry.mermaidTimeline,
        fixture: fixture
    )
}
```

- [ ] **Step 5.7: Run test, confirm RED**

Expected: FAIL on `timeline.tasks.count`.

- [ ] **Step 5.8: Implement emit**

```swift
static func emit(_ model: TimelineDiagram) throws -> DiagramExportResult {
    var lines: [String] = ["timeline"]
    var diagnostics: [DiagramDiagnostic] = []

    if let title = model.diagramTitle, !title.isEmpty {
        lines.append("    title \(singleLine(title))")
    }
    if let accTitle = model.accTitle, !accTitle.isEmpty {
        lines.append("    accTitle: \(singleLine(accTitle))")
    }
    if let accDescr = model.accDescr, !accDescr.isEmpty {
        if accDescr.contains("\n") {
            lines.append("    accDescr: {")
            for sub in accDescr.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("        \(sub)")
            }
            lines.append("    }")
        } else {
            lines.append("    accDescr: \(accDescr)")
        }
    }

    var currentSection: String? = nil
    for task in model.tasks {
        if task.section != currentSection {
            if !task.section.isEmpty {
                lines.append("    section \(singleLine(task.section))")
            }
            currentSection = task.section
        }
        let eventStrings = task.events.map { singleLine($0.text) }
        let head = "    \(singleLine(task.text))"
        if eventStrings.isEmpty {
            lines.append(head)
        } else {
            lines.append("\(head) : \(eventStrings.joined(separator: " : "))")
        }
    }

    let source = lines.joined(separator: "\n") + "\n"
    return DiagramExportResult(source: source, diagnostics: diagnostics)
}

private static func singleLine(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\r\n", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
}
```

- [ ] **Step 5.9: Run test, confirm GREEN**

Expected: PASS.

- [ ] **Step 5.10: Extract `emitSectionedItems` helper**

Second caller has appeared — extract the section-transition pattern.
Add to `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidExportHelpers.swift`,
before the final closing brace of `MermaidExportHelpers`:

```swift
// MARK: - Sectioned item emission

/// Emit a sequence of items grouped under section transitions. The
/// section name is read from each item; whenever it differs from the
/// previous item's section, a `section <name>` line is emitted with
/// the supplied indent. Empty section names (`""`) suppress the
/// section header but still reset `currentSection`.
///
/// Used by journey and timeline (Wave 1), kanban (Wave 1, partial),
/// and eventModeling (Wave 2).
static func emitSectionedItems<Item>(
    _ items: [Item],
    sectionOf: (Item) -> String,
    sectionIndent: String,
    sectionKeyword: String = "section",
    emitItem: (Item) -> String
) -> [String] {
    var lines: [String] = []
    var currentSection: String? = nil
    for item in items {
        let section = sectionOf(item)
        if section != currentSection {
            if !section.isEmpty {
                lines.append("\(sectionIndent)\(sectionKeyword) \(section)")
            }
            currentSection = section
        }
        lines.append(emitItem(item))
    }
    return lines
}
```

- [ ] **Step 5.11: Refactor journey and timeline to use the helper**

In `MermaidJourneyExport.swift`, replace the `var currentSection ...
for task in model.tasks { ... }` block with:

```swift
let taskLines = MermaidExportHelpers.emitSectionedItems(
    model.tasks,
    sectionOf: { singleLine($0.section) },
    sectionIndent: "    ",
    emitItem: { task in
        let people = task.people.joined(separator: ",")
        return "      \(singleLine(task.task)): \(task.score): \(people)"
    }
)
lines.append(contentsOf: taskLines)
```

In `MermaidTimelineExport.swift`, replace the equivalent block with:

```swift
let taskLines = MermaidExportHelpers.emitSectionedItems(
    model.tasks,
    sectionOf: { singleLine($0.section) },
    sectionIndent: "    ",
    emitItem: { task in
        let eventStrings = task.events.map { singleLine($0.text) }
        let head = "    \(singleLine(task.text))"
        if eventStrings.isEmpty {
            return head
        }
        return "\(head) : \(eventStrings.joined(separator: " : "))"
    }
)
lines.append(contentsOf: taskLines)
```

- [ ] **Step 5.12: Run journey + timeline tests, confirm still GREEN**

```bash
swift test --filter SameFormatRoundTripTests/mermaidJourney
swift test --filter SameFormatRoundTripTests/mermaidTimeline
```
Expected: PASS for both.

- [ ] **Step 5.13: Add fixture `02-multi-period.md`**

```
timeline
    title Tech eras
    section 1990s
      Web 1.0 : HTML : Netscape : AOL
    section 2000s
      Web 2.0 : Blogs : Wikipedia : Facebook
    section 2010s
      Mobile : iPhone : Android
    section 2020s
      AI : GPT : Diffusion models
```

- [ ] **Step 5.14: Run timeline test, confirm GREEN**

Expected: PASS for both fixtures.

- [ ] **Step 5.15: Discipline gates**

- [ ] **Step 5.16: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidTimelineExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidJourneyExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidExportHelpers.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Timeline.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-timeline/

git commit -m "$(cat <<'EOF'
Add Mermaid timeline exporter + section-emission helper

Wave 1: timeline tasks group under sections, events joined inline
with ` : ` separators. Extracts emitSectionedItems helper now that
journey is a second caller of the section-transition pattern.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Kanban Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidKanbanExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Kanban.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-kanban/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-kanban/02-metadata.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 6.1: Add fixture `01-basic.md`**

```
kanban
    todo[Todo]
        item1[Buy milk]
        item2[Call dentist]
    doing[In Progress]
        item3[Cook dinner]
    done[Done]
        item4[Pay rent]
```

- [ ] **Step 6.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `kanban` source from a `KanbanDiagram`.
///
/// Lossless: each section emits as a column header at indent 4, with
/// its child nodes at indent 8. Metadata (`assigned`, `ticket`,
/// `priority`) is emitted as a sorted `@{ ... }` block on the line
/// following the node label. CSS classes and icons travel inline
/// where the parser supports them.
enum MermaidKanbanExport {

    static func emit(_ model: KanbanDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "kanban\n", diagnostics: [])
    }
}
```

- [ ] **Step 6.3: Wire dispatch**

`.kanban` to `supportedDiagramTypes`; switch arm:

```swift
case .kanban(let model):
    result = try MermaidKanbanExport.emit(model)
```

- [ ] **Step 6.4: Diff arm**

```swift
import DiagramKitModel

func diffKanbanDiagram(_ a: KanbanDiagram, _ b: KanbanDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "kanban.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.sections.count != b.sections.count {
        deltas.append(.unexpected(
            path: "kanban.sections.count",
            detail: "lhs=\(a.sections.count) rhs=\(b.sections.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.sections, b.sections).enumerated() {
        if l.id != r.id || l.label != r.label {
            deltas.append(.unexpected(
                path: "kanban.sections[\(i)]",
                detail: "lhs=\(l.id):\(l.label) rhs=\(r.id):\(r.label)"
            ))
        }
    }
    if a.nodes.count != b.nodes.count {
        deltas.append(.unexpected(
            path: "kanban.nodes.count",
            detail: "lhs=\(a.nodes.count) rhs=\(b.nodes.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.nodes, b.nodes).enumerated() {
        if l.id != r.id
            || l.label != r.label
            || l.parentId != r.parentId
            || l.assigned != r.assigned
            || l.ticket != r.ticket
            || l.priority != r.priority {
            deltas.append(.unexpected(
                path: "kanban.nodes[\(i)]",
                detail: "lhs=\(l.id):\(l.label) parent=\(l.parentId ?? "nil") meta=[\(l.assigned ?? "")|\(l.ticket ?? "")|\(l.priority ?? "")] rhs=\(r.id):\(r.label) parent=\(r.parentId ?? "nil") meta=[\(r.assigned ?? "")|\(r.ticket ?? "")|\(r.priority ?? "")]"
            ))
        }
    }
    return deltas
}
```

Add to `DiagramDocumentDiff.swift`:

```swift
case (.kanban(let lhs), .kanban(let rhs)):
    deltas.append(contentsOf: diffKanbanDiagram(lhs, rhs))
```

- [ ] **Step 6.5: Register cell**

```swift
static let mermaidKanban = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: DiagramType.kanban,
    allowedLosses: []
)
```

- [ ] **Step 6.6: Register test**

```swift
@Test(
    "Mermaid kanban round-trip",
    arguments: try fixtures(for: "mermaid-kanban", fromRoot: roundTripResourcesRoot())
)
func mermaidKanban(fixture: RoundTripFixture) throws {
    try runSameFormatRoundTrip(
        cell: RoundTripCellRegistry.mermaidKanban,
        fixture: fixture
    )
}
```

- [ ] **Step 6.7: Run test, confirm RED**

Expected: FAIL on `kanban.sections.count`.

- [ ] **Step 6.8: Implement emit**

```swift
static func emit(_ model: KanbanDiagram) throws -> DiagramExportResult {
    var lines: [String] = ["kanban"]
    var diagnostics: [DiagramDiagnostic] = []

    if let title = model.diagramTitle, !title.isEmpty {
        lines.append("    title \(singleLine(title))")
    }
    if let accTitle = model.accTitle, !accTitle.isEmpty {
        lines.append("    accTitle: \(singleLine(accTitle))")
    }
    if let accDescr = model.accDescr, !accDescr.isEmpty {
        if accDescr.contains("\n") {
            lines.append("    accDescr: {")
            for sub in accDescr.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("        \(sub)")
            }
            lines.append("    }")
        } else {
            lines.append("    accDescr: \(accDescr)")
        }
    }

    for section in model.sections {
        lines.append("    \(section.id)[\(escapeLabel(section.label))]")
        let children = model.nodes.filter { $0.parentId == section.id }
        for node in children {
            lines.append("        \(node.id)[\(escapeLabel(node.label))]")
            let meta = formatMetadata(node)
            if !meta.isEmpty {
                lines.append("        \(node.id)@{ \(meta) }")
            }
        }
    }

    let source = lines.joined(separator: "\n") + "\n"
    return DiagramExportResult(source: source, diagnostics: diagnostics)
}

private static func escapeLabel(_ text: String) -> String {
    let (escaped, _) = MermaidExportHelpers.escapeBracketLabel(text)
    return escaped
}

/// Metadata keys are emitted in fixed alphabetical order (per spec
/// canonicalization) so the round-trip is stable regardless of the
/// order the parser populated `KanbanNode`.
private static func formatMetadata(_ node: KanbanNode) -> String {
    var pairs: [(String, String)] = []
    if let assigned = node.assigned, !assigned.isEmpty {
        pairs.append(("assigned", assigned))
    }
    if let priority = node.priority, !priority.isEmpty {
        pairs.append(("priority", priority))
    }
    if let ticket = node.ticket, !ticket.isEmpty {
        pairs.append(("ticket", ticket))
    }
    return pairs.map { "\($0.0): '\($0.1)'" }.joined(separator: ", ")
}

private static func singleLine(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\r\n", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
}
```

- [ ] **Step 6.9: Run test, confirm GREEN**

Expected: PASS.

- [ ] **Step 6.10: Add fixture `02-metadata.md`**

```
kanban
    todo[Todo]
        t1[Refactor parser]
        t1@{ assigned: 'alice', priority: 'High', ticket: 'PROJ-1' }
    doing[Doing]
        d1[Run benchmarks]
        d1@{ assigned: 'bob', ticket: 'PROJ-2' }
    done[Done]
        e1[Ship docs]
        e1@{ priority: 'Low' }
```

- [ ] **Step 6.11: Run test, confirm GREEN**

Expected: PASS for both fixtures.

- [ ] **Step 6.12: Discipline gates**

- [ ] **Step 6.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidKanbanExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Kanban.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-kanban/

git commit -m "$(cat <<'EOF'
Add Mermaid kanban exporter

Wave 1: sections emit as bracketed column headers at indent 4, with
child nodes nested at indent 8. Metadata (assigned / priority /
ticket) emits in fixed alphabetical order via @{ ... } block.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Mindmap Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidMindmapExport.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-mindmap/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-mindmap/02-nested.md`
- Modify: `MermaidExporter.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`
- Note: `DiagramDocumentDiff+Mindmap.swift` already exists; no
  changes needed to `DiagramDocumentDiff.swift`.

- [ ] **Step 7.1: Add fixture `01-basic.md`**

```
mindmap
  root((mindmap))
    Origins
      Long history
      Popularisation
    Research
```

- [ ] **Step 7.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `mindmap` source from a `MindmapDiagram`.
///
/// Walks the tree rooted at `model.root` and emits one node per line
/// indented by `node.level * 2` spaces. Node shape is encoded via
/// the bracket pair that wraps the label (`((double-round))`,
/// `[square]`, `(round)`, etc.).
enum MermaidMindmapExport {

    static func emit(_ model: MindmapDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "mindmap\n", diagnostics: [])
    }
}
```

- [ ] **Step 7.3: Wire dispatch**

`.mindmap` to `supportedDiagramTypes`; switch arm:

```swift
case .mindmap(let model):
    result = try MermaidMindmapExport.emit(model)
```

- [ ] **Step 7.4: (no diff arm needed)**

`DiagramDocumentDiff+Mindmap.swift` already exists and the
`.mindmap` arm is already registered in `DiagramDocumentDiff.swift`.

- [ ] **Step 7.5: Register cell**

```swift
static let mermaidMindmap = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: DiagramType.mindmap,
    allowedLosses: []
)
```

- [ ] **Step 7.6: Register test**

```swift
@Test(
    "Mermaid mindmap round-trip",
    arguments: try fixtures(for: "mermaid-mindmap", fromRoot: roundTripResourcesRoot())
)
func mermaidMindmap(fixture: RoundTripFixture) throws {
    try runSameFormatRoundTrip(
        cell: RoundTripCellRegistry.mermaidMindmap,
        fixture: fixture
    )
}
```

- [ ] **Step 7.7: Run test, confirm RED**

Run: `swift test --filter SameFormatRoundTripTests/mermaidMindmap`
Expected: FAIL on `root.descr` (stub emits no children).

- [ ] **Step 7.8: Implement emit (local tree walk)**

```swift
static func emit(_ model: MindmapDiagram) throws -> DiagramExportResult {
    var lines: [String] = ["mindmap"]
    var diagnostics: [DiagramDiagnostic] = []

    guard let root = model.root else {
        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    emitNode(root, indentLevel: 1, lines: &lines)

    let source = lines.joined(separator: "\n") + "\n"
    return DiagramExportResult(source: source, diagnostics: diagnostics)
}

private static func emitNode(
    _ node: MindmapNode,
    indentLevel: Int,
    lines: inout [String]
) {
    let indent = String(repeating: " ", count: indentLevel * 2)
    lines.append("\(indent)\(formatNodeLabel(node))")
    for child in node.children {
        emitNode(child, indentLevel: indentLevel + 1, lines: &lines)
    }
}

private static func formatNodeLabel(_ node: MindmapNode) -> String {
    let label = singleLine(node.descr)
    let escapedID = node.nodeId
    let body: String
    switch node.type {
    case .roundedRect:
        body = "\(escapedID)(\(label))"
    case .rect:
        body = "\(escapedID)[\(label)]"
    case .circle:
        body = "\(escapedID)((\(label)))"
    case .cloud:
        body = "\(escapedID))\(label)("
    case .bang:
        body = "\(escapedID)))\(label)(("
    case .hexagon:
        body = "\(escapedID){{\(label)}}"
    case .`default`:
        body = "\(escapedID)\(label)"
    }
    return body
}

private static func singleLine(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\r\n", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
}
```

> **Type alignment note.** `MindmapNodeType`'s default case spelling
> varies across the codebase (`KanbanNodeShape` uses `default_` with
> an underscore; `MindmapNodeType` may use either `default_` or the
> backtick-escaped `` `default` ``). The switch above uses
> `` `default` `` — if Swift rejects it because the source enum spells
> it `default_`, change the arm to `case .default_:`. The compile
> error will pinpoint it; do not guess.

- [ ] **Step 7.9: Run test, confirm GREEN**

Run: `swift test --filter SameFormatRoundTripTests/mermaidMindmap`
Expected: PASS.

- [ ] **Step 7.10: Add fixture `02-nested.md`**

```
mindmap
  root((Project plan))
    Phase 1
      Discovery
      Research
        Stakeholder interviews
        Competitor analysis
      Synthesis
    Phase 2
      Design
        Wireframes
        Prototypes
      Validation
    Phase 3
      Launch
```

- [ ] **Step 7.11: Run test, confirm GREEN**

Expected: PASS for both fixtures.

- [ ] **Step 7.12: Discipline gates**

- [ ] **Step 7.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidMindmapExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-mindmap/

git commit -m "$(cat <<'EOF'
Add Mermaid mindmap exporter

Wave 1: tree walk from model.root, emitting one node per line with
indentation = level * 2 spaces. Shape encoded via bracket pair.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Treemap Exporter (extracts indent helper)

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidTreemapExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Treemap.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-treemap/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-treemap/02-nested-values.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`,
  `MermaidExportHelpers.swift`, `MermaidMindmapExport.swift`

- [ ] **Step 8.1: Add fixture `01-basic.md`**

```
treemap-beta
"Section 1"
    "Leaf 1.1": 12
    "Leaf 1.2": 8
"Section 2"
    "Leaf 2.1": 15
    "Leaf 2.2": 5
```

- [ ] **Step 8.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `treemap-beta` source from a `TreemapDiagram`.
///
/// Walks the tree forest (top-level `model.nodes`) and emits one
/// node per line. Indent level = depth × 4 spaces. Leaf nodes
/// (value present, no children) emit as `"name": value`; branch
/// nodes emit as `"name"` and recurse into `children`.
enum MermaidTreemapExport {

    static func emit(_ model: TreemapDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "treemap-beta\n", diagnostics: [])
    }
}
```

- [ ] **Step 8.3: Wire dispatch**

`.treemap` to `supportedDiagramTypes`; switch arm:

```swift
case .treemap(let model):
    result = try MermaidTreemapExport.emit(model)
```

- [ ] **Step 8.4: Diff arm**

```swift
import DiagramKitModel

func diffTreemapDiagram(_ a: TreemapDiagram, _ b: TreemapDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "treemap.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.nodes.count != b.nodes.count {
        deltas.append(.unexpected(
            path: "treemap.nodes.count",
            detail: "lhs=\(a.nodes.count) rhs=\(b.nodes.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.nodes, b.nodes).enumerated() {
        diffTreemapNode(l, r, path: "treemap.nodes[\(i)]", deltas: &deltas)
    }
    return deltas
}

private func diffTreemapNode(
    _ a: TreemapNode,
    _ b: TreemapNode,
    path: String,
    deltas: inout [RoundTripDelta]
) {
    if a.name != b.name {
        deltas.append(.unexpected(
            path: "\(path).name",
            detail: "lhs=\(a.name) rhs=\(b.name)"
        ))
    }
    if a.value != b.value {
        deltas.append(.unexpected(
            path: "\(path).value",
            detail: "lhs=\(a.value.map(String.init) ?? "nil") rhs=\(b.value.map(String.init) ?? "nil")"
        ))
    }
    let aChildren = a.children ?? []
    let bChildren = b.children ?? []
    if aChildren.count != bChildren.count {
        deltas.append(.unexpected(
            path: "\(path).children.count",
            detail: "lhs=\(aChildren.count) rhs=\(bChildren.count)"
        ))
        return
    }
    for (i, (l, r)) in zip(aChildren, bChildren).enumerated() {
        diffTreemapNode(l, r, path: "\(path).children[\(i)]", deltas: &deltas)
    }
}
```

Add to `DiagramDocumentDiff.swift`:

```swift
case (.treemap(let lhs), .treemap(let rhs)):
    deltas.append(contentsOf: diffTreemapDiagram(lhs, rhs))
```

- [ ] **Step 8.5: Register cell**

```swift
static let mermaidTreemap = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: DiagramType.treemap,
    allowedLosses: []
)
```

- [ ] **Step 8.6: Register test**

```swift
@Test(
    "Mermaid treemap round-trip",
    arguments: try fixtures(for: "mermaid-treemap", fromRoot: roundTripResourcesRoot())
)
func mermaidTreemap(fixture: RoundTripFixture) throws {
    try runSameFormatRoundTrip(
        cell: RoundTripCellRegistry.mermaidTreemap,
        fixture: fixture
    )
}
```

- [ ] **Step 8.7: Run test, confirm RED**

Expected: FAIL on `treemap.nodes.count`.

- [ ] **Step 8.8: Implement emit (local recursion)**

```swift
static func emit(_ model: TreemapDiagram) throws -> DiagramExportResult {
    var lines: [String] = ["treemap-beta"]
    var diagnostics: [DiagramDiagnostic] = []

    if let title = model.diagramTitle, !title.isEmpty {
        lines.append("    title \(singleLine(title))")
    }

    for node in model.nodes {
        emitNode(node, depth: 0, lines: &lines)
    }

    let source = lines.joined(separator: "\n") + "\n"
    return DiagramExportResult(source: source, diagnostics: diagnostics)
}

private static func emitNode(
    _ node: TreemapNode,
    depth: Int,
    lines: inout [String]
) {
    let indent = String(repeating: "    ", count: depth)
    let name = "\"\(node.name.replacingOccurrences(of: "\"", with: "\\\""))\""
    if let value = node.value, (node.children == nil || node.children!.isEmpty) {
        let formatted = value.rounded() == value && abs(value) < 1e15
            ? String(Int64(value))
            : String(value)
        lines.append("\(indent)\(name): \(formatted)")
    } else {
        lines.append("\(indent)\(name)")
        for child in node.children ?? [] {
            emitNode(child, depth: depth + 1, lines: &lines)
        }
    }
}

private static func singleLine(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\r\n", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
}
```

- [ ] **Step 8.9: Run test, confirm GREEN**

Expected: PASS.

- [ ] **Step 8.10: Extract `emitIndentedTree` helper**

Second tree caller has appeared. Add to
`MermaidExportHelpers.swift`:

```swift
// MARK: - Indent-based tree emission

/// Emit a tree as indented lines. For each node, `emitNode` returns
/// the line content (no indent); `childrenOf` returns the node's
/// children. The helper prepends `indentUnit` repeated `depth` times.
///
/// Used by mindmap and treemap (Wave 1), treeView and block
/// (Wave 3).
static func emitIndentedTree<Node>(
    roots: [Node],
    indentUnit: String,
    startDepth: Int = 0,
    childrenOf: (Node) -> [Node],
    emitNode: (Node, Int) -> [String]
) -> [String] {
    var lines: [String] = []
    func walk(_ node: Node, _ depth: Int) {
        let indent = String(repeating: indentUnit, count: depth)
        for line in emitNode(node, depth) {
            lines.append("\(indent)\(line)")
        }
        for child in childrenOf(node) {
            walk(child, depth + 1)
        }
    }
    for root in roots {
        walk(root, startDepth)
    }
    return lines
}
```

- [ ] **Step 8.11: Refactor treemap to use the helper**

In `MermaidTreemapExport.swift`, replace the recursive `emitNode`
plus the `for node in model.nodes { emitNode(node, ...) }` block
with:

```swift
let treeLines = MermaidExportHelpers.emitIndentedTree(
    roots: model.nodes,
    indentUnit: "    ",
    childrenOf: { $0.children ?? [] },
    emitNode: { node, _ in
        let name = "\"\(node.name.replacingOccurrences(of: "\"", with: "\\\""))\""
        if let value = node.value, (node.children == nil || node.children!.isEmpty) {
            let formatted = value.rounded() == value && abs(value) < 1e15
                ? String(Int64(value))
                : String(value)
            return ["\(name): \(formatted)"]
        }
        return [name]
    }
)
lines.append(contentsOf: treeLines)
```

Delete the now-unused private `emitNode` from `MermaidTreemapExport`.

- [ ] **Step 8.12: Refactor mindmap to use the helper**

In `MermaidMindmapExport.swift`, replace `emit(_:)` body's tree walk
with:

```swift
static func emit(_ model: MindmapDiagram) throws -> DiagramExportResult {
    var lines: [String] = ["mindmap"]
    let diagnostics: [DiagramDiagnostic] = []

    guard let root = model.root else {
        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    let treeLines = MermaidExportHelpers.emitIndentedTree(
        roots: [root],
        indentUnit: "  ",
        startDepth: 1,
        childrenOf: { $0.children },
        emitNode: { node, _ in [formatNodeLabel(node)] }
    )
    lines.append(contentsOf: treeLines)

    let source = lines.joined(separator: "\n") + "\n"
    return DiagramExportResult(source: source, diagnostics: diagnostics)
}
```

Delete the now-unused private `emitNode` from `MermaidMindmapExport`.

- [ ] **Step 8.13: Run mindmap + treemap tests, confirm GREEN**

```bash
swift test --filter SameFormatRoundTripTests/mermaidMindmap
swift test --filter SameFormatRoundTripTests/mermaidTreemap
```
Expected: PASS for both.

- [ ] **Step 8.14: Add fixture `02-nested-values.md`**

```
treemap-beta
"Engineering"
    "Backend"
        "API": 40
        "DB": 25
    "Frontend"
        "Web": 30
        "Mobile": 15
"Sales"
    "EMEA": 50
    "AMER": 70
"Support": 10
```

- [ ] **Step 8.15: Run treemap test**

Expected: PASS for both fixtures.

- [ ] **Step 8.16: Discipline gates**

- [ ] **Step 8.17: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidTreemapExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidMindmapExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidExportHelpers.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Treemap.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-treemap/

git commit -m "$(cat <<'EOF'
Add Mermaid treemap exporter + indent-tree helper

Wave 1: treemap-beta forest emitted as nested indented lines; leaves
carry "name": value, branches recurse. Extracts the emitIndentedTree
helper now that mindmap is a second caller of the tree-walk pattern.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: GitGraph Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidGitGraphExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+GitGraph.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-gitgraph/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-gitgraph/02-branches.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 9.1: Add fixture `01-basic.md`**

```
gitGraph
    commit
    commit
    branch develop
    checkout develop
    commit
    checkout main
    merge develop
    commit
```

- [ ] **Step 9.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `gitGraph` source from a `GitGraphDiagram`.
///
/// Re-emits `model.statements` in source order: `commit`, `branch`,
/// `checkout`, `merge`, `cherry-pick`. The statement stream is the
/// canonical history form; `commits` / `branches` / `branchHeads`
/// are derived state and are not re-emitted directly.
enum MermaidGitGraphExport {

    static func emit(_ model: GitGraphDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "gitGraph\n", diagnostics: [])
    }
}
```

- [ ] **Step 9.3: Wire dispatch**

`.gitGraph` to `supportedDiagramTypes`; switch arm:

```swift
case .gitGraph(let model):
    result = try MermaidGitGraphExport.emit(model)
```

- [ ] **Step 9.4: Diff arm**

```swift
import DiagramKitModel

func diffGitGraphDiagram(_ a: GitGraphDiagram, _ b: GitGraphDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "gitGraph.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.direction != b.direction {
        deltas.append(.unexpected(
            path: "gitGraph.direction",
            detail: "lhs=\(a.direction) rhs=\(b.direction)"
        ))
    }

    // Compare commits by (id, branch, type, tags, parents). Use a
    // set on a normalized string so insertion order is irrelevant to
    // equality but mismatches still surface useful detail.
    func commitKey(_ c: GitGraphCommit) -> String {
        let tags = c.tags.sorted().joined(separator: ",")
        let parents = c.parents.sorted().joined(separator: ",")
        return "\(c.id)|\(c.branch)|\(c.type)|tags=\(tags)|parents=\(parents)"
    }
    let lhsCommits = Set(a.commits.map(commitKey))
    let rhsCommits = Set(b.commits.map(commitKey))
    if lhsCommits != rhsCommits {
        let onlyLhs = lhsCommits.subtracting(rhsCommits).sorted()
        let onlyRhs = rhsCommits.subtracting(lhsCommits).sorted()
        deltas.append(.unexpected(
            path: "gitGraph.commits",
            detail: "onlyLhs=\(onlyLhs.joined(separator: ";")) onlyRhs=\(onlyRhs.joined(separator: ";"))"
        ))
    }

    let lhsBranches = Set(a.branches)
    let rhsBranches = Set(b.branches)
    if lhsBranches != rhsBranches {
        deltas.append(.unexpected(
            path: "gitGraph.branches",
            detail: "onlyLhs=\(lhsBranches.subtracting(rhsBranches).sorted()) onlyRhs=\(rhsBranches.subtracting(lhsBranches).sorted())"
        ))
    }
    return deltas
}
```

Add to `DiagramDocumentDiff.swift`:

```swift
case (.gitGraph(let lhs), .gitGraph(let rhs)):
    deltas.append(contentsOf: diffGitGraphDiagram(lhs, rhs))
```

- [ ] **Step 9.5: Register cell**

```swift
static let mermaidGitGraph = RoundTripCell(
    importer: MermaidImporter(),
    exporter: MermaidExporter(),
    family: DiagramType.gitGraph,
    allowedLosses: []
)
```

- [ ] **Step 9.6: Register test**

```swift
@Test(
    "Mermaid gitGraph round-trip",
    arguments: try fixtures(for: "mermaid-gitgraph", fromRoot: roundTripResourcesRoot())
)
func mermaidGitGraph(fixture: RoundTripFixture) throws {
    try runSameFormatRoundTrip(
        cell: RoundTripCellRegistry.mermaidGitGraph,
        fixture: fixture
    )
}
```

- [ ] **Step 9.7: Run test, confirm RED**

Expected: FAIL on `gitGraph.commits`.

- [ ] **Step 9.8: Implement emit**

```swift
static func emit(_ model: GitGraphDiagram) throws -> DiagramExportResult {
    var lines: [String] = []
    var diagnostics: [DiagramDiagnostic] = []

    var header = "gitGraph"
    switch model.direction {
    case .LR:
        header += " LR:"
    case .TB:
        header += " TB:"
    case .BT:
        header += " BT:"
    }
    lines.append(header)

    if let title = model.diagramTitle, !title.isEmpty {
        lines.append("    title \(singleLine(title))")
    }
    if let accTitle = model.accTitle, !accTitle.isEmpty {
        lines.append("    accTitle: \(singleLine(accTitle))")
    }
    if let accDescr = model.accDescr, !accDescr.isEmpty {
        if accDescr.contains("\n") {
            lines.append("    accDescr: {")
            for sub in accDescr.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("        \(sub)")
            }
            lines.append("    }")
        } else {
            lines.append("    accDescr: \(accDescr)")
        }
    }

    for stmt in model.statements {
        lines.append("    \(emitStatement(stmt))")
    }

    let source = lines.joined(separator: "\n") + "\n"
    return DiagramExportResult(source: source, diagnostics: diagnostics)
}

private static func emitStatement(_ stmt: GitGraphStatement) -> String {
    switch stmt {
    case .commit(let s):
        var parts: [String] = ["commit"]
        if s.customId {
            parts.append("id: \"\(escape(s.id))\"")
        }
        if !s.tags.isEmpty {
            for tag in s.tags {
                parts.append("tag: \"\(escape(tag))\"")
            }
        }
        switch s.type {
        case .normal: break
        case .reverse: parts.append("type: REVERSE")
        case .highlight: parts.append("type: HIGHLIGHT")
        case .merge, .cherryPick:
            // Merge/cherry-pick commits arrive via .merge / .cherryPick
            // statements, not commit statements. If we see one here
            // the parser produced an unexpected shape; flag it but
            // emit anyway.
            break
        }
        return parts.joined(separator: " ")
    case .branch(let s):
        var parts: [String] = ["branch \(s.name)"]
        if let order = s.order { parts.append("order: \(order)") }
        return parts.joined(separator: " ")
    case .checkout(let s):
        return "checkout \(s.branch)"
    case .merge(let s):
        var parts: [String] = ["merge \(s.branch)"]
        if let id = s.id { parts.append("id: \"\(escape(id))\"") }
        if let tag = s.tag { parts.append("tag: \"\(escape(tag))\"") }
        if let type = s.type {
            switch type {
            case .normal: break
            case .reverse: parts.append("type: REVERSE")
            case .highlight: parts.append("type: HIGHLIGHT")
            case .merge, .cherryPick: break
            }
        }
        return parts.joined(separator: " ")
    case .cherryPick(let s):
        var parts: [String] = ["cherry-pick id: \"\(escape(s.id))\""]
        if let tag = s.tag { parts.append("tag: \"\(escape(tag))\"") }
        if let parent = s.parent { parts.append("parent: \"\(escape(parent))\"") }
        return parts.joined(separator: " ")
    }
}

private static func escape(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}

private static func singleLine(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\r\n", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
}
```

> **Type alignment note.** `GitGraphBranchStatement.order`,
> `GitGraphMergeStatement.id` / `.tag` / `.type`, and
> `GitGraphCherryPickStatement.tag` / `.parent` are read as
> optional fields. If implementation finds the actual statement
> structs use different optionality (e.g. non-optional with sentinel
> values), adjust the conditional emits in `emitStatement` to match
> — the round-trip test will surface a mismatch immediately.

- [ ] **Step 9.9: Run test, confirm GREEN**

Expected: PASS for `01-basic.md`.

- [ ] **Step 9.10: Add fixture `02-branches.md`**

```
gitGraph
    commit id: "init"
    branch develop
    branch feature
    checkout feature
    commit tag: "v0.1"
    checkout develop
    commit
    merge feature
    checkout main
    merge develop tag: "release-1.0"
    commit type: HIGHLIGHT
```

- [ ] **Step 9.11: Run test, confirm GREEN**

Expected: PASS for both fixtures. If type-alignment notes from
Step 9.8 trigger a failure, adjust `emitStatement` to match the
actual struct shape — round-trip diff will pinpoint the field.

- [ ] **Step 9.12: Discipline gates**

- [ ] **Step 9.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidGitGraphExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+GitGraph.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-gitgraph/

git commit -m "$(cat <<'EOF'
Add Mermaid gitGraph exporter

Wave 1: re-emit statements in source order (commit / branch /
checkout / merge / cherry-pick). Direction header, accessibility
metadata, commit tags, and type modifiers preserved.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Corpus Round-Trip Test Suite

**Files:**
- Create: `Tests/DiagramKitTests/RoundTrip/CorpusRoundTripTests.swift`

- [ ] **Step 10.1: Create the corpus round-trip suite**

```swift
import Testing
import Foundation
import DiagramKit
import DiagramKitMermaid
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
import DiagramKitTestSupport

/// Exercises every Mermaid corpus entry whose family the exporter
/// supports through a parse → export → parse → assertStructurallyEqual
/// cycle. Catches contract drift across the full 397-entry corpus
/// without hand-authored fixtures.
///
/// Skips entries whose family is not yet in
/// `MermaidExporter.supportedDiagramTypes`. As wave 2 / 3 land, the
/// supported set grows and additional entries automatically join the
/// run.
@Suite("Corpus round-trip")
struct CorpusRoundTripTests {

    @Test(
        "Mermaid corpus round-trip",
        arguments: try Self.supportedCorpusEntries()
    )
    func mermaidCorpus(entry: CorpusEntry) throws {
        let importer = MermaidImporter()
        let exporter = MermaidExporter()

        let parsed = try importer.importDiagram(source: entry.source)
        let exported = try exporter.export(parsed.document)
        let reparsed = try importer.importDiagram(source: exported.source)

        let deltas = compare(parsed.document, reparsed.document)
        let blocking = deltas.filter {
            if case .loss = $0 { return false }
            return true
        }
        #expect(
            blocking.isEmpty,
            "Corpus entry \(entry.id): round-trip diverged → \(blocking)"
        )
    }

    /// All Mermaid corpus entries whose family is currently in
    /// `MermaidExporter().supportedDiagramTypes`. Loaded once per
    /// test invocation; `swift-testing` parameterises across the
    /// array.
    static func supportedCorpusEntries() throws -> [CorpusEntry] {
        let allEntries = try CorpusEntry.loadDefault()
        let supported = MermaidExporter().supportedDiagramTypes
        return allEntries.filter { entry in
            entry.format == "mermaid" && supported.contains(entry.diagramType)
        }
    }
}
```

> **Note.** `CorpusEntry.loadDefault()` is the existing helper in
> `Sources/DiagramKitTestSupport/CorpusEntry.swift`. If its API
> differs (e.g. requires an explicit Bundle), match the pattern used
> in existing corpus consumers under `Tests/DiagramKitTests/Corpus/`.

- [ ] **Step 10.2: Run the corpus suite**

Run: `swift test --filter CorpusRoundTripTests`
Expected: PASS for every Mermaid corpus entry whose family is in
`supportedDiagramTypes` (16 families after wave 1 commits).

If any entry fails, the failure pinpoints the diverging field via
the per-family diff. Fix the exporter (not the corpus); commit the
exporter fix as a separate commit referencing the corpus entry id.

- [ ] **Step 10.3: Commit the corpus suite**

```bash
git add Tests/DiagramKitTests/RoundTrip/CorpusRoundTripTests.swift

git commit -m "$(cat <<'EOF'
Add corpus round-trip regression suite

Parameterises a Mermaid parse → export → parse → assertStructurallyEqual
cycle across every corpus entry whose family is in
MermaidExporter.supportedDiagramTypes. Wave 1 enables 16 families'
worth of entries; subsequent waves auto-grow the run.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Wave 1 Closing Gates

- [ ] **Step 11.1: Full round-trip suite green**

```bash
swift test --filter SameFormatRoundTripTests
swift test --filter CorpusRoundTripTests
swift test --filter RoundTripHarnessTests
swift test --filter LossPairingTests
```
Expected: all PASS.

- [ ] **Step 11.2: Discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
```
Expected: all exit 0.

- [ ] **Step 11.3: Bootstrap smoke check**

```bash
Scripts/bootstrap-smoke-check.sh
```
Expected: exit 0. If Docker/Podman is not running locally, the
`linux-check.sh` step inside `bootstrap-smoke-check.sh` records as
skipped — that is acceptable per CLAUDE.md.

- [ ] **Step 11.4: Update BASELINES.md**

Append a Wave 1 entry to BASELINES.md noting:
- New supported families count (Mermaid Export: 7/28 → 16/28).
- 18 new round-trip fixture files.
- New `CorpusRoundTripTests` suite.

Read the current BASELINES.md to find the correct insertion point
and format. Commit:

```bash
git add BASELINES.md
git commit -m "$(cat <<'EOF'
Update BASELINES for Mermaid exporter wave 1

9 new Mermaid exporter families (pie, sankey, packet, journey,
timeline, kanban, mindmap, treemap, gitGraph) plus CorpusRoundTripTests
suite. Mermaid Export coverage: 7/28 → 16/28. COVERAGE.md updates
deferred to wave 3 closing commit per the spec.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 11.5: Announce Wave 1 complete; hand off to Wave 2**

Wave 1 lands 9 families. The implementation plan for Wave 2
(`xyChart`, `quadrantChart`, `requirement`, `radar`, `venn`,
`ishikawa`, `zenuml`, `treeView`, `eventModeling`) is authored as a
follow-up via the writing-plans skill, referencing the same source
spec.

The `default:` arm in `MermaidExporter.export(_:)` stays until
Wave 3 closes the remaining 3 families.

---

## Self-Review Checklist (executor uses on completion)

- [ ] All 9 family `case` arms present in `MermaidExporter.export(_:)`.
- [ ] `supportedDiagramTypes` contains all 9 new entries:
      `.pie, .sankey, .packet, .journey, .timeline, .kanban, .mindmap, .treemap, .gitGraph`.
- [ ] 9 new `Mermaid<Family>Export.swift` files exist; each is under
      300 lines.
- [ ] 8 new `DiagramDocumentDiff+<Family>.swift` files exist (mindmap
      pre-existed).
- [ ] `DiagramDocumentDiff.swift` switch has arms for `.pie`,
      `.sankey`, `.packet`, `.journey`, `.timeline`, `.kanban`,
      `.treemap`, `.gitGraph` (mindmap already present).
- [ ] 9 round-trip fixture directories exist with ≥ 2 fixtures each.
- [ ] 9 new cells in `RoundTripCellRegistry`.
- [ ] 9 new `@Test` methods in `SameFormatRoundTripTests`.
- [ ] `MermaidExportHelpers.swift` contains `emitSectionedItems`
      (added in Task 5) and `emitIndentedTree` (added in Task 8).
- [ ] `CorpusRoundTripTests.swift` exists and runs green.
- [ ] All discipline gates green
      (`check-diagnostic-discipline.sh`, `check-file-sizes.sh`,
      `check-sendable-annotations.sh`, `strict-concurrency-check.sh`).
- [ ] `BASELINES.md` updated.
- [ ] No raw `DiagramDiagnostic(severity:message:)` constructors
      introduced.
- [ ] No exporter throws on lossy emission (diagnostics only;
      throws reserved for impossible payloads).

---

## References

- Spec: [docs/superpowers/specs/2026-05-19-mermaid-exporter-completion-design.md](../specs/2026-05-19-mermaid-exporter-completion-design.md)
- Diagnostic discipline:
  [docs/diagnostic-severity-discipline.md](../../diagnostic-severity-discipline.md)
- Existing exemplar exporters:
  `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidFlowchartExport.swift`,
  `MermaidGanttExport.swift`.
- Round-trip harness:
  `Sources/DiagramKitTestSupport/RoundTripHarness.swift`,
  `Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift`.
- Discipline gates:
  `Scripts/check-diagnostic-discipline.sh`,
  `Scripts/check-file-sizes.sh`,
  `Scripts/bootstrap-smoke-check.sh`.

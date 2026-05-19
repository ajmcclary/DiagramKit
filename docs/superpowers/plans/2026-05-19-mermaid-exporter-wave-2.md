# Mermaid Exporter Completion — Wave 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land Mermaid-source exporters for 9 structured-but-bounded
families (`xyChart`, `quadrantChart`, `requirement`, `radar`, `venn`,
`ishikawa`, `zenuml`, `treeView`, `eventModeling`), wiring each into
the existing `RoundTripHarness`. Wave 2 closes 9 of the 12 remaining
backlog families. Mermaid Export coverage moves from 16/28 to 25/28.

**Architecture:** One file per family under
`Sources/DiagramKitMermaid/Exporter/MermaidExport/`, mirroring Wave 1.
Dispatch added to `MermaidExporter.export(_:)` arm by arm; the
umbrella `default: .unsupportedDiagram` fall-through stays until
Wave 3. Round-trip discipline is the primary acceptance gate via
two `.md` fixtures per family, structural diff via per-family
`DiagramDocumentDiff+<Family>.swift`, and the existing
`CorpusRoundTripTests` suite which auto-grows as each family lands in
`supportedDiagramTypes`. `treeView` and `ishikawa` reuse Wave 1's
`emitIndentedTree`; `eventModeling` and the other 6 families emit
linearly with no helper reuse.

**Tech Stack:** Swift 6, SwiftPM,
[swift-testing](https://github.com/swiftlang/swift-testing) for new
tests (XCTest for legacy ones), `DiagramKitTestSupport.RoundTripHarness`,
`Scripts/check-diagnostic-discipline.sh`,
`Scripts/check-file-sizes.sh`.

**Source spec:**
[docs/superpowers/specs/2026-05-19-mermaid-exporter-completion-design.md](../specs/2026-05-19-mermaid-exporter-completion-design.md)
(commit `34705b4`).

**Wave 1 plan (reference for structural template + lessons):**
[docs/superpowers/plans/2026-05-19-mermaid-exporter-wave-1.md](2026-05-19-mermaid-exporter-wave-1.md)
(commits `90253f2..780eddf`).

---

## Lessons Folded In Up-Front (from Wave 1)

These are baked into every task below; do not relearn them.

1. **No `accDescr: { ... }` block form.** Mermaid family parsers reject
   the multiline block form. Every emitter collapses multiline
   `accDescr` to a single line via `newline → space`. The plan uses a
   single `singleLine(_:)` private helper per file (no shared helper —
   each file is 1-2 lines of duplication and that's fine).
2. **Test filter form.** Always use `swift test --filter
   <ExactSuiteName>` per the `feedback_swift_test_filter` standing
   default. Substring filters that match parameterized
   `CorpusSnapshotTests` cases hang. Each task's run command names
   the exact `SameFormatRoundTripTests/<methodName>` path.
3. **Commit-by-commit on `main`.** Per `feedback_branching`. No
   branches or worktrees. Each task ends with a commit.
4. **SourceKit lag is normal.** When you add a new file to a module,
   IDE diagnostics like "Cannot find X in scope" persist briefly.
   `swift build` is the source of truth. Do not chase ghost errors.
5. **Pre-existing failures in non-Wave 1/2 exporters are
   allowlisted.** `CorpusRoundTripTests.knownFailures` already lists
   them; leave that allowlist alone unless one of your new Wave 2
   families lands in it — in which case investigate and fix the
   exporter, never expand the allowlist.
6. **Diagnostic discipline.** Only typed factories
   (`.lossyTransform`, `.featureDropped`, `.informational`). Raw
   `DiagramDiagnostic(severity:message:)` is forbidden.
   `Scripts/check-diagnostic-discipline.sh` enforces it.

---

## Wave 2 Family → Payload Type Cheat Sheet

These names come from real source inspection. Field names below the
struct are what each task's diff arm and emit code references.

| Family | `DiagramType` case | Payload struct | Top-level fields used |
|---|---|---|---|
| xyChart | `.xyChart` | `XYChart` | `diagramTitle`, `accTitle`, `accDescr`, `horizontal`, `xAxis`, `yAxis`, `series` |
| quadrantChart | `.quadrantChart` | `QuadrantChart` | `titleText`, `diagramTitle`, `accTitle`, `accDescr`, `xAxisLeftText`/`Right`, `yAxisBottomText`/`Top`, `quadrant1Text`–`quadrant4Text`, `points`, `classes` |
| requirement | `.requirement` | `RequirementDiagram` | `diagramTitle`, `accTitle`, `accDescr`, `direction`, `requirements`, `elements`, `relationships` |
| radar | `.radar` | `RadarDiagram` | `diagramTitle`, `accTitle`, `accDescr`, `axes`, `curves`, `options` |
| venn | `.venn` | `VennDiagram` | `diagramTitle`, `accTitle`, `accDescr`, `areas`, `textNodes` |
| ishikawa | `.ishikawa` | `IshikawaDiagram` | `diagramTitle`, `accTitle`, `accDescr`, `root` (`IshikawaNode?`) |
| treeView | `.treeView` | `TreeViewDiagram` | `diagramTitle`, `accTitle`, `accDescr`, `root` (`TreeViewNode`), `nodes` (flat) |
| zenuml | `.zenuml` | `ZenUMLDiagram` | `title`, `accTitle`, `accDescr`, `participants`, `groups`, `statements` (indirect enum) |
| eventModeling | `.eventModeling` | `EventModelingDiagram` | `diagramTitle`, `accTitle`, `accDescr`, `modelEntities`, `dataEntities`, `frames`, `noteEntities`, `gwtEntities` |

Note: `ZenUMLDiagram.title` (no `diagram` prefix) is the field name.
Every other Wave 2 family uses `diagramTitle`.

---

## File Structure

**Files created (Wave 2):**

```
Sources/DiagramKitMermaid/Exporter/MermaidExport/
  MermaidXYChartExport.swift          # Task 1
  MermaidQuadrantExport.swift         # Task 2
  MermaidRequirementExport.swift      # Task 3
  MermaidRadarExport.swift            # Task 4
  MermaidVennExport.swift             # Task 5
  MermaidIshikawaExport.swift         # Task 6
  MermaidTreeViewExport.swift         # Task 7
  MermaidZenUMLExport.swift           # Task 8
  MermaidEventModelingExport.swift    # Task 9

Sources/DiagramKitTestSupport/
  DiagramDocumentDiff+XYChart.swift          # Task 1
  DiagramDocumentDiff+Quadrant.swift         # Task 2
  DiagramDocumentDiff+Requirement.swift      # Task 3
  DiagramDocumentDiff+Radar.swift            # Task 4
  DiagramDocumentDiff+Venn.swift             # Task 5
  DiagramDocumentDiff+Ishikawa.swift         # Task 6
  DiagramDocumentDiff+TreeView.swift         # Task 7
  DiagramDocumentDiff+ZenUML.swift           # Task 8
  DiagramDocumentDiff+EventModeling.swift    # Task 9

Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/
  mermaid-xychart/01-basic.md, 02-bar-and-line.md
  mermaid-quadrant/01-basic.md, 02-styled-points.md
  mermaid-requirement/01-basic.md, 02-all-types.md
  mermaid-radar/01-basic.md, 02-multi-curve.md
  mermaid-venn/01-basic.md, 02-three-way.md
  mermaid-ishikawa/01-basic.md, 02-nested-causes.md
  mermaid-treeview/01-basic.md, 02-nested-with-icons.md
  mermaid-zenuml/01-basic.md, 02-control-flow.md
  mermaid-eventmodeling/01-basic.md, 02-with-gwt.md
```

**Files modified (Wave 2):**

```
Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift     # +9 case arms, +9 supportedDiagramTypes
Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift      # +9 case arms
Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift  # +9 cells
Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift  # +9 @Test methods
```

No changes to `MermaidExportHelpers.swift`. The Wave 1 helpers
(`emitIndentedTree`, `emitSectionedItems`, `quote`, `escapeBracketLabel`,
`sanitizeIdentifier`) are sufficient.

---

## Task Ordering Rationale

Tasks 1–5 (xyChart, quadrantChart, requirement, radar, venn) each
introduce a moderately structured per-family schema with no shared
scaffolding. Tasks 6–7 (ishikawa, treeView) exercise the Wave 1
`emitIndentedTree` helper as second/third callers — proving the
abstraction holds. Task 8 (zenuml) is the largest single family due
to its `indirect enum` statement grammar with nested fragments. Task 9
(eventModeling) closes Wave 2 with a multi-section emission (model
entities → data entities → frames → notes → gwt). Task 10 is the
Wave 2 closing gates.

---

## Task 1: XYChart Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidXYChartExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+XYChart.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-xychart/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-xychart/02-bar-and-line.md`
- Modify: `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift`
- Modify: `Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift`
- Modify: `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift`
- Modify: `Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift`

- [ ] **Step 1.1: Add fixture `01-basic.md`**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-xychart/01-basic.md`:

```
xychart-beta
    line [1.3, 0.6, 2.4, -0.34]
```

> Note: the corpus seed `xychart-11-simplest` uses the bare `xychart`
> header and unbracketed leading-dot floats (`.6`, `-.34`). The
> exporter canonicalizes to `xychart-beta` and pads leading-dot floats
> to `0.6` / `-0.34`. The structural round-trip is what matters; both
> forms parse to the same `XYChart`.

- [ ] **Step 1.2: Stub the exporter file**

Create `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidXYChartExport.swift`:

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `xychart-beta` source from an `XYChart`.
///
/// Lossless: header (with optional `horizontal`) → title →
/// accessibility metadata → `x-axis` definition → `y-axis` range →
/// `bar`/`line` series data arrays.
enum MermaidXYChartExport {

    static func emit(_ model: XYChart) throws -> DiagramExportResult {
        return DiagramExportResult(source: "xychart-beta\n", diagnostics: [])
    }
}
```

- [ ] **Step 1.3: Wire dispatch arm**

In `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift`, append
`.xyChart` to `supportedDiagramTypes`:

```swift
        .xyChart,         // wave 2
```

And insert a case arm above the `default:`:

```swift
        case .xyChart(let model):
            result = try MermaidXYChartExport.emit(model)
```

- [ ] **Step 1.4: Create the diff arm**

Create `Sources/DiagramKitTestSupport/DiagramDocumentDiff+XYChart.swift`:

```swift
import DiagramKitModel

func diffXYChart(_ a: XYChart, _ b: XYChart) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "xychart.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.horizontal != b.horizontal {
        deltas.append(.unexpected(
            path: "xychart.horizontal",
            detail: "lhs=\(a.horizontal) rhs=\(b.horizontal)"
        ))
    }

    // Categories on x-axis (band kind) vs range on y-axis (linear).
    if a.xAxis.title != b.xAxis.title {
        deltas.append(.unexpected(
            path: "xychart.xAxis.title",
            detail: "lhs=\(a.xAxis.title ?? "nil") rhs=\(b.xAxis.title ?? "nil")"
        ))
    }
    if (a.xAxis.categories ?? []) != (b.xAxis.categories ?? []) {
        deltas.append(.unexpected(
            path: "xychart.xAxis.categories",
            detail: "lhs=\(a.xAxis.categories ?? []) rhs=\(b.xAxis.categories ?? [])"
        ))
    }
    if a.yAxis.title != b.yAxis.title {
        deltas.append(.unexpected(
            path: "xychart.yAxis.title",
            detail: "lhs=\(a.yAxis.title ?? "nil") rhs=\(b.yAxis.title ?? "nil")"
        ))
    }
    // Tuple `(min, max)` is not Equatable; compare element-wise.
    let aRange = a.yAxis.range.map { ($0.min, $0.max) }
    let bRange = b.yAxis.range.map { ($0.min, $0.max) }
    if aRange?.0 != bRange?.0 || aRange?.1 != bRange?.1 {
        deltas.append(.unexpected(
            path: "xychart.yAxis.range",
            detail: "lhs=\(String(describing: aRange)) rhs=\(String(describing: bRange))"
        ))
    }

    if a.series.count != b.series.count {
        deltas.append(.unexpected(
            path: "xychart.series.count",
            detail: "lhs=\(a.series.count) rhs=\(b.series.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.series, b.series).enumerated() {
        if l.type != r.type {
            deltas.append(.unexpected(
                path: "xychart.series[\(i)].type",
                detail: "lhs=\(l.type) rhs=\(r.type)"
            ))
        }
        if l.data != r.data {
            deltas.append(.unexpected(
                path: "xychart.series[\(i)].data",
                detail: "lhs=\(l.data) rhs=\(r.data)"
            ))
        }
    }
    return deltas
}
```

In `Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift`, add an
arm to the `compare(_:_:)` switch (above the `default:`):

```swift
    case (.xyChart(let lhs), .xyChart(let rhs)):
        deltas.append(contentsOf: diffXYChart(lhs, rhs))
```

- [ ] **Step 1.5: Register the round-trip cell**

In `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift`, add
after `mermaidGitGraph`:

```swift
    static let mermaidXYChart = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.xyChart,
        allowedLosses: []
    )
```

- [ ] **Step 1.6: Register the test method**

In `Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift`,
add inside `struct SameFormatRoundTripTests`:

```swift
    @Test(
        "Mermaid xychart round-trip",
        arguments: try fixtures(for: "mermaid-xychart", fromRoot: roundTripResourcesRoot())
    )
    func mermaidXYChart(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidXYChart,
            fixture: fixture
        )
    }
```

- [ ] **Step 1.7: Run test to confirm RED**

Run: `swift test --filter SameFormatRoundTripTests/mermaidXYChart`
Expected: FAIL. The stub returns just `"xychart-beta\n"`, so the diff
will report mismatched `xychart.series.count`.

- [ ] **Step 1.8: Implement the emit body**

Replace the stub `emit` in `MermaidXYChartExport.swift` with:

```swift
    static func emit(_ model: XYChart) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        var header = "xychart-beta"
        if model.horizontal {
            header += " horizontal"
        }
        lines.append(header)

        if let title = model.diagramTitle ?? model.title, !title.isEmpty {
            lines.append("    title \"\(escape(singleLine(title)))\"")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        // x-axis: either a title + bracketed category list, or just a
        // title. Skip entirely if neither field is populated.
        let xTitle = model.xAxis.title
        let xCats = model.xAxis.categories ?? []
        if xTitle != nil || !xCats.isEmpty {
            var line = "    x-axis"
            if let t = xTitle, !t.isEmpty {
                line += " \"\(escape(singleLine(t)))\""
            }
            if !xCats.isEmpty {
                let joined = xCats.map { escape(singleLine($0)) }.joined(separator: ", ")
                line += " [\(joined)]"
            }
            lines.append(line)
        }

        // y-axis: title + optional range.
        let yTitle = model.yAxis.title
        let yRange = model.yAxis.range
        if yTitle != nil || yRange != nil {
            var line = "    y-axis"
            if let t = yTitle, !t.isEmpty {
                line += " \"\(escape(singleLine(t)))\""
            }
            if let r = yRange {
                line += " \(formatNumber(r.min)) --> \(formatNumber(r.max))"
            }
            lines.append(line)
        }

        for series in model.series {
            let keyword: String
            switch series.type {
            case .bar: keyword = "bar"
            case .line: keyword = "line"
            }
            let joined = series.data.map { formatNumber($0) }.joined(separator: ", ")
            lines.append("    \(keyword) [\(joined)]")
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

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func formatNumber(_ value: Double) -> String {
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }
```

- [ ] **Step 1.9: Run test to confirm GREEN**

Run: `swift test --filter SameFormatRoundTripTests/mermaidXYChart`
Expected: PASS for `01-basic.md`.

- [ ] **Step 1.10: Add fixture `02-bar-and-line.md`**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-xychart/02-bar-and-line.md`:

```
xychart-beta
    title "Monthly Revenue"
    x-axis "Month" [Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec]
    y-axis "Revenue (USD)" 0 --> 10000
    bar [4200, 5000, 5800, 6200, 5500, 7000, 7800, 7200, 8400, 8100, 9000, 9200]
    line [4200, 5000, 5800, 6200, 5500, 7000, 7800, 7200, 8400, 8100, 9000, 9200]
```

- [ ] **Step 1.11: Run test to confirm 02 GREEN**

Run: `swift test --filter SameFormatRoundTripTests/mermaidXYChart`
Expected: PASS for both fixtures.

- [ ] **Step 1.12: Run discipline gates**

```bash
Scripts/check-diagnostic-discipline.sh
Scripts/check-file-sizes.sh
```
Expected: both exit 0.

- [ ] **Step 1.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidXYChartExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+XYChart.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-xychart/

git commit -m "$(cat <<'EOF'
Add Mermaid xychart exporter

Wave 2 of the Mermaid exporter completion spec. Lossless re-emission
from XYChart: header (with optional horizontal flag) → title →
accessibility metadata → x-axis (categories) → y-axis (range) →
bar / line series data arrays.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: QuadrantChart Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidQuadrantExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Quadrant.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-quadrant/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-quadrant/02-styled-points.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 2.1: Add fixture `01-basic.md`**

```
quadrantChart
```

- [ ] **Step 2.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `quadrantChart` source from a `QuadrantChart`.
///
/// Lossless: header → title → accessibility metadata → x-axis labels
/// (`Left --> Right`) → y-axis labels (`Bottom --> Top`) → quadrant
/// labels (`quadrant-1` … `quadrant-4`) → classDef lines → point
/// lines `Name[:className]: [x, y]`.
enum MermaidQuadrantExport {

    static func emit(_ model: QuadrantChart) throws -> DiagramExportResult {
        return DiagramExportResult(source: "quadrantChart\n", diagnostics: [])
    }
}
```

- [ ] **Step 2.3: Wire dispatch**

`.quadrantChart` to `supportedDiagramTypes`; switch arm:

```swift
        case .quadrantChart(let model):
            result = try MermaidQuadrantExport.emit(model)
```

- [ ] **Step 2.4: Diff arm**

Create `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Quadrant.swift`:

```swift
import DiagramKitModel

func diffQuadrantChart(_ a: QuadrantChart, _ b: QuadrantChart) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    let aTitle = a.diagramTitle ?? a.titleText
    let bTitle = b.diagramTitle ?? b.titleText
    if aTitle != bTitle {
        deltas.append(.unexpected(
            path: "quadrant.title",
            detail: "lhs=\(aTitle ?? "nil") rhs=\(bTitle ?? "nil")"
        ))
    }

    let labels: [(String, String?, String?)] = [
        ("xAxisLeft", a.xAxisLeftText, b.xAxisLeftText),
        ("xAxisRight", a.xAxisRightText, b.xAxisRightText),
        ("yAxisBottom", a.yAxisBottomText, b.yAxisBottomText),
        ("yAxisTop", a.yAxisTopText, b.yAxisTopText),
        ("quadrant1", a.quadrant1Text, b.quadrant1Text),
        ("quadrant2", a.quadrant2Text, b.quadrant2Text),
        ("quadrant3", a.quadrant3Text, b.quadrant3Text),
        ("quadrant4", a.quadrant4Text, b.quadrant4Text),
    ]
    for (name, lhs, rhs) in labels where lhs != rhs {
        deltas.append(.unexpected(
            path: "quadrant.\(name)",
            detail: "lhs=\(lhs ?? "nil") rhs=\(rhs ?? "nil")"
        ))
    }

    if a.points.count != b.points.count {
        deltas.append(.unexpected(
            path: "quadrant.points.count",
            detail: "lhs=\(a.points.count) rhs=\(b.points.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.points, b.points).enumerated() {
        if l.text != r.text
            || l.x != r.x
            || l.y != r.y
            || l.className != r.className {
            deltas.append(.unexpected(
                path: "quadrant.points[\(i)]",
                detail: "lhs=\(l.text)[\(l.className ?? "nil")]:(\(l.x),\(l.y)) rhs=\(r.text)[\(r.className ?? "nil")]:(\(r.x),\(r.y))"
            ))
        }
    }

    let lhsClassNames = Set(a.classes.keys)
    let rhsClassNames = Set(b.classes.keys)
    if lhsClassNames != rhsClassNames {
        deltas.append(.unexpected(
            path: "quadrant.classes.keys",
            detail: "onlyLhs=\(lhsClassNames.subtracting(rhsClassNames).sorted()) onlyRhs=\(rhsClassNames.subtracting(lhsClassNames).sorted())"
        ))
    }
    return deltas
}
```

In `DiagramDocumentDiff.swift`:

```swift
    case (.quadrantChart(let lhs), .quadrantChart(let rhs)):
        deltas.append(contentsOf: diffQuadrantChart(lhs, rhs))
```

- [ ] **Step 2.5: Register cell**

```swift
    static let mermaidQuadrant = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.quadrantChart,
        allowedLosses: []
    )
```

- [ ] **Step 2.6: Register test**

```swift
    @Test(
        "Mermaid quadrant round-trip",
        arguments: try fixtures(for: "mermaid-quadrant", fromRoot: roundTripResourcesRoot())
    )
    func mermaidQuadrant(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidQuadrant,
            fixture: fixture
        )
    }
```

- [ ] **Step 2.7: Run test, confirm RED**

Run: `swift test --filter SameFormatRoundTripTests/mermaidQuadrant`
Expected: PASS on `01-basic.md` (empty quadrant has nothing to diff
beyond the header) — but FAIL on the discipline gate after Step 2.10
adds `02-styled-points.md`. If 01 passes alone, that confirms the
stub matches the empty case; proceed to implement before adding 02.

- [ ] **Step 2.8: Implement emit**

```swift
    static func emit(_ model: QuadrantChart) throws -> DiagramExportResult {
        var lines: [String] = ["quadrantChart"]
        var diagnostics: [DiagramDiagnostic] = []

        let title = model.diagramTitle ?? model.titleText
        if let title, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        if model.xAxisLeftText != nil || model.xAxisRightText != nil {
            let left = singleLine(model.xAxisLeftText ?? "")
            if let right = model.xAxisRightText, !right.isEmpty {
                lines.append("    x-axis \(left) --> \(singleLine(right))")
            } else {
                lines.append("    x-axis \(left)")
            }
        }
        if model.yAxisBottomText != nil || model.yAxisTopText != nil {
            let bot = singleLine(model.yAxisBottomText ?? "")
            if let top = model.yAxisTopText, !top.isEmpty {
                lines.append("    y-axis \(bot) --> \(singleLine(top))")
            } else {
                lines.append("    y-axis \(bot)")
            }
        }

        let quads: [(String, String?)] = [
            ("quadrant-1", model.quadrant1Text),
            ("quadrant-2", model.quadrant2Text),
            ("quadrant-3", model.quadrant3Text),
            ("quadrant-4", model.quadrant4Text),
        ]
        for (keyword, text) in quads {
            if let text, !text.isEmpty {
                lines.append("    \(keyword) \(singleLine(text))")
            }
        }

        // classDefs in alphabetical order for stable output.
        for name in model.classes.keys.sorted() {
            guard let styles = model.classes[name] else { continue }
            let parts = styles.cssDeclarations()
            lines.append("    classDef \(name) \(parts.joined(separator: ", "))")
        }

        for point in model.points {
            let xy = "[\(formatCoord(point.x)), \(formatCoord(point.y))]"
            if let cls = point.className, !cls.isEmpty {
                lines.append("    \(singleLine(point.text)):::\(cls): \(xy)")
            } else {
                lines.append("    \(singleLine(point.text)): \(xy)")
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

    private static func formatCoord(_ value: Double) -> String {
        // Quadrant coords are in [0, 1]; emit with up to 4 decimal
        // places, trimming trailing zeros for stability.
        let s = String(format: "%.4f", value)
        var trimmed = s
        while trimmed.contains(".") && (trimmed.hasSuffix("0") || trimmed.hasSuffix(".")) {
            let suffix = trimmed.removeLast()
            if suffix == "." { break }
        }
        return trimmed
    }
```

> **Type alignment note.** `QuadrantPointStyles` is referenced in
> `QuadrantChart.classes`. The plan assumes it exposes a
> `cssDeclarations() -> [String]` method that returns Mermaid-syntax
> css fragments. If the type instead exposes raw properties
> (`color`, `radius`, etc.), build the declaration array inline:
>
> ```swift
> var parts: [String] = []
> if let c = styles.color { parts.append("color: \(c)") }
> if let r = styles.radius { parts.append("radius: \(r)") }
> // … etc., matching the property set exposed by QuadrantPointStyles.
> ```
>
> The compiler will pinpoint the actual API on first build.

- [ ] **Step 2.9: Run test, confirm GREEN**

Run: `swift test --filter SameFormatRoundTripTests/mermaidQuadrant`
Expected: PASS.

- [ ] **Step 2.10: Add fixture `02-styled-points.md`**

```
quadrantChart
    x-axis Low --> High
    y-axis Low --> High
    classDef primary color: #ff0000, radius: 10
    classDef secondary color: #0000ff, radius: 7
    quadrant-1 Plan
    Point A:::primary: [0.3, 0.6]
    Point B:::secondary: [0.7, 0.4]
```

- [ ] **Step 2.11: Run test, confirm GREEN**

Run: `swift test --filter SameFormatRoundTripTests/mermaidQuadrant`
Expected: PASS for both fixtures.

- [ ] **Step 2.12: Discipline gates**

```bash
Scripts/check-diagnostic-discipline.sh
Scripts/check-file-sizes.sh
```

- [ ] **Step 2.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidQuadrantExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Quadrant.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-quadrant/

git commit -m "$(cat <<'EOF'
Add Mermaid quadrantChart exporter

Wave 2: header → title → axis labels (Left --> Right / Bottom --> Top)
→ quadrant labels → classDef lines → point lines with optional
className via the :::name suffix and [x, y] coords.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Requirement Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidRequirementExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Requirement.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-requirement/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-requirement/02-all-types.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 3.1: Add fixture `01-basic.md`**

```
requirementDiagram

requirement test_req {
  id: 1
  text: the test text.
  risk: high
  verifymethod: test
}

element test_entity {
  type: simulation
}

test_entity - satisfies -> test_req
```

- [ ] **Step 3.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `requirementDiagram` source from a `RequirementDiagram`.
///
/// Lossless: header → optional title / accessibility metadata →
/// typed `<requirementType> <name> { … }` blocks → `element <name>
/// { … }` blocks → relationship lines (`source - type -> dest` or
/// the reversed `dest <- type - source` form).
///
/// Block field order is fixed: id → text → risk → verifymethod.
enum MermaidRequirementExport {

    static func emit(_ model: RequirementDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "requirementDiagram\n", diagnostics: [])
    }
}
```

- [ ] **Step 3.3: Wire dispatch**

`.requirement` to `supportedDiagramTypes`; switch arm:

```swift
        case .requirement(let model):
            result = try MermaidRequirementExport.emit(model)
```

- [ ] **Step 3.4: Diff arm**

```swift
import DiagramKitModel

func diffRequirementDiagram(_ a: RequirementDiagram, _ b: RequirementDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "requirement.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.direction != b.direction {
        deltas.append(.unexpected(
            path: "requirement.direction",
            detail: "lhs=\(a.direction) rhs=\(b.direction)"
        ))
    }

    // Compare requirements by name (parser-assigned identifier). The
    // sourceOrder differs across re-emission so we sort by name on
    // both sides for the structural compare.
    let aReqs = a.requirements.sorted { $0.name < $1.name }
    let bReqs = b.requirements.sorted { $0.name < $1.name }
    if aReqs.count != bReqs.count {
        deltas.append(.unexpected(
            path: "requirement.requirements.count",
            detail: "lhs=\(aReqs.count) rhs=\(bReqs.count)"
        ))
    } else {
        for (i, (l, r)) in zip(aReqs, bReqs).enumerated() {
            if l.name != r.name
                || l.type != r.type
                || l.requirementId != r.requirementId
                || l.text != r.text
                || l.risk != r.risk
                || l.verifyMethod != r.verifyMethod {
                deltas.append(.unexpected(
                    path: "requirement.requirements[\(i)]",
                    detail: "lhs=\(l.name):\(l.type) id=\(l.requirementId) text=\(l.text) risk=\(String(describing: l.risk)) vm=\(String(describing: l.verifyMethod)) rhs=\(r.name):\(r.type) id=\(r.requirementId) text=\(r.text) risk=\(String(describing: r.risk)) vm=\(String(describing: r.verifyMethod))"
                ))
            }
        }
    }

    let aElems = a.elements.sorted { $0.name < $1.name }
    let bElems = b.elements.sorted { $0.name < $1.name }
    if aElems.count != bElems.count {
        deltas.append(.unexpected(
            path: "requirement.elements.count",
            detail: "lhs=\(aElems.count) rhs=\(bElems.count)"
        ))
    } else {
        for (i, (l, r)) in zip(aElems, bElems).enumerated() {
            if l.name != r.name || l.type != r.type || l.docRef != r.docRef {
                deltas.append(.unexpected(
                    path: "requirement.elements[\(i)]",
                    detail: "lhs=\(l.name):\(l.type):\(l.docRef) rhs=\(r.name):\(r.type):\(r.docRef)"
                ))
            }
        }
    }

    // Relationships compared as a set on a normalized triple. Reversal
    // is folded into the comparison: `(s, t, type, false)` and
    // `(t, s, type, true)` describe the same logical relationship.
    func relKey(_ r: RequirementRelationship) -> String {
        let (s, t) = r.isReversed
            ? (r.destinationName, r.sourceName)
            : (r.sourceName, r.destinationName)
        return "\(s)|\(t)|\(r.type.rawValue)"
    }
    let lhs = Set(a.relationships.map(relKey))
    let rhs = Set(b.relationships.map(relKey))
    if lhs != rhs {
        deltas.append(.unexpected(
            path: "requirement.relationships",
            detail: "onlyLhs=\(lhs.subtracting(rhs).sorted()) onlyRhs=\(rhs.subtracting(lhs).sorted())"
        ))
    }
    return deltas
}
```

Add to `DiagramDocumentDiff.swift`:

```swift
    case (.requirement(let lhs), .requirement(let rhs)):
        deltas.append(contentsOf: diffRequirementDiagram(lhs, rhs))
```

- [ ] **Step 3.5: Register cell**

```swift
    static let mermaidRequirement = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.requirement,
        allowedLosses: []
    )
```

- [ ] **Step 3.6: Register test**

```swift
    @Test(
        "Mermaid requirement round-trip",
        arguments: try fixtures(for: "mermaid-requirement", fromRoot: roundTripResourcesRoot())
    )
    func mermaidRequirement(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidRequirement,
            fixture: fixture
        )
    }
```

- [ ] **Step 3.7: Run test, confirm RED**

Run: `swift test --filter SameFormatRoundTripTests/mermaidRequirement`
Expected: FAIL on `requirement.requirements.count` (stub emits zero
blocks).

- [ ] **Step 3.8: Implement emit**

```swift
    static func emit(_ model: RequirementDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["requirementDiagram"]
        var diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("")
            lines.append("title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("accDescr: \(singleLine(accDescr))")
        }

        for req in model.requirements.sorted(by: { $0.sourceOrder < $1.sourceOrder }) {
            lines.append("")
            lines.append("\(typeKeyword(req.type)) \(req.name) {")
            lines.append("  id: \(req.requirementId)")
            lines.append("  text: \(singleLine(req.text))")
            if let risk = req.risk {
                lines.append("  risk: \(risk.rawValue.lowercased())")
            }
            if let vm = req.verifyMethod {
                lines.append("  verifymethod: \(vm.rawValue.lowercased())")
            }
            lines.append("}")
        }

        for elem in model.elements.sorted(by: { $0.sourceOrder < $1.sourceOrder }) {
            lines.append("")
            lines.append("element \(elem.name) {")
            if !elem.type.isEmpty {
                lines.append("  type: \(singleLine(elem.type))")
            }
            if !elem.docRef.isEmpty {
                lines.append("  docref: \(singleLine(elem.docRef))")
            }
            lines.append("}")
        }

        if !model.relationships.isEmpty { lines.append("") }
        for rel in model.relationships {
            if rel.isReversed {
                lines.append("\(rel.sourceName) <- \(rel.type.rawValue) - \(rel.destinationName)")
            } else {
                lines.append("\(rel.sourceName) - \(rel.type.rawValue) -> \(rel.destinationName)")
            }
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func typeKeyword(_ t: RequirementType) -> String {
        switch t {
        case .requirement: return "requirement"
        case .functionalRequirement: return "functionalRequirement"
        case .interfaceRequirement: return "interfaceRequirement"
        case .performanceRequirement: return "performanceRequirement"
        case .physicalRequirement: return "physicalRequirement"
        case .designConstraint: return "designConstraint"
        }
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
```

- [ ] **Step 3.9: Run test, confirm GREEN**

Expected: PASS for `01-basic.md`.

- [ ] **Step 3.10: Add fixture `02-all-types.md`**

```
requirementDiagram

requirement req1 {
  id: 1
  text: basic requirement
}

functionalRequirement req2 {
  id: 2
  text: functional
}

interfaceRequirement req3 {
  id: 3
  text: interface
}

performanceRequirement req4 {
  id: 4
  text: performance
}

physicalRequirement req5 {
  id: 5
  text: physical
}

designConstraint req6 {
  id: 6
  text: design constraint
}
```

- [ ] **Step 3.11: Run test, confirm GREEN**

Expected: PASS for both fixtures.

- [ ] **Step 3.12: Discipline gates**

- [ ] **Step 3.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidRequirementExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Requirement.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-requirement/

git commit -m "$(cat <<'EOF'
Add Mermaid requirement exporter

Wave 2: typed `<requirementType> <name> { … }` blocks with fixed
field order (id → text → risk → verifymethod), `element` blocks,
and `source - type -> dest` (or reversed `<-`) relationship lines.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Radar Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidRadarExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Radar.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-radar/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-radar/02-multi-curve.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 4.1: Add fixture `01-basic.md`**

```
radar-beta
```

- [ ] **Step 4.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `radar-beta` source from a `RadarDiagram`.
///
/// Lossless: header → title → accessibility metadata → comma-joined
/// `axis` list → `curve <name>{<comma-joined entries>}` lines →
/// per-option lines (`showLegend`, `ticks`, `max`, `min`,
/// `graticule`) emitted only when they differ from defaults.
enum MermaidRadarExport {

    static func emit(_ model: RadarDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "radar-beta\n", diagnostics: [])
    }
}
```

- [ ] **Step 4.3: Wire dispatch**

`.radar` to `supportedDiagramTypes`; switch arm:

```swift
        case .radar(let model):
            result = try MermaidRadarExport.emit(model)
```

- [ ] **Step 4.4: Diff arm**

```swift
import DiagramKitModel

func diffRadarDiagram(_ a: RadarDiagram, _ b: RadarDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "radar.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }

    let aAxes = a.axes.map { "\($0.name)|\($0.label)" }
    let bAxes = b.axes.map { "\($0.name)|\($0.label)" }
    if aAxes != bAxes {
        deltas.append(.unexpected(
            path: "radar.axes",
            detail: "lhs=\(aAxes) rhs=\(bAxes)"
        ))
    }

    if a.curves.count != b.curves.count {
        deltas.append(.unexpected(
            path: "radar.curves.count",
            detail: "lhs=\(a.curves.count) rhs=\(b.curves.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.curves, b.curves).enumerated() {
        if l.name != r.name || l.label != r.label || l.entries != r.entries {
            deltas.append(.unexpected(
                path: "radar.curves[\(i)]",
                detail: "lhs=\(l.name):\(l.label)={\(l.entries)} rhs=\(r.name):\(r.label)={\(r.entries)}"
            ))
        }
    }

    if a.options.showLegend != b.options.showLegend
        || a.options.ticks != b.options.ticks
        || a.options.min != b.options.min
        || a.options.max != b.options.max
        || a.options.graticule != b.options.graticule {
        deltas.append(.unexpected(
            path: "radar.options",
            detail: "lhs=legend=\(a.options.showLegend) ticks=\(a.options.ticks) min=\(a.options.min) max=\(String(describing: a.options.max)) grat=\(a.options.graticule) rhs=legend=\(b.options.showLegend) ticks=\(b.options.ticks) min=\(b.options.min) max=\(String(describing: b.options.max)) grat=\(b.options.graticule)"
        ))
    }
    return deltas
}
```

In `DiagramDocumentDiff.swift`:

```swift
    case (.radar(let lhs), .radar(let rhs)):
        deltas.append(contentsOf: diffRadarDiagram(lhs, rhs))
```

- [ ] **Step 4.5: Register cell**

```swift
    static let mermaidRadar = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.radar,
        allowedLosses: []
    )
```

- [ ] **Step 4.6: Register test**

```swift
    @Test(
        "Mermaid radar round-trip",
        arguments: try fixtures(for: "mermaid-radar", fromRoot: roundTripResourcesRoot())
    )
    func mermaidRadar(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidRadar,
            fixture: fixture
        )
    }
```

- [ ] **Step 4.7: Run test, confirm RED**

Expected: PASS on `01-basic.md` alone (empty radar — header matches
the stub). FAIL once `02-multi-curve.md` is added in Step 4.10; that
is when the emit body has to actually do something.

- [ ] **Step 4.8: Implement emit**

```swift
    static func emit(_ model: RadarDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["radar-beta"]
        var diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("  title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("  accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("  accDescr: \(singleLine(accDescr))")
        }

        if !model.axes.isEmpty {
            let joined = model.axes.map { axis -> String in
                if axis.label.isEmpty || axis.label == axis.name {
                    return axis.name
                }
                return "\(axis.name)[\"\(escape(axis.label))\"]"
            }.joined(separator: ",")
            lines.append("  axis \(joined)")
        }

        for curve in model.curves {
            let entries = curve.entries.map { formatNumber($0) }.joined(separator: ",")
            let lhs: String
            if curve.label.isEmpty || curve.label == curve.name {
                lhs = curve.name
            } else {
                lhs = "\(curve.name)[\"\(escape(curve.label))\"]"
            }
            lines.append("  curve \(lhs){\(entries)}")
        }

        // Options: emit only when they differ from the default.
        let defaults = RadarOptions()
        if model.options.showLegend != defaults.showLegend {
            lines.append("  showLegend \(model.options.showLegend)")
        }
        if model.options.ticks != defaults.ticks {
            lines.append("  ticks \(model.options.ticks)")
        }
        if model.options.min != defaults.min {
            lines.append("  min \(formatNumber(model.options.min))")
        }
        if let m = model.options.max, m != defaults.max {
            lines.append("  max \(formatNumber(m))")
        }
        if model.options.graticule != defaults.graticule {
            lines.append("  graticule \(model.options.graticule.rawValue)")
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

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func formatNumber(_ value: Double) -> String {
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }
```

> **Type alignment note.** `RadarOptions()` is assumed to construct
> the default-valued options record. If the type has no zero-arg
> initializer, build the defaults inline from the source-of-truth
> file `Sources/DiagramKitModel/src_radar_types.swift` (currently
> `showLegend=true`, `ticks=5`, `max=nil`, `min=0`, `graticule=.circle`).

- [ ] **Step 4.9: Run test, confirm GREEN**

Expected: PASS for `01-basic.md`.

- [ ] **Step 4.10: Add fixture `02-multi-curve.md`**

```
radar-beta
  axis A,B,C,D,E
  curve c1{1,2,3,4,5}
  curve c2{5,4,3,2,1}
```

- [ ] **Step 4.11: Run test, confirm GREEN**

Expected: PASS for both fixtures.

- [ ] **Step 4.12: Discipline gates**

- [ ] **Step 4.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidRadarExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Radar.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-radar/

git commit -m "$(cat <<'EOF'
Add Mermaid radar exporter

Wave 2: comma-joined axes, brace-bound curve entries, and option
lines (showLegend, ticks, min, max, graticule) emitted only when
they diverge from RadarOptions defaults.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Venn Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidVennExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Venn.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-venn/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-venn/02-three-way.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 5.1: Add fixture `01-basic.md`**

```
venn-beta
  set A
  set B
  union A,B
```

- [ ] **Step 5.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `venn-beta` source from a `VennDiagram`.
///
/// Lossless: header → title → accessibility metadata → `set <name>`
/// lines for single-set areas → `union <a>,<b>[,…]["label"]` lines
/// for multi-set areas. Set member lists are sorted within each area
/// for canonical output.
enum MermaidVennExport {

    static func emit(_ model: VennDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "venn-beta\n", diagnostics: [])
    }
}
```

- [ ] **Step 5.3: Wire dispatch**

`.venn` to `supportedDiagramTypes`; switch arm:

```swift
        case .venn(let model):
            result = try MermaidVennExport.emit(model)
```

- [ ] **Step 5.4: Diff arm**

```swift
import DiagramKitModel

func diffVennDiagram(_ a: VennDiagram, _ b: VennDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "venn.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }

    // Compare areas as a set keyed on (sorted set members, label).
    // Size differences are excluded — the parser may recompute size
    // from member count.
    func areaKey(_ area: VennArea) -> String {
        let sets = area.sets.sorted().joined(separator: ",")
        return "\(sets)|\(area.label ?? "")"
    }
    let lhs = Set(a.areas.map(areaKey))
    let rhs = Set(b.areas.map(areaKey))
    if lhs != rhs {
        deltas.append(.unexpected(
            path: "venn.areas",
            detail: "onlyLhs=\(lhs.subtracting(rhs).sorted()) onlyRhs=\(rhs.subtracting(lhs).sorted())"
        ))
    }
    return deltas
}
```

In `DiagramDocumentDiff.swift`:

```swift
    case (.venn(let lhs), .venn(let rhs)):
        deltas.append(contentsOf: diffVennDiagram(lhs, rhs))
```

- [ ] **Step 5.5: Register cell**

```swift
    static let mermaidVenn = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.venn,
        allowedLosses: []
    )
```

- [ ] **Step 5.6: Register test**

```swift
    @Test(
        "Mermaid venn round-trip",
        arguments: try fixtures(for: "mermaid-venn", fromRoot: roundTripResourcesRoot())
    )
    func mermaidVenn(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidVenn,
            fixture: fixture
        )
    }
```

- [ ] **Step 5.7: Run test, confirm RED**

Expected: FAIL on `venn.areas` (stub emits no `set` / `union` lines).

- [ ] **Step 5.8: Implement emit**

```swift
    static func emit(_ model: VennDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["venn-beta"]
        var diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("  title \"\(escape(singleLine(title)))\"")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("  accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("  accDescr: \(singleLine(accDescr))")
        }

        for area in model.areas {
            let sets = area.sets.sorted()
            let labelSuffix: String
            if let l = area.label, !l.isEmpty {
                labelSuffix = "[\"\(escape(singleLine(l)))\"]"
            } else {
                labelSuffix = ""
            }
            if sets.count == 1 {
                lines.append("  set \(sets[0])\(labelSuffix)")
            } else {
                lines.append("  union \(sets.joined(separator: ","))\(labelSuffix)")
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

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
```

- [ ] **Step 5.9: Run test, confirm GREEN**

Expected: PASS for `01-basic.md`.

- [ ] **Step 5.10: Add fixture `02-three-way.md`**

```
venn-beta
  title "Three overlapping sets"
  set A
  set B
  set C
  union A,B["AB"]
  union B,C["BC"]
  union A,C["AC"]
  union A,B,C["ABC"]
```

- [ ] **Step 5.11: Run test, confirm GREEN**

Expected: PASS for both fixtures.

- [ ] **Step 5.12: Discipline gates**

- [ ] **Step 5.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidVennExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Venn.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-venn/

git commit -m "$(cat <<'EOF'
Add Mermaid venn exporter

Wave 2: single-set areas emit as `set X`, multi-set areas as
`union A,B[,C]["label"]` with members sorted for canonical output.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Ishikawa Exporter (reuses `emitIndentedTree`)

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidIshikawaExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+Ishikawa.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-ishikawa/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-ishikawa/02-nested-causes.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 6.1: Add fixture `01-basic.md`**

```
ishikawa-beta
Problem
```

- [ ] **Step 6.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `ishikawa-beta` source from an `IshikawaDiagram`.
///
/// Walks the root tree and emits each node on its own line with
/// indentation = depth × 4 spaces. Reuses the Wave 1
/// `MermaidExportHelpers.emitIndentedTree` helper now that it has a
/// third tree caller.
enum MermaidIshikawaExport {

    static func emit(_ model: IshikawaDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "ishikawa-beta\n", diagnostics: [])
    }
}
```

- [ ] **Step 6.3: Wire dispatch**

`.ishikawa` to `supportedDiagramTypes`; switch arm:

```swift
        case .ishikawa(let model):
            result = try MermaidIshikawaExport.emit(model)
```

- [ ] **Step 6.4: Diff arm**

```swift
import DiagramKitModel

func diffIshikawaDiagram(_ a: IshikawaDiagram, _ b: IshikawaDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "ishikawa.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }

    switch (a.root, b.root) {
    case (nil, nil):
        break
    case (let l?, let r?):
        diffIshikawaNode(l, r, path: "ishikawa.root", deltas: &deltas)
    default:
        deltas.append(.unexpected(
            path: "ishikawa.root",
            detail: "lhs=\(a.root == nil ? "nil" : "present") rhs=\(b.root == nil ? "nil" : "present")"
        ))
    }
    return deltas
}

private func diffIshikawaNode(_ a: IshikawaNode, _ b: IshikawaNode, path: String, deltas: inout [RoundTripDelta]) {
    if a.text != b.text {
        deltas.append(.unexpected(
            path: "\(path).text",
            detail: "lhs=\(a.text) rhs=\(b.text)"
        ))
    }
    if a.children.count != b.children.count {
        deltas.append(.unexpected(
            path: "\(path).children.count",
            detail: "lhs=\(a.children.count) rhs=\(b.children.count)"
        ))
        return
    }
    for (i, (l, r)) in zip(a.children, b.children).enumerated() {
        diffIshikawaNode(l, r, path: "\(path).children[\(i)]", deltas: &deltas)
    }
}
```

In `DiagramDocumentDiff.swift`:

```swift
    case (.ishikawa(let lhs), .ishikawa(let rhs)):
        deltas.append(contentsOf: diffIshikawaDiagram(lhs, rhs))
```

- [ ] **Step 6.5: Register cell**

```swift
    static let mermaidIshikawa = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.ishikawa,
        allowedLosses: []
    )
```

- [ ] **Step 6.6: Register test**

```swift
    @Test(
        "Mermaid ishikawa round-trip",
        arguments: try fixtures(for: "mermaid-ishikawa", fromRoot: roundTripResourcesRoot())
    )
    func mermaidIshikawa(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidIshikawa,
            fixture: fixture
        )
    }
```

- [ ] **Step 6.7: Run test, confirm RED**

Expected: FAIL on `ishikawa.root` (stub emits no root, parser
re-reads `nil`).

- [ ] **Step 6.8: Implement emit (using `emitIndentedTree`)**

```swift
    static func emit(_ model: IshikawaDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["ishikawa-beta"]
        var diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        if let root = model.root {
            let treeLines = MermaidExportHelpers.emitIndentedTree(
                roots: [root],
                indentUnit: "    ",
                childrenOf: { $0.children },
                emitNode: { node, _ in [singleLine(node.text)] }
            )
            lines.append(contentsOf: treeLines)
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

- [ ] **Step 6.9: Run test, confirm GREEN**

Expected: PASS for `01-basic.md`.

- [ ] **Step 6.10: Add fixture `02-nested-causes.md`**

```
ishikawa-beta
Effect
    Cause A
        Sub A1
            SubSub A1a
                Leaf
```

- [ ] **Step 6.11: Run test, confirm GREEN**

Expected: PASS for both fixtures.

- [ ] **Step 6.12: Discipline gates**

- [ ] **Step 6.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidIshikawaExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+Ishikawa.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-ishikawa/

git commit -m "$(cat <<'EOF'
Add Mermaid ishikawa exporter

Wave 2: root tree walked through MermaidExportHelpers.emitIndentedTree
with indentUnit=4-spaces. Third caller of the Wave 1 indent helper.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: TreeView Exporter (reuses `emitIndentedTree`)

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidTreeViewExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+TreeView.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-treeview/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-treeview/02-nested-with-icons.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 7.1: Add fixture `01-basic.md`**

```
treeView-beta
```

- [ ] **Step 7.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `treeView-beta` source from a `TreeViewDiagram`.
///
/// Walks the root tree and emits one node per line. Directories
/// (`nodeType == .directory`) emit with a trailing `/`. Files emit
/// as their bare name. Icon ids surface inline when set, with the
/// upstream Mermaid syntax. Indent = depth × 4 spaces.
enum MermaidTreeViewExport {

    static func emit(_ model: TreeViewDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "treeView-beta\n", diagnostics: [])
    }
}
```

- [ ] **Step 7.3: Wire dispatch**

`.treeView` to `supportedDiagramTypes`; switch arm:

```swift
        case .treeView(let model):
            result = try MermaidTreeViewExport.emit(model)
```

- [ ] **Step 7.4: Diff arm**

```swift
import DiagramKitModel

func diffTreeViewDiagram(_ a: TreeViewDiagram, _ b: TreeViewDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "treeview.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    diffTreeViewNode(a.root, b.root, path: "treeview.root", deltas: &deltas)
    return deltas
}

private func diffTreeViewNode(_ a: TreeViewNode, _ b: TreeViewNode, path: String, deltas: inout [RoundTripDelta]) {
    if a.name != b.name || a.nodeType != b.nodeType || a.iconId != b.iconId {
        deltas.append(.unexpected(
            path: "\(path).self",
            detail: "lhs=\(a.name)[\(a.nodeType)]icon=\(a.iconId ?? "nil") rhs=\(b.name)[\(b.nodeType)]icon=\(b.iconId ?? "nil")"
        ))
    }
    if a.children.count != b.children.count {
        deltas.append(.unexpected(
            path: "\(path).children.count",
            detail: "lhs=\(a.children.count) rhs=\(b.children.count)"
        ))
        return
    }
    for (i, (l, r)) in zip(a.children, b.children).enumerated() {
        diffTreeViewNode(l, r, path: "\(path).children[\(i)]", deltas: &deltas)
    }
}
```

In `DiagramDocumentDiff.swift`:

```swift
    case (.treeView(let lhs), .treeView(let rhs)):
        deltas.append(contentsOf: diffTreeViewDiagram(lhs, rhs))
```

- [ ] **Step 7.5: Register cell**

```swift
    static let mermaidTreeView = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.treeView,
        allowedLosses: []
    )
```

- [ ] **Step 7.6: Register test**

```swift
    @Test(
        "Mermaid treeView round-trip",
        arguments: try fixtures(for: "mermaid-treeview", fromRoot: roundTripResourcesRoot())
    )
    func mermaidTreeView(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidTreeView,
            fixture: fixture
        )
    }
```

- [ ] **Step 7.7: Run test, confirm RED**

Expected: PASS for `01-basic.md` alone (empty tree means a synthetic
or empty `root`; the diff arm should treat empty vs empty as match).
If 01 fails, the empty-root case isn't matching cleanly — adjust the
diff arm or the stub to align before adding 02.

- [ ] **Step 7.8: Implement emit (using `emitIndentedTree`)**

```swift
    static func emit(_ model: TreeViewDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["treeView-beta"]
        var diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        // The root is a synthetic container per
        // src_treeview_types.swift; its children are the visible top
        // level. Skip the root itself, emit children at depth 0.
        let treeLines = MermaidExportHelpers.emitIndentedTree(
            roots: model.root.children,
            indentUnit: "    ",
            childrenOf: { $0.children },
            emitNode: { node, _ in [renderLine(node)] }
        )
        lines.append(contentsOf: treeLines)

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func renderLine(_ node: TreeViewNode) -> String {
        var label = singleLine(node.name)
        switch node.nodeType {
        case .directory:
            if !label.hasSuffix("/") { label += "/" }
        case .file:
            break
        }
        if let icon = node.iconId, !icon.isEmpty {
            return "\(label) :\(icon):"
        }
        return label
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
```

> **Type alignment note.** `TreeViewDiagram.root` is `TreeViewNode`
> (non-optional). It is conventionally a synthetic container whose
> visible top-level entries are `root.children`. If concrete corpus
> behavior shows `root` itself is meant to render (e.g. as a single
> file/folder at the top), pivot the emit body to walk `[model.root]`
> instead of `model.root.children`. The round-trip test will pinpoint
> the call.

- [ ] **Step 7.9: Run test, confirm GREEN**

Expected: PASS for `01-basic.md`.

- [ ] **Step 7.10: Add fixture `02-nested-with-icons.md`**

```
treeView-beta
    src/
        App.tsx
        index.js
        utils.py
        config.json
    Dockerfile
    package.json
    .gitignore
```

- [ ] **Step 7.11: Run test, confirm GREEN**

Expected: PASS for both fixtures.

- [ ] **Step 7.12: Discipline gates**

- [ ] **Step 7.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidTreeViewExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+TreeView.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-treeview/

git commit -m "$(cat <<'EOF'
Add Mermaid treeView exporter

Wave 2: walks model.root.children via emitIndentedTree; directories
emit with trailing slash, optional icon ids surface as :iconId:.
Fourth caller of the Wave 1 indent helper.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: ZenUML Exporter

ZenUML carries the most structural complexity of any Wave 2 family
because `ZenUMLStatement` is an `indirect enum` with seven cases
including nested statement blocks inside `.message`, `.creation`, and
`.fragment` (which has its own `[ZenUMLFragmentSection]` of further
statements). The plan handles this with a recursive `emitStatement`
private function. Keep this task self-contained even though it is
larger than the others.

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidZenUMLExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+ZenUML.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-zenuml/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-zenuml/02-control-flow.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 8.1: Add fixture `01-basic.md`**

```
zenuml
Alice->Bob: Hello
```

- [ ] **Step 8.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `zenuml` source from a `ZenUMLDiagram`.
///
/// Lossless re-emission of the participant set plus the statement
/// stream. `ZenUMLStatement` is an indirect enum; nested blocks
/// inside `.message`, `.creation`, and `.fragment` recurse through
/// `emitStatement`.
enum MermaidZenUMLExport {

    static func emit(_ model: ZenUMLDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "zenuml\n", diagnostics: [])
    }
}
```

- [ ] **Step 8.3: Wire dispatch**

`.zenuml` to `supportedDiagramTypes`; switch arm:

```swift
        case .zenuml(let model):
            result = try MermaidZenUMLExport.emit(model)
```

- [ ] **Step 8.4: Diff arm**

```swift
import DiagramKitModel

func diffZenUMLDiagram(_ a: ZenUMLDiagram, _ b: ZenUMLDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.title != b.title {
        deltas.append(.unexpected(
            path: "zenuml.title",
            detail: "lhs=\(a.title ?? "nil") rhs=\(b.title ?? "nil")"
        ))
    }

    // Compare participants by name. Explicit participants are first-
    // class; implicit ones are derived from message endpoints and may
    // be re-derived in any order, so compare the explicit set only.
    let aPart = Set(a.participants.filter { $0.explicit }.map { $0.name })
    let bPart = Set(b.participants.filter { $0.explicit }.map { $0.name })
    if aPart != bPart {
        deltas.append(.unexpected(
            path: "zenuml.participants",
            detail: "onlyLhs=\(aPart.subtracting(bPart).sorted()) onlyRhs=\(bPart.subtracting(aPart).sorted())"
        ))
    }

    if a.statements.count != b.statements.count {
        deltas.append(.unexpected(
            path: "zenuml.statements.count",
            detail: "lhs=\(a.statements.count) rhs=\(b.statements.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.statements, b.statements).enumerated() {
        diffZenUMLStatement(l, r, path: "zenuml.statements[\(i)]", deltas: &deltas)
    }
    return deltas
}

private func diffZenUMLStatement(
    _ a: ZenUMLStatement,
    _ b: ZenUMLStatement,
    path: String,
    deltas: inout [RoundTripDelta]
) {
    switch (a, b) {
    case let (.message(af, at, asig, atyp, ablk, _),
              .message(bf, bt, bsig, btyp, bblk, _)):
        if af != bf || at != bt || asig != bsig || atyp != btyp {
            deltas.append(.unexpected(
                path: "\(path).message",
                detail: "lhs=\(af)->\(at):\(asig)[\(atyp)] rhs=\(bf)->\(bt):\(bsig)[\(btyp)]"
            ))
        }
        let aBlock = ablk ?? []
        let bBlock = bblk ?? []
        if aBlock.count != bBlock.count {
            deltas.append(.unexpected(
                path: "\(path).message.block.count",
                detail: "lhs=\(aBlock.count) rhs=\(bBlock.count)"
            ))
        } else {
            for (i, (l, r)) in zip(aBlock, bBlock).enumerated() {
                diffZenUMLStatement(l, r, path: "\(path).message.block[\(i)]", deltas: &deltas)
            }
        }
    case let (.asyncMessage(af, at, ac, _), .asyncMessage(bf, bt, bc, _)):
        if af != bf || at != bt || ac != bc {
            deltas.append(.unexpected(
                path: "\(path).async",
                detail: "lhs=\(af)->\(at):\(ac ?? "nil") rhs=\(bf)->\(bt):\(bc ?? "nil")"
            ))
        }
    case let (.return(af, at, av, _), .return(bf, bt, bv, _)):
        if af != bf || at != bt || av != bv {
            deltas.append(.unexpected(
                path: "\(path).return",
                detail: "lhs=\(af)->\(at):\(av ?? "nil") rhs=\(bf)->\(bt):\(bv ?? "nil")"
            ))
        }
    case let (.fragment(akind, acond, asecs), .fragment(bkind, bcond, bsecs)):
        if akind != bkind || acond != bcond || asecs.count != bsecs.count {
            deltas.append(.unexpected(
                path: "\(path).fragment.shape",
                detail: "lhs=\(akind):\(acond ?? "nil") secs=\(asecs.count) rhs=\(bkind):\(bcond ?? "nil") secs=\(bsecs.count)"
            ))
            return
        }
        for (s, (asec, bsec)) in zip(asecs, bsecs).enumerated() {
            if asec.label != bsec.label || asec.statements.count != bsec.statements.count {
                deltas.append(.unexpected(
                    path: "\(path).fragment.section[\(s)]",
                    detail: "lhs=\(asec.label) stmts=\(asec.statements.count) rhs=\(bsec.label) stmts=\(bsec.statements.count)"
                ))
                continue
            }
            for (i, (l, r)) in zip(asec.statements, bsec.statements).enumerated() {
                diffZenUMLStatement(l, r, path: "\(path).fragment.section[\(s)].stmt[\(i)]", deltas: &deltas)
            }
        }
    case let (.divider(al), .divider(bl)):
        if al != bl {
            deltas.append(.unexpected(path: "\(path).divider", detail: "lhs=\(al) rhs=\(bl)"))
        }
    case let (.comment(at), .comment(bt)):
        if at != bt {
            deltas.append(.unexpected(path: "\(path).comment", detail: "lhs=\(at) rhs=\(bt)"))
        }
    case let (.creation(aas, atyp, ac, at, ap, _, _),
              .creation(bas, btyp, bc, bt, bp, _, _)):
        if aas != bas || atyp != btyp || ac != bc || at != bt || (ap ?? []) != (bp ?? []) {
            deltas.append(.unexpected(
                path: "\(path).creation",
                detail: "lhs=\(aas ?? "nil")=\(atyp ?? "nil"):\(ac)->\(at) rhs=\(bas ?? "nil")=\(btyp ?? "nil"):\(bc)->\(bt)"
            ))
        }
    default:
        deltas.append(.unexpected(
            path: "\(path).kind",
            detail: "lhs=\(String(describing: a)) rhs=\(String(describing: b))"
        ))
    }
}
```

In `DiagramDocumentDiff.swift`:

```swift
    case (.zenuml(let lhs), .zenuml(let rhs)):
        deltas.append(contentsOf: diffZenUMLDiagram(lhs, rhs))
```

- [ ] **Step 8.5: Register cell**

```swift
    static let mermaidZenUML = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.zenuml,
        allowedLosses: []
    )
```

- [ ] **Step 8.6: Register test**

```swift
    @Test(
        "Mermaid zenuml round-trip",
        arguments: try fixtures(for: "mermaid-zenuml", fromRoot: roundTripResourcesRoot())
    )
    func mermaidZenUML(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidZenUML,
            fixture: fixture
        )
    }
```

- [ ] **Step 8.7: Run test, confirm RED**

Expected: FAIL on `zenuml.statements.count` (stub emits zero
statements).

- [ ] **Step 8.8: Implement emit**

```swift
    static func emit(_ model: ZenUMLDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["zenuml"]
        var diagnostics: [DiagramDiagnostic] = []

        if let title = model.title, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        for p in model.participants where p.explicit {
            var kind = p.type ?? "@Actor"
            if !kind.hasPrefix("@") { kind = "@" + kind }
            if let label = p.label, !label.isEmpty, label != p.name {
                lines.append("\(kind) \"\(escape(label))\" as \(p.name)")
            } else {
                lines.append("\(kind) \(p.name)")
            }
        }

        for stmt in model.statements {
            lines.append(contentsOf: emitStatement(stmt, indent: ""))
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func emitStatement(_ stmt: ZenUMLStatement, indent: String) -> [String] {
        switch stmt {
        case let .message(from, to, sig, type, block, _):
            let arrow: String
            switch type {
            case .sync: arrow = "->"
            case .async: arrow = "->"
            case .creation: arrow = "->"
            case .return: arrow = "->"
            }
            let head = "\(indent)\(from)\(arrow)\(to): \(sig)"
            if let block, !block.isEmpty {
                var out = ["\(head) {"]
                for s in block {
                    out.append(contentsOf: emitStatement(s, indent: indent + "  "))
                }
                out.append("\(indent)}")
                return out
            }
            return [head]
        case let .asyncMessage(from, to, content, _):
            return ["\(indent)\(from)->\(to): \(content ?? "")"]
        case let .creation(assignee, type, construct, to, params, _, _):
            let lhs = [assignee, type].compactMap { $0 }.joined(separator: " ")
            let argList: String
            if let params, !params.isEmpty {
                argList = "(\(params.joined(separator: ", ")))"
            } else {
                argList = "()"
            }
            if lhs.isEmpty {
                return ["\(indent)new \(to).\(construct)\(argList)"]
            }
            return ["\(indent)\(lhs) = new \(to).\(construct)\(argList)"]
        case let .return(_, _, value, _):
            return ["\(indent)return \(value ?? "")"]
        case let .fragment(kind, condition, sections):
            var out: [String] = []
            let head: String
            switch kind {
            case .alt:
                head = "if (\(condition ?? "true"))"
            case .opt:
                head = "opt"
            case .loop:
                head = "while (\(condition ?? ""))"
            case .par:
                head = "par"
            case .critical:
                head = "critical"
            case .section:
                head = "section \(condition ?? "")"
            case .ref:
                head = "ref \(condition ?? "")"
            case .tcf:
                head = "try"
            }
            out.append("\(indent)\(head) {")
            for (i, sec) in sections.enumerated() {
                if i > 0 {
                    let separator: String
                    switch kind {
                    case .alt:
                        separator = sec.label.isEmpty
                            ? "} else {"
                            : "} else if (\(sec.label)) {"
                    case .tcf:
                        separator = "} \(sec.label) {"
                    default:
                        separator = "} \(sec.label) {"
                    }
                    out.append("\(indent)\(separator)")
                }
                for s in sec.statements {
                    out.append(contentsOf: emitStatement(s, indent: indent + "  "))
                }
            }
            out.append("\(indent)}")
            return out
        case let .divider(label):
            return ["\(indent)== \(label) =="]
        case let .comment(text):
            return ["\(indent)// \(text)"]
        }
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
```

> **Surface variance note.** ZenUML's textual syntax has multiple
> accepted shapes (e.g. `try { … } catch (e) { … } finally { … }` vs
> the longer `tcf { … } catch (e) { … } finally { … }`). The
> structural diff cares about `(kind, condition, sections)` equality,
> not surface form. If the round-trip fails on `02-control-flow.md`,
> the failure will pinpoint which section label/condition the emitter
> mis-emitted. Adjust the `emitStatement` arm rather than the diff.

- [ ] **Step 8.9: Run test, confirm GREEN**

Expected: PASS for `01-basic.md`.

- [ ] **Step 8.10: Add fixture `02-control-flow.md`**

```
zenuml
try { B.process } catch(error) { C.handle } finally { D.cleanup }
```

- [ ] **Step 8.11: Run test, confirm GREEN**

Expected: PASS for both fixtures. If 02 fails on a section-label
mismatch, the structural details surface in the diff output —
revise the `.tcf` separator emission rather than the fixture.

- [ ] **Step 8.12: Discipline gates**

```bash
Scripts/check-diagnostic-discipline.sh
Scripts/check-file-sizes.sh
```

If the file approaches 300 lines (the recurring guidance for new
files), split the `emitStatement` cases into a private extension
within the same file — the goal is one file per family, not
necessarily one enum per file.

- [ ] **Step 8.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidZenUMLExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+ZenUML.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-zenuml/

git commit -m "$(cat <<'EOF'
Add Mermaid zenuml exporter

Wave 2: explicit participants emit as `@<type> <name>` declarations;
statements re-emit through a recursive emitStatement that handles
sync/async messages, creations, returns, fragments (alt/loop/par/
opt/critical/section/ref/tcf with their separator forms), dividers,
and comments. Implicit participants are derived from message
endpoints and are not re-emitted.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: EventModeling Exporter

**Files:**
- Create: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidEventModelingExport.swift`
- Create: `Sources/DiagramKitTestSupport/DiagramDocumentDiff+EventModeling.swift`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-eventmodeling/01-basic.md`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-eventmodeling/02-with-gwt.md`
- Modify: `MermaidExporter.swift`, `DiagramDocumentDiff.swift`,
  `RoundTripCellRegistry.swift`, `SameFormatRoundTripTests.swift`

- [ ] **Step 9.1: Add fixture `01-basic.md`**

```
eventmodeling
tf 01 ui CartUI
tf 02 cmd AddItem
tf 03 evt ItemAdded
```

- [ ] **Step 9.2: Stub the exporter**

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `eventmodeling` source from an `EventModelingDiagram`.
///
/// Emission order: model entities → data entities → frames →
/// note entities → GWT entities. Each section is silent when empty.
/// Frame source references (parent frames, data references, inline
/// data) follow the upstream Mermaid grammar.
enum MermaidEventModelingExport {

    static func emit(_ model: EventModelingDiagram) throws -> DiagramExportResult {
        return DiagramExportResult(source: "eventmodeling\n", diagnostics: [])
    }
}
```

- [ ] **Step 9.3: Wire dispatch**

`.eventModeling` to `supportedDiagramTypes`; switch arm:

```swift
        case .eventModeling(let model):
            result = try MermaidEventModelingExport.emit(model)
```

- [ ] **Step 9.4: Diff arm**

```swift
import DiagramKitModel

func diffEventModelingDiagram(_ a: EventModelingDiagram, _ b: EventModelingDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "eventmodeling.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }

    func frameKey(_ f: EventModelingFrame) -> String {
        let srcs = f.sourceFrameNames.joined(separator: ",")
        return "\(f.name)|\(f.modelEntityType.rawValue)|\(f.entityIdentifier)|reset=\(f.isResetFrame)|src=\(srcs)|dref=\(f.dataReferenceName ?? "")|dtyp=\(f.dataInlineType?.rawValue ?? "")|dval=\(f.dataInlineValue ?? "")"
    }
    let aFrames = Set(a.frames.map(frameKey))
    let bFrames = Set(b.frames.map(frameKey))
    if aFrames != bFrames {
        deltas.append(.unexpected(
            path: "eventmodeling.frames",
            detail: "onlyLhs=\(aFrames.subtracting(bFrames).sorted()) onlyRhs=\(bFrames.subtracting(aFrames).sorted())"
        ))
    }

    let aEntities = Set(a.modelEntities.map { $0.name })
    let bEntities = Set(b.modelEntities.map { $0.name })
    if aEntities != bEntities {
        deltas.append(.unexpected(
            path: "eventmodeling.modelEntities",
            detail: "onlyLhs=\(aEntities.subtracting(bEntities).sorted()) onlyRhs=\(bEntities.subtracting(aEntities).sorted())"
        ))
    }

    func dataKey(_ d: EventModelingDataEntity) -> String {
        "\(d.name)|\(d.dataType?.rawValue ?? "")|\(d.dataBlockValue)"
    }
    let aData = Set(a.dataEntities.map(dataKey))
    let bData = Set(b.dataEntities.map(dataKey))
    if aData != bData {
        deltas.append(.unexpected(
            path: "eventmodeling.dataEntities",
            detail: "onlyLhs=\(aData.subtracting(bData).sorted()) onlyRhs=\(bData.subtracting(aData).sorted())"
        ))
    }

    func gwtKey(_ g: EventModelingGwtEntity) -> String {
        func stmts(_ ss: [EventModelingGwtStatement]) -> String {
            ss.map { "\($0.entityType.rawValue):\($0.modelEntityName)" }.joined(separator: ",")
        }
        return "\(g.sourceFrameName)|G=\(stmts(g.givenStatements))|W=\(stmts(g.whenStatements))|T=\(stmts(g.thenStatements))"
    }
    let aGwt = Set(a.gwtEntities.map(gwtKey))
    let bGwt = Set(b.gwtEntities.map(gwtKey))
    if aGwt != bGwt {
        deltas.append(.unexpected(
            path: "eventmodeling.gwtEntities",
            detail: "onlyLhs=\(aGwt.subtracting(bGwt).sorted()) onlyRhs=\(bGwt.subtracting(aGwt).sorted())"
        ))
    }
    return deltas
}
```

In `DiagramDocumentDiff.swift`:

```swift
    case (.eventModeling(let lhs), .eventModeling(let rhs)):
        deltas.append(contentsOf: diffEventModelingDiagram(lhs, rhs))
```

- [ ] **Step 9.5: Register cell**

```swift
    static let mermaidEventModeling = RoundTripCell(
        importer: MermaidImporter(),
        exporter: MermaidExporter(),
        family: DiagramType.eventModeling,
        allowedLosses: []
    )
```

- [ ] **Step 9.6: Register test**

```swift
    @Test(
        "Mermaid eventmodeling round-trip",
        arguments: try fixtures(for: "mermaid-eventmodeling", fromRoot: roundTripResourcesRoot())
    )
    func mermaidEventModeling(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.mermaidEventModeling,
            fixture: fixture
        )
    }
```

- [ ] **Step 9.7: Run test, confirm RED**

Expected: FAIL on `eventmodeling.frames` (stub emits zero frames).

- [ ] **Step 9.8: Implement emit**

```swift
    static func emit(_ model: EventModelingDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["eventmodeling"]
        var diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("accDescr: \(singleLine(accDescr))")
        }

        // 1. model entities (used by gwt references).
        for entity in model.modelEntities {
            lines.append("entity \(entity.name)")
        }

        // 2. data entities (referenced by frames via [[name]]).
        for data in model.dataEntities {
            var head = "data \(data.name)"
            if let t = data.dataType { head += " \(t.rawValue)" }
            if data.dataBlockValue.isEmpty {
                lines.append(head)
            } else {
                lines.append("\(head) {")
                for line in data.dataBlockValue.split(separator: "\n", omittingEmptySubsequences: false) {
                    lines.append("  \(line)")
                }
                lines.append("}")
            }
        }

        // 3. frames.
        for frame in model.frames {
            if frame.isResetFrame {
                lines.append("rf \(frame.name) \(frame.modelEntityType.rawValue) \(frame.entityIdentifier)")
            } else {
                var parts = ["tf", frame.name, frame.modelEntityType.rawValue, frame.entityIdentifier]
                if !frame.sourceFrameNames.isEmpty {
                    parts.append("from \(frame.sourceFrameNames.joined(separator: ","))")
                }
                if let ref = frame.dataReferenceName {
                    parts.append("[[\(ref)]]")
                }
                if let t = frame.dataInlineType, let v = frame.dataInlineValue {
                    parts.append("\(t.rawValue){\(v)}")
                }
                lines.append(parts.joined(separator: " "))
            }
        }

        // 4. note entities.
        for note in model.noteEntities {
            var head = "note \(note.sourceFrameName)"
            if let t = note.dataType { head += " \(t.rawValue)" }
            head += " {"
            lines.append(head)
            for line in note.dataBlockValue.split(separator: "\n", omittingEmptySubsequences: false) {
                lines.append("  \(line)")
            }
            lines.append("}")
        }

        // 5. GWT entities.
        for gwt in model.gwtEntities {
            var parts = ["gwt", gwt.sourceFrameName]
            if !gwt.givenStatements.isEmpty {
                parts.append("given")
                for s in gwt.givenStatements {
                    parts.append("\(s.entityType.rawValue) \(s.modelEntityName)")
                }
            }
            if !gwt.whenStatements.isEmpty {
                parts.append("when")
                for s in gwt.whenStatements {
                    parts.append("\(s.entityType.rawValue) \(s.modelEntityName)")
                }
            }
            if !gwt.thenStatements.isEmpty {
                parts.append("then")
                for s in gwt.thenStatements {
                    parts.append("\(s.entityType.rawValue) \(s.modelEntityName)")
                }
            }
            lines.append(parts.joined(separator: " "))
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

- [ ] **Step 9.9: Run test, confirm GREEN**

Expected: PASS for `01-basic.md`.

- [ ] **Step 9.10: Add fixture `02-with-gwt.md`**

```
eventmodeling
entity CartUI
entity AddItem
entity ItemAdded
tf 02 cmd AddItem
gwt 02 given ui CartUI when cmd AddItem then evt ItemAdded
```

- [ ] **Step 9.11: Run test, confirm GREEN**

Expected: PASS for both fixtures.

- [ ] **Step 9.12: Discipline gates**

- [ ] **Step 9.13: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidEventModelingExport.swift \
        Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff+EventModeling.swift \
        Sources/DiagramKitTestSupport/DiagramDocumentDiff.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-eventmodeling/

git commit -m "$(cat <<'EOF'
Add Mermaid eventmodeling exporter

Wave 2: emits in fixed section order — model entities, data
entities (with optional block bodies), frames (`tf`/`rf` with
`from`/`[[ref]]`/inline-data suffixes), note entities, and
`gwt <frame> given … when … then …` lines.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Wave 2 Closing Gates

- [ ] **Step 10.1: Full round-trip suite green**

```bash
swift test --filter SameFormatRoundTripTests
swift test --filter CorpusRoundTripTests
swift test --filter RoundTripHarnessTests
swift test --filter LossPairingTests
```
Expected: all PASS. `CorpusRoundTripTests` auto-expands to cover
every Mermaid corpus entry whose family is now in
`supportedDiagramTypes` (25 families post-Wave 2). If a corpus entry
fails for one of the Wave 2 families, the failure pinpoints the
diverging field — fix the exporter (not the corpus) and commit the
fix as a separate commit citing the corpus entry id. Do NOT add a
new entry to `CorpusRoundTripTests.knownFailures` for a Wave 2
family; the spec's contract is structural round-trip without
allowlist.

- [ ] **Step 10.2: Discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
```
Expected: all exit 0.

- [ ] **Step 10.3: Bootstrap smoke check**

```bash
Scripts/bootstrap-smoke-check.sh
```
Expected: exit 0. If Docker/Podman is not running locally, the
`linux-check.sh` step inside `bootstrap-smoke-check.sh` records as
skipped — that is acceptable per CLAUDE.md.

- [ ] **Step 10.4: Update BASELINES.md**

Append a Wave 2 entry to BASELINES.md noting:
- Mermaid Export coverage: 16/28 → 25/28.
- 18 new round-trip fixture files.
- `CorpusRoundTripTests` count grows automatically.

Read the current BASELINES.md to find the correct insertion point
and format. Commit:

```bash
git add BASELINES.md
git commit -m "$(cat <<'EOF'
Update BASELINES for Mermaid exporter wave 2

9 new Mermaid exporter families (xyChart, quadrantChart, requirement,
radar, venn, ishikawa, treeView, zenuml, eventModeling). Mermaid
Export coverage: 16/28 → 25/28. COVERAGE.md update deferred to wave
3 closing commit per the spec.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10.5: Announce Wave 2 complete; hand off to Wave 3**

Wave 2 lands 9 families. The implementation plan for Wave 3 (`block`,
`architecture`, `wardleyBeta`) is authored as a follow-up via the
writing-plans skill, referencing the same source spec. Wave 3 also
removes the `default:` arm from `MermaidExporter.export(_:)` once
the switch becomes exhaustive at 28/28.

The `default:` arm in `MermaidExporter.export(_:)` stays for now.

---

## Self-Review Checklist (executor uses on completion)

- [ ] All 9 family `case` arms present in `MermaidExporter.export(_:)`.
- [ ] `supportedDiagramTypes` contains all 9 new entries:
      `.xyChart, .quadrantChart, .requirement, .radar, .venn,
      .ishikawa, .treeView, .zenuml, .eventModeling`.
- [ ] 9 new `Mermaid<Family>Export.swift` files exist; each is under
      300 lines (zenuml may push the limit — split into a private
      extension within the same file if it crosses 300, do not split
      across multiple files).
- [ ] 9 new `DiagramDocumentDiff+<Family>.swift` files exist.
- [ ] `DiagramDocumentDiff.swift` switch has arms for `.xyChart`,
      `.quadrantChart`, `.requirement`, `.radar`, `.venn`,
      `.ishikawa`, `.treeView`, `.zenuml`, `.eventModeling`.
- [ ] 9 round-trip fixture directories exist with 2 fixtures each
      (18 fixtures total).
- [ ] 9 new cells in `RoundTripCellRegistry`.
- [ ] 9 new `@Test` methods in `SameFormatRoundTripTests`.
- [ ] `MermaidExportHelpers.swift` is unchanged (Wave 1 helpers
      `emitIndentedTree` / `emitSectionedItems` / `quote` /
      `escapeBracketLabel` / `sanitizeIdentifier` are reused as-is).
- [ ] `CorpusRoundTripTests.swift` still runs green; Wave 2 families
      are NOT added to `knownFailures`.
- [ ] All discipline gates green
      (`check-diagnostic-discipline.sh`, `check-file-sizes.sh`,
      `check-sendable-annotations.sh`, `strict-concurrency-check.sh`).
- [ ] `BASELINES.md` updated.
- [ ] No raw `DiagramDiagnostic(severity:message:)` constructors
      introduced.
- [ ] No exporter throws on lossy emission (diagnostics only;
      throws reserved for impossible payloads).
- [ ] `default: .unsupportedDiagram` arm still present in
      `MermaidExporter.export(_:)` (Wave 3 closes it).

---

## References

- Spec:
  [docs/superpowers/specs/2026-05-19-mermaid-exporter-completion-design.md](../specs/2026-05-19-mermaid-exporter-completion-design.md)
- Wave 1 plan (structural template + lessons):
  [docs/superpowers/plans/2026-05-19-mermaid-exporter-wave-1.md](2026-05-19-mermaid-exporter-wave-1.md)
- Diagnostic discipline:
  [docs/diagnostic-severity-discipline.md](../../diagnostic-severity-discipline.md)
- Existing exemplar exporters (Wave 1):
  `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidPieExport.swift`,
  `MermaidKanbanExport.swift`, `MermaidGitGraphExport.swift`.
- Round-trip harness:
  `Sources/DiagramKitTestSupport/RoundTripHarness.swift`,
  `Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift`,
  `Tests/DiagramKitTests/RoundTrip/CorpusRoundTripTests.swift`.
- Discipline gates:
  `Scripts/check-diagnostic-discipline.sh`,
  `Scripts/check-file-sizes.sh`,
  `Scripts/check-sendable-annotations.sh`,
  `Scripts/strict-concurrency-check.sh`.

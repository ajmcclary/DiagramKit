# Wave H — PlantUML treeView Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flip the `treeView × PlantUML` matrix cell from `—` to `✓` for both import and export by adding three new dialect import probes (`@startwbs`, `@startjson`, `@startyaml`) that all land on `TreeViewDiagram`, plus a single canonical `PlantUMLTreeViewExporter` emitting `@startwbs` + recovery markers.

**Architecture:** Three sibling dialect parsers/mappers under `Sources/DiagramKitPlantUML/{WBS,JSON,YAML}/`, one new exporter under `Sources/DiagramKitPlantUML/Exporter/`, three new `PlantUMLRecoveryMarker.Kind` cases (`treeViewNodeDescription`, `treeViewNodeIcon`, `treeViewNodeCssClass`). `@startwbs` retargets from `MindmapDiagram` to `TreeViewDiagram` — a documented behavior change with a 1-test-file migration cost. JSON parsing uses `Foundation.JSONSerialization`; YAML uses a hand-rolled minimal indent scanner (subset only).

**Tech Stack:** Swift 6, SwiftPM, `swift-testing` + XCTest, `Foundation.JSONSerialization`, `NSRegularExpression`, the existing `RecoveryMarkerScanner` shared scaffolding under `DiagramKitCommon/RecoveryMarker/`.

**Spec:** [`docs/superpowers/specs/2026-05-21-plantuml-treeview-design.md`](../specs/2026-05-21-plantuml-treeview-design.md)

**Spec correction.** The spec said `RoundTripLoss` "reuses `.slotUnsupported`". That kind doesn't exist in `RoundTripLossKind`. The plan instead follows the existing treeView cross-format convention: same-format cells use `allowedLosses: []`; cross-format cells use `[.idSanitization, .titleDrop]` (matching `mermaidD2TreeView` et al. on line 89-94 of `RoundTripCrossRegistry.swift`). Diagnostics still use `DiagnosticCategory.slotUnsupported` for shape/color drops — that category exists on the diagnostic side; the asymmetry with `RoundTripLossKind` is intentional in the codebase (silent-drop losses don't need a paired kind because both legs drop equally).

---

## Working invariants (read first)

- **All work happens on `main`** per [feedback_branching memory]. No worktrees, no branches. One commit per task.
- **Tests are filtered.** Never run `swift test` without `--filter`. Per-task examples below use precise filters.
- **DFS pre-order is the marker-keying invariant.** TreeViewNode.id assignment in DFS pre-order is verified in Task 1 before any new mapper depends on it.
- **No new `DiagnosticCategory` cases. No new `RoundTripLossKind` cases.**
- **Diagnostic discipline.** New code uses typed factories `DiagramDiagnostic.lossyTransform(_:message:)` / `.featureDropped(_:message:)` / `.informational(_:message:)`. Never the raw `DiagramDiagnostic(severity:message:)` initializer. `Scripts/check-diagnostic-discipline.sh` enforces this at grep level.

---

## Task 1: Verify DFS pre-order across all treeView mappers

**Goal:** Confirm that the existing Mermaid / D2 / DOT treeView mappers assign `TreeViewNode.id` in DFS pre-order. If any diverge, document the gap (do not fix in this wave; record it as a follow-up). The new WBS / JSON / YAML mappers in later tasks rely on this invariant for cross-format marker recovery.

**Files:**
- Read-only: `Sources/DiagramKit/Layout.swift` (Mermaid TreeView mapping), `Sources/DiagramKitD2/D2TreeViewMapper.swift`, `Sources/DiagramKitGraphviz/DOTTreeViewMapper.swift`.
- Create (if any mapper diverges): inline notes in this plan's Task 13 fixture design.

- [ ] **Step 1: Grep for treeView id-assignment sites**

```bash
grep -n "TreeViewNode(" Sources/DiagramKit/Layout.swift Sources/DiagramKitD2/D2TreeViewMapper.swift Sources/DiagramKitGraphviz/DOTTreeViewMapper.swift
```

Expected: each file constructs `TreeViewNode(id:level:name:...)`. Read each call site and trace where `id` comes from.

- [ ] **Step 2: Verify DFS pre-order in each mapper**

For each of the three files, read the mapping function top-to-bottom and answer: when traversing a parent's children, does the parent get its `id` before any child? If yes ⇒ DFS pre-order ✓. If a child gets its id first (post-order) or via a separate flatten pass ⇒ NOT pre-order.

Document findings inline in this checklist as a comment under Step 2 before committing:

```
Mermaid: pre-order? ___
D2:      pre-order? ___
DOT:     pre-order? ___
```

- [ ] **Step 3: If any mapper diverges, note in plan and proceed**

If any mapper isn't pre-order, the cross-format marker recovery in Tasks 11/14 will silently drop those markers. That's acceptable behavior — note the divergence as a follow-up in COVERAGE.md Wave H prose (Task 15) but do NOT fix in this wave. Marker drops are harmless: structural shape still round-trips.

- [ ] **Step 4: No commit**

Task 1 is investigation-only. No source change. Move on to Task 2.

---

## Task 2: Outer probe + family-probe scaffolding

**Goal:** Make `extractPlantUMLBody` recognize `@startjson` and `@startyaml`; split `@startwbs` out of the mindmap probe into its own probe; add the three new family probes.

**Files:**
- Modify: `Sources/DiagramKitPlantUML/PlantUMLProbe.swift`
- Modify: `Sources/DiagramKitPlantUML/PlantUMLFamilyProbe.swift`
- Test: `Tests/DiagramKitTests/PlantUMLProbeTests.swift` (new) and existing `PlantUMLFamilyProbeTests.swift` if present

- [ ] **Step 1: Find existing probe tests**

```bash
grep -rln "isPlantUMLSource\|extractPlantUMLBody\|isPlantUMLMindmap" Tests/DiagramKitTests/ 2>/dev/null
```

If a probe-tests file exists, extend it. Otherwise create `Tests/DiagramKitTests/PlantUMLProbeTests.swift`.

- [ ] **Step 2: Write failing tests for the new probe behavior**

Append (or create) the following swift-testing block. Adjust file path to match Step 1's finding.

```swift
import Testing
@testable import DiagramKitPlantUML

@Suite struct PlantUMLProbeTests {
    @Test func extractsJSONBody() {
        let src = "@startjson\n{ \"a\": 1 }\n@endjson"
        let result = extractPlantUMLBody(src)
        #expect(result?.startKind == "json")
        #expect(result?.body.contains("\"a\"") == true)
    }

    @Test func extractsYAMLBody() {
        let src = "@startyaml\nkey: value\n@endyaml"
        let result = extractPlantUMLBody(src)
        #expect(result?.startKind == "yaml")
        #expect(result?.body.contains("key") == true)
    }

    @Test func wbsStillRecognized() {
        let src = "@startwbs\n* root\n@endwbs"
        let result = extractPlantUMLBody(src)
        #expect(result?.startKind == "wbs")
    }

    @Test func mismatchedStartEndRejected() {
        let src = "@startjson\n{ }\n@endyaml"
        #expect(extractPlantUMLBody(src) == nil)
    }

    @Test func wbsProbeAcceptsOnlyWBS() {
        #expect(isPlantUMLWBS(startKind: "wbs", "") == true)
        #expect(isPlantUMLWBS(startKind: "mindmap", "") == false)
    }

    @Test func mindmapProbeNoLongerClaimsWBS() {
        #expect(isPlantUMLMindmap(startKind: "wbs", "") == false)
        #expect(isPlantUMLMindmap(startKind: "mindmap", "") == true)
    }

    @Test func jsonProbeAcceptsOnlyJSON() {
        #expect(isPlantUMLJSON(startKind: "json", "") == true)
        #expect(isPlantUMLJSON(startKind: "yaml", "") == false)
    }

    @Test func yamlProbeAcceptsOnlyYAML() {
        #expect(isPlantUMLYAML(startKind: "yaml", "") == true)
        #expect(isPlantUMLYAML(startKind: "json", "") == false)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
swift test --filter PlantUMLProbeTests
```

Expected: build failure (symbols `isPlantUMLWBS`, `isPlantUMLJSON`, `isPlantUMLYAML` not defined) or assertion failures on the WBS / JSON / YAML cases.

- [ ] **Step 4: Update `PlantUMLProbe.swift` regex**

In `Sources/DiagramKitPlantUML/PlantUMLProbe.swift`, change the regex from:

```swift
pattern: "@start(uml|mindmap|gantt|wbs)(.*?)@end(uml|mindmap|gantt|wbs)",
```

to:

```swift
pattern: "@start(uml|mindmap|gantt|wbs|json|yaml)(.*?)@end(uml|mindmap|gantt|wbs|json|yaml)",
```

Also update the doc comment to list the new start kinds:

```swift
/// Returns (body, startTagKind) where startTagKind is "uml", "mindmap",
/// "gantt", "wbs", "json", or "yaml".
```

- [ ] **Step 5: Update `PlantUMLFamilyProbe.swift`**

Replace the existing `isPlantUMLMindmap` function with this WBS-narrowed version and add three new probes immediately after it:

```swift
/// Returns `true` when body is from an explicit @startmindmap header.
/// `@startwbs` no longer routes here — see `isPlantUMLWBS` below. Mindmap
/// keeps its own dispatch branch in `PlantUMLImporter`.
public func isPlantUMLMindmap(startKind: String, _ body: String) -> Bool {
    startKind == "mindmap"
}

/// Returns `true` when body is from an explicit @startwbs header.
/// Routes to the WBS parser which produces a `TreeViewDiagram` payload
/// (not `MindmapDiagram`).
public func isPlantUMLWBS(startKind: String, _ body: String) -> Bool {
    startKind == "wbs"
}

/// Returns `true` when body is from an explicit @startjson header.
public func isPlantUMLJSON(startKind: String, _ body: String) -> Bool {
    startKind == "json"
}

/// Returns `true` when body is from an explicit @startyaml header.
public func isPlantUMLYAML(startKind: String, _ body: String) -> Bool {
    startKind == "yaml"
}
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
swift test --filter PlantUMLProbeTests
```

Expected: all 8 tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitPlantUML/PlantUMLProbe.swift Sources/DiagramKitPlantUML/PlantUMLFamilyProbe.swift Tests/DiagramKitTests/PlantUMLProbeTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 2 — probe + family-probe scaffolding

Extend extractPlantUMLBody regex to recognize @startjson/@startyaml.
Split @startwbs out of isPlantUMLMindmap into its own isPlantUMLWBS
probe so it can route to a separate parser. Add isPlantUMLJSON and
isPlantUMLYAML companions.

No dispatch wiring yet — that lands in Task 11.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Recovery marker kinds + emit/parse helpers

**Goal:** Add three new `PlantUMLRecoveryMarker.Kind` cases (`treeViewNodeDescription`, `treeViewNodeIcon`, `treeViewNodeCssClass`) with matching parse and emit helpers. No call sites yet — those land in Tasks 5/8/10/12.

**Files:**
- Modify: `Sources/DiagramKitPlantUML/PlantUMLRecoveryMarker.swift`
- Test: `Tests/DiagramKitTests/PlantUMLRecoveryMarkerTests.swift` (extend if exists, create if not)

- [ ] **Step 1: Find existing recovery marker tests**

```bash
ls Tests/DiagramKitTests/PlantUML*RecoveryMarker* 2>/dev/null
```

If a tests file exists, extend it. Otherwise create `Tests/DiagramKitTests/PlantUMLRecoveryMarkerTests.swift`.

- [ ] **Step 2: Write failing tests**

```swift
import Testing
import Foundation
@testable import DiagramKitPlantUML

@Suite struct PlantUMLTreeViewRecoveryMarkerTests {
    @Test func descriptionRoundTrip() {
        let body = "primitive value with ; and \" chars"
        let line = PlantUMLRecoveryMarker.emitTreeViewNodeDescription(nodeId: 3, body: body)
        #expect(line.hasPrefix("' diagramkit:treeview-node-description=3,b64:"))

        let markers = PlantUMLRecoveryMarker.scanner.scan(source: line + "\n").markers
        #expect(markers.count == 1)
        if case .treeViewNodeDescription(let nodeId, let b64) = markers[0].kind {
            #expect(nodeId == 3)
            let decoded = Data(base64Encoded: b64).flatMap { String(data: $0, encoding: .utf8) }
            #expect(decoded == body)
        } else {
            Issue.record("expected treeViewNodeDescription marker, got \(markers[0].kind)")
        }
    }

    @Test func iconRoundTrip() {
        let line = PlantUMLRecoveryMarker.emitTreeViewNodeIcon(nodeId: 5, iconId: "folder")
        #expect(line == "' diagramkit:treeview-node-icon=5,folder")

        let markers = PlantUMLRecoveryMarker.scanner.scan(source: line + "\n").markers
        #expect(markers.count == 1)
        #expect(markers[0].kind == .treeViewNodeIcon(nodeId: 5, iconId: "folder"))
    }

    @Test func cssClassRoundTrip() {
        let line = PlantUMLRecoveryMarker.emitTreeViewNodeCssClass(nodeId: 7, cssClass: "highlighted")
        #expect(line == "' diagramkit:treeview-node-cssclass=7,highlighted")

        let markers = PlantUMLRecoveryMarker.scanner.scan(source: line + "\n").markers
        #expect(markers.count == 1)
        #expect(markers[0].kind == .treeViewNodeCssClass(nodeId: 7, cssClass: "highlighted"))
    }

    @Test func malformedNodeIdReturnsNil() {
        let bogus = "' diagramkit:treeview-node-icon=not-an-int,folder\n"
        let markers = PlantUMLRecoveryMarker.scanner.scan(source: bogus).markers
        #expect(markers.isEmpty)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
swift test --filter PlantUMLTreeViewRecoveryMarkerTests
```

Expected: build failure — the three new Kind cases and emit helpers don't exist yet.

- [ ] **Step 4: Add the three Kind cases**

In `Sources/DiagramKitPlantUML/PlantUMLRecoveryMarker.swift`, add three cases to the `Kind` enum. Insert immediately after `deploymentLegend`:

```swift
        case treeViewNodeDescription(nodeId: Int, base64Body: String)
        case treeViewNodeIcon(nodeId: Int, iconId: String)
        case treeViewNodeCssClass(nodeId: Int, cssClass: String)
```

- [ ] **Step 5: Add the three parseKind branches**

In `parseKind(_:)`, add three new prefix branches. Insert immediately before the final `return nil`:

```swift
        if let args = stripPrefix("treeview-node-description=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2,
                  let nodeId = Int(fields[0]),
                  fields[1].hasPrefix("b64:") else { return nil }
            return .treeViewNodeDescription(
                nodeId: nodeId,
                base64Body: String(fields[1].dropFirst(4))
            )
        }
        if let args = stripPrefix("treeview-node-icon=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, let nodeId = Int(fields[0]) else { return nil }
            return .treeViewNodeIcon(nodeId: nodeId, iconId: String(fields[1]))
        }
        if let args = stripPrefix("treeview-node-cssclass=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, let nodeId = Int(fields[0]) else { return nil }
            return .treeViewNodeCssClass(nodeId: nodeId, cssClass: String(fields[1]))
        }
```

- [ ] **Step 6: Add the three emit helpers**

After `emitDeploymentLegend(body:)`, add:

```swift
    public static func emitTreeViewNodeDescription(nodeId: Int, body: String) -> String {
        let base64 = Data(body.utf8).base64EncodedString()
        return "' diagramkit:treeview-node-description=\(nodeId),b64:\(base64)"
    }

    public static func emitTreeViewNodeIcon(nodeId: Int, iconId: String) -> String {
        "' diagramkit:treeview-node-icon=\(nodeId),\(sanitize(iconId))"
    }

    public static func emitTreeViewNodeCssClass(nodeId: Int, cssClass: String) -> String {
        "' diagramkit:treeview-node-cssclass=\(nodeId),\(sanitize(cssClass))"
    }
```

- [ ] **Step 7: Run tests to verify they pass**

```bash
swift test --filter PlantUMLTreeViewRecoveryMarkerTests
```

Expected: all 4 tests pass.

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKitPlantUML/PlantUMLRecoveryMarker.swift Tests/DiagramKitTests/PlantUMLRecoveryMarkerTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 3 — treeView recovery marker kinds

Add three new PlantUMLRecoveryMarker.Kind cases:
  - treeViewNodeDescription(nodeId, base64Body)
  - treeViewNodeIcon(nodeId, iconId)
  - treeViewNodeCssClass(nodeId, cssClass)

Plus matching parseKind branches and emit* helpers. No call sites yet
— the WBS/JSON/YAML mappers and PlantUMLTreeViewExporter wire these in
Tasks 5/8/10/12.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: WBS parser + AST

**Goal:** Implement `PlantUMLWBSParser` and `PlantUMLWBSAST`. The parser extracts WBS-specific tokens (`<<shape>>`, `#color`) onto AST node slots so the mapper can surface them as diagnostics in Task 5.

**Files:**
- Create: `Sources/DiagramKitPlantUML/WBS/PlantUMLWBSAST.swift`
- Create: `Sources/DiagramKitPlantUML/WBS/PlantUMLWBSParser.swift`
- Test: `Tests/DiagramKitTests/PlantUMLWBSParserTests.swift` (new)

- [ ] **Step 1: Write failing parser tests**

Create `Tests/DiagramKitTests/PlantUMLWBSParserTests.swift`:

```swift
import Testing
@testable import DiagramKitPlantUML

@Suite struct PlantUMLWBSParserTests {
    @Test func parsesSingleRoot() {
        let body = "* root"
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.root?.label == "root")
        #expect(tree.root?.depth == 1)
        #expect(tree.root?.children.isEmpty == true)
    }

    @Test func parsesHierarchy() {
        let body = """
        * root
        ** child1
        *** grandchild
        ** child2
        """
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.root?.label == "root")
        #expect(tree.root?.children.count == 2)
        #expect(tree.root?.children[0].label == "child1")
        #expect(tree.root?.children[0].children.count == 1)
        #expect(tree.root?.children[0].children[0].label == "grandchild")
        #expect(tree.root?.children[1].label == "child2")
    }

    @Test func extractsShapeVariant() {
        let body = "* root <<box>>"
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.root?.label == "root")
        #expect(tree.root?.shape == "box")
    }

    @Test func extractsColorSuffix() {
        let body = "* root #LightBlue"
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.root?.label == "root")
        #expect(tree.root?.color == "LightBlue")
    }

    @Test func skipsCommentsAndBlankLines() {
        let body = """

        ' a comment
        * root
        ' another
        ** child
        """
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.root?.label == "root")
        #expect(tree.root?.children.count == 1)
    }

    @Test func extractsTitle() {
        let body = """
        title My Tree
        * root
        """
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.title == "My Tree")
        #expect(tree.root?.label == "root")
    }

    @Test func capturesMultipleRoots() {
        let body = """
        * root1
        * root2
        """
        let tree = PlantUMLWBSParser().parse(body)
        #expect(tree.root?.label == "root1")
        #expect(tree.unsupportedLines.isEmpty == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter PlantUMLWBSParserTests
```

Expected: build failure — `PlantUMLWBSParser` does not exist.

- [ ] **Step 3: Create the AST**

Create `Sources/DiagramKitPlantUML/WBS/PlantUMLWBSAST.swift`:

```swift
import Foundation

/// AST produced by `PlantUMLWBSParser`. Hierarchical tree of
/// `PlantUMLWBSNode` plus diagram-level metadata (title) and the list of
/// unsupported lines collected during parse.
///
/// Distinct from `PlantUMLMindmapTree` because WBS targets `TreeViewDiagram`
/// (not `MindmapDiagram`) and carries WBS-specific shape/color slots that
/// surface as `.slotUnsupported` diagnostics in the mapper.
public struct PlantUMLWBSTree: Sendable {
    public var root: PlantUMLWBSNode?
    public var title: String?
    public var unsupportedLines: [String]

    public init(
        root: PlantUMLWBSNode? = nil,
        title: String? = nil,
        unsupportedLines: [String] = []
    ) {
        self.root = root
        self.title = title
        self.unsupportedLines = unsupportedLines
    }
}

public struct PlantUMLWBSNode: Sendable {
    public var label: String
    public var depth: Int
    /// WBS `<<…>>` shape token if present, stripped from `label`.
    /// Mapper surfaces as `.featureDropped(.slotUnsupported, …)`.
    public var shape: String?
    /// WBS `#…` color suffix if present, stripped from `label`.
    /// Mapper surfaces as `.featureDropped(.slotUnsupported, …)`.
    public var color: String?
    public var children: [PlantUMLWBSNode]

    public init(
        label: String,
        depth: Int,
        shape: String? = nil,
        color: String? = nil,
        children: [PlantUMLWBSNode] = []
    ) {
        self.label = label
        self.depth = depth
        self.shape = shape
        self.color = color
        self.children = children
    }
}
```

- [ ] **Step 4: Create the parser**

Create `Sources/DiagramKitPlantUML/WBS/PlantUMLWBSParser.swift`:

```swift
import Foundation

/// Parses PlantUML WBS bodies between `@startwbs`/`@endwbs`.
///
/// Syntax mirrors PlantUML mindmap indent prefixes (`*`, `+`, `-`,
/// repeated for depth). WBS-specific shape tokens (`<<box>>`) and color
/// suffixes (`#LightBlue`) are extracted onto AST node slots and surfaced
/// as `.featureDropped(.slotUnsupported, …)` diagnostics by
/// `PlantUMLWBSMapper`. The `title` line populates `PlantUMLWBSTree.title`.
public struct PlantUMLWBSParser {

    public init() {}

    public func parse(_ body: String) -> PlantUMLWBSTree {
        var tree = PlantUMLWBSTree()
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
        var stack: [(depth: Int, pathIndex: [Int])] = []

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("'") { continue }

            if let title = stripPrefix("title ", trimmed) {
                tree.title = title
                continue
            }

            guard let parsed = parseLine(trimmed) else {
                tree.unsupportedLines.append(trimmed)
                continue
            }

            while let top = stack.last, top.depth >= parsed.depth {
                stack.removeLast()
            }

            let newNode = PlantUMLWBSNode(
                label: parsed.label,
                depth: parsed.depth,
                shape: parsed.shape,
                color: parsed.color
            )

            if parsed.depth == 1 || stack.isEmpty {
                if tree.root == nil {
                    tree.root = newNode
                    stack.append((depth: parsed.depth, pathIndex: []))
                } else {
                    tree.unsupportedLines.append("Multiple roots: \(trimmed)")
                }
                continue
            }

            let parentPath = stack.last!.pathIndex
            insertChild(into: &tree.root!, at: parentPath, child: newNode)
            let childCount = countChildren(in: tree.root!, at: parentPath)
            stack.append((depth: parsed.depth, pathIndex: parentPath + [childCount - 1]))
        }
        return tree
    }

    private struct LineComponents {
        let depth: Int
        let label: String
        let shape: String?
        let color: String?
    }

    private func parseLine(_ line: String) -> LineComponents? {
        guard let firstChar = line.first else { return nil }
        let markerChar: Character
        switch firstChar {
        case "*", "+", "-": markerChar = firstChar
        default: return nil
        }
        var depth = 0
        var index = line.startIndex
        while index < line.endIndex, line[index] == markerChar {
            depth += 1
            index = line.index(after: index)
        }
        guard depth > 0 else { return nil }
        var remainder = line[index...].trimmingCharacters(in: .whitespaces)
        let shape = extractShape(from: &remainder)
        let color = extractColor(from: &remainder)
        return LineComponents(
            depth: depth,
            label: remainder.trimmingCharacters(in: .whitespaces),
            shape: shape,
            color: color
        )
    }

    private func extractShape(from remainder: inout String) -> String? {
        // Match trailing `<<word>>` token.
        guard let range = remainder.range(
            of: #"\s*<<([A-Za-z_][A-Za-z0-9_]*)>>\s*$"#,
            options: .regularExpression
        ) else { return nil }
        let captured = remainder[range]
        let inner = captured.replacingOccurrences(
            of: #"\s*<<|>>\s*"#,
            with: "",
            options: .regularExpression
        )
        remainder.removeSubrange(range)
        return inner.isEmpty ? nil : inner
    }

    private func extractColor(from remainder: inout String) -> String? {
        // Match trailing `#name` or `#hexvalue` token after the label.
        guard let range = remainder.range(
            of: #"\s+#([A-Za-z0-9_]+)\s*$"#,
            options: .regularExpression
        ) else { return nil }
        let captured = remainder[range]
        let value = captured
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: "")
        remainder.removeSubrange(range)
        return value.isEmpty ? nil : value
    }

    private func stripPrefix(_ prefix: String, _ s: String) -> String? {
        guard s.hasPrefix(prefix) else { return nil }
        return String(s.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    private func insertChild(
        into node: inout PlantUMLWBSNode,
        at path: [Int],
        child: PlantUMLWBSNode
    ) {
        if path.isEmpty {
            node.children.append(child)
            return
        }
        insertChild(into: &node.children[path[0]], at: Array(path.dropFirst()), child: child)
    }

    private func countChildren(in node: PlantUMLWBSNode, at path: [Int]) -> Int {
        if path.isEmpty { return node.children.count }
        return countChildren(in: node.children[path[0]], at: Array(path.dropFirst()))
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
swift test --filter PlantUMLWBSParserTests
```

Expected: all 7 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitPlantUML/WBS/ Tests/DiagramKitTests/PlantUMLWBSParserTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 4 — PlantUMLWBSParser + WBS AST

Parses @startwbs bodies into PlantUMLWBSTree with hierarchical
PlantUMLWBSNodes. Extracts <<shape>> and #color tokens onto AST node
slots (label-stripped). title lines populate tree.title.

Distinct from PlantUMLMindmapTree because WBS targets TreeViewDiagram
(Wave H spec behavior change).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: WBS mapper — AST → `TreeViewDiagram`

**Goal:** Convert `PlantUMLWBSTree` into `TreeViewDiagram` with `TreeViewNode` ids assigned in DFS pre-order. Surface shape/color drops as `.featureDropped(.slotUnsupported, …)` diagnostics. Apply incoming `treeViewNode*` markers via a separate post-mapping hook (the importer in Task 11 runs the scanner and calls this hook).

**Files:**
- Create: `Sources/DiagramKitPlantUML/WBS/PlantUMLWBSMapper.swift`
- Test: `Tests/DiagramKitTests/PlantUMLWBSMapperTests.swift` (new)

- [ ] **Step 1: Write failing mapper tests**

```swift
import Testing
@testable import DiagramKitPlantUML
import DiagramKitModel

@Suite struct PlantUMLWBSMapperTests {
    @Test func mapsSingleRoot() {
        let tree = PlantUMLWBSTree(root: PlantUMLWBSNode(label: "root", depth: 1))
        let (diagram, diagnostics) = PlantUMLWBSMapper().map(tree)
        #expect(diagnostics.isEmpty)
        #expect(diagram.root.id == 0)
        #expect(diagram.root.name == "root")
        #expect(diagram.root.nodeType == .file) // leaf
        #expect(diagram.nodes.count == 1)
    }

    @Test func mapsHierarchyWithDFSPreOrderIds() {
        let inner = PlantUMLWBSNode(label: "grandchild", depth: 3)
        let mid = PlantUMLWBSNode(label: "child1", depth: 2, children: [inner])
        let sib = PlantUMLWBSNode(label: "child2", depth: 2)
        let root = PlantUMLWBSNode(label: "root", depth: 1, children: [mid, sib])
        let (diagram, diagnostics) = PlantUMLWBSMapper().map(PlantUMLWBSTree(root: root))

        #expect(diagnostics.isEmpty)
        #expect(diagram.root.id == 0)
        #expect(diagram.root.name == "root")
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.children.count == 2)

        let c1 = diagram.root.children[0]
        #expect(c1.id == 1)
        #expect(c1.name == "child1")
        #expect(c1.nodeType == .directory)
        #expect(c1.children.count == 1)

        let gc = c1.children[0]
        #expect(gc.id == 2)
        #expect(gc.name == "grandchild")
        #expect(gc.nodeType == .file)

        let c2 = diagram.root.children[1]
        #expect(c2.id == 3)
        #expect(c2.name == "child2")
    }

    @Test func surfacesShapeAndColorAsSlotUnsupported() {
        let root = PlantUMLWBSNode(label: "root", depth: 1, shape: "box", color: "LightBlue")
        let (diagram, diagnostics) = PlantUMLWBSMapper().map(PlantUMLWBSTree(root: root))
        #expect(diagram.root.name == "root")
        #expect(diagnostics.count == 2)
        for d in diagnostics {
            #expect(d.category == .slotUnsupported)
        }
    }

    @Test func surfacesTitle() {
        let tree = PlantUMLWBSTree(
            root: PlantUMLWBSNode(label: "root", depth: 1),
            title: "My Tree"
        )
        let (diagram, _) = PlantUMLWBSMapper().map(tree)
        #expect(diagram.diagramTitle == "My Tree")
    }

    @Test func mapsEmptyTreeToDefaultRoot() {
        let (diagram, diagnostics) = PlantUMLWBSMapper().map(PlantUMLWBSTree())
        #expect(diagnostics.isEmpty)
        #expect(diagram.root.name == "/") // matches TreeViewDiagram.empty
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter PlantUMLWBSMapperTests
```

Expected: build failure.

- [ ] **Step 3: Create the mapper**

`Sources/DiagramKitPlantUML/WBS/PlantUMLWBSMapper.swift`:

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Converts a `PlantUMLWBSTree` into a `TreeViewDiagram` payload.
///
/// Assigns `TreeViewNode.id` in **DFS pre-order**: parent id is allocated
/// before any child id. This invariant is required by the
/// `treeViewNode*` recovery markers in `PlantUMLRecoveryMarker.Kind` —
/// markers reference nodes by their id, and cross-format markers only
/// apply correctly when all treeView mappers (including
/// Mermaid / D2 / DOT) follow the same pre-order assignment.
///
/// WBS-specific shape tokens (`<<box>>`) and color suffixes (`#LightBlue`)
/// have no slot on `TreeViewNode` — they surface as
/// `.featureDropped(.slotUnsupported, …)` diagnostics and are not
/// preserved across round-trip.
public struct PlantUMLWBSMapper {

    public init() {}

    public func map(
        _ tree: PlantUMLWBSTree
    ) -> (model: TreeViewDiagram, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        for line in tree.unsupportedLines {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "PlantUML WBS line not yet supported: \(line)"
            ))
        }

        guard let root = tree.root else {
            return (TreeViewDiagram.empty, diagnostics)
        }

        var counter = 0
        var flat: [TreeViewNode] = []
        let mapped = mapNode(root, level: 0, counter: &counter, flat: &flat, diagnostics: &diagnostics)
        let diagram = TreeViewDiagram(
            root: mapped,
            nodes: flat,
            diagramTitle: tree.title
        )
        return (diagram, diagnostics)
    }

    private func mapNode(
        _ source: PlantUMLWBSNode,
        level: Int,
        counter: inout Int,
        flat: inout [TreeViewNode],
        diagnostics: inout [DiagramDiagnostic]
    ) -> TreeViewNode {
        let id = counter
        counter += 1

        if let shape = source.shape {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "PlantUML WBS shape variant <<\(shape)>> has no TreeViewNode slot"
            ))
        }
        if let color = source.color {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "PlantUML WBS color suffix #\(color) has no TreeViewNode slot"
            ))
        }

        // Reserve node first (pre-order), then recurse into children.
        var node = TreeViewNode(
            id: id,
            level: level,
            name: source.label,
            nodeType: source.children.isEmpty ? .file : .directory,
            children: []
        )
        flat.append(node)

        var children: [TreeViewNode] = []
        for child in source.children {
            children.append(mapNode(
                child,
                level: level + 1,
                counter: &counter,
                flat: &flat,
                diagnostics: &diagnostics
            ))
        }
        node.children = children
        // Replace the placeholder in flat[] with the populated node so
        // `nodes` matches the hierarchy when callers walk by id.
        flat[id] = node
        return node
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter PlantUMLWBSMapperTests
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitPlantUML/WBS/PlantUMLWBSMapper.swift Tests/DiagramKitTests/PlantUMLWBSMapperTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 5 — PlantUMLWBSMapper

Convert PlantUMLWBSTree to TreeViewDiagram. TreeViewNode.id is assigned
in DFS pre-order (parent first, then descend) so cross-format recovery
markers can key by id.

Shape variants (<<box>>) and color suffixes (#LightBlue) have no
TreeViewNode slot — surfaced as .featureDropped(.slotUnsupported, ...)
diagnostics per the Wave H spec.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Migrate existing WBS tests out of `PlantUMLMindmapImporterTests`

**Goal:** The existing `PlantUMLMindmapImporterTests` likely contains `@startwbs` cases expecting a `MindmapDiagram` payload. The Wave H spec retargets `@startwbs` to `TreeViewDiagram`, so those cases must move to a new `PlantUMLWBSImporterTests` and assert against `TreeViewDiagram`. This task migrates the tests but does NOT yet wire up the dispatch — the new tests will still fail until Task 11.

**Files:**
- Read: `Tests/DiagramKitTests/PlantUMLMindmapImporterTests.swift`
- Modify: same — remove WBS cases
- Create: `Tests/DiagramKitTests/PlantUMLWBSImporterTests.swift`

- [ ] **Step 1: Find WBS test cases in mindmap tests**

```bash
grep -n "wbs\|startwbs\|WBS" Tests/DiagramKitTests/PlantUMLMindmapImporterTests.swift
```

- [ ] **Step 2: Extract each WBS test into a new file**

Create `Tests/DiagramKitTests/PlantUMLWBSImporterTests.swift`. For each WBS test in the mindmap file, copy the test body and rewrite the assertion to check for `.treeView(let diagram)` payload instead of `.mindmap`. Use this skeleton:

```swift
import Testing
import Foundation
import DiagramKitPlantUML
import DiagramKitModel

@Suite struct PlantUMLWBSImporterTests {
    @Test func parsesBasicWBS() throws {
        let src = """
        @startwbs
        * root
        ** child
        @endwbs
        """
        let result = try PlantUMLImporter().parse(src)
        guard case .treeView(let diagram) = result.document.payload else {
            Issue.record("expected .treeView payload, got \(result.document.payload)")
            return
        }
        #expect(diagram.root.name == "root")
        #expect(diagram.root.children.count == 1)
        #expect(diagram.root.children[0].name == "child")
    }

    // Copy each previously-WBS test from PlantUMLMindmapImporterTests here
    // with the .treeView assertion shape above.
}
```

- [ ] **Step 3: Remove the WBS cases from the mindmap test file**

Delete each `@Test`/`func test*` that uses `@startwbs` from `PlantUMLMindmapImporterTests.swift`. Leave the `@startmindmap` cases unchanged.

- [ ] **Step 4: Run tests to verify the mindmap tests still pass and WBS tests fail**

```bash
swift test --filter PlantUMLMindmapImporterTests
```

Expected: all remaining mindmap tests pass (they only exercise `@startmindmap`).

```bash
swift test --filter PlantUMLWBSImporterTests
```

Expected: tests fail — `PlantUMLImporter` still routes `@startwbs` to `MindmapDiagram`. This is intentional; Task 11 wires up the new dispatch.

- [ ] **Step 5: Commit**

```bash
git add Tests/DiagramKitTests/PlantUMLMindmapImporterTests.swift Tests/DiagramKitTests/PlantUMLWBSImporterTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 6 — migrate WBS tests out of PlantUMLMindmapImporterTests

Move @startwbs cases into a new PlantUMLWBSImporterTests, asserting
against .treeView payload per the Wave H spec retargeting. Tests will
fail until the importer dispatch is rewired in Task 11.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: JSON parser (thin wrapper over `JSONSerialization`)

**Goal:** Create `PlantUMLJSONParser` that parses `@startjson` bodies via `Foundation.JSONSerialization` and returns a typed value tree. The parser is a thin wrapper — it does NOT shape the data into `TreeViewDiagram`. The mapper in Task 8 handles that.

**Files:**
- Create: `Sources/DiagramKitPlantUML/JSON/PlantUMLJSONParser.swift`
- Test: `Tests/DiagramKitTests/PlantUMLJSONParserTests.swift` (new)

- [ ] **Step 1: Write failing parser tests**

```swift
import Testing
import Foundation
@testable import DiagramKitPlantUML

@Suite struct PlantUMLJSONParserTests {
    @Test func parsesObject() throws {
        let body = #"{ "a": 1, "b": "x" }"#
        let value = try PlantUMLJSONParser().parse(body)
        guard case .object(let pairs) = value else {
            Issue.record("expected object, got \(value)")
            return
        }
        #expect(pairs.count == 2)
        #expect(pairs[0].key == "a")
    }

    @Test func parsesArray() throws {
        let body = #"[1, 2, "three"]"#
        let value = try PlantUMLJSONParser().parse(body)
        guard case .array(let elements) = value else {
            Issue.record("expected array")
            return
        }
        #expect(elements.count == 3)
    }

    @Test func parsesPrimitive() throws {
        let value = try PlantUMLJSONParser().parse("42")
        if case .number(let n) = value {
            #expect(n.contains("42"))
        } else {
            Issue.record("expected number")
        }
    }

    @Test func parsesNull() throws {
        let value = try PlantUMLJSONParser().parse("null")
        #expect(value == .null)
    }

    @Test func parsesBool() throws {
        let value = try PlantUMLJSONParser().parse("true")
        #expect(value == .bool(true))
    }

    @Test func throwsOnMalformed() {
        #expect(throws: Error.self) {
            try PlantUMLJSONParser().parse("{ malformed")
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter PlantUMLJSONParserTests
```

Expected: build failure.

- [ ] **Step 3: Create the parser**

`Sources/DiagramKitPlantUML/JSON/PlantUMLJSONParser.swift`:

```swift
import Foundation
import DiagramKitCommon

/// Typed value tree produced by `PlantUMLJSONParser`. Preserves source
/// order of object keys (which `JSONSerialization` does not on its own
/// when decoding to `[String: Any]`). The parser re-walks the raw bytes
/// to recover insertion order.
public indirect enum PlantUMLJSONValue: Sendable, Equatable {
    case object([(key: String, value: PlantUMLJSONValue)])
    case array([PlantUMLJSONValue])
    case string(String)
    case number(String)  // preserved as text so 42 ≠ 42.0
    case bool(Bool)
    case null

    public static func == (lhs: PlantUMLJSONValue, rhs: PlantUMLJSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.bool(let l), .bool(let r)): return l == r
        case (.string(let l), .string(let r)): return l == r
        case (.number(let l), .number(let r)): return l == r
        case (.array(let l), .array(let r)): return l == r
        case (.object(let l), .object(let r)):
            guard l.count == r.count else { return false }
            for (a, b) in zip(l, r) {
                if a.key != b.key || a.value != b.value { return false }
            }
            return true
        default: return false
        }
    }
}

/// Parses `@startjson` bodies via `Foundation.JSONSerialization` and a
/// minimal lexer-driven re-walk to preserve object-key insertion order.
public struct PlantUMLJSONParser {

    public init() {}

    public func parse(_ body: String) throws -> PlantUMLJSONValue {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DiagramError.malformedSource(message: "PlantUML @startjson body is empty")
        }
        var index = trimmed.startIndex
        let value = try parseValue(trimmed, index: &index)
        skipWhitespace(trimmed, index: &index)
        guard index == trimmed.endIndex else {
            throw DiagramError.malformedSource(
                message: "PlantUML @startjson: trailing data after value"
            )
        }
        return value
    }

    private func parseValue(_ s: String, index: inout String.Index) throws -> PlantUMLJSONValue {
        skipWhitespace(s, index: &index)
        guard index < s.endIndex else {
            throw DiagramError.malformedSource(message: "PlantUML @startjson: unexpected end")
        }
        switch s[index] {
        case "{": return try parseObject(s, index: &index)
        case "[": return try parseArray(s, index: &index)
        case "\"": return .string(try parseString(s, index: &index))
        case "t", "f": return .bool(try parseBool(s, index: &index))
        case "n": return try parseNull(s, index: &index)
        case "-", "0"..."9": return .number(try parseNumber(s, index: &index))
        default:
            throw DiagramError.malformedSource(
                message: "PlantUML @startjson: unexpected character '\(s[index])'"
            )
        }
    }

    private func parseObject(_ s: String, index: inout String.Index) throws -> PlantUMLJSONValue {
        index = s.index(after: index)  // consume '{'
        var pairs: [(key: String, value: PlantUMLJSONValue)] = []
        skipWhitespace(s, index: &index)
        if index < s.endIndex, s[index] == "}" {
            index = s.index(after: index)
            return .object(pairs)
        }
        while index < s.endIndex {
            skipWhitespace(s, index: &index)
            guard index < s.endIndex, s[index] == "\"" else {
                throw DiagramError.malformedSource(message: "PlantUML @startjson: expected string key")
            }
            let key = try parseString(s, index: &index)
            skipWhitespace(s, index: &index)
            guard index < s.endIndex, s[index] == ":" else {
                throw DiagramError.malformedSource(message: "PlantUML @startjson: expected ':'")
            }
            index = s.index(after: index)
            let value = try parseValue(s, index: &index)
            pairs.append((key: key, value: value))
            skipWhitespace(s, index: &index)
            if index < s.endIndex, s[index] == "," {
                index = s.index(after: index)
                continue
            }
            if index < s.endIndex, s[index] == "}" {
                index = s.index(after: index)
                return .object(pairs)
            }
            throw DiagramError.malformedSource(message: "PlantUML @startjson: expected ',' or '}'")
        }
        throw DiagramError.malformedSource(message: "PlantUML @startjson: unterminated object")
    }

    private func parseArray(_ s: String, index: inout String.Index) throws -> PlantUMLJSONValue {
        index = s.index(after: index)  // consume '['
        var elements: [PlantUMLJSONValue] = []
        skipWhitespace(s, index: &index)
        if index < s.endIndex, s[index] == "]" {
            index = s.index(after: index)
            return .array(elements)
        }
        while index < s.endIndex {
            elements.append(try parseValue(s, index: &index))
            skipWhitespace(s, index: &index)
            if index < s.endIndex, s[index] == "," {
                index = s.index(after: index)
                continue
            }
            if index < s.endIndex, s[index] == "]" {
                index = s.index(after: index)
                return .array(elements)
            }
            throw DiagramError.malformedSource(message: "PlantUML @startjson: expected ',' or ']'")
        }
        throw DiagramError.malformedSource(message: "PlantUML @startjson: unterminated array")
    }

    private func parseString(_ s: String, index: inout String.Index) throws -> String {
        guard index < s.endIndex, s[index] == "\"" else {
            throw DiagramError.malformedSource(message: "PlantUML @startjson: expected '\"'")
        }
        index = s.index(after: index)
        var out = ""
        while index < s.endIndex {
            let ch = s[index]
            if ch == "\"" {
                index = s.index(after: index)
                return out
            }
            if ch == "\\" {
                index = s.index(after: index)
                guard index < s.endIndex else { break }
                switch s[index] {
                case "\"": out.append("\"")
                case "\\": out.append("\\")
                case "/": out.append("/")
                case "n": out.append("\n")
                case "t": out.append("\t")
                case "r": out.append("\r")
                case "b": out.append("\u{08}")
                case "f": out.append("\u{0C}")
                case "u":
                    // 4-hex Unicode escape
                    let start = s.index(after: index)
                    guard let end = s.index(start, offsetBy: 4, limitedBy: s.endIndex) else {
                        throw DiagramError.malformedSource(message: "PlantUML @startjson: short \\u escape")
                    }
                    guard let cp = UInt32(s[start..<end], radix: 16),
                          let scalar = Unicode.Scalar(cp) else {
                        throw DiagramError.malformedSource(message: "PlantUML @startjson: bad \\u escape")
                    }
                    out.append(Character(scalar))
                    index = s.index(before: end)
                default: out.append(s[index])
                }
                index = s.index(after: index)
            } else {
                out.append(ch)
                index = s.index(after: index)
            }
        }
        throw DiagramError.malformedSource(message: "PlantUML @startjson: unterminated string")
    }

    private func parseBool(_ s: String, index: inout String.Index) throws -> Bool {
        if s[index...].hasPrefix("true") {
            index = s.index(index, offsetBy: 4)
            return true
        }
        if s[index...].hasPrefix("false") {
            index = s.index(index, offsetBy: 5)
            return false
        }
        throw DiagramError.malformedSource(message: "PlantUML @startjson: expected true/false")
    }

    private func parseNull(_ s: String, index: inout String.Index) throws -> PlantUMLJSONValue {
        guard s[index...].hasPrefix("null") else {
            throw DiagramError.malformedSource(message: "PlantUML @startjson: expected null")
        }
        index = s.index(index, offsetBy: 4)
        return .null
    }

    private func parseNumber(_ s: String, index: inout String.Index) throws -> String {
        let start = index
        if s[index] == "-" { index = s.index(after: index) }
        while index < s.endIndex, "0"..."9" ~= s[index] || s[index] == "." || s[index] == "e" || s[index] == "E" || s[index] == "+" || s[index] == "-" {
            index = s.index(after: index)
        }
        let token = String(s[start..<index])
        guard !token.isEmpty, Double(token) != nil else {
            throw DiagramError.malformedSource(message: "PlantUML @startjson: invalid number '\(token)'")
        }
        return token
    }

    private func skipWhitespace(_ s: String, index: inout String.Index) {
        while index < s.endIndex, s[index].isWhitespace {
            index = s.index(after: index)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter PlantUMLJSONParserTests
```

Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitPlantUML/JSON/ Tests/DiagramKitTests/PlantUMLJSONParserTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 7 — PlantUMLJSONParser

Hand-rolled JSON parser producing a typed PlantUMLJSONValue tree that
preserves object-key insertion order (JSONSerialization on [String: Any]
loses it). Supports the full JSON grammar: object, array, string,
number, bool, null, escape sequences including \\uXXXX.

The mapper in Task 8 shapes this into TreeViewDiagram.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: JSON mapper — `PlantUMLJSONValue` → `TreeViewDiagram`

**Goal:** Shape the parsed JSON tree into a `TreeViewDiagram`. Objects/arrays ⇒ `.directory`; primitives ⇒ `.file` with the literal in `description`. Synthesize a `(root)` container if the document itself is a primitive. DFS pre-order id assignment matches the WBS mapper.

**Files:**
- Create: `Sources/DiagramKitPlantUML/JSON/PlantUMLJSONMapper.swift`
- Test: `Tests/DiagramKitTests/PlantUMLJSONMapperTests.swift` (new)

- [ ] **Step 1: Write failing mapper tests**

```swift
import Testing
@testable import DiagramKitPlantUML
import DiagramKitModel

@Suite struct PlantUMLJSONMapperTests {
    @Test func mapsObjectToDirectoryWithStringKeys() throws {
        let value = PlantUMLJSONValue.object([
            (key: "a", value: .number("1")),
            (key: "b", value: .string("hello"))
        ])
        let (diagram, diagnostics) = PlantUMLJSONMapper().map(value)
        #expect(diagnostics.isEmpty)
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.id == 0)
        #expect(diagram.root.children.count == 2)
        #expect(diagram.root.children[0].name == "a")
        #expect(diagram.root.children[0].id == 1)
        #expect(diagram.root.children[0].nodeType == .file)
        #expect(diagram.root.children[0].description == "1")
        #expect(diagram.root.children[1].name == "b")
        #expect(diagram.root.children[1].id == 2)
        #expect(diagram.root.children[1].description == "\"hello\"")
    }

    @Test func mapsArrayWithIndexedNames() {
        let value = PlantUMLJSONValue.array([.number("10"), .number("20")])
        let (diagram, _) = PlantUMLJSONMapper().map(value)
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.children.count == 2)
        #expect(diagram.root.children[0].name == "[0]")
        #expect(diagram.root.children[1].name == "[1]")
    }

    @Test func synthesizesRootForPrimitiveDocument() {
        let value = PlantUMLJSONValue.number("42")
        let (diagram, _) = PlantUMLJSONMapper().map(value)
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.name == "(root)")
        #expect(diagram.root.children.count == 1)
        #expect(diagram.root.children[0].description == "42")
    }

    @Test func encodesNullAndBoolLiterals() {
        let value = PlantUMLJSONValue.object([
            (key: "n", value: .null),
            (key: "b", value: .bool(true))
        ])
        let (diagram, _) = PlantUMLJSONMapper().map(value)
        #expect(diagram.root.children[0].description == "null")
        #expect(diagram.root.children[1].description == "true")
    }

    @Test func assignsDFSPreOrderIds() {
        let value = PlantUMLJSONValue.object([
            (key: "outer", value: .object([
                (key: "inner", value: .number("1"))
            ])),
            (key: "sibling", value: .number("2"))
        ])
        let (diagram, _) = PlantUMLJSONMapper().map(value)
        #expect(diagram.root.id == 0)
        #expect(diagram.root.children[0].id == 1)         // outer
        #expect(diagram.root.children[0].children[0].id == 2) // inner
        #expect(diagram.root.children[1].id == 3)         // sibling
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter PlantUMLJSONMapperTests
```

- [ ] **Step 3: Create the mapper**

`Sources/DiagramKitPlantUML/JSON/PlantUMLJSONMapper.swift`:

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Converts a `PlantUMLJSONValue` into a `TreeViewDiagram`. Mapping:
///
///   - object ⇒ `.directory`, children keyed by their JSON key
///   - array  ⇒ `.directory`, children named `[0]`, `[1]`, …
///   - string ⇒ `.file`, description = `"literal"` (with quotes)
///   - number/bool/null ⇒ `.file`, description = literal text
///
/// Primitive documents (root is a string/number/bool/null) are wrapped
/// in a synthesized `.directory` node named `(root)` so
/// `TreeViewDiagram.root` (non-optional) always has structural context.
///
/// `TreeViewNode.id` is assigned in DFS pre-order (parent before children).
public struct PlantUMLJSONMapper {

    public init() {}

    public func map(
        _ value: PlantUMLJSONValue
    ) -> (model: TreeViewDiagram, diagnostics: [DiagramDiagnostic]) {
        var counter = 0
        var flat: [TreeViewNode] = []
        let diagnostics: [DiagramDiagnostic] = []

        let rootNode: TreeViewNode
        switch value {
        case .object, .array:
            rootNode = buildNode(
                name: "(root)",
                value: value,
                level: 0,
                counter: &counter,
                flat: &flat
            )
        default:
            // Wrap primitive root in synthesized container.
            let containerId = counter
            counter += 1
            flat.append(TreeViewNode(id: containerId, level: 0, name: "(root)", nodeType: .directory))
            let child = buildLeaf(
                name: literalName(for: value),
                value: value,
                level: 1,
                counter: &counter,
                flat: &flat
            )
            var container = flat[containerId]
            container.children = [child]
            flat[containerId] = container
            rootNode = container
        }

        return (TreeViewDiagram(root: rootNode, nodes: flat), diagnostics)
    }

    private func buildNode(
        name: String,
        value: PlantUMLJSONValue,
        level: Int,
        counter: inout Int,
        flat: inout [TreeViewNode]
    ) -> TreeViewNode {
        let id = counter
        counter += 1

        switch value {
        case .object(let pairs):
            flat.append(TreeViewNode(id: id, level: level, name: name, nodeType: .directory))
            var children: [TreeViewNode] = []
            for (key, val) in pairs {
                children.append(buildNode(
                    name: key,
                    value: val,
                    level: level + 1,
                    counter: &counter,
                    flat: &flat
                ))
            }
            var node = flat[id]
            node.children = children
            flat[id] = node
            return node

        case .array(let elements):
            flat.append(TreeViewNode(id: id, level: level, name: name, nodeType: .directory))
            var children: [TreeViewNode] = []
            for (idx, val) in elements.enumerated() {
                children.append(buildNode(
                    name: "[\(idx)]",
                    value: val,
                    level: level + 1,
                    counter: &counter,
                    flat: &flat
                ))
            }
            var node = flat[id]
            node.children = children
            flat[id] = node
            return node

        case .string, .number, .bool, .null:
            let leaf = TreeViewNode(
                id: id,
                level: level,
                name: name,
                nodeType: .file,
                description: literalDescription(for: value)
            )
            flat.append(leaf)
            return leaf
        }
    }

    private func buildLeaf(
        name: String,
        value: PlantUMLJSONValue,
        level: Int,
        counter: inout Int,
        flat: inout [TreeViewNode]
    ) -> TreeViewNode {
        let id = counter
        counter += 1
        let leaf = TreeViewNode(
            id: id,
            level: level,
            name: name,
            nodeType: .file,
            description: literalDescription(for: value)
        )
        flat.append(leaf)
        return leaf
    }

    private func literalName(for value: PlantUMLJSONValue) -> String {
        switch value {
        case .string: return "string"
        case .number: return "number"
        case .bool:   return "bool"
        case .null:   return "null"
        case .object, .array: return "(root)"
        }
    }

    private func literalDescription(for value: PlantUMLJSONValue) -> String {
        switch value {
        case .string(let s): return "\"\(s)\""
        case .number(let n): return n
        case .bool(let b):   return b ? "true" : "false"
        case .null:          return "null"
        case .object, .array: return ""
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter PlantUMLJSONMapperTests
```

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitPlantUML/JSON/PlantUMLJSONMapper.swift Tests/DiagramKitTests/PlantUMLJSONMapperTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 8 — PlantUMLJSONMapper

Shape PlantUMLJSONValue into TreeViewDiagram. Objects/arrays become
.directory nodes; primitives become .file leaves with the JSON literal
in description. Primitive document roots wrap in a synthesized "(root)"
container so TreeViewDiagram.root is always populated.

DFS pre-order id assignment matches PlantUMLWBSMapper for cross-mapper
marker compatibility.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: YAML parser (minimal indent scanner)

**Goal:** Hand-rolled YAML subset parser supporting block mappings, block sequences, plain + quoted scalars, line comments. Unsupported features emit `.featureDropped(.slotUnsupported, …)` diagnostics rather than aborting the parse.

**Files:**
- Create: `Sources/DiagramKitPlantUML/YAML/PlantUMLYAMLParser.swift`
- Test: `Tests/DiagramKitTests/PlantUMLYAMLParserTests.swift` (new)

- [ ] **Step 1: Write failing parser tests**

```swift
import Testing
@testable import DiagramKitPlantUML

@Suite struct PlantUMLYAMLParserTests {
    @Test func parsesBlockMapping() throws {
        let body = """
        a: 1
        b: hello
        """
        let result = try PlantUMLYAMLParser().parse(body)
        guard case .mapping(let pairs) = result.value else {
            Issue.record("expected mapping")
            return
        }
        #expect(pairs.count == 2)
        #expect(pairs[0].key == "a")
        #expect(pairs[1].key == "b")
        #expect(result.unsupportedFeatures.isEmpty)
    }

    @Test func parsesBlockSequence() throws {
        let body = """
        - one
        - two
        - three
        """
        let result = try PlantUMLYAMLParser().parse(body)
        guard case .sequence(let elements) = result.value else {
            Issue.record("expected sequence")
            return
        }
        #expect(elements.count == 3)
    }

    @Test func parsesNestedStructure() throws {
        let body = """
        outer:
          inner:
            leaf: value
          list:
            - a
            - b
        """
        let result = try PlantUMLYAMLParser().parse(body)
        guard case .mapping(let topPairs) = result.value else {
            Issue.record("expected mapping")
            return
        }
        #expect(topPairs.count == 1)
        #expect(topPairs[0].key == "outer")
        guard case .mapping(let outerPairs) = topPairs[0].value else {
            Issue.record("expected nested mapping")
            return
        }
        #expect(outerPairs.count == 2)
    }

    @Test func parsesQuotedScalar() throws {
        let body = #"key: "hello world""#
        let result = try PlantUMLYAMLParser().parse(body)
        guard case .mapping(let pairs) = result.value,
              case .scalar(let raw) = pairs[0].value else {
            Issue.record("expected mapping → scalar")
            return
        }
        #expect(raw == "\"hello world\"")
    }

    @Test func skipsLineComments() throws {
        let body = """
        # a header comment
        a: 1
        # mid comment
        b: 2
        """
        let result = try PlantUMLYAMLParser().parse(body)
        guard case .mapping(let pairs) = result.value else {
            Issue.record("expected mapping")
            return
        }
        #expect(pairs.count == 2)
    }

    @Test func reportsAnchorAsUnsupported() throws {
        let body = """
        a: &anchor 1
        b: *anchor
        """
        let result = try PlantUMLYAMLParser().parse(body)
        #expect(result.unsupportedFeatures.contains { $0.contains("anchor") })
    }

    @Test func reportsTagAsUnsupported() throws {
        let body = """
        a: !!str 1
        """
        let result = try PlantUMLYAMLParser().parse(body)
        #expect(result.unsupportedFeatures.contains { $0.contains("tag") })
    }

    @Test func reportsFlowStyleAsUnsupported() throws {
        let body = #"a: {b: 1}"#
        let result = try PlantUMLYAMLParser().parse(body)
        #expect(result.unsupportedFeatures.contains { $0.contains("flow") })
    }

    @Test func reportsMultiDocAsUnsupported() throws {
        let body = """
        a: 1
        ---
        b: 2
        """
        let result = try PlantUMLYAMLParser().parse(body)
        #expect(result.unsupportedFeatures.contains { $0.contains("multi-document") })
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter PlantUMLYAMLParserTests
```

- [ ] **Step 3: Create the parser**

`Sources/DiagramKitPlantUML/YAML/PlantUMLYAMLParser.swift`:

```swift
import Foundation
import DiagramKitCommon

public indirect enum PlantUMLYAMLValue: Sendable, Equatable {
    case mapping([(key: String, value: PlantUMLYAMLValue)])
    case sequence([PlantUMLYAMLValue])
    case scalar(String)  // raw token (quoted strings keep their quotes)

    public static func == (lhs: PlantUMLYAMLValue, rhs: PlantUMLYAMLValue) -> Bool {
        switch (lhs, rhs) {
        case (.scalar(let l), .scalar(let r)): return l == r
        case (.sequence(let l), .sequence(let r)): return l == r
        case (.mapping(let l), .mapping(let r)):
            guard l.count == r.count else { return false }
            for (a, b) in zip(l, r) {
                if a.key != b.key || a.value != b.value { return false }
            }
            return true
        default: return false
        }
    }
}

public struct PlantUMLYAMLParseResult: Sendable {
    public let value: PlantUMLYAMLValue
    public let unsupportedFeatures: [String]
}

/// Minimal YAML subset parser. Supports block mappings, block sequences,
/// plain + quoted scalars, line comments. Unsupported features are
/// detected and reported via `unsupportedFeatures`; the parser then
/// continues with a best-effort recovery (skips the offending construct).
public struct PlantUMLYAMLParser {

    public init() {}

    public func parse(_ body: String) throws -> PlantUMLYAMLParseResult {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DiagramError.malformedSource(message: "PlantUML @startyaml body is empty")
        }

        // Pre-scan for unsupported features so the result is honest.
        var unsupported: [String] = []
        let rawLines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        var sawDocSep = false
        for raw in rawLines {
            let line = String(raw)
            let stripped = line.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
            if stripped.trimmingCharacters(in: .whitespaces) == "---" {
                if sawDocSep {
                    unsupported.append("YAML feature: multi-document streams")
                    break
                }
                sawDocSep = true
                continue
            }
            if stripped.contains("&") {
                unsupported.append("YAML feature: anchor (&name)")
            }
            if stripped.contains(" *") || stripped.contains(":*") {
                unsupported.append("YAML feature: alias (*name)")
            }
            if stripped.contains("!!") || stripped.range(of: #"!\w"#, options: .regularExpression) != nil {
                unsupported.append("YAML feature: tag (!!t / !Tag)")
            }
            if stripped.contains("{") || stripped.contains("[") {
                unsupported.append("YAML feature: flow style ({…}, […])")
            }
            if stripped.hasSuffix("|") || stripped.hasSuffix(">") {
                unsupported.append("YAML feature: block scalar (|, >)")
            }
        }

        // Filter out lines after the first `---` and lines that contain
        // unsupported tokens so the rest can parse as a plain subset.
        var workingLines: [String] = []
        var docCutoff = false
        for raw in rawLines {
            let line = String(raw)
            let withoutComment = line.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
            let stripped = withoutComment.trimmingCharacters(in: .whitespaces)
            if stripped == "---" {
                if docCutoff { break }
                docCutoff = true
                continue
            }
            // Drop lines that contain unsupported tokens entirely.
            if line.contains("&") || line.contains("!!") || line.contains("{") || line.contains("[") {
                continue
            }
            workingLines.append(line)
        }

        var index = 0
        let value = try parseBlock(lines: workingLines, indent: 0, index: &index)

        let unique = Array(Set(unsupported))
        return PlantUMLYAMLParseResult(value: value, unsupportedFeatures: unique)
    }

    private func parseBlock(
        lines: [String],
        indent baseIndent: Int,
        index: inout Int
    ) throws -> PlantUMLYAMLValue {
        // Decide block kind by the first non-blank line.
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                index += 1
                continue
            }
            let lineIndent = leadingSpaces(lines[index])
            if lineIndent < baseIndent {
                return .mapping([])  // empty block
            }
            if trimmed.hasPrefix("- ") || trimmed == "-" {
                return try parseSequence(lines: lines, indent: lineIndent, index: &index)
            }
            return try parseMapping(lines: lines, indent: lineIndent, index: &index)
        }
        return .mapping([])
    }

    private func parseMapping(
        lines: [String],
        indent baseIndent: Int,
        index: inout Int
    ) throws -> PlantUMLYAMLValue {
        var pairs: [(key: String, value: PlantUMLYAMLValue)] = []
        while index < lines.count {
            let line = lines[index]
            let stripped = line.trimmingCharacters(in: .whitespaces)
            if stripped.isEmpty {
                index += 1
                continue
            }
            let lineIndent = leadingSpaces(line)
            if lineIndent < baseIndent { return .mapping(pairs) }
            if lineIndent > baseIndent {
                // Should not happen at top of mapping iteration.
                index += 1
                continue
            }
            guard let colonRange = stripped.range(of: ":") else {
                throw DiagramError.malformedSource(
                    message: "PlantUML @startyaml: expected 'key: value' at line \(index + 1)"
                )
            }
            let key = String(stripped[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let valuePart = String(stripped[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            index += 1
            if valuePart.isEmpty {
                // Block child follows.
                let child = try parseBlock(lines: lines, indent: baseIndent + 1, index: &index)
                pairs.append((key: key, value: child))
            } else {
                pairs.append((key: key, value: .scalar(valuePart)))
            }
        }
        return .mapping(pairs)
    }

    private func parseSequence(
        lines: [String],
        indent baseIndent: Int,
        index: inout Int
    ) throws -> PlantUMLYAMLValue {
        var elements: [PlantUMLYAMLValue] = []
        while index < lines.count {
            let line = lines[index]
            let stripped = line.trimmingCharacters(in: .whitespaces)
            if stripped.isEmpty {
                index += 1
                continue
            }
            let lineIndent = leadingSpaces(line)
            if lineIndent < baseIndent { return .sequence(elements) }
            if lineIndent > baseIndent {
                index += 1
                continue
            }
            guard stripped.hasPrefix("- ") || stripped == "-" else {
                return .sequence(elements)
            }
            let rest = stripped == "-" ? "" : String(stripped.dropFirst(2))
            index += 1
            if rest.isEmpty {
                let child = try parseBlock(lines: lines, indent: baseIndent + 1, index: &index)
                elements.append(child)
            } else {
                elements.append(.scalar(rest))
            }
        }
        return .sequence(elements)
    }

    private func leadingSpaces(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == " " { count += 1 }
            else if ch == "\t" { count += 2 }  // treat tab as 2 spaces
            else { break }
        }
        return count
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter PlantUMLYAMLParserTests
```

Expected: 9 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitPlantUML/YAML/ Tests/DiagramKitTests/PlantUMLYAMLParserTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 9 — PlantUMLYAMLParser (minimal subset)

Indent-scanner YAML parser supporting block mappings, block sequences,
plain + quoted scalars, line comments. Detects and reports unsupported
features (anchors, aliases, tags, multi-doc, flow style, block scalars)
via PlantUMLYAMLParseResult.unsupportedFeatures rather than aborting.

The mapper in Task 10 surfaces unsupportedFeatures as
.featureDropped(.slotUnsupported, ...) diagnostics.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: YAML mapper — `PlantUMLYAMLValue` → `TreeViewDiagram`

**Goal:** Shape parsed YAML into a `TreeViewDiagram` with the same conventions as the JSON mapper (mappings/sequences ⇒ `.directory`; scalars ⇒ `.file` with the literal in description). Surface `unsupportedFeatures` from the parser as `.featureDropped(.slotUnsupported, …)` diagnostics. DFS pre-order ids.

**Files:**
- Create: `Sources/DiagramKitPlantUML/YAML/PlantUMLYAMLMapper.swift`
- Test: `Tests/DiagramKitTests/PlantUMLYAMLMapperTests.swift` (new)

- [ ] **Step 1: Write failing mapper tests**

```swift
import Testing
@testable import DiagramKitPlantUML
import DiagramKitCommon
import DiagramKitModel

@Suite struct PlantUMLYAMLMapperTests {
    @Test func mapsMappingToDirectoryWithStringKeys() {
        let value = PlantUMLYAMLValue.mapping([
            (key: "a", value: .scalar("1")),
            (key: "b", value: .scalar("hello"))
        ])
        let (diagram, diagnostics) = PlantUMLYAMLMapper().map(
            PlantUMLYAMLParseResult(value: value, unsupportedFeatures: [])
        )
        #expect(diagnostics.isEmpty)
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.children.count == 2)
        #expect(diagram.root.children[0].name == "a")
        #expect(diagram.root.children[0].description == "1")
    }

    @Test func mapsSequenceWithIndexedNames() {
        let value = PlantUMLYAMLValue.sequence([.scalar("x"), .scalar("y")])
        let (diagram, _) = PlantUMLYAMLMapper().map(
            PlantUMLYAMLParseResult(value: value, unsupportedFeatures: [])
        )
        #expect(diagram.root.children.count == 2)
        #expect(diagram.root.children[0].name == "[0]")
        #expect(diagram.root.children[1].name == "[1]")
    }

    @Test func synthesizesRootForScalarDocument() {
        let value = PlantUMLYAMLValue.scalar("just-a-scalar")
        let (diagram, _) = PlantUMLYAMLMapper().map(
            PlantUMLYAMLParseResult(value: value, unsupportedFeatures: [])
        )
        #expect(diagram.root.name == "(root)")
        #expect(diagram.root.nodeType == .directory)
        #expect(diagram.root.children.count == 1)
        #expect(diagram.root.children[0].description == "just-a-scalar")
    }

    @Test func surfacesUnsupportedFeaturesAsDiagnostics() {
        let value = PlantUMLYAMLValue.mapping([
            (key: "a", value: .scalar("1"))
        ])
        let (_, diagnostics) = PlantUMLYAMLMapper().map(
            PlantUMLYAMLParseResult(
                value: value,
                unsupportedFeatures: [
                    "YAML feature: anchor (&name)",
                    "YAML feature: flow style ({…}, […])"
                ]
            )
        )
        #expect(diagnostics.count == 2)
        for d in diagnostics {
            #expect(d.category == .slotUnsupported)
        }
    }

    @Test func assignsDFSPreOrderIds() {
        let value = PlantUMLYAMLValue.mapping([
            (key: "outer", value: .mapping([
                (key: "inner", value: .scalar("1"))
            ])),
            (key: "sibling", value: .scalar("2"))
        ])
        let (diagram, _) = PlantUMLYAMLMapper().map(
            PlantUMLYAMLParseResult(value: value, unsupportedFeatures: [])
        )
        #expect(diagram.root.id == 0)
        #expect(diagram.root.children[0].id == 1)
        #expect(diagram.root.children[0].children[0].id == 2)
        #expect(diagram.root.children[1].id == 3)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter PlantUMLYAMLMapperTests
```

- [ ] **Step 3: Create the mapper**

`Sources/DiagramKitPlantUML/YAML/PlantUMLYAMLMapper.swift`:

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Converts `PlantUMLYAMLParseResult` into a `TreeViewDiagram`.
/// Conventions mirror `PlantUMLJSONMapper`:
///   - mapping  ⇒ `.directory` with string keys
///   - sequence ⇒ `.directory` with `[i]` keys
///   - scalar   ⇒ `.file` with raw token in description
///
/// Scalar document roots wrap in a synthesized `(root)` container.
/// `unsupportedFeatures` from the parser surface as
/// `.featureDropped(.slotUnsupported, …)` diagnostics.
/// `TreeViewNode.id` is assigned in DFS pre-order.
public struct PlantUMLYAMLMapper {

    public init() {}

    public func map(
        _ result: PlantUMLYAMLParseResult
    ) -> (model: TreeViewDiagram, diagnostics: [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        for feature in result.unsupportedFeatures {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: feature
            ))
        }

        var counter = 0
        var flat: [TreeViewNode] = []

        let rootNode: TreeViewNode
        switch result.value {
        case .mapping, .sequence:
            rootNode = buildNode(
                name: "(root)",
                value: result.value,
                level: 0,
                counter: &counter,
                flat: &flat
            )
        case .scalar(let raw):
            let containerId = counter
            counter += 1
            flat.append(TreeViewNode(id: containerId, level: 0, name: "(root)", nodeType: .directory))
            let leafId = counter
            counter += 1
            let leaf = TreeViewNode(
                id: leafId,
                level: 1,
                name: "scalar",
                nodeType: .file,
                description: raw
            )
            flat.append(leaf)
            var container = flat[containerId]
            container.children = [leaf]
            flat[containerId] = container
            rootNode = container
        }

        return (TreeViewDiagram(root: rootNode, nodes: flat), diagnostics)
    }

    private func buildNode(
        name: String,
        value: PlantUMLYAMLValue,
        level: Int,
        counter: inout Int,
        flat: inout [TreeViewNode]
    ) -> TreeViewNode {
        let id = counter
        counter += 1

        switch value {
        case .mapping(let pairs):
            flat.append(TreeViewNode(id: id, level: level, name: name, nodeType: .directory))
            var children: [TreeViewNode] = []
            for (key, val) in pairs {
                children.append(buildNode(
                    name: key, value: val, level: level + 1, counter: &counter, flat: &flat
                ))
            }
            var node = flat[id]
            node.children = children
            flat[id] = node
            return node

        case .sequence(let elements):
            flat.append(TreeViewNode(id: id, level: level, name: name, nodeType: .directory))
            var children: [TreeViewNode] = []
            for (idx, val) in elements.enumerated() {
                children.append(buildNode(
                    name: "[\(idx)]", value: val, level: level + 1, counter: &counter, flat: &flat
                ))
            }
            var node = flat[id]
            node.children = children
            flat[id] = node
            return node

        case .scalar(let raw):
            let leaf = TreeViewNode(
                id: id, level: level, name: name, nodeType: .file, description: raw
            )
            flat.append(leaf)
            return leaf
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter PlantUMLYAMLMapperTests
```

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitPlantUML/YAML/PlantUMLYAMLMapper.swift Tests/DiagramKitTests/PlantUMLYAMLMapperTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 10 — PlantUMLYAMLMapper

Shape PlantUMLYAMLParseResult into TreeViewDiagram. Mappings/sequences
become .directory nodes; scalars become .file leaves with the raw
token in description. Scalar document roots wrap in synthesized "(root)"
container.

unsupportedFeatures surface as .featureDropped(.slotUnsupported, ...)
diagnostics. DFS pre-order ids match the WBS and JSON mappers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Wire WBS / JSON / YAML branches into `PlantUMLImporter`

**Goal:** Add three new dispatch branches at the top of `PlantUMLImporter.parse(_:)`. Apply incoming treeView markers via a helper analogous to `applyActivityOriginalIdMarkers`. Add `.treeView` to `supportedDiagramTypes`.

**Files:**
- Modify: `Sources/DiagramKitPlantUML/PlantUMLImporter.swift`
- Test: `Tests/DiagramKitTests/PlantUMLWBSImporterTests.swift` (created in Task 6 — these should now pass)
- Test: `Tests/DiagramKitTests/PlantUMLJSONImporterTests.swift` (new)
- Test: `Tests/DiagramKitTests/PlantUMLYAMLImporterTests.swift` (new)

- [ ] **Step 1: Write end-to-end importer tests for JSON and YAML**

`Tests/DiagramKitTests/PlantUMLJSONImporterTests.swift`:

```swift
import Testing
import DiagramKitPlantUML
import DiagramKitModel

@Suite struct PlantUMLJSONImporterTests {
    @Test func parsesBasicJSON() throws {
        let src = """
        @startjson
        { "a": 1, "b": "hello" }
        @endjson
        """
        let result = try PlantUMLImporter().parse(src)
        guard case .treeView(let diagram) = result.document.payload else {
            Issue.record("expected .treeView")
            return
        }
        #expect(diagram.root.children.count == 2)
        #expect(diagram.root.children[0].name == "a")
        #expect(diagram.root.children[0].description == "1")
    }

    @Test func parsesPrimitiveRootJSON() throws {
        let src = """
        @startjson
        42
        @endjson
        """
        let result = try PlantUMLImporter().parse(src)
        guard case .treeView(let diagram) = result.document.payload else {
            Issue.record("expected .treeView")
            return
        }
        #expect(diagram.root.name == "(root)")
        #expect(diagram.root.children.count == 1)
        #expect(diagram.root.children[0].description == "42")
    }

    @Test func appliesIncomingDescriptionMarker() throws {
        // The exporter emits markers above the @startwbs body, but for
        // round-trip parity the importer scans the full source. For JSON
        // sources we don't expect markers in fresh input; this test
        // guards against marker drops when JSON is re-imported after
        // being exported and re-imported.
        let src = """
        ' diagramkit:treeview-node-description=1,b64:Zm9v
        @startjson
        { "a": 1 }
        @endjson
        """
        let result = try PlantUMLImporter().parse(src)
        guard case .treeView(let diagram) = result.document.payload else {
            Issue.record("expected .treeView")
            return
        }
        // Marker overrides parser-supplied description on node id 1.
        #expect(diagram.root.children[0].id == 1)
        #expect(diagram.root.children[0].description == "foo")
    }
}
```

`Tests/DiagramKitTests/PlantUMLYAMLImporterTests.swift`:

```swift
import Testing
import DiagramKitPlantUML
import DiagramKitModel

@Suite struct PlantUMLYAMLImporterTests {
    @Test func parsesBasicYAML() throws {
        let src = """
        @startyaml
        a: 1
        b: hello
        @endyaml
        """
        let result = try PlantUMLImporter().parse(src)
        guard case .treeView(let diagram) = result.document.payload else {
            Issue.record("expected .treeView")
            return
        }
        #expect(diagram.root.children.count == 2)
    }

    @Test func parsesNestedYAML() throws {
        let src = """
        @startyaml
        outer:
          inner: value
        @endyaml
        """
        let result = try PlantUMLImporter().parse(src)
        guard case .treeView(let diagram) = result.document.payload else {
            Issue.record("expected .treeView")
            return
        }
        #expect(diagram.root.children[0].name == "outer")
        #expect(diagram.root.children[0].children[0].name == "inner")
    }

    @Test func unsupportedFeaturesProduceDiagnostics() throws {
        let src = """
        @startyaml
        a: &anchor 1
        b: *anchor
        @endyaml
        """
        let result = try PlantUMLImporter().parse(src)
        #expect(result.diagnostics.contains { $0.category == .slotUnsupported })
    }
}
```

- [ ] **Step 2: Run all three importer tests — expect failures**

```bash
swift test --filter PlantUMLWBSImporterTests
swift test --filter PlantUMLJSONImporterTests
swift test --filter PlantUMLYAMLImporterTests
```

Expected: all three fail. Dispatch isn't wired yet.

- [ ] **Step 3: Add `.treeView` to `supportedDiagramTypes`**

In `Sources/DiagramKitPlantUML/PlantUMLImporter.swift`, update the set literal:

```swift
public let supportedDiagramTypes: Set<DiagramType> = [
    .sequenceDiagram,
    .classDiagram,
    .stateDiagram,
    .mindmap,
    .gantt,
    .c4,
    .flowchart,
    .erDiagram,
    .architecture,
    .treeView,
]
```

- [ ] **Step 4: Insert three new dispatch branches at the top of `parse(_:)`**

Immediately after the `guard let (body, startKind) = extractPlantUMLBody(source) else { … }` block, BEFORE the existing `if startKind == "gantt"` branch, insert:

```swift
        if startKind == "json" {
            let value: PlantUMLJSONValue
            do {
                value = try PlantUMLJSONParser().parse(body)
            } catch {
                throw error
            }
            var (diagram, diagnostics) = PlantUMLJSONMapper().map(value)
            Self.applyTreeViewMarkers(&diagram, source: source)
            return DiagramImportResult(
                document: DiagramDocument(payload: .treeView(diagram)),
                diagnostics: diagnostics
            )
        }
        if startKind == "yaml" {
            let parsed = try PlantUMLYAMLParser().parse(body)
            var (diagram, diagnostics) = PlantUMLYAMLMapper().map(parsed)
            Self.applyTreeViewMarkers(&diagram, source: source)
            return DiagramImportResult(
                document: DiagramDocument(payload: .treeView(diagram)),
                diagnostics: diagnostics
            )
        }
        if startKind == "wbs" {
            let tree = PlantUMLWBSParser().parse(body)
            var (diagram, diagnostics) = PlantUMLWBSMapper().map(tree)
            Self.applyTreeViewMarkers(&diagram, source: source)
            return DiagramImportResult(
                document: DiagramDocument(payload: .treeView(diagram)),
                diagnostics: diagnostics
            )
        }
```

Then remove `|| startKind == "wbs"` from the existing mindmap branch so it only fires for `@startmindmap`:

```swift
        if startKind == "mindmap" {
            let tree = PlantUMLMindmapParser().parse(body)
            let (model, diagnostics) = PlantUMLMindmapMapper().map(tree)
            return DiagramImportResult(
                document: DiagramDocument(payload: .mindmap(model)),
                diagnostics: diagnostics
            )
        }
```

- [ ] **Step 5: Add the marker-application helper**

At the bottom of `PlantUMLImporter`, after `applyActivityOriginalIdMarkers(_:markers:)`, add:

```swift
    /// Apply treeView recovery markers to nodes by DFS-pre-order id.
    /// Markers referencing unknown ids are silently dropped (matches
    /// existing activity-marker behavior).
    private static func applyTreeViewMarkers(
        _ diagram: inout TreeViewDiagram,
        source: String
    ) {
        let markers = PlantUMLRecoveryMarker.scanner.scan(source: source).markers
        guard !markers.isEmpty else { return }

        var descriptions: [Int: String] = [:]
        var icons: [Int: String] = [:]
        var cssClasses: [Int: String] = [:]
        for marker in markers {
            switch marker.kind {
            case .treeViewNodeDescription(let nodeId, let base64):
                if let data = Data(base64Encoded: base64),
                   let text = String(data: data, encoding: .utf8) {
                    descriptions[nodeId] = text
                }
            case .treeViewNodeIcon(let nodeId, let iconId):
                icons[nodeId] = iconId
            case .treeViewNodeCssClass(let nodeId, let cssClass):
                cssClasses[nodeId] = cssClass
            default:
                continue
            }
        }
        guard !descriptions.isEmpty || !icons.isEmpty || !cssClasses.isEmpty else { return }

        diagram.root = applyMarkersTo(diagram.root,
                                       descriptions: descriptions,
                                       icons: icons,
                                       cssClasses: cssClasses)
        for i in diagram.nodes.indices {
            let id = diagram.nodes[i].id
            if let d = descriptions[id] { diagram.nodes[i].description = d }
            if let icon = icons[id]      { diagram.nodes[i].iconId = icon }
            if let css = cssClasses[id]  { diagram.nodes[i].cssClass = css }
        }
    }

    private static func applyMarkersTo(
        _ node: TreeViewNode,
        descriptions: [Int: String],
        icons: [Int: String],
        cssClasses: [Int: String]
    ) -> TreeViewNode {
        var copy = node
        if let d = descriptions[copy.id] { copy.description = d }
        if let icon = icons[copy.id]      { copy.iconId = icon }
        if let css = cssClasses[copy.id]  { copy.cssClass = css }
        copy.children = copy.children.map {
            applyMarkersTo($0, descriptions: descriptions, icons: icons, cssClasses: cssClasses)
        }
        return copy
    }
```

- [ ] **Step 6: Update the routing comment block at the top of `parse(_:)`**

Replace the `// 1. Gantt … 11. Sequence …` comment with the updated order:

```swift
        // Family routing order — narrow start-kind matches first so generic
        // `@startuml` sources only fall through to Sequence after explicit
        // families have had a chance to claim them:
        //   1. JSON     (`@startjson`)         — Wave H
        //   2. YAML     (`@startyaml`)         — Wave H
        //   3. WBS      (`@startwbs`)          — Wave H (split from Mindmap)
        //   4. Gantt    (`@startgantt`)
        //   5. Mindmap  (`@startmindmap`)
        //   6. C4       (C4-specific keywords)
        //   7. Activity (`start`/`stop`/`:text;`/`partition`)
        //   8. State    (`state` keyword / `[*]` pseudostate)
        //   9. ER       (`entity` keyword / IE arrows `||--o{`)
        //  10. UseCase  (`(usecase)` / `:actor:`)
        //  11. Object   (`object X` declaration)
        //  12. Component (`[component]` / `interface` keyword)
        //  13. Class    (class shape syntax)
        //  14. Deployment (`node`, `artifact`, ... declarations)
        //  15. Sequence (fallback)
```

- [ ] **Step 7: Run all three importer tests to verify they pass**

```bash
swift test --filter PlantUMLWBSImporterTests
swift test --filter PlantUMLJSONImporterTests
swift test --filter PlantUMLYAMLImporterTests
```

Expected: all pass.

- [ ] **Step 8: Run the broader PlantUML tests to verify nothing regressed**

```bash
swift test --filter PlantUMLMindmapImporterTests
swift test --filter PlantUMLProbeTests
```

Expected: pass.

- [ ] **Step 9: Commit**

```bash
git add Sources/DiagramKitPlantUML/PlantUMLImporter.swift Tests/DiagramKitTests/PlantUMLJSONImporterTests.swift Tests/DiagramKitTests/PlantUMLYAMLImporterTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 11 — wire WBS/JSON/YAML branches into PlantUMLImporter

Three new dispatch branches at the top of parse(_:) for @startjson,
@startyaml, @startwbs. Each parses, maps, then applies treeView
recovery markers (description/icon/cssClass) keyed by DFS-pre-order id.

Mindmap branch no longer claims @startwbs. .treeView is now in
supportedDiagramTypes.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: `PlantUMLTreeViewExporter` + dispatch

**Goal:** New exporter file emitting WBS canonical encoding. Dispatch in `PlantUMLExporter.swift`. Add `.treeView` to its `supportedDiagramTypes`.

**Files:**
- Create: `Sources/DiagramKitPlantUML/Exporter/PlantUMLTreeViewExporter.swift`
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift`
- Test: `Tests/DiagramKitTests/PlantUMLTreeViewExporterTests.swift` (new)

- [ ] **Step 1: Write failing exporter tests**

```swift
import Testing
import Foundation
import DiagramKitPlantUML
import DiagramKitModel
import DiagramKitCommon

@Suite struct PlantUMLTreeViewExporterTests {
    @Test func emitsSimpleTreeAsWBS() throws {
        let root = TreeViewNode(id: 0, level: 0, name: "root", nodeType: .directory, children: [
            TreeViewNode(id: 1, level: 1, name: "child1", nodeType: .file),
            TreeViewNode(id: 2, level: 1, name: "child2", nodeType: .file)
        ])
        let diagram = TreeViewDiagram(root: root, nodes: [root, root.children[0], root.children[1]])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        #expect(result.source.hasPrefix("@startwbs"))
        #expect(result.source.contains("* root"))
        #expect(result.source.contains("** child1"))
        #expect(result.source.contains("** child2"))
        #expect(result.source.hasSuffix("@endwbs\n") || result.source.hasSuffix("@endwbs"))
    }

    @Test func emitsTitle() throws {
        var root = TreeViewNode(id: 0, level: 0, name: "root", nodeType: .file)
        let diagram = TreeViewDiagram(root: root, nodes: [root], diagramTitle: "My Tree")
        let result = try PlantUMLTreeViewExporter().export(diagram)
        #expect(result.source.contains("title My Tree"))
    }

    @Test func emitsDescriptionMarker() throws {
        let leaf = TreeViewNode(id: 1, level: 1, name: "a", nodeType: .file, description: "42")
        let root = TreeViewNode(id: 0, level: 0, name: "(root)", nodeType: .directory, children: [leaf])
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        let expected = PlantUMLRecoveryMarker.emitTreeViewNodeDescription(nodeId: 1, body: "42")
        #expect(result.source.contains(expected))
    }

    @Test func emitsIconMarker() throws {
        let leaf = TreeViewNode(id: 1, level: 1, name: "a", nodeType: .file, iconId: "folder")
        let root = TreeViewNode(id: 0, level: 0, name: "root", nodeType: .directory, children: [leaf])
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        #expect(result.source.contains(PlantUMLRecoveryMarker.emitTreeViewNodeIcon(nodeId: 1, iconId: "folder")))
    }

    @Test func emitsCssClassMarker() throws {
        let leaf = TreeViewNode(id: 1, level: 1, name: "a", nodeType: .file, cssClass: "highlighted")
        let root = TreeViewNode(id: 0, level: 0, name: "root", nodeType: .directory, children: [leaf])
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        #expect(result.source.contains(PlantUMLRecoveryMarker.emitTreeViewNodeCssClass(nodeId: 1, cssClass: "highlighted")))
    }

    @Test func newlineInNameProducesIdSanitization() throws {
        let root = TreeViewNode(id: 0, level: 0, name: "line1\nline2", nodeType: .file)
        let diagram = TreeViewDiagram(root: root, nodes: [root])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        #expect(result.diagnostics.contains { $0.category == .idSanitization })
        #expect(!result.source.contains("\nline2"))  // stripped
    }

    @Test func accTitleDropsWithDiagnostic() throws {
        var root = TreeViewNode(id: 0, level: 0, name: "root", nodeType: .file)
        let diagram = TreeViewDiagram(
            root: root,
            nodes: [root],
            accTitle: "screen reader title"
        )
        let result = try PlantUMLTreeViewExporter().export(diagram)
        #expect(result.diagnostics.contains { $0.category == .accessibilityDrop })
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
swift test --filter PlantUMLTreeViewExporterTests
```

- [ ] **Step 3: Create the exporter**

`Sources/DiagramKitPlantUML/Exporter/PlantUMLTreeViewExporter.swift`:

```swift
import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits a `TreeViewDiagram` as PlantUML `@startwbs` source. WBS is the
/// canonical encoding for treeView in PlantUML; there is no per-call
/// encoding selector. JSON and YAML are import-only entry points that
/// converge to WBS on export.
///
/// Output shape:
///
/// ```
/// @startwbs
/// title <diagramTitle if set>
/// ' diagramkit:treeview-node-description=42,b64:NDI=
/// ' diagramkit:treeview-node-icon=3,folder
/// * root
/// ** child1
/// ** child2
/// @endwbs
/// ```
///
/// Markers emit in ascending nodeId order, grouped (descriptions first,
/// then icons, then cssClasses).
public struct PlantUMLTreeViewExporter {

    public init() {}

    public func export(_ diagram: TreeViewDiagram) throws -> DiagramExportResult {
        var diagnostics: [DiagramDiagnostic] = []
        var lines: [String] = ["@startwbs"]

        if let title = diagram.diagramTitle, !title.isEmpty {
            lines.append("title \(title.replacingOccurrences(of: "\n", with: " "))")
        }

        if diagram.accTitle != nil || diagram.accDescr != nil {
            diagnostics.append(.lossyTransform(
                .accessibilityDrop,
                message: "PlantUML WBS does not preserve accessibility metadata"
            ))
        }

        // Collect descriptions/icons/cssClasses in ascending id order.
        var descMarkers: [(id: Int, line: String)] = []
        var iconMarkers: [(id: Int, line: String)] = []
        var cssMarkers: [(id: Int, line: String)] = []
        walk(diagram.root) { node in
            if let d = node.description, !d.isEmpty {
                descMarkers.append((node.id,
                    PlantUMLRecoveryMarker.emitTreeViewNodeDescription(nodeId: node.id, body: d)))
            }
            if let icon = node.iconId, !icon.isEmpty {
                iconMarkers.append((node.id,
                    PlantUMLRecoveryMarker.emitTreeViewNodeIcon(nodeId: node.id, iconId: icon)))
            }
            if let css = node.cssClass, !css.isEmpty {
                cssMarkers.append((node.id,
                    PlantUMLRecoveryMarker.emitTreeViewNodeCssClass(nodeId: node.id, cssClass: css)))
            }
        }
        descMarkers.sort { $0.id < $1.id }
        iconMarkers.sort { $0.id < $1.id }
        cssMarkers.sort { $0.id < $1.id }
        lines.append(contentsOf: descMarkers.map { $0.line })
        lines.append(contentsOf: iconMarkers.map { $0.line })
        lines.append(contentsOf: cssMarkers.map { $0.line })

        // Tree body.
        emitNode(diagram.root, lines: &lines, diagnostics: &diagnostics)

        lines.append("@endwbs")
        return DiagramExportResult(source: lines.joined(separator: "\n") + "\n", diagnostics: diagnostics)
    }

    private func emitNode(
        _ node: TreeViewNode,
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let depth = node.level + 1  // WBS depth is 1-based (`*` = root)
        var name = node.name
        if name.contains("\n") {
            diagnostics.append(.lossyTransform(
                .idSanitization,
                message: "PlantUML WBS node names must be single-line; stripped newlines in '\(name.prefix(40))…'"
            ))
            name = name.replacingOccurrences(of: "\n", with: " ")
        }
        lines.append(String(repeating: "*", count: depth) + " " + name)
        for child in node.children {
            emitNode(child, lines: &lines, diagnostics: &diagnostics)
        }
    }

    private func walk(_ node: TreeViewNode, _ visit: (TreeViewNode) -> Void) {
        visit(node)
        for child in node.children {
            walk(child, visit)
        }
    }
}

extension PlantUMLTreeViewExporter {
    public static func emit(_ diagram: TreeViewDiagram) throws -> DiagramExportResult {
        try PlantUMLTreeViewExporter().export(diagram)
    }
}
```

- [ ] **Step 4: Add `.treeView` to `PlantUMLExporter.supportedDiagramTypes` and dispatch**

In `Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift`:

Add `.treeView,` to the set literal:

```swift
public let supportedDiagramTypes: Set<DiagramType> = [
    .sequenceDiagram,
    .classDiagram,
    .stateDiagram,
    .mindmap,
    .gantt,
    .c4,
    .flowchart,
    .erDiagram,
    .architecture,
    .treeView,
]
```

Add a `case .treeView(let diagram):` branch to the switch, between `.architecture` and `default`:

```swift
case .treeView(let diagram):
    return try PlantUMLTreeViewExporter.emit(diagram)
```

- [ ] **Step 5: Run exporter tests to verify they pass**

```bash
swift test --filter PlantUMLTreeViewExporterTests
```

- [ ] **Step 6: Run the broader PlantUML exporter tests for regressions**

```bash
swift test --filter PlantUML | grep -E "(Exporter|Importer)Tests"  # confirm what runs
# then explicitly:
swift test --filter PlantUMLMindmapImporterTests
swift test --filter PlantUMLWBSImporterTests
```

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitPlantUML/Exporter/PlantUMLTreeViewExporter.swift Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift Tests/DiagramKitTests/PlantUMLTreeViewExporterTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 12 — PlantUMLTreeViewExporter + dispatch

New exporter emits TreeViewDiagram as @startwbs source with markers
for description/iconId/cssClass preservation. WBS is the single
canonical encoding; JSON and YAML are import-only.

Newlines in node names sanitize with .idSanitization diagnostic.
accTitle/accDescr drop with .accessibilityDrop diagnostic. Markers
emit in ascending nodeId order, grouped by kind.

PlantUMLExporter gains .treeView in supportedDiagramTypes and a
matching dispatch branch.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Same-format fixtures + `RoundTripCellRegistry` entry

**Goal:** Add three round-trip fixtures (WBS, JSON, YAML) and register a `plantumlTreeView` cell. Fixtures live under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-treeView/`. All three use the same `RoundTripCell` because the importer routes by start-keyword.

**Files:**
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-treeView/plantuml-treeview-wbs.puml`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-treeView/plantuml-treeview-json.puml`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-treeView/plantuml-treeview-yaml.puml`
- Modify: `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift`
- Modify: `Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift` (add the parameterized invocation — this is the file that holds same-format harness runs; do NOT use the unrelated `RoundTripCellTests.swift`)

- [ ] **Step 1: Create the fixture directory + WBS fixture**

```bash
mkdir -p Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-treeView
```

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-treeView/plantuml-treeview-wbs.puml`:

```
@startwbs
title Project Breakdown
* Project
** Phase 1
*** Task A
*** Task B
** Phase 2
*** Task C
@endwbs
```

- [ ] **Step 2: Create the JSON fixture**

`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-treeView/plantuml-treeview-json.puml`:

```
@startjson
{
  "name": "demo",
  "version": "1.0",
  "active": true,
  "count": 42,
  "score": 3.14,
  "missing": null,
  "tags": ["a", "b"],
  "nested": {
    "deep": "value"
  }
}
@endjson
```

- [ ] **Step 3: Create the YAML fixture**

`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-treeView/plantuml-treeview-yaml.puml`:

```
@startyaml
name: demo
version: "1.0"
nested:
  deep: value
list:
  - alpha
  - beta
@endyaml
```

- [ ] **Step 4: Register the cell in `RoundTripCellRegistry.swift`**

After the `dotTreeView` static let (around line 327), add:

```swift
    static let plantumlTreeView = RoundTripCell(
        importer: PlantUMLImporter(),
        exporter: PlantUMLExporter(),
        family: DiagramType.treeView,
        allowedLosses: []
    )
```

- [ ] **Step 5: Add the parameterized invocation in `SameFormatRoundTripTests.swift`**

The harness pattern (lines 250-259 of the file, for `mermaidTreeView`) loads every file in a fixture directory automatically via `fixtures(for: "<dirname>", fromRoot: roundTripResourcesRoot())`. So you only need one `@Test` declaration; it parameterizes over all `.puml` files in the dir.

Insert immediately after the `dotTreeView` invocation:

```swift
    @Test(
        "PlantUML treeView round-trip",
        arguments: try fixtures(for: "plantuml-treeView", fromRoot: roundTripResourcesRoot())
    )
    func plantumlTreeView(fixture: RoundTripFixture) throws {
        try runSameFormatRoundTrip(
            cell: RoundTripCellRegistry.plantumlTreeView,
            fixture: fixture
        )
    }
```

- [ ] **Step 6: Run the same-format round-trip tests**

```bash
swift test --filter SameFormatRoundTripTests/plantumlTreeView
```

Expected: all 3 fixtures pass.

- [ ] **Step 7: Commit**

```bash
git add Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-treeView/ Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 13 — same-format treeView round-trip fixtures + cell

Three new fixtures under plantuml-treeView/: WBS, JSON, YAML. Each
parses, exports as @startwbs + markers, re-parses, and asserts
structural equality on the parsed TreeViewDiagram.

Same RoundTripCell handles all three because the importer routes by
start-keyword. allowedLosses = [] — description/icon/cssClass survive
via markers, shape/color drops are equal on both legs.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Cross-format fixtures + `RoundTripCrossRegistry` entries

**Goal:** Add six directed cross-format fixtures pairing PlantUML treeView with each of Mermaid, D2, and DOT. Register the six directed allowed-loss sets in `RoundTripCrossRegistry.swift`.

**Files:**
- Create fixtures under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`:
  - `cross-mermaid-plantuml-treeView/`
  - `cross-plantuml-mermaid-treeView/`
  - `cross-d2-plantuml-treeView/`
  - `cross-plantuml-d2-treeView/`
  - `cross-dot-plantuml-treeView/`
  - `cross-plantuml-dot-treeView/`
- Modify: `Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift`
- Modify: `Tests/DiagramKitTests/RoundTrip/CrossFormatRoundTripTests.swift` (add parameterized invocations — this is the file that holds cross-format harness runs)

- [ ] **Step 1: Create the cross-format fixture dirs**

```bash
for d in cross-mermaid-plantuml-treeView cross-plantuml-mermaid-treeView cross-d2-plantuml-treeView cross-plantuml-d2-treeView cross-dot-plantuml-treeView cross-plantuml-dot-treeView; do
  mkdir -p "Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/$d"
done
```

- [ ] **Step 2: Find an existing Mermaid treeView fixture to copy structure from**

```bash
ls Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/mermaid-treeview/
ls Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-d2-treeView/
```

- [ ] **Step 3: Create the six cross fixtures**

Use minimal trees that exercise structural shape plus a description and an iconId where the source format supports them. Each cross dir gets ONE fixture file. Pattern for filenames matches existing convention (e.g. `cross-mermaid-d2-treeView/cross-mermaid-d2-treeView-basic.mmd`).

For each pair, the fixture's filename and contents follow the *source* format. Examples:

`cross-mermaid-plantuml-treeView/cross-mermaid-plantuml-treeView-basic.mmd` — mermaid treeView source:

```
treeview
    root[icon=folder]
        child1[icon=file]
        child2[icon=file]
```

(Match the exact mermaid treeView syntax used by an existing mermaid-treeview fixture.)

`cross-plantuml-mermaid-treeView/cross-plantuml-mermaid-treeView-basic.puml` — PlantUML WBS source:

```
@startwbs
* root
** child1
** child2
@endwbs
```

Repeat for d2/dot pairs using each format's treeView syntax from the existing same-format fixtures as reference.

- [ ] **Step 4: Register allowed-loss sets in `RoundTripCrossRegistry.swift`**

After the existing Wave E treeView block (around line 89-94), add:

```swift
    // Wave H — treeView cross-format pairs (PlantUML × mermaid/d2/dot)
    static let mermaidPlantumlTreeView: Set<RoundTripLossKind> = [.idSanitization, .titleDrop]
    static let plantumlMermaidTreeView: Set<RoundTripLossKind> = [.idSanitization, .titleDrop]
    static let d2PlantumlTreeView: Set<RoundTripLossKind> = [.idSanitization, .titleDrop]
    static let plantumlD2TreeView: Set<RoundTripLossKind> = [.idSanitization, .titleDrop]
    static let dotPlantumlTreeView: Set<RoundTripLossKind> = [.idSanitization, .titleDrop]
    static let plantumlDotTreeView: Set<RoundTripLossKind> = [.idSanitization, .titleDrop]
```

- [ ] **Step 5: Add the parameterized invocations in `CrossFormatRoundTripTests.swift`**

The harness pattern at lines 764-833 (existing Wave E treeView block) parameterizes each direction over all fixtures in its cross dir. Append the following six `@Test` declarations immediately after the existing `// MARK: D2 ↔ DOT (treeView)` block, before the next family's section:

```swift
    // MARK: Mermaid ↔ PlantUML (treeView)

    @Test(
        "Mermaid → PlantUML → Mermaid (treeView)",
        arguments: try fixtures(for: "cross-mermaid-plantuml-treeView", fromRoot: roundTripResourcesRoot())
    )
    func mermaidPlantumlTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidTreeView,
            legB: RoundTripCellRegistry.plantumlTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidPlantumlTreeView,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML → Mermaid → PlantUML (treeView)",
        arguments: try fixtures(for: "cross-plantuml-mermaid-treeView", fromRoot: roundTripResourcesRoot())
    )
    func plantumlMermaidTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlTreeView,
            legB: RoundTripCellRegistry.mermaidTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlMermaidTreeView,
            fixture: fixture
        )
    }

    // MARK: D2 ↔ PlantUML (treeView)

    @Test(
        "D2 → PlantUML → D2 (treeView)",
        arguments: try fixtures(for: "cross-d2-plantuml-treeView", fromRoot: roundTripResourcesRoot())
    )
    func d2PlantumlTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.d2TreeView,
            legB: RoundTripCellRegistry.plantumlTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.d2PlantumlTreeView,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML → D2 → PlantUML (treeView)",
        arguments: try fixtures(for: "cross-plantuml-d2-treeView", fromRoot: roundTripResourcesRoot())
    )
    func plantumlD2TreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlTreeView,
            legB: RoundTripCellRegistry.d2TreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlD2TreeView,
            fixture: fixture
        )
    }

    // MARK: DOT ↔ PlantUML (treeView)

    @Test(
        "DOT → PlantUML → DOT (treeView)",
        arguments: try fixtures(for: "cross-dot-plantuml-treeView", fromRoot: roundTripResourcesRoot())
    )
    func dotPlantumlTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.dotTreeView,
            legB: RoundTripCellRegistry.plantumlTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.dotPlantumlTreeView,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML → DOT → PlantUML (treeView)",
        arguments: try fixtures(for: "cross-plantuml-dot-treeView", fromRoot: roundTripResourcesRoot())
    )
    func plantumlDotTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlTreeView,
            legB: RoundTripCellRegistry.dotTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlDotTreeView,
            fixture: fixture
        )
    }
```

- [ ] **Step 6: Run the cross-format tests**

```bash
swift test --filter CrossFormatRoundTripTests/mermaidPlantumlTreeView
swift test --filter CrossFormatRoundTripTests/plantumlMermaidTreeView
swift test --filter CrossFormatRoundTripTests/d2PlantumlTreeView
swift test --filter CrossFormatRoundTripTests/plantumlD2TreeView
swift test --filter CrossFormatRoundTripTests/dotPlantumlTreeView
swift test --filter CrossFormatRoundTripTests/plantumlDotTreeView
```

Expected: all six tests pass.

- [ ] **Step 7: Commit**

```bash
git add Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-*-*-treeView Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift Tests/DiagramKitTests/RoundTrip/CrossFormatRoundTripTests.swift
git commit -m "$(cat <<'EOF'
Wave H Task 14 — cross-format treeView round-trip fixtures (PlantUML)

Six new directed fixtures pairing PlantUML treeView with each of
Mermaid, D2, DOT. Each cross dir holds one fixture in the source
format; the harness runs parse(A) → export(B) → parse(B) → export(A)
→ parse(A) and asserts structural equality on doc1 vs doc3.

Allowed losses [.idSanitization, .titleDrop] mirror the existing
Wave E treeView cross-format pattern (mermaidD2TreeView et al).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: `COVERAGE.md` updates (wave closer)

**Goal:** Flip the matrix cells, update totals, append the Wave H prose block, update the round-trip fixture counts, bump the last-audited line.

**Files:**
- Modify: `COVERAGE.md`

- [ ] **Step 1: Flip the import matrix cell**

In the import-coverage table, change row `treeView`, column `PlantUML` from `—` to `✓`. Update the `**Totals**` row: PlantUML column `9/28` → `10/28`.

- [ ] **Step 2: Flip the export matrix cell**

Same change in the export-coverage table. PlantUML totals row: `9/28` → `10/28`.

- [ ] **Step 3: Update the round-trip discipline table**

In the "Same-format" row, add `treeView` to the PlantUML set list (currently `plantuml {sequence, class, state, gantt, mindmap, c4, activity, er, useCase, object, component}`).

In the "Cross-format pairs" row, add a new clause for treeView:
`treeView × {mermaid↔d2, mermaid↔dot, d2↔dot, mermaid↔plantuml, d2↔plantuml, dot↔plantuml}` (extending the existing `treeView × {mermaid↔d2, mermaid↔dot, d2↔dot}` clause).

Update the fixture-count prose paragraph:
- Same-format fixtures: 40 → 43 (+3 new PlantUML treeView WBS/JSON/YAML).
- Cross-format directed: 76 → 82 (+6 PlantUML treeView pairs).
- Cross-format unordered: 38 → 41 (+3 unordered).

- [ ] **Step 4: Update last-audited line**

```
Last audited: 2026-05-21 (Wave G).
```

→

```
Last audited: 2026-05-21 (Wave H).
```

- [ ] **Step 5: Append the Wave H prose paragraph**

After the existing Wave G paragraph in the "Partial-support detail" section, append:

```markdown
- **Wave H — PlantUML treeView (WBS + JSON + YAML).** PlantUML gains
  one family (no matrix `⚠` involved; the cell was `—`). Detection:
  marker-forced via outer-probe start keywords (`@startwbs`,
  `@startjson`, `@startyaml`); body-content probes unchanged. Three
  new shared recovery-marker kinds (`treeViewNodeDescription`,
  `treeViewNodeIcon`, `treeViewNodeCssClass`) preserve
  `TreeViewNode.description` (where JSON/YAML primitive values land),
  `TreeViewNode.iconId`, and `TreeViewNode.cssClass` across same-format
  and cross-format round-trip. PlantUML treeView export emits a single
  canonical encoding (`@startwbs` + markers); JSON and YAML are
  import-only entry points that converge to WBS on export.
  **Behavior change**: `@startwbs` previously routed to
  `PlantUMLMindmapParser` and produced a `MindmapDiagram` payload;
  this spec retargets it to `PlantUMLWBSParser` → `TreeViewDiagram`.
  WBS-specific shape variants (`<<arrow>>`, `<<separator>>`,
  `<<box>>`) and color suffixes (`#color`) are lossy-dropped on
  import via `.featureDropped(.slotUnsupported, …)` with no marker
  preservation. Cross-format paths `mermaid ↔ plantuml`,
  `d2 ↔ plantuml`, `dot ↔ plantuml` (3 unordered, 6 directed) bridge
  through the canonical `TreeViewDiagram` payload. No new
  `DiagnosticCategory` cases; reuses `.slotUnsupported` /
  `.idSanitization` / `.accessibilityDrop`. No new `RoundTripLoss`
  cases. Closes
  [`docs/superpowers/specs/2026-05-21-plantuml-treeview-design.md`](docs/superpowers/specs/2026-05-21-plantuml-treeview-design.md).
```

- [ ] **Step 6: Add the struck-through backlog item**

In the "Backlog summary" section, append (the existing list ends at item 8; add 9):

```markdown
9. ~~**PlantUML expansion: treeView (one family × three import
   dialects + one canonical export encoding, marker-recovered
   round-trip + 3 new cross-format pairs).**~~ Closed by Wave H
   (2026-05-21-plantuml-treeview spec).
```

- [ ] **Step 7: Sanity-check the doc**

```bash
grep -n "Wave H\|treeView.*PlantUML\|treeView.*plantuml\|10/28" COVERAGE.md
```

Expected: Wave H appears in the partial-support section and backlog. Both totals lines show `10/28` for PlantUML.

- [ ] **Step 8: Run full discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/check-diagnostic-discipline.sh
```

Expected: all three pass. If any flag a new file, address before committing.

- [ ] **Step 9: Run a final filtered test to confirm the wave still passes end-to-end**

```bash
swift test --filter "PlantUMLWBS"
swift test --filter "PlantUMLJSON"
swift test --filter "PlantUMLYAML"
swift test --filter "PlantUMLTreeView"
swift test --filter "SameFormatRoundTripTests/plantumlTreeView"
```

Expected: all five filter sweeps pass.

- [ ] **Step 10: Commit the wave closer**

```bash
git add COVERAGE.md
git commit -m "$(cat <<'EOF'
Wave H closer — COVERAGE.md updates

- treeView × PlantUML: — → ✓ (both import and export matrices)
- PlantUML totals: 9/28 → 10/28
- Round-trip same-format: 40 → 43; cross-format directed: 76 → 82
- Append Wave H prose paragraph + backlog item 9 (struck-through)
- Bump last-audited to Wave H

Closes docs/superpowers/specs/2026-05-21-plantuml-treeview-design.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review checklist (run after all 15 tasks complete)

- [ ] All matrix flips visible in COVERAGE.md (`grep -n "treeView" COVERAGE.md`).
- [ ] `swift test --filter "PlantUML"` runs clean across the wave's tests.
- [ ] `Scripts/check-diagnostic-discipline.sh` passes.
- [ ] No raw `DiagramDiagnostic(severity:message:)` calls introduced.
- [ ] No new `DiagnosticCategory` cases.
- [ ] No new `RoundTripLossKind` cases.
- [ ] Public API additions limited to: 3 `PlantUMLRecoveryMarker.Kind` cases + emit/parse helpers, `PlantUMLWBSParser` / `PlantUMLWBSMapper` / `PlantUMLWBSTree` / `PlantUMLWBSNode`, `PlantUMLJSONParser` / `PlantUMLJSONMapper` / `PlantUMLJSONValue`, `PlantUMLYAMLParser` / `PlantUMLYAMLMapper` / `PlantUMLYAMLValue` / `PlantUMLYAMLParseResult`, `PlantUMLTreeViewExporter`. No changes to `DiagramKitCommon` or `DiagramKitModel`.
- [ ] One commit per task (15 commits total).

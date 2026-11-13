// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Every ordinary canvas edit the public editor API offers, on every Mermaid
// diagram type with canvas editing, must be accepted on a fresh document and
// on a corpus document: an export gap that makes an ordinary edit impossible
// fails here instead of in the app (DiagramKit 0.1.0-beta.9: inserting a
// shape, icon or image node was always refused).

import Foundation
import Testing
import DiagramKit
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitInteractive

/// Shape aliases the app's shape catalog offers (RepoPrompt
/// `ShapeCatalog`), every one a `NodeShape` raw value.
let catalogShapeAliases = [
    "rectangle", "rounded", "stadium", "circle", "doublecircle", "diamond", "hexagon", "ellipse",
    "cylinder", "subroutine", "parallelogram", "parallelogram-alt", "trapezoid", "trapezoid-alt",
    "document", "stacked-document", "lined-document", "tagged-document", "asymmetric", "delay",
    "curved-trapezoid", "sloped-rectangle", "flipped-triangle", "flag", "divided-rectangle",
    "stacked-rectangle", "lined-rectangle", "notched-rectangle", "tagged-rectangle",
    "cloud", "horizontal-cylinder", "lined-cylinder", "bow-tie-rectangle", "window-pane", "data-store",
    "small-circle", "framed-circle", "filled-circle", "crossed-circle", "fork", "join", "hourglass",
    "triangle", "notched-pentagon", "lightning-bolt", "braces", "bang", "text",
]

private typealias Step = (DiagramEditor) async throws -> Void

private func node(_ id: String, _ type: DiagramType = .flowchart) -> DiagramSelection {
    DiagramSelection(diagramType: type, elementID: "node:\(id)")
}

/// The flowchart edits, each a sequence of mutations as the app issues
/// them. `X` is an existing node, `Y` another, `S` an existing subgraph.
private func flowchartEdits(existing x: String, other y: String, subgraph s: String?) -> [(String, [Step])] {
    var edits: [(String, [Step])] = []
    for alias in catalogShapeAliases {
        edits.append(("insert \(alias)", [{ try await $0.performFlowchart(.insertNode(id: "zz1", label: "New node", type: alias)) }]))
    }
    edits += [
        ("insert icon node", [
            { try await $0.performFlowchart(.insertNode(id: "zz1", label: "New icon", type: "icon-circle")) },
            { try await $0.performFlowchart(.setNodeIcon(of: node("zz1"), to: IconSpec(name: "user"))) },
        ]),
        ("insert icon node, square, large, label below", [
            { try await $0.performFlowchart(.insertNode(id: "zz1", label: "New icon", type: "icon-square")) },
            { try await $0.performFlowchart(.setNodeIcon(of: node("zz1"), to: IconSpec(name: "fa:database", background: .square, size: .large, labelPosition: .bottom))) },
        ]),
        ("insert image node", [
            { try await $0.performFlowchart(.insertNode(id: "zz1", label: "Image", type: "image-square")) },
            { try await $0.performFlowchart(.setNodeImage(of: node("zz1"), to: ImageSpec(urlString: "https://example.com/a.png", width: 120, height: 90, title: "Image"))) },
        ]),
        ("insert image node, sized, untitled", [
            { try await $0.performFlowchart(.insertNode(id: "zz1", label: "Image", type: "image-square")) },
            { try await $0.performFlowchart(.setNodeImage(of: node("zz1"), to: ImageSpec(urlString: "https://example.com/b.svg", width: 300.5, height: 4096))) },
        ]),
        ("insert edge", [{ try await $0.performFlowchart(.insertEdge(id: "e99", from: node(x), to: node(y), label: "calls")) }]),
        ("insert edge, unlabelled", [{ try await $0.performFlowchart(.insertEdge(id: "e98", from: node(y), to: node(x))) }]),
        ("edge style dotted", [{ try await $0.performFlowchart(.setEdgeStyle(edgeId: nil, source: x, target: y, to: .dotted)) }]),
        ("set shape", [{ try await $0.performFlowchart(.setNodeShape(of: node(x), toShape: "cloud")) }]),
        ("set style", [{ try await $0.performFlowchart(.setNodeStyle(of: node(x), to: NodeStyleSpec(fill: "#ffcc00", stroke: "#333333", textColor: "#111111", borderStyle: .dashed))) }]),
        ("set icon on existing", [{ try await $0.performFlowchart(.setNodeIcon(of: node(x), to: IconSpec(name: "cog"))) }]),
        ("set image on existing", [{ try await $0.performFlowchart(.setNodeImage(of: node(x), to: ImageSpec(urlString: "https://example.com/c.png"))) }]),
        ("group two nodes", [{ try await $0.performFlowchart(.groupIntoSubgraph(selections: [node(x), node(y)], title: "Team A")) }]),
        ("insert subgraph", [{ try await $0.performFlowchart(.insertSubgraph(title: "New group")) }]),
        ("rename", [{ try await $0.perform(.setLabel(of: node(x), to: "Renamed \"x\"")) }]),
        ("delete", [{ try await $0.perform(.deleteElement(node(y))) }]),
        ("title", [{ try await $0.perform(.setTitle("A title")) }]),
        ("theme", [{ try await $0.perform(.setTheme("nord")) }]),
        ("layout", [{ try await $0.perform(.setLayoutPreset(.adaptive)) }]),
        ("direction", [{ try await $0.setFlowchartDirection(.LR) }]),
    ]
    if let s {
        edits += [
            ("move to subgraph", [{ try await $0.performFlowchart(.moveToSubgraph(selections: [node(y)], target: s)) }]),
            ("rename subgraph", [{ try await $0.performFlowchart(.renameSubgraph(id: s, title: "Renamed group")) }]),
            ("ungroup", [{ try await $0.performFlowchart(.ungroupSubgraph(id: s)) }]),
        ]
    }
    return edits
}

@Suite("Every ordinary canvas edit is accepted") @MainActor
struct CanvasEditSweepTests {

    struct Row: CustomStringConvertible {
        let type: String, document: String, edit: String, result: String
        var description: String { "| \(type) | \(document) | \(edit) | \(result) |" }
    }

    private func run(_ source: String, _ steps: [Step]) async -> String {
        guard let document = try? MermaidImporter().parse(source).document else { return "unparsable" }
        let editor = DiagramEditor(document: document, preferredExportFormat: .mermaid,
                                   exportRegistry: DiagramPipeline.defaultExportRegistry, initialSource: source)
        do {
            for step in steps { try await step(editor) }
        } catch {
            return "refused: \(error.localizedDescription)"
        }
        // The saved text reads back as the edited model.
        guard let saved = editor.source, let back = try? MermaidImporter().parse(saved).document else { return "saved text does not parse" }
        return _modelFingerprint(back) == _modelFingerprint(editor.document) ? "ok" : "saved text differs"
    }

    @Test("flowchart: every insert, add and edit mutation on a fresh document and on corpus documents")
    func flowchartSweep() async throws {
        let fresh = "flowchart TD\n  A[Start] --> B[End]\n"
        let corpusSource = try #require(try DiagramCorpus.load().first { $0.id == "flow-16-subgraphs" }).source
        guard case .flowchart(let g) = try MermaidImporter().parse(corpusSource).document.payload else { Issue.record("not a flowchart"); return }
        let firstEdge = try #require(g.edges.first)
        var rows: [Row] = []
        for (doc, source, x, y, s) in [("fresh", fresh, "A", "B", nil as String?),
                                       ("flow-16-subgraphs", corpusSource, firstEdge.source, firstEdge.target, g.subgraphs.first?.id)] {
            for (name, steps) in flowchartEdits(existing: x, other: y, subgraph: s) {
                rows.append(Row(type: "flowchart", document: doc, edit: name, result: await run(source, steps)))
            }
        }
        let bad = rows.filter { $0.result != "ok" }
        #expect(rows.count >= 130)
        #expect(bad.isEmpty, "\(bad.count) of \(rows.count):\n\(bad.map(\.description).joined(separator: "\n"))")
    }

    @Test("state, sequence and gantt: every canvas mutation on a fresh document and on a corpus document")
    func otherTypesSweep() async throws {
        let corpus = try DiagramCorpus.load()
        var rows: [Row] = []
        // State: the generic mutations (state shares the flowchart model but
        // not the flowchart-only mutations).
        let stateFresh = "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Busy : go\n  Busy --> [*]\n"
        let stateCorpus = try #require(corpus.first { $0.id == "state-12-complex" }).source
        for (doc, source) in [("fresh", stateFresh), ("state-12-complex", stateCorpus)] {
            guard case .stateDiagram(let g) = try MermaidImporter().parse(source).document.payload,
                  let first = g.nodesInOrder.first(where: { !$0.id.hasSuffix("_start") && !$0.id.hasSuffix("_end") && $0.node.shape != .stateNote }) else { continue }
            let steps: [(String, [Step])] = [
                ("rename", [{ try await $0.perform(.setLabel(of: node(first.id, .stateDiagram), to: "Renamed")) }]),
                ("delete", [{ try await $0.perform(.deleteElement(node(first.id, .stateDiagram))) }]),
                ("title", [{ try await $0.perform(.setTitle("States")) }]),
                ("theme", [{ try await $0.perform(.setTheme("nord")) }]),
                ("layout", [{ try await $0.perform(.setLayoutPreset(.adaptive)) }]),
            ]
            for (name, s) in steps { rows.append(Row(type: "state", document: doc, edit: name, result: await run(source, s))) }
        }
        // Sequence: message moves (the only sequence mutation) and settings.
        let seqFresh = "sequenceDiagram\n  participant A\n  participant B\n  A->>B: one\n  B-->>A: two\n  A-)B: three\n"
        let seqCorpus = try #require(corpus.first { $0.id == "seq-13-oauth" }).source
        for (doc, source) in [("fresh", seqFresh), ("seq-13-oauth", seqCorpus)] {
            let steps: [(String, [Step])] = [
                ("move last to first", [{ try await $0.performSequence(.moveMessage(at: 2, to: 0)) }]),
                ("move first down", [{ try await $0.performSequence(.moveMessage(at: 0, to: 1)) }]),
                ("title", [{ try await $0.perform(.setTitle("Flow")) }]),
                ("theme", [{ try await $0.perform(.setTheme("nord")) }]),
            ]
            for (name, s) in steps { rows.append(Row(type: "sequence", document: doc, edit: name, result: await run(source, s))) }
        }
        // Gantt: resize (the only gantt mutation) and settings.
        let ganttFresh = "gantt\n  dateFormat YYYY-MM-DD\n  section S\n  Plan :p1, 2024-01-01, 3d\n  Build :b1, after p1, 5d\n"
        let ganttCorpus = try #require(corpus.first { $0.id == "gantt-2-full-syntax" }).source
        for (doc, source) in [("fresh", ganttFresh), ("gantt-2-full-syntax", ganttCorpus)] {
            guard case .gantt(let g) = try MermaidImporter().parse(source).document.payload else { continue }
            let tasks = g.tasks.filter { !$0.tags.contains(.milestone) }
            var steps: [(String, [Step])] = [
                ("title", [{ try await $0.perform(.setTitle("Plan")) }]),
                ("theme", [{ try await $0.perform(.setTheme("nord")) }]),
            ]
            for task in [tasks.first, tasks.last].compactMap({ $0 }) {
                steps.append(("resize \(task.id) +2d", [{ try await $0.performGantt(.resizeTask(taskId: task.id, newEndTime: task.endTime.addingTimeInterval(2 * 86400))) }]))
            }
            for (name, s) in steps { rows.append(Row(type: "gantt", document: doc, edit: name, result: await run(source, s))) }
        }
        let bad = rows.filter { $0.result != "ok" }
        #expect(rows.count > 25)
        #expect(bad.isEmpty, "\(bad.count) of \(rows.count):\n\(bad.map(\.description).joined(separator: "\n"))")
    }
}
#endif
#if canImport(UIKit) || canImport(AppKit)
import DiagramKitExport
import DiagramKitImport

/// The real Mermaid exporter with one `@{ … }` key removed from its output.
private struct KeyDroppingExporter: DiagramExporter {
    let name = "Key-dropping Mermaid"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = MermaidExporter().supportedDiagramTypes
    let pattern: String
    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        let source = try MermaidExporter().export(document).source
        return DiagramExportResult(source: source.replacingOccurrences(of: pattern, with: "", options: .regularExpression))
    }
}

@Suite("Node properties: an absent block is not a loss, a dropped property is") @MainActor
struct NodePropertiesLossTests {

    private func editor(_ pattern: String) throws -> DiagramEditor {
        let source = "flowchart TD\n  A[Start] --> B[End]\n"
        return DiagramEditor(
            document: try MermaidImporter().parse(source).document, preferredExportFormat: .mermaid,
            exportRegistry: ExporterRegistry.empty.registering(KeyDroppingExporter(pattern: pattern)).readingBack { s, f in
                try DiagramLoader.parseDocument(s, as: f, registry: DiagramPipeline.defaultRegistry)
            },
            initialSource: source
        )
    }

    @Test("an export that drops a node's icon, image, size or label position is still refused", arguments: [
        #"icon: "fa:user", "#, #"img: "https://example\.com/a\.png", "#, #", w: 120"#, #", pos: "b""#,
    ])
    func droppedPropertyRefused(_ pattern: String) async throws {
        let edit = try editor(pattern)
        let node = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        let mutation: FlowchartMutation = pattern.contains("img") || pattern.contains("w:")
            ? .setNodeImage(of: node, to: ImageSpec(urlString: "https://example.com/a.png", width: 120, height: 90))
            : .setNodeIcon(of: node, to: IconSpec(name: "user", labelPosition: .bottom))
        do {
            try await edit.performFlowchart(mutation)
            Issue.record("applied: \(edit.source ?? "")")
        } catch DiagramEditorError.exportWouldLoseContent {
        }
        #expect(edit.source == "flowchart TD\n  A[Start] --> B[End]\n")
        #expect(!edit.canUndo)
    }
}
#endif

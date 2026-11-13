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

private typealias Step = @MainActor (DiagramEditor) async throws -> Void

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
            ("move to root", [{ try await $0.performFlowchart(.moveToSubgraph(selections: [node(y)], target: nil)) }]),
            ("delete group", [{ try await $0.perform(.deleteElement(DiagramSelection(diagramType: .flowchart, elementID: "group:\(s)"))) }]),
        ]
    }
    edits.append(("delete edge", [{ @MainActor editor in
        guard case .flowchart(let g) = editor.document.payload, let e = g.edges.first else { return }
        let id = _guaranteedDiagramEdgeID(id: e.id, source: e.source, target: e.target, label: e.label)
        try await editor.perform(.deleteElement(DiagramSelection(diagramType: .flowchart, elementID: id)))
    }]))
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
#if canImport(UIKit) || canImport(AppKit)
// Review of cc9e6ff2: the sweep must delete every state, transition,
// composite and region; check undo; and check the result with concrete
// facts rather than the safety net's own fingerprint.

private func edgeSelectionIDs(_ graph: original_src_types.MermaidGraph) -> [(id: String, edge: original_src_types.MermaidEdge)] {
    var counts: [String: Int] = [:]
    return graph.edges.map { edge in
        let base = _guaranteedDiagramEdgeID(id: edge.id, source: edge.source, target: edge.target, label: edge.label)
        let n = counts[base, default: 0]
        counts[base] = n + 1
        return (n > 0 ? "\(base)/\(n)" : base, edge)
    }
}

private func allSubgraphs(_ list: [original_src_types.MermaidSubgraph]) -> [original_src_types.MermaidSubgraph] {
    list.flatMap { [$0] + allSubgraphs($0.children) }
}

private func edgeKey(_ e: original_src_types.MermaidEdge) -> String { "\(e.source)->\(e.target):\(e.label ?? "")" }

let stateDeleteFixtures: [(name: String, source: String)] = [
    ("st-real", "stateDiagram-v2\n  [*] --> Draft\n  Draft --> [*] : discard\n  Draft --> Review\n  Review --> Published\n  Published --> [*]\n"),
    ("st-comp", "stateDiagram-v2\n  [*] --> Active\n  state Active {\n    [*] --> Idle\n    Idle --> Busy : go\n    Busy --> [*]\n  }\n  Active --> Done\n  Done --> [*]\n"),
    ("st-regions", "stateDiagram-v2\n  [*] --> Active\n  state Active {\n    [*] --> NumOff\n    NumOff --> NumOn\n    --\n    [*] --> CapsOff\n    CapsOff --> CapsOn\n    CapsOn --> [*]\n  }\n  Active --> [*]\n"),
]

private func checkIcon(_ node: original_src_types.MermaidNode) -> String? {
    let props = node.properties
    let ok: Bool = node.shape == .iconSquare && props?.icon == "fa:database" && props?.pos == "b" && props?.h != nil
    return ok ? nil : "icon node \(node.shape) \(String(describing: props))"
}

private func checkImage(_ node: original_src_types.MermaidNode) -> String? {
    let props = node.properties
    let url: Bool = props?.img == "https://example.com/a.png?x=1"
    let size: Bool = props?.w == 300.5 && props?.h == 4096
    return node.shape == .imageSquare && url && size ? nil : "image node \(node.shape) \(String(describing: props))"
}

private func checkShape(_ alias: String) -> (original_src_types.MermaidNode) -> String? {
    { node in node.shape == original_src_types.NodeShape.resolve(alias: alias) ? nil : "shape \(node.shape)" }
}

private func insertSteps(_ alias: String) -> [Step] {
    [{ try await $0.performFlowchart(.insertNode(id: "zz1", label: "New node", type: alias)) }]
}

@Suite("State deletes: every element, with undo and concrete checks") @MainActor
struct StateDeleteSweepTests {

    @Test("deleting every state, transition, composite and region of every state corpus document and fixture is accepted, reads back as asked, and undoes exactly")
    func deleteEverything() async throws {
        let corpus = try DiagramCorpus.load().compactMap { entry -> (String, String)? in
            guard let doc = try? MermaidImporter().parse(entry.source).document, doc.type == .stateDiagram else { return nil }
            return (entry.id, entry.source)
        }
        var failures: [String] = []
        var rows = 0
        for (name, source) in corpus + stateDeleteFixtures {
            let document = try MermaidImporter().parse(source).document
            guard case .stateDiagram(let graph) = document.payload else { continue }
            let markers = Set(graph.nodesInOrder.filter { $0.node.shape == .stateStart || $0.node.shape == .stateEnd }.map(\.id))
            let subgraphs = allSubgraphs(graph.subgraphs)
            let subgraphIDs = Set(subgraphs.map(\.id))
            var targets: [(String, Set<String>, Set<String>)] = []   // selection, removed ids, removed edge keys
            for (id, _) in graph.nodesInOrder where !markers.contains(id) && !subgraphIDs.contains(id) {
                let edges = Set(graph.edges.filter { $0.source == id || $0.target == id }.map(edgeKey))
                targets.append(("node:\(id)", [id], edges))
            }
            for (sid, edge) in edgeSelectionIDs(graph) {
                targets.append((sid, [], [edgeKey(edge)]))
            }
            for sub in subgraphs {
                var ids = Set([sub.id])
                for inner in allSubgraphs([sub]) { ids.formUnion(inner.nodeIds); ids.insert(inner.id) }
                let edges = Set(graph.edges.filter { ids.contains($0.source) || ids.contains($0.target) }.map(edgeKey))
                targets.append(("group:\(sub.id)", ids, edges))
            }
            for (selection, removed, removedEdges) in targets {
                rows += 1
                let label = "[\(name) \(selection)]"
                let editor = DiagramEditor(document: document, preferredExportFormat: .mermaid,
                                           exportRegistry: DiagramPipeline.defaultExportRegistry, initialSource: source)
                do {
                    try await editor.perform(.deleteElement(DiagramSelection(diagramType: .stateDiagram, elementID: selection)))
                } catch {
                    failures.append("\(label) refused: \(error.localizedDescription)"); continue
                }
                // Concrete facts, without the fingerprint. Notes are
                // compared by (state, text): a state's notes are numbered
                // in order, so deleting one renumbers the next, and a note
                // goes with its state or its attaching link.
                guard let saved = editor.source,
                      case .stateDiagram(let back) = try MermaidImporter().parse(saved).document.payload else {
                    failures.append("\(label) saved text does not parse"); continue
                }
                let noteIDs = Set(graph.nodesInOrder.filter { $0.node.shape == .stateNote }.map(\.id))
                func notes(_ g: original_src_types.MermaidGraph, dropping removedIDs: Set<String>, edges removedEdgeKeys: Set<String>) -> [String] {
                    g.nodesInOrder.filter { $0.node.shape == .stateNote && !removedIDs.contains($0.id) }.compactMap { note -> String? in
                        let link = g.edges.first { $0.source == note.id || $0.target == note.id }
                        if let link, removedEdgeKeys.contains(edgeKey(link)) { return nil }
                        let state = link.map { $0.source == note.id ? $0.target : $0.source } ?? "floating"
                        if removedIDs.contains(state) { return nil }
                        return "\(state): \(note.node.label)"
                    }.sorted()
                }
                let expectedNotes = notes(graph, dropping: removed, edges: removedEdges)
                let backNotes = notes(back, dropping: [], edges: [])
                if backNotes != expectedNotes { failures.append("\(label) notes \(backNotes) expected \(expectedNotes)") }
                let isNoteEdge = { (e: original_src_types.MermaidEdge) in noteIDs.contains(e.source) || noteIDs.contains(e.target) || e.source.contains("----note") || e.target.contains("----note") }
                let backIDs = Set(back.nodesInOrder.filter { $0.node.shape != .stateNote }.map(\.id))
                for id in removed where !noteIDs.contains(id) && backIDs.contains(id) { failures.append("\(label) \(id) still present") }
                if back.edges.contains(where: { !isNoteEdge($0) && (removed.contains($0.source) || removed.contains($0.target)) }) {
                    failures.append("\(label) a transition still names a deleted id")
                }
                let expectedEdges = graph.edges.filter { !isNoteEdge($0) }.map(edgeKey).filter { !removedEdges.contains($0) }.sorted()
                let backEdges = back.edges.filter { !isNoteEdge($0) }.map(edgeKey).sorted()
                if backEdges != expectedEdges {
                    failures.append("\(label) transitions \(backEdges) expected \(expectedEdges)")
                }
                let used = Set(back.edges.flatMap { [$0.source, $0.target] })
                let expectedIDs = Set(graph.nodesInOrder.filter { $0.node.shape != .stateNote }.map(\.id)).subtracting(removed)
                    .filter { !markers.contains($0) || used.contains($0) }
                if backIDs != expectedIDs {
                    failures.append("\(label) nodes \(backIDs.subtracting(expectedIDs)) extra, \(expectedIDs.subtracting(backIDs)) missing")
                }
                // One undo restores the source byte for byte.
                await editor.undo()
                if editor.source != source { failures.append("\(label) undo did not restore the source") }
                if editor.canUndo { failures.append("\(label) more than one undo step") }
            }
        }
        #expect(rows > 100)
        #expect(failures.isEmpty, "\(failures.count) of \(rows):\n\(failures.prefix(25).joined(separator: "\n"))")
    }

    @Test("every picker insert into a flowchart reads back with the expected shape, icon and image, other nodes and edges unchanged, and undoes exactly")
    func insertsConcrete() async throws {
        let source = "flowchart TD\n  A[Start] --> B[End]\n"
        var failures: [String] = []
        let cases: [(String, [Step], (original_src_types.MermaidNode) -> String?)] =
            catalogShapeAliases.map { alias in (alias, insertSteps(alias), checkShape(alias)) } + [
                ("icon", [
                    { try await $0.performFlowchart(.insertNode(id: "zz1", label: "New icon", type: "icon-circle")) },
                    { try await $0.performFlowchart(.setNodeIcon(of: node("zz1"), to: IconSpec(name: "database", background: .square, size: .large, labelPosition: .bottom))) },
                ], checkIcon),
                ("image", [
                    { try await $0.performFlowchart(.insertNode(id: "zz1", label: "Image", type: "image-square")) },
                    { try await $0.performFlowchart(.setNodeImage(of: node("zz1"), to: ImageSpec(urlString: "https://example.com/a.png?x=1", width: 300.5, height: 4096, title: "Shot"))) },
                ], checkImage),
            ]
        for (name, steps, check) in cases {
            let editor = DiagramEditor(document: try MermaidImporter().parse(source).document, preferredExportFormat: .mermaid,
                                       exportRegistry: DiagramPipeline.defaultExportRegistry, initialSource: source)
            editor.beginUndoGrouping()
            do {
                for step in steps { try await step(editor) }
            } catch {
                failures.append("[\(name)] refused: \(error.localizedDescription)")
            }
            editor.endUndoGrouping()
            guard case .flowchart(let back) = try MermaidImporter().parse(editor.source ?? "").document.payload,
                  let inserted = back.nodesInOrder.first(where: { $0.id == "zz1" }) else {
                failures.append("[\(name)] inserted node missing"); continue
            }
            if let problem = check(inserted.node) { failures.append("[\(name)] \(problem)") }
            if back.nodesInOrder.map(\.id) != ["A", "B", "zz1"] || back.edges.map(edgeKey) != ["A->B:"] {
                failures.append("[\(name)] other nodes or edges changed")
            }
            await editor.undo()
            if editor.source != source { failures.append("[\(name)] undo did not restore the source") }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }
}
#endif

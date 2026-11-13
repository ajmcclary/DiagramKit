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

    /// Deletes whose refusal is a known residual (M-R1: a state nested in a
    /// composite and reached only from outside it; the exporter cannot yet
    /// write it inside its composite once its sibling is gone).
    static let knownRefusals: Set<String> = []

    @Test("deleting every state, transition, composite and region of every state corpus document and fixture keeps everything else, judged from the source text, and undoes exactly")
    func deleteEverything() async throws {
        let corpus = try DiagramCorpus.load().compactMap { entry -> (String, String)? in
            guard let doc = try? MermaidImporter().parse(entry.source).document, doc.type == .stateDiagram else { return nil }
            return (entry.id, entry.source)
        }
        var failures: [String] = []
        var census: [String: (accepted: Int, refused: [String])] = [:]
        var rows = 0
        for (name, source) in corpus + stateDeleteFixtures + reviewerStateFixtures {
            let document = try MermaidImporter().parse(source).document
            guard case .stateDiagram(let graph) = document.payload else { continue }
            let facts = StateSourceFacts(source)
            let markers = Set(graph.nodesInOrder.filter { $0.node.shape == .stateStart || $0.node.shape == .stateEnd }.map(\.id))
            let noteIDs = Set(graph.nodesInOrder.filter { $0.node.shape == .stateNote }.map(\.id))
            let subgraphs = allSubgraphs(graph.subgraphs)
            let subgraphIDs = Set(subgraphs.map(\.id))
            // (selection, kind, what the source says should go)
            var targets: [(String, String, StateSourceFacts.Deletion)] = []
            for (id, node) in graph.nodesInOrder where !markers.contains(id) && !subgraphIDs.contains(id) {
                if node.shape == .stateNote {
                    targets.append(("node:\(id)", "node", .note(text: node.label)))
                } else {
                    targets.append(("node:\(id)", "node", .state(id)))
                }
            }
            for (sid, edge) in edgeSelectionIDs(graph) {
                if noteIDs.contains(edge.source) || noteIDs.contains(edge.target) {
                    let note = noteIDs.contains(edge.source) ? edge.source : edge.target
                    let state = note == edge.source ? edge.target : edge.source
                    let text = graph.nodesInOrder.first { $0.id == note }?.node.label ?? ""
                    targets.append((sid, "transition", .noteLink(state: state, text: text)))
                } else {
                    targets.append((sid, "transition", .transition(StateSourceFacts.key(edge.source, edge.target, edge.label ?? ""))))
                }
            }
            for sub in subgraphs {
                if let range = sub.id.range(of: "_region_"), let index = Int(sub.id[range.upperBound...]) {
                    targets.append(("group:\(sub.id)", "group", .region(String(sub.id[..<range.lowerBound]), index)))
                } else {
                    targets.append(("group:\(sub.id)", "group", .composite(sub.id)))
                }
            }
            for (selection, kind, deletion) in targets {
                rows += 1
                let label = "[\(name) \(selection)]"
                let editor = DiagramEditor(document: document, preferredExportFormat: .mermaid,
                                           exportRegistry: DiagramPipeline.defaultExportRegistry, initialSource: source)
                var counts = census[kind] ?? (0, [])
                do {
                    try await editor.perform(.deleteElement(DiagramSelection(diagramType: .stateDiagram, elementID: selection)))
                } catch {
                    counts.refused.append("\(label) \(error.localizedDescription)")
                    census[kind] = counts
                    if !Self.knownRefusals.contains("\(name) \(selection)") {
                        failures.append("\(label) refused: \(error.localizedDescription)")
                    }
                    continue
                }
                counts.accepted += 1
                census[kind] = counts
                // What should survive, from the source text alone.
                let expected = facts.after(deleting: deletion)
                let saved = StateSourceFacts(editor.source ?? "")
                if saved.transitions.sorted() != expected.transitions.sorted() {
                    let lost = expected.transitions.filter { !saved.transitions.contains($0) }
                    let extra = saved.transitions.filter { !expected.transitions.contains($0) }
                    failures.append("\(label) transitions lost \(lost), unexpected \(extra)")
                }
                if saved.states != expected.states {
                    failures.append("\(label) states lost \(expected.states.subtracting(saved.states).sorted()), unexpected \(saved.states.subtracting(expected.states).sorted())")
                }
                if saved.notes.sorted() != expected.notes.sorted() {
                    failures.append("\(label) notes \(saved.notes.sorted()) expected \(expected.notes.sorted())")
                }
                // One undo restores the source byte for byte.
                await editor.undo()
                if editor.source != source { failures.append("\(label) undo did not restore the source") }
                if editor.canUndo { failures.append("\(label) more than one undo step") }
            }
        }
        let summary = census.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value.accepted) accepted, \($0.value.refused.count) refused \($0.value.refused)" }
        print("STATE-DELETE-CENSUS " + summary.joined(separator: " | "))
        #expect(rows > 200)
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

/// What a state diagram's source text says, read without DiagramKit's
/// parser: its transitions (`[*]` named by its enclosing composite), the
/// states it names, and its notes by (state, text). The delete sweep judges
/// an edit by these facts, independently of the editor's membership rules.
struct StateSourceFacts {
    struct Transition: Hashable, Comparable, CustomStringConvertible {
        let from: String, to: String, label: String
        static func < (a: Self, b: Self) -> Bool { a.description < b.description }
        var description: String { "\(from) --> \(to)\(label.isEmpty ? "" : " : \(label)")" }
    }
    enum Deletion {
        case state(String), note(text: String), noteLink(state: String, text: String), transition(Transition)
        case composite(String), region(String, Int)
    }

    var transitions: [Transition] = []
    var states: Set<String> = []
    var notes: [String] = []                       // "state: text" or "floating: text"
    /// Where each transition and state sits: the (composite, region) pairs
    /// enclosing it, outermost first.
    var transitionScopes: [[(String, Int)]] = []
    var stateScopes: [String: [(String, Int)]] = [:]
    var noteStates: [String] = []                  // the state each note in `notes` is on, or ""
    var noteScopes: [[(String, Int)]] = []         // where each note is written

    /// A model edge's ends as the source writes them.
    static func key(_ source: String, _ target: String, _ label: String) -> Transition {
        func end(_ id: String) -> String {
            if id.hasSuffix("_start") { return "[*]@\(id.dropLast(6))" }
            if id.hasSuffix("_end") { return "[*]@\(id.dropLast(4))" }
            return id
        }
        return Transition(from: end(source), to: end(target), label: label)
    }

    init(_ text: String) {
        var stack: [(name: String, region: Int)] = []
        var pendingNote: (state: String, lines: [String])?
        func normalize(_ t: String) -> String {
            t.replacingOccurrences(of: "<br/>", with: "\n").replacingOccurrences(of: "<br>", with: "\n")
                .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        }
        func scope() -> [(String, Int)] { stack.map { ($0.name, $0.region) } }
        func mention(_ s: String) {
            guard s != "[*]", !s.isEmpty else { return }
            states.insert(s)
            if stateScopes[s] == nil { stateScopes[s] = scope() }
        }
        let keywords = ["classDef", "class ", "style ", "click ", "direction", "hide ", "scale ", "accTitle", "accDescr", "linkStyle", "%%", "---", "stateDiagram"]
        for raw in text.split(separator: "\n").map(String.init) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if var note = pendingNote {
                if line.lowercased() == "end note" {
                    notes.append("\(note.state): \(normalize(note.lines.joined(separator: "\n")))")
                    noteStates.append(note.state)
                    noteScopes.append(scope())
                    pendingNote = nil
                } else {
                    note.lines.append(line)
                    pendingNote = note
                }
                continue
            }
            if line.isEmpty || keywords.contains(where: { line.hasPrefix($0) }) { continue }
            if line == "}" { _ = stack.popLast(); continue }
            if line == "--" { if !stack.isEmpty { stack[stack.count - 1].region += 1 }; continue }
            if line.hasPrefix("note ") {
                let rest = line.dropFirst(5)
                if rest.hasPrefix("\"") {
                    let parts = rest.dropFirst().split(separator: "\"", maxSplits: 1)
                    notes.append("floating: \(normalize(String(parts.first ?? "")))")
                    noteStates.append("")
                    noteScopes.append(scope())
                    continue
                }
                for side in ["left of ", "right of "] where rest.hasPrefix(side) {
                    let body = rest.dropFirst(side.count)
                    if let colon = body.firstIndex(of: ":") {
                        let state = body[..<colon].trimmingCharacters(in: .whitespaces)
                        notes.append("\(state): \(normalize(String(body[body.index(after: colon)...]).trimmingCharacters(in: .whitespaces)))")
                        noteStates.append(state)
                        noteScopes.append(scope())
                        mention(state)
                    } else {
                        let state = body.trimmingCharacters(in: .whitespaces)
                        mention(state)
                        pendingNote = (state, [])
                    }
                }
                continue
            }
            if line.hasPrefix("state ") {
                var rest = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                let opens = rest.hasSuffix("{")
                if opens { rest = String(rest.dropLast()).trimmingCharacters(in: .whitespaces) }
                if let asRange = rest.range(of: " as ") { rest = String(rest[asRange.upperBound...]) }
                let name = rest.split(separator: " ").first.map(String.init) ?? rest
                let id = name.replacingOccurrences(of: "<<choice>>", with: "").replacingOccurrences(of: "<<fork>>", with: "").replacingOccurrences(of: "<<join>>", with: "")
                mention(id)
                if opens { stack.append((id, 0)) }
                continue
            }
            if let arrow = line.range(of: "-->") {
                let from = line[..<arrow.lowerBound].trimmingCharacters(in: .whitespaces)
                var rhs = line[arrow.upperBound...].trimmingCharacters(in: .whitespaces)
                var label = ""
                if let colon = rhs.firstIndex(of: ":") {
                    label = rhs[rhs.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    rhs = rhs[..<colon].trimmingCharacters(in: .whitespaces)
                }
                let here = stack.last?.name ?? "root"
                func end(_ e: String) -> String { e == "[*]" ? "[*]@\(here)" : e }
                mention(from)
                mention(rhs)
                transitions.append(Transition(from: end(from), to: end(rhs), label: label))
                transitionScopes.append(scope())
                continue
            }
            if let colon = line.firstIndex(of: ":") {
                mention(line[..<colon].trimmingCharacters(in: .whitespaces))
                continue
            }
            mention(line)
        }
    }

    /// The facts the text should state after `deletion`.
    func after(deleting deletion: Deletion) -> (transitions: [Transition], states: Set<String>, notes: [String]) {
        var deletedStates: Set<String> = []
        var inDeletedBlock: (([(String, Int)]) -> Bool) = { _ in false }
        var removedTransition: Transition?
        var floated: String?
        var deletedNoteText: String?
        func clean(_ t: String) -> String {
            t.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        }
        switch deletion {
        case .state(let s):
            deletedStates = [s]
        case .note(let text):
            deletedNoteText = text
        case .noteLink(let state, let text):
            floated = "\(state): \(clean(text))"
        case .transition(let t):
            removedTransition = t
        case .composite(let c):
            deletedStates = [c]
            inDeletedBlock = { scope in scope.contains { $0.0 == c } }
        case .region(let c, let k):
            inDeletedBlock = { scope in scope.contains { $0.0 == c && $0.1 == k } }
        }
        for (state, scope) in stateScopes where inDeletedBlock(scope) { deletedStates.insert(state) }
        var kept: [Transition] = []
        var removedOne = false
        for (t, scope) in zip(transitions, transitionScopes) {
            if let r = removedTransition, !removedOne, t == r { removedOne = true; continue }
            if inDeletedBlock(scope) || deletedStates.contains(t.from) || deletedStates.contains(t.to) { continue }
            kept.append(t)
        }
        var keptNotes: [String] = []
        var droppedOneNote = false
        for ((note, state), scope) in zip(zip(notes, noteStates), noteScopes) {
            // A note goes with its state, or with the block it is written in.
            if deletedStates.contains(state) || inDeletedBlock(scope) { continue }
            let text = String(note.drop(while: { $0 != ":" }).dropFirst()).trimmingCharacters(in: .whitespaces)
            if let d = deletedNoteText, !droppedOneNote, text == clean(d) {
                droppedOneNote = true
                continue
            }
            if let f = floated, note == f {
                // The note whose link was deleted stays, unattached.
                floated = nil
                keptNotes.append("floating: \(text)")
                continue
            }
            keptNotes.append(note)
        }
        return (kept, states.subtracting(deletedStates), keptNotes)
    }
}

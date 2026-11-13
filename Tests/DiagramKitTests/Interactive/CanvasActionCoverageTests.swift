// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Everyday canvas actions must not be refused on documents they can be
// written for (2026-11-12 review, round 2: I-R2-1, I-R2-2).

import Testing
import DiagramKit
import DiagramKitModel
import DiagramKitTestSupport
@testable import DiagramKitInteractive

@MainActor
private func editor(_ document: DiagramDocument, source: String?) -> DiagramEditor {
    DiagramEditor(
        document: document, preferredExportFormat: .mermaid,
        exportRegistry: DiagramPipeline.defaultExportRegistry, initialSource: source
    )
}

private func flowchartCorpus() throws -> [(id: String, source: String, document: DiagramDocument)] {
    try DiagramCorpus.load().compactMap { entry in
        guard let document = try? MermaidImporter().parse(entry.source).document,
              document.type == .flowchart || document.type == .stateDiagram else { return nil }
        return (entry.id, entry.source, document)
    }
}

@Suite("Canvas actions are not refused on corpus flowcharts") @MainActor
struct CanvasActionCoverageTests {

    @Test("every layout preset applies to every corpus flowchart and state diagram, with and without its source text")
    func layoutPresetsApply() async throws {
        var refused: [String] = []
        var applied = 0
        for (id, source, document) in try flowchartCorpus() {
            for withSource in [true, false] {
                for preset in [LayoutPreset.adaptive, .hierarchical] {
                    let edit = editor(document, source: withSource ? source : nil)
                    do {
                        try await edit.perform(.setLayoutPreset(preset))
                        applied += 1
                        #expect(edit.document.frontmatter?.layout == (preset == .adaptive ? "adaptive" : nil), "\(id)")
                    } catch {
                        refused.append("[\(id) source=\(withSource) \(preset)] \(error)")
                    }
                }
            }
        }
        #expect(applied > 200)
        #expect(refused.isEmpty, "\(refused.count) refused:\n\(refused.prefix(10).joined(separator: "\n"))")
    }

    @Test("Group and Ungroup apply to nodes inside and outside subgraphs on every corpus flowchart")
    func groupAndUngroup() async throws {
        var refused: [String] = []
        var grouped = 0
        for (id, source, document) in try flowchartCorpus() {
            guard case .flowchart(let graph) = document.payload else { continue }
            var memberOf: [String: String] = [:]
            func walk(_ s: original_src_types.MermaidSubgraph) {
                for n in s.nodeIds { memberOf[n] = s.id }
                s.children.forEach(walk)
            }
            graph.subgraphs.forEach(walk)
            let nodes = graph.nodesInOrder.map(\.id)
            var selections: [[String]] = []
            if nodes.count >= 2 { selections.append(Array(nodes.prefix(2))) }
            if let inside = nodes.first(where: { memberOf[$0] != nil }) { selections.append([inside]) }
            let siblings = Dictionary(grouping: nodes.filter { memberOf[$0] != nil }, by: { memberOf[$0]! }).values.first { $0.count >= 2 }
            if let siblings { selections.append(Array(siblings.prefix(2))) }
            if let outside = nodes.first(where: { memberOf[$0] == nil }), let inside = nodes.first(where: { memberOf[$0] != nil }) {
                selections.append([outside, inside])
            }
            for selection in selections {
                let edit = editor(document, source: source)
                do {
                    try await edit.performFlowchart(.groupIntoSubgraph(
                        selections: selection.map { DiagramSelection(diagramType: .flowchart, elementID: "node:\($0)") },
                        title: "Group"
                    ))
                    grouped += 1
                } catch {
                    refused.append("[\(id) group \(selection)] \(error)")
                    continue
                }
                guard case .flowchart(let after) = edit.document.payload else { continue }
                // Every selected node is now in exactly one subgraph: the new one.
                var owners: [String: [String]] = [:]
                func collect(_ s: original_src_types.MermaidSubgraph) {
                    for n in s.nodeIds { owners[n, default: []].append(s.id) }
                    s.children.forEach(collect)
                }
                after.subgraphs.forEach(collect)
                let newGroups = Set(selection.compactMap { owners[$0] }.flatMap { $0 })
                if newGroups.count != 1 || selection.contains(where: { owners[$0]?.count != 1 }) {
                    refused.append("[\(id) group \(selection)] owners \(selection.map { owners[$0] ?? [] })")
                }
                guard let newID = newGroups.first else { continue }
                do {
                    try await edit.performFlowchart(.ungroupSubgraph(id: newID))
                } catch {
                    refused.append("[\(id) ungroup \(newID)] \(error)")
                }
            }
        }
        #expect(grouped > 50)
        #expect(refused.isEmpty, "\(refused.count):\n\(refused.prefix(10).joined(separator: "\n"))")
    }
}
#endif

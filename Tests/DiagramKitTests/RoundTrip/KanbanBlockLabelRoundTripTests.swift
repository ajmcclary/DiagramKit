import Foundation
import Testing
import DiagramKit
import DiagramKitMermaid
import DiagramKitModel

// Kanban and block labels are raw display text in the model. The app
// re-exports the whole document on theme, title and layout changes, so a
// label must come back unchanged from parse → export → parse, round after
// round — including the characters Mermaid's syntax or entity decoding
// treats specially.

private let hostileLabels: [String] = [
    "Fix \"login\" bug",
    "odd \" quote",
    "back\\slash \\\" mix",
    "R&D <b>bold</b> & a > b",
    "[open and ] close",
    "only ] close",
    "#hash, #quot; and #35; written out",
    "amp &amp; &lt; written out",
    "50%% done",
    "'apostrophes'",
    "label @{ not metadata }",
    "\"\"",
]

private func exportAndParse(_ document: DiagramDocument) throws -> DiagramDocument {
    let source = try MermaidExporter().export(document).source
    return try MermaidImporter().parse(source).document
}

@Suite("Kanban and block labels round-trip through Mermaid export")
struct KanbanBlockLabelRoundTripTests {

    @Test("kanban card and column labels", arguments: hostileLabels)
    func kanbanLabels(_ label: String) throws {
        var document = try MermaidImporter().parse("kanban\n  todo[Todo]\n    t1[Card]\n").document
        guard case .kanban(var model) = document.payload else { Issue.record("not kanban"); return }
        // `nodes` lists the column as well as the card.
        for i in model.nodes.indices { model.nodes[i].label = label }
        for i in model.sections.indices { model.sections[i].label = label }
        document.payload = .kanban(model)
        for round in 1...3 {
            document = try exportAndParse(document)
            guard case .kanban(let back) = document.payload else { Issue.record("not kanban"); return }
            #expect(back.nodes.count == 2 && back.nodes.allSatisfy { $0.label == label }, "round \(round): \(back.nodes.map(\.label))")
            #expect(back.sections.map(\.label) == [label], "round \(round)")
        }
    }

    @Test("block node, composite and edge labels", arguments: hostileLabels)
    func blockLabels(_ label: String) throws {
        let source = "block-beta\n  block:g[\"Group\"]\n    a[\"A\"]\n  end\n  b[\"B\"]\n  a -- \"edge\" --> b\n"
        var document = try MermaidImporter().parse(source).document
        guard case .block(var model) = document.payload else { Issue.record("not block"); return }
        model.blockDatabase["a"]?.label = label
        model.blockDatabase["g"]?.label = label
        model.edges[0].label = label
        document.payload = .block(model)
        for round in 1...3 {
            document = try exportAndParse(document)
            guard case .block(let back) = document.payload else { Issue.record("not block"); return }
            #expect(back.blockDatabase["a"]?.label == label, "round \(round): \(back.blockDatabase["a"]?.label ?? "nil")")
            #expect(back.blockDatabase["g"]?.label == label, "round \(round)")
            #expect(back.edges.first?.label == label, "round \(round)")
        }
    }
}

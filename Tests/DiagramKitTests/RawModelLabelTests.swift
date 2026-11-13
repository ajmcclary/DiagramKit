import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitModel

/// Kanban and block labels are stored raw; only the SVG sink escapes them.
@Suite("Kanban and block labels are not escaped in the model")
struct RawModelLabelTests {

    @Test("kanban labels keep &, <, >, quotes and apostrophes")
    func kanbanRawLabels() async throws {
        let source = "kanban\n  todo[R&D \"x\" <b>]\n    t1[it's & more]\n    t2[Don't do]"
        let document = try await DiagramEngine.parse(source)
        guard case .kanban(let diagram) = document.payload else {
            Issue.record("expected kanban")
            return
        }
        #expect(diagram.sections.first?.label == "R&D \"x\" <b>")
        #expect(diagram.nodes.map(\.label).contains("it's & more"))
        #expect(diagram.nodes.map(\.label).contains("Don't do"))
        let ascii = try await DiagramEngine.renderASCII(source: source).text
        #expect(ascii.contains("R&D"))
        #expect(!ascii.contains("&amp;"))
        let svg = try await DiagramEngine.renderSVG(source: source)
        #expect(svg.contains("R&amp;D"))
        #expect(!svg.contains("&amp;amp;"))
        #expect(!svg.contains("<b>"))
    }

    @Test("block labels keep apostrophes and ampersands")
    func blockRawLabels() async throws {
        let source = "block-beta\na[\"It's\"] b[\"Don't\"] c[\"A & B\"]"
        let document = try await DiagramEngine.parse(source)
        guard case .block(let diagram) = document.payload else {
            Issue.record("expected block")
            return
        }
        #expect(diagram.blockDatabase["a"]?.label == "It's")
        #expect(diagram.blockDatabase["b"]?.label == "Don't")
        #expect(diagram.blockDatabase["c"]?.label == "A & B")
        let svg = try await DiagramEngine.renderSVG(source: source)
        #expect(!svg.contains("&amp;#39;"))
        #expect(!svg.contains("&amp;amp;"))
    }
}

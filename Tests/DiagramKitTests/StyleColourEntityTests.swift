import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// `#000;` at the end of a style statement is a colour, not an entity.
@Suite("Style colours are not decoded as entities")
struct StyleColourEntityTests {

    private static func graph(_ source: String) async throws -> ParsedGraphModel {
        let document = try await DiagramEngine.parse(source)
        guard case .flowchart(let graph) = document.payload else {
            Issue.record("expected a flowchart")
            throw CancellationError()
        }
        return graph
    }

    @Test("classDef colours ending in ; survive", arguments: [
        ("classDef k fill:#000;", "fill", "#000"),
        ("classDef k fill:#333;", "fill", "#333"),
        ("classDef k fill:#111;", "fill", "#111"),
        ("classDef k fill:#f9f,stroke:#333,stroke-width:4px,color:#000;", "color", "#000"),
    ])
    func classDefColour(_ statement: String, _ key: String, _ expected: String) async throws {
        let graph = try await Self.graph("graph TD\nA-->B\n\(statement)\nclass B k")
        #expect(graph.classDefs["k"]?[key] == expected)
    }

    @Test("style colours ending in ; survive")
    func styleColour() async throws {
        let graph = try await Self.graph("graph TD\nA-->B\nstyle A fill:#999999;")
        #expect(graph.nodeStyles["A"]?["fill"] == "#999999")
    }

    @Test("the SVG has no control characters from a colour")
    func svgHasNoNul() async throws {
        let svg = try await DiagramEngine.renderSVG(source: "graph TD\nA-->B\nclassDef k fill:#000;\nclass B k")
        #expect(!svg.unicodeScalars.contains { $0.value < 0x20 && $0 != "\n" && $0 != "\t" && $0 != "\r" })
    }

    @Test("entities in labels still decode, but never to a control character")
    func labelEntities() {
        #expect(_HTMLEntities.decode("A #35; B &amp; C #9829;") == "A # B & C \u{2665}")
        #expect(_HTMLEntities.decode("x #0; y &#1;") == "x #0; y &#1;")
    }
}

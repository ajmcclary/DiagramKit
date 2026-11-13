import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// Valid forms that used to fail loudly (2026-11-12 parser review).
@Suite("Valid forms that used to fail loudly")
struct ValidFormsFailingLoudlyTests {

    @Test("a pie value followed by a %% comment")
    func pieTrailingComment() async throws {
        let document = try await DiagramEngine.parse("pie\n    \"A\" : 10\n    \"B\" : 50.05 %% c")
        guard case .pie(let pie) = document.payload else {
            Issue.record("expected pie")
            return
        }
        #expect(pie.sections.map(\.value) == [10, 50.05])
    }

    @Test("an ER relationship written without spaces")
    func erUnspacedRelationship() async throws {
        let document = try await DiagramEngine.parse("erDiagram\n    A||--o{B : x")
        guard case .erDiagram(let diagram) = document.payload else {
            Issue.record("expected ER")
            return
        }
        let rel = try #require(diagram.relationships.first)
        #expect(rel.entity1 == "A")
        #expect(rel.entity2 == "B")
        #expect(rel.roleA == "x")
        #expect(rel.relSpec.cardA == .zeroOrMore)
        #expect(rel.relSpec.cardB == .onlyOne)
        #expect(rel.relSpec.relType == .identifying)
    }

    @Test("an ER relationship label keeps its apostrophe")
    func erApostropheLabel() async throws {
        let document = try await DiagramEngine.parse("erDiagram\n    A ||--o{ B : it's")
        guard case .erDiagram(let diagram) = document.payload else {
            Issue.record("expected ER")
            return
        }
        #expect(diagram.relationships.first?.roleA == "it's")
    }

    @Test("an apostrophe in a quadrant point name")
    func quadrantApostrophe() async throws {
        let document = try await DiagramEngine.parse("quadrantChart\n    A's: [0.1, 0.2]\n    'Quoted B': [0.3, 0.4]")
        guard case .quadrantChart(let chart) = document.payload else {
            Issue.record("expected quadrant")
            return
        }
        #expect(Set(chart.points.map(\.text)) == ["A's", "Quoted B"])
    }
}

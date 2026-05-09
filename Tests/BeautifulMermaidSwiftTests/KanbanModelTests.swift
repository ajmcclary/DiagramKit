import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class KanbanModelTests: XCTestCase {

    private func rawLines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    func test_sectionsHaveIsGroupTrue() throws {
        let source = "kanban\n  Todo\n    [Task]"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        for section in diagram.sections {
            XCTAssertTrue(section.isGroup)
        }
    }

    func test_cardsHaveIsGroupFalse() throws {
        let source = "kanban\n  S\n    card1\n    card2"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards.count, 2)
    }

    func test_cardsHaveParentId() throws {
        let source = "kanban\n  S1\n    c1\n  S2\n    c2"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let cards = diagram.nodes.filter { !$0.isGroup }
        XCTAssertEqual(cards[0].parentId, diagram.sections[0].id)
        XCTAssertEqual(cards[1].parentId, diagram.sections[1].id)
    }

    func test_sectionsInSourceOrder() throws {
        let source = "kanban\n  B\n  A\n  C"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.sections.map(\.label), ["B", "A", "C"])
    }

    func test_emptyEdgeCollection() throws {
        let source = "kanban\n  S"
        let diagram = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        XCTAssertNotNil(diagram.nodes)
        XCTAssertNotNil(diagram.sections)
    }
}

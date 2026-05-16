import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class KanbanLayoutTests: XCTestCase {

    private func rawLines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    func test_singleSectionLayout() throws {
        let source = "kanban\n  Todo\n    [Create Docs]"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        XCTAssertEqual(positioned.sections.count, 1)
        XCTAssertGreaterThan(positioned.sections[0].width, 0)
        XCTAssertGreaterThan(positioned.sections[0].height, 0)
    }

    func test_horizontalSectionPlacement() throws {
        let source = "kanban\n  A\n    a\n  B\n    b\n  C\n    c"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        XCTAssertEqual(positioned.sections.count, 3)
        XCTAssertLessThan(positioned.sections[0].x, positioned.sections[1].x)
        XCTAssertLessThan(positioned.sections[1].x, positioned.sections[2].x)
    }

    func test_cardWidthCalculation() throws {
        let source = "kanban\n  S\n    card1\n    card2"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let sectionWidth = diagram.config.sectionWidth
        let expectedCardWidth = sectionWidth - 1.5 * 10
        XCTAssertEqual(positioned.cards[0].width, expectedCardWidth)
    }

    func test_emptySectionsMinimumHeight() throws {
        let source = "kanban\n  S"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        XCTAssertGreaterThan(positioned.sections[0].height, 0)
    }

    func test_sectionIndexStartsAtOne() throws {
        let source = "kanban\n  A\n  B\n  C"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        XCTAssertEqual(positioned.sections[0].sectionIndex, 1)
        XCTAssertEqual(positioned.sections[1].sectionIndex, 2)
        XCTAssertEqual(positioned.sections[2].sectionIndex, 3)
    }

    func test_configPaddingAffectsTotalWidth() throws {
        let source = "kanban\n  S"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        XCTAssertGreaterThan(positioned.width, 0)
        XCTAssertGreaterThan(positioned.height, 0)
    }

    func test_totalWidthMatchesContentBounds() throws {
        let source = "kanban\n  A\n    a\n  B\n    b"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let expectedRightEdge = positioned.sections.last!.x + positioned.sections.last!.width / 2
        let expectedWidth = expectedRightEdge + diagram.config.padding * 2
        XCTAssertEqual(positioned.width, expectedWidth)
    }

    func test_totalHeightMatchesContentBounds() throws {
        let source = "kanban\n  S\n    card1\n    card2\n    card3"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let sectionBottom = positioned.sections.map { $0.y + $0.height }.max() ?? 0
        let cardBottom = positioned.cards.map { $0.y + $0.height / 2 }.max() ?? 0
        let expectedHeight = max(sectionBottom, cardBottom) + diagram.config.padding * 2
        XCTAssertEqual(positioned.height, expectedHeight)
    }

    func test_configPaddingDoesNotChangeCardWidthOrColumnGap() throws {
        let source = "kanban\n  A\n    a\n  B\n    b"
        var frontmatterA = DiagramFrontmatter()
        frontmatterA.perDiagram.kanban.config = KanbanDiagramConfig(padding: 8)
        let (diagramA, _) = try parseKanbanDiagram(rawLines(source), frontmatter: frontmatterA)
        let positionedA = layoutKanbanDiagram(diagramA)

        var frontmatterB = DiagramFrontmatter()
        frontmatterB.perDiagram.kanban.config = KanbanDiagramConfig(padding: 48)
        let (diagramB, _) = try parseKanbanDiagram(rawLines(source), frontmatter: frontmatterB)
        let positionedB = layoutKanbanDiagram(diagramB)

        XCTAssertEqual(positionedA.cards[0].width, positionedB.cards[0].width)
        XCTAssertEqual(positionedA.sections[1].x - positionedA.sections[0].x, positionedB.sections[1].x - positionedB.sections[0].x)
        XCTAssertNotEqual(positionedA.width, positionedB.width)
    }

    func test_firstCardStartsBelowSectionHeader() throws {
        let source = "kanban\n  Todo\n    [Create Documentation]"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)
        let section = positioned.sections[0]
        let card = positioned.cards[0]
        let sectionTop = section.y - section.width * 3 / 2
        let titleCenterY = sectionTop + 25
        let cardTop = card.y - card.height / 2

        XCTAssertGreaterThanOrEqual(cardTop, titleCenterY + 10)
    }

    func test_longCardLabelsIncreaseCardHeightForWrapping() throws {
        let source = "kanban\n  Todo\n    [Wrap long text across multiple lines to test layout]@{ assigned: alice }"
        let (diagram, _) = try parseKanbanDiagram(rawLines(source), frontmatter: nil)
        let positioned = layoutKanbanDiagram(diagram)

        XCTAssertGreaterThan(positioned.cards[0].height, 66)
    }
}

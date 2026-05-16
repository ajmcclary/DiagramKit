import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class KanbanConfigTests: XCTestCase {

    func test_defaultConfigValues() {
        let config = KanbanDiagramConfig()
        XCTAssertEqual(config.padding, 8)
        XCTAssertEqual(config.sectionWidth, 200)
        XCTAssertEqual(config.ticketBaseUrl, "")
        XCTAssertTrue(config.useMaxWidth)
    }

    func test_frontmatterParsing() {
        let yaml = "---\nconfig:\n  kanban:\n    padding: 12\n    sectionWidth: 250\n    ticketBaseUrl: 'https://jira.example.com/browse/#TICKET#'\n    useMaxWidth: false\n---\nkanban\n  S"
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        XCTAssertNotNil(fm?.perDiagram.kanban.config)
        XCTAssertEqual(fm?.perDiagram.kanban.config?.padding, 12)
        XCTAssertEqual(fm?.perDiagram.kanban.config?.sectionWidth, 250)
        XCTAssertEqual(fm?.perDiagram.kanban.config?.ticketBaseUrl, "https://jira.example.com/browse/#TICKET#")
        XCTAssertFalse(fm?.perDiagram.kanban.config?.useMaxWidth ?? true)
    }

    func test_frontmatterPartialConfig() {
        let yaml = "---\nconfig:\n  kanban:\n    padding: 20\n---\nkanban\n  S"
        let (_, fm) = _parseFrontMatterAndStripped(yaml)
        XCTAssertNotNil(fm?.perDiagram.kanban.config)
        XCTAssertEqual(fm?.perDiagram.kanban.config?.padding, 20)
        XCTAssertEqual(fm?.perDiagram.kanban.config?.sectionWidth, 200)
    }
}

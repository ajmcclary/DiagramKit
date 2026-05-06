import XCTest
@testable import BeautifulMermaid

final class TimelineModelTests: XCTestCase {

    private func parse(_ source: String) throws -> TimelineDiagram {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return try parseTimelineDiagram(lines, frontmatter: nil)
    }

    // MARK: - Direction

    func test_defaultDirection_LR() throws {
        let source = """
        timeline
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.direction, .LR)
    }

    func test_explicitDirection_TD() throws {
        let source = """
        timeline TD
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.direction, .TD)
    }

    // MARK: - Section Tracking

    func test_sectionTracking_perTask() throws {
        let source = """
        timeline
            section A
            2020 : E1
            section B
            2021 : E2
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].section, "A")
        XCTAssertEqual(diagram.tasks[1].section, "B")
    }

    func test_duplicateSection_perTask() throws {
        let source = """
        timeline
            section A
            2020 : E1
            section A
            2021 : E2
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].section, "A")
        XCTAssertEqual(diagram.tasks[1].section, "A")
    }

    func test_noSection_emptySectionName() throws {
        let source = """
        timeline
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.sections.count, 0)
        XCTAssertEqual(diagram.tasks[0].section, "")
    }

    // MARK: - Task Order and IDs

    func test_taskIds_sourceOrder() throws {
        let source = """
        timeline
            2020 : A
            2021 : B
            2022 : C
        """
        let diagram = try parse(source)
        for i in 0..<3 {
            XCTAssertEqual(diagram.tasks[i].id, i)
        }
    }

    func test_taskId_globalMonotonic() throws {
        let source = """
        timeline
            section X
            2020 : A
            section Y
            2021 : B
            2022 : C
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].id, 0)
        XCTAssertEqual(diagram.tasks[1].id, 1)
        XCTAssertEqual(diagram.tasks[2].id, 2)
    }

    // MARK: - Event Ordering

    func test_eventOrder_withinTask() throws {
        let source = """
        timeline
            2020 : First : Second : Third
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].events[0].text, "First")
        XCTAssertEqual(diagram.tasks[0].events[1].text, "Second")
        XCTAssertEqual(diagram.tasks[0].events[2].text, "Third")
    }

    func test_eventOrder_continuations() throws {
        let source = """
        timeline
            2020 : E1
                : E2
                : E3
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].events[0].text, "E1")
        XCTAssertEqual(diagram.tasks[0].events[1].text, "E2")
        XCTAssertEqual(diagram.tasks[0].events[2].text, "E3")
    }

    // MARK: - Empty Diagram

    func test_emptyDiagram() throws {
        let source = """
        timeline
        """
        let diagram = try parse(source)
        XCTAssertTrue(diagram.tasks.isEmpty)
        XCTAssertTrue(diagram.sections.isEmpty)
    }

    // MARK: - Config Defaults

    func test_defaultConfig() throws {
        let source = """
        timeline
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.config.disableMulticolor, false)
        XCTAssertEqual(diagram.config.leftMargin, 150)
        XCTAssertEqual(diagram.config.padding, 50)
        XCTAssertEqual(diagram.config.textPlacement, "fo")
    }

    // MARK: - Theme Defaults

    func test_defaultTheme() throws {
        let source = """
        timeline
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.theme.cScale.count, 12)
        XCTAssertEqual(diagram.theme.themeColorLimit, 12)
        XCTAssertFalse(diagram.theme.useGradient)
    }

    // MARK: - Title

    func test_title() throws {
        let source = """
        timeline
            title My Title
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.diagramTitle, "My Title")
    }

    // MARK: - Accessibility

    func test_accessibility_title() throws {
        let source = """
        timeline
            accTitle: Accessible Timeline
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.accTitle, "Accessible Timeline")
    }

    func test_accessibility_descr_singleLine() throws {
        let source = """
        timeline
            accDescr: A description
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.accDescr, "A description")
    }

    func test_accessibility_descr_multiline() throws {
        let source = """
        timeline
            accDescr {
            Line one
            Line two
            }
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.accDescr, "Line one\nLine two")
    }
}

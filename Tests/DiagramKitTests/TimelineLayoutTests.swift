import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class TimelineLayoutTests: XCTestCase {

    private func parseAndLayout(_ source: String) throws -> PositionedTimelineDiagram {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let diagram = try parseTimelineDiagram(lines, frontmatter: nil)
        return layoutTimelineDiagram(diagram)
    }

    // MARK: - LR Layout

    func test_lr_basicPositioning() throws {
        let source = """
        timeline
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        XCTAssertEqual(positioned.direction, .LR)
        XCTAssertEqual(positioned.tasks.count, 1)
        XCTAssertEqual(positioned.tasks[0].text, "2020")
        XCTAssertGreaterThan(positioned.width, 0)
        XCTAssertGreaterThan(positioned.height, 0)
    }

    func test_lr_multipleTasksHorizontal() throws {
        let source = """
        timeline
            2020 : Event A
            2021 : Event B
            2022 : Event C
        """
        let positioned = try parseAndLayout(source)
        XCTAssertEqual(positioned.tasks.count, 3)
        XCTAssertEqual(positioned.events.count, 3)
        XCTAssertEqual(positioned.connectors.count, 3)
    }

    func test_lr_eventsHaveConnectors() throws {
        let source = """
        timeline
            2020 : E1 : E2
        """
        let positioned = try parseAndLayout(source)
        XCTAssertEqual(positioned.tasks.count, 1)
        XCTAssertEqual(positioned.events.count, 2)
        XCTAssertEqual(positioned.connectors.count, 2)
        for connector in positioned.connectors {
            switch connector.kind {
            case .verticalLR(let x1, let y1, let x2, let y2):
                XCTAssertLessThanOrEqual(y1, y2)
                XCTAssertEqual(x1, x2)
            default:
                XCTFail("Expected vertical LR connector")
            }
        }
    }

    func test_lr_sections_positioned() throws {
        let source = """
        timeline
            section Era 1
            2020 : Event A
            section Era 2
            2021 : Event B
        """
        let positioned = try parseAndLayout(source)
        XCTAssertEqual(positioned.sections.count, 2)
        XCTAssertEqual(positioned.sections[0].text, "Era 1")
        XCTAssertEqual(positioned.sections[1].text, "Era 2")
    }

    func test_lr_sectionsShareRowAndAdvanceHorizontally() throws {
        let source = """
        timeline
            section Era 1
            2020 : Event A
            section Era 2
            2021 : Event B
        """
        let positioned = try parseAndLayout(source)
        XCTAssertEqual(positioned.sections.count, 2)
        XCTAssertEqual(positioned.tasks.count, 2)
        XCTAssertEqual(positioned.sections[0].y, positioned.sections[1].y)
        XCTAssertGreaterThan(positioned.sections[1].x, positioned.sections[0].x)
        XCTAssertEqual(positioned.tasks[0].y, positioned.tasks[1].y)
        XCTAssertGreaterThan(positioned.tasks[1].x, positioned.tasks[0].x)
    }

    func test_lr_sectionTaskAssociation() throws {
        let source = """
        timeline
            section Era 1
            2020 : Event A
            section Era 2
            2021 : Event B
        """
        let positioned = try parseAndLayout(source)
        let task0 = positioned.tasks.first(where: { $0.id == 0 })
        let task1 = positioned.tasks.first(where: { $0.id == 1 })
        XCTAssertEqual(task0?.section, "Era 1")
        XCTAssertEqual(task1?.section, "Era 2")
    }

    func test_lr_activityLine() throws {
        let source = """
        timeline
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        XCTAssertGreaterThan(positioned.activityLine.x2, positioned.activityLine.x1)
        XCTAssertEqual(positioned.activityLine.y1, positioned.activityLine.y2)
    }

    func test_lr_activityLineIsBetweenTaskRowAndEventsWithoutSections() throws {
        let source = """
        timeline
            2020 : Event
            2021 : Later Event
        """
        let positioned = try parseAndLayout(source)
        let axisY = positioned.activityLine.y1
        let maxTaskBottom = positioned.tasks.map { $0.y + $0.height }.max() ?? 0
        let minEventTop = positioned.events.map(\.y).min() ?? .greatestFiniteMagnitude
        XCTAssertGreaterThan(axisY, maxTaskBottom)
        XCTAssertLessThan(axisY, minEventTop)
    }

    func test_lr_activityLineIsBetweenTaskRowAndEventsWithSections() throws {
        let source = """
        timeline
            section Era 1
            2020 : Event A
            section Era 2
            2021 : Event B
        """
        let positioned = try parseAndLayout(source)
        let axisY = positioned.activityLine.y1
        let maxTaskBottom = positioned.tasks.map { $0.y + $0.height }.max() ?? 0
        let minEventTop = positioned.events.map(\.y).min() ?? .greatestFiniteMagnitude
        XCTAssertGreaterThan(axisY, maxTaskBottom)
        XCTAssertLessThan(axisY, minEventTop)
    }

    func test_lr_titlePresent() throws {
        let source = """
        timeline
            title My Timeline
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        XCTAssertNotNil(positioned.title)
        XCTAssertEqual(positioned.title?.text, "My Timeline")
    }

    func test_lr_titleAbsent() throws {
        let source = """
        timeline
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        XCTAssertNil(positioned.title)
    }

    func test_lr_noSections_colorIndex() throws {
        let source = """
        timeline
            2020 : Event A
            2021 : Event B
            2022 : Event C
        """
        let positioned = try parseAndLayout(source)
        XCTAssertEqual(positioned.tasks[0].colorIndex, 0)
        XCTAssertEqual(positioned.tasks[1].colorIndex, 1)
        XCTAssertEqual(positioned.tasks[2].colorIndex, 2)
    }

    func test_lr_disableMulticolor_singleColor() throws {
        let source = """
        timeline
            2020 : Event A
            2021 : Event B
        """
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var diagram = try parseTimelineDiagram(lines, frontmatter: nil)
        diagram.config.disableMulticolor = true
        let positioned = layoutTimelineDiagram(diagram)
        for task in positioned.tasks {
            XCTAssertEqual(task.colorIndex, 0)
        }
    }

    // MARK: - TD Layout

    func test_td_basicPositioning() throws {
        let source = """
        timeline TD
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        XCTAssertEqual(positioned.direction, .TD)
        XCTAssertEqual(positioned.tasks.count, 1)
        XCTAssertGreaterThan(positioned.width, 0)
    }

    func test_td_tasksLeftOfAxis() throws {
        let source = """
        timeline TD
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        for task in positioned.tasks {
            XCTAssertLessThan(task.x + task.width, positioned.activityLine.x1)
        }
    }

    func test_td_eventsRightOfAxis() throws {
        let source = """
        timeline TD
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        for event in positioned.events {
            XCTAssertGreaterThan(event.x, positioned.activityLine.x1)
        }
    }

    func test_td_connectorsHorizontal() throws {
        let source = """
        timeline TD
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        for connector in positioned.connectors {
            switch connector.kind {
            case .horizontalTD(let x1, _, let x2, _):
                XCTAssertLessThan(x1, x2)
            default:
                XCTFail("Expected horizontal TD connector")
            }
        }
    }

    func test_td_verticalActivityLine() throws {
        let source = """
        timeline TD
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        XCTAssertEqual(positioned.activityLine.x1, positioned.activityLine.x2)
        XCTAssertLessThan(positioned.activityLine.y1, positioned.activityLine.y2)
    }

    func test_td_activityLineExtendsAboveContent() throws {
        let source = """
        timeline TD
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        let topY = positioned.tasks.map(\.y).min() ?? 0
        XCTAssertLessThan(positioned.activityLine.y1, topY, "TD activity line should start above content")
    }

    func test_td_activityLineExtendsBelowContent() throws {
        let source = """
        timeline TD
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        let bottomY = (positioned.events.map { $0.y + $0.height }.max() ?? 0)
        XCTAssertGreaterThan(positioned.activityLine.y2, bottomY, "TD activity line should extend below content")
    }

    func test_td_titlePresent() throws {
        let source = """
        timeline TD
            title My Vertical Timeline
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        XCTAssertNotNil(positioned.title)
        XCTAssertEqual(positioned.title?.text, "My Vertical Timeline")
    }

    func test_td_multipleTasks() throws {
        let source = """
        timeline TD
            2020 : Event A
            2021 : Event B
        """
        let positioned = try parseAndLayout(source)
        XCTAssertEqual(positioned.tasks.count, 2)
        XCTAssertEqual(positioned.events.count, 2)
        XCTAssertEqual(positioned.connectors.count, 2)
    }

    // MARK: - Accessible metadata

    func test_accessibilityMetadata_passedThrough() throws {
        let source = """
        timeline
            accTitle: The Title
            accDescr: The Description
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        XCTAssertEqual(positioned.accTitle, "The Title")
        XCTAssertEqual(positioned.accDescr, "The Description")
    }

    // MARK: - Diagram title

    func test_diagramTitle_passedThrough() throws {
        let source = """
        timeline
            title Diagram Title
            2020 : Event
        """
        let positioned = try parseAndLayout(source)
        XCTAssertEqual(positioned.diagramTitle, "Diagram Title")
    }
}

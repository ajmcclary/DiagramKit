import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class JourneyLayoutTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n").map(String.init)
    }

    private func parsedDiagram(_ source: String) throws -> JourneyDiagram {
        try parseJourneyDiagram(lines(source)).0
    }

    // MARK: - Basic layout

    func test_basicLayoutDimensions() throws {
        let source = """
        journey
            title Test
            section Go
            Do thing: 5: Me
        """
        let diagram = try parsedDiagram(source)
        let positioned = layoutJourneyDiagram(diagram)
        XCTAssertGreaterThan(positioned.width, 0)
        XCTAssertGreaterThan(positioned.height, 0)
    }

    func test_actorLegendYIncrement() throws {
        let source = """
        journey
            section Test
            Task1: 1: Alice
            Task2: 2: Bob
        """
        let diagram = try parsedDiagram(source)
        let positioned = layoutJourneyDiagram(diagram)
        XCTAssertEqual(positioned.actors.count, 2)
        if positioned.actors.count >= 2 {
            XCTAssertGreaterThan(positioned.actors[1].circleCenter.y, positioned.actors[0].circleCenter.y)
        }
    }

    func test_legendWidth() throws {
        let source = """
        journey
            section Test
            Task1: 1: Alice
        """
        let diagram = try parsedDiagram(source)
        let positioned = layoutJourneyDiagram(diagram)
        XCTAssertGreaterThan(positioned.legendWidth, 0)
    }

    func test_taskColumnXPositions() throws {
        let source = """
        journey
            section Test
            Task1: 1: Me
            Task2: 2: Me
            Task3: 3: Me
        """
        let diagram = try parsedDiagram(source)
        let positioned = layoutJourneyDiagram(diagram)
        XCTAssertEqual(positioned.tasks.count, 3)
        for i in 1..<positioned.tasks.count {
            XCTAssertGreaterThan(positioned.tasks[i].x, positioned.tasks[i - 1].x,
                                  "Task \(i) should be to the right of task \(i - 1)")
        }
    }

    func test_taskRectDimensions() throws {
        let source = """
        journey
            section Test
            Task: 3: Me
        """
        let diagram = try parsedDiagram(source)
        let config = JourneyDiagramConfig()
        let positioned = layoutJourneyDiagram(diagram, config: config)
        XCTAssertEqual(positioned.tasks.count, 1)
        XCTAssertEqual(positioned.tasks[0].rectWidth, config.width)
        XCTAssertEqual(positioned.tasks[0].rectHeight, config.height)
    }

    func test_taskBoundsDimensions() throws {
        let source = """
        journey
            section Test
            Task: 3: Me
        """
        let diagram = try parsedDiagram(source)
        let config = JourneyDiagramConfig()
        let positioned = layoutJourneyDiagram(diagram, config: config)
        XCTAssertEqual(positioned.tasks[0].boundsWidth, config.diagramMarginX)
        XCTAssertEqual(positioned.tasks[0].boundsHeight, config.diagramMarginY)
    }

    func test_sectionSpanCoversTasks() throws {
        let source = """
        journey
            section Go
            Task1: 1: Me
            Task2: 2: Me
        """
        let diagram = try parsedDiagram(source)
        let positioned = layoutJourneyDiagram(diagram)
        XCTAssertEqual(positioned.sections.count, 1)
        if positioned.tasks.count >= 2 {
            let expectedWidth = positioned.tasks[1].x - positioned.tasks[0].x + positioned.tasks[1].rectWidth
            let sectionWidth = positioned.sections[0].width
            XCTAssertEqual(sectionWidth, expectedWidth, accuracy: 1.0)
        }
    }

    func test_repeatedSectionNamesCreateSeparateContiguousRuns() throws {
        let source = """
        journey
            section Darkoob
            First: 5: Me
            section External Service
            Second: 4: Me
            section Darkoob
            Third: 3: Me
        """
        let diagram = try parsedDiagram(source)
        let positioned = layoutJourneyDiagram(diagram)
        XCTAssertEqual(positioned.sections.map(\.name), ["Darkoob", "External Service", "Darkoob"])
        if positioned.sections.count >= 3 {
            XCTAssertEqual(positioned.sections[2].x, positioned.tasks[2].x)
            XCTAssertEqual(positioned.sections[2].width, positioned.tasks[2].rectWidth, accuracy: 1.0)
        }
    }

    func test_colorPalettesWrapByModulo() throws {
        let source = """
        journey
            section One
            Task1: 5: Alice
            section Two
            Task2: 4: Bob
            section Three
            Task3: 3: Charlie
        """
        var config = JourneyDiagramConfig()
        config.actorColours = ["#111111", "#222222"]
        config.sectionFills = ["#aaaaaa", "#bbbbbb"]
        config.sectionColours = ["#ffffff", "#000000"]

        let positioned = layoutJourneyDiagram(try parsedDiagram(source), config: config)
        XCTAssertEqual(positioned.actors.map(\.color), ["#111111", "#222222", "#111111"])
        XCTAssertEqual(positioned.sections.map(\.fill), ["#aaaaaa", "#bbbbbb", "#aaaaaa"])
        XCTAssertEqual(positioned.sections.map(\.colour), ["#ffffff", "#000000", "#ffffff"])
        XCTAssertEqual(positioned.sections.map(\.num), [0, 1, 0])
    }

    func test_scoreFaceY() throws {
        let source = """
        journey
            section Test
            High: 5: Me
            Mid: 3: Me
            Low: 1: Me
        """
        let diagram = try parsedDiagram(source)
        let positioned = layoutJourneyDiagram(diagram)
        XCTAssertEqual(positioned.tasks.count, 3)

        let high = positioned.tasks.first(where: { $0.score == 5 })!
        let mid = positioned.tasks.first(where: { $0.score == 3 })!
        let low = positioned.tasks.first(where: { $0.score == 1 })!

        // Higher score = happier = higher on page = smaller Y
        XCTAssertLessThan(high.faceY, mid.faceY)
        XCTAssertLessThan(mid.faceY, low.faceY)

        // Clamped: out-of-range scores should clamp to 1-5 range for face position
    }

    func test_outOfRangeScoreClamps() throws {
        let source = """
        journey
            section Test
            TooHigh: 10: Me
            TooLow: -5: Me
        """
        let diagram = try parsedDiagram(source)
        let positioned = layoutJourneyDiagram(diagram)
        XCTAssertEqual(positioned.tasks.count, 2)
        // Scores stored as-is in model
        XCTAssertEqual(positioned.tasks[0].score, 10)
        XCTAssertEqual(positioned.tasks[1].score, -5)
        // Face Y is clamped
        let expectedMaxFaceY = 300.0 + (5.0 - 1.0) * 30.0 // score=1 gives highest Y
        let expectedMinFaceY = 300.0 + (5.0 - 5.0) * 30.0 // score=5 gives lowest Y
        XCTAssertEqual(positioned.tasks[0].faceY, expectedMinFaceY)
        XCTAssertEqual(positioned.tasks[1].faceY, expectedMaxFaceY)
    }

    func test_titleOffset() throws {
        let withTitle = """
        journey
            title With Title
            section Test
            Task: 3: Me
        """
        let withoutTitle = """
        journey
            section Test
            Task: 3: Me
        """
        let with = layoutJourneyDiagram(try parsedDiagram(withTitle))
        let without = layoutJourneyDiagram(try parsedDiagram(withoutTitle))
        XCTAssertEqual(with.title, "With Title")
        XCTAssertNil(without.title)
        XCTAssertGreaterThan(with.height, without.height)
    }

    func test_effectiveLeftMargin() throws {
        let source = """
        journey
            section Test
            Task: 3: Me
        """
        let diagram = try parsedDiagram(source)
        let positioned = layoutJourneyDiagram(diagram)
        XCTAssertGreaterThan(positioned.effectiveLeftMargin, 0)
        XCTAssertEqual(positioned.effectiveLeftMargin, JourneyDiagramConfig().leftMargin, accuracy: 0.1)
    }

    func test_activityLineY() throws {
        let source = """
        journey
            section Test
            Task: 3: Me
        """
        let diagram = try parsedDiagram(source)
        let positioned = layoutJourneyDiagram(diagram)
        let config = JourneyDiagramConfig()
        let task = try XCTUnwrap(positioned.tasks.first)
        XCTAssertEqual(positioned.activityLineY, task.y + task.rectHeight + config.diagramMarginY)
    }

    func test_activityLineDoesNotIntersectTaskRects() throws {
        let source = """
        journey
            section Test
            Task1: 5: Me
            Task2: 4: Me
        """
        let positioned = layoutJourneyDiagram(try parsedDiagram(source))
        for task in positioned.tasks {
            XCTAssertGreaterThan(
                positioned.activityLineY,
                task.y + task.rectHeight,
                "Activity line should sit below task \(task.task), not through its rectangle"
            )
        }
    }

    func test_diagramWidthUsesTaskRightEdgeWithoutDoubleCountingLeftMargin() throws {
        let source = """
        journey
            section Checkout
            Add to cart: 5: Me
            Pay: 5: Me
        """
        let config = JourneyDiagramConfig()
        let positioned = layoutJourneyDiagram(try parsedDiagram(source), config: config)
        let lastTask = try XCTUnwrap(positioned.tasks.last)
        XCTAssertEqual(positioned.width, lastTask.x + lastTask.rectWidth + config.diagramMarginX, accuracy: 1.0)
    }

    func test_emptyDiagramReturnsZeroSized() throws {
        let source = """
        journey
        """
        let diagram = try parsedDiagram(source)
        let positioned = layoutJourneyDiagram(diagram)
        XCTAssertEqual(positioned.tasks.count, 0)
        XCTAssertEqual(positioned.sections.count, 0)
        XCTAssertGreaterThanOrEqual(positioned.width, 0)
    }

    func test_nonNumericScoreFaceClampedToScore1() throws {
        let source = """
        journey
            section Test
            A task: 0: Me
        """
        let diagram = try parsedDiagram(source)
        let positioned = layoutJourneyDiagram(diagram)
        XCTAssertEqual(positioned.tasks.count, 1)
        // Score 0 stored as-is, but faceY clamped as score=1
        XCTAssertEqual(positioned.tasks[0].score, 0)
        let expectedFaceY = 300.0 + (5.0 - 1.0) * 30.0
        XCTAssertEqual(positioned.tasks[0].faceY, expectedFaceY)
    }
}

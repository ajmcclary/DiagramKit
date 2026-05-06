import XCTest
@testable import BeautifulMermaid

final class JourneyParserTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n").map(String.init)
    }

    // MARK: - Basic parsing

    func test_basicDocsExample() throws {
        let source = """
        journey
            title My working day
            section Go to work
              Make tea: 5: Me
              Go upstairs: 3: Me
              Do work: 1: Me, Cat
            section Go home
              Go downstairs: 5: Me
              Sit down: 5: Me
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.title, "My working day")
        XCTAssertEqual(diagram.sections.count, 2)
        XCTAssertEqual(diagram.sections[0], "Go to work")
        XCTAssertEqual(diagram.sections[1], "Go home")
        XCTAssertEqual(diagram.tasks.count, 5)
        XCTAssertEqual(Set(diagram.actors), Set(["Me", "Cat"]))
    }

    func test_titleParsing() throws {
        let source = """
        journey
            title Adding journey diagram functionality to mermaid
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.title, "Adding journey diagram functionality to mermaid")
    }

    func test_accTitleParsing() throws {
        let source = """
        journey
            accTitle: The title
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.accTitle, "The title")
    }

    func test_singleLineAccDescr() throws {
        let source = """
        journey
            accDescr: A user journey for family shopping
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.accDescr, "A user journey for family shopping")
    }

    func test_multilineAccDescr() throws {
        let source = """
        journey
            accDescr {
            A user journey for
            family shopping
            }
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.accDescr, "A user journey for\nfamily shopping")
    }

    func test_inlineMultilineAccDescr_singleLine() throws {
        let source = """
        journey
            accDescr { A one-line journey description }
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.accDescr, "A one-line journey description")
    }

    func test_inlineMultilineAccDescr_preservesContentAfterOpeningBrace() throws {
        let source = """
        journey
            accDescr { A user journey for
            family shopping
            }
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.accDescr, "A user journey for\nfamily shopping")
    }

    func test_combinedAccessibility() throws {
        let source = """
        journey
            accTitle: A journey
            accDescr: A journey description
            title My Title
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.accTitle, "A journey")
        XCTAssertEqual(diagram.accDescr, "A journey description")
        XCTAssertEqual(diagram.title, "My Title")
    }

    func test_singleSection() throws {
        let source = """
        journey
            section Order from website
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.sections.count, 1)
        XCTAssertEqual(diagram.sections[0], "Order from website")
    }

    func test_sectionWithBrVariants() throws {
        let source = """
        journey
            section Line1<br>Line2<br/>Line3</br />Line4<br\t/>Line5
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.sections.count, 1)
        XCTAssertTrue(diagram.sections[0].contains("<br>"))
    }

    func test_taskWithoutActors() throws {
        let source = """
        journey
            section Test
            C task: 5
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.tasks.count, 1)
        XCTAssertEqual(diagram.tasks[0].task, "C task")
        XCTAssertEqual(diagram.tasks[0].score, 5)
        XCTAssertEqual(diagram.tasks[0].people, [])
    }

    func test_taskWithMultipleActors() throws {
        let source = """
        journey
            section Test
            A task: 5: Alice, Bob, Charlie
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.tasks.count, 1)
        XCTAssertEqual(diagram.tasks[0].score, 5)
        XCTAssertEqual(diagram.tasks[0].people, ["Alice", "Bob", "Charlie"])
    }

    func test_taskWithTrailingColon() throws {
        let source = """
        journey
            section Test
            E task: 5:
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.tasks.count, 1)
        XCTAssertEqual(diagram.tasks[0].score, 5)
        XCTAssertEqual(diagram.tasks[0].people, [""])
    }

    func test_multipleSections() throws {
        let source = """
        journey
            section Documentation
            Task1: 1: Me
            section Another section
            Task2: 3: You
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.sections.count, 2)
        XCTAssertEqual(diagram.tasks[0].section, "Documentation")
        XCTAssertEqual(diagram.tasks[1].section, "Another section")
    }

    func test_actorDedupAndSorting() throws {
        let source = """
        journey
            section Test
            Task1: 1: Charlie, Alice
            Task2: 3: Bob, Alice
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.actors, ["Alice", "Bob", "Charlie"])
    }

    func test_emptyDiagram() throws {
        let source = """
        journey
        title Test
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.title, "Test")
        XCTAssertEqual(diagram.sections.count, 0)
        XCTAssertEqual(diagram.tasks.count, 0)
        XCTAssertEqual(diagram.actors.count, 0)
    }

    func test_inlineHashCommentStripping() throws {
        let source = """
        journey
            section Checkout # this is a comment
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.sections[0], "Checkout")
    }

    func test_inlineHashInTask() throws {
        let source = """
        journey
            section Test
            Do work: 5: Me # priority task
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.tasks[0].task, "Do work")
        XCTAssertEqual(diagram.tasks[0].score, 5)
        XCTAssertEqual(diagram.tasks[0].people, ["Me"])
    }

    func test_missingJourneyHeader_throws() {
        let source = """
        flowchart
            section Test
        """
        XCTAssertThrowsError(try parseJourneyDiagram(lines(source))) { error in
            guard case JourneyParserError.invalidHeader = error else {
                XCTFail("Expected invalidHeader, got \(error)")
                return
            }
        }
    }

    func test_trailingEmptyActorWithComma() throws {
        let source = """
        journey
            section Test
            F task: 5: Alice,
        """
        let diagram = try parseJourneyDiagram(lines(source))
        XCTAssertEqual(diagram.tasks[0].people, ["Alice", ""])
    }

    func test_publicParserAcceptsSemicolonSeparatedJourney() throws {
        let graph = try MermaidParser.parse("journey; title T; section S; A: 5: Me")
        guard case let .journey(diagram) = graph.payload else {
            XCTFail("Expected journey payload, got \(graph.payload)")
            return
        }
        XCTAssertEqual(diagram.title, "T")
        XCTAssertEqual(diagram.sections, ["S"])
        XCTAssertEqual(diagram.tasks.first?.task, "A")
        XCTAssertEqual(diagram.tasks.first?.people, ["Me"])
    }

    func test_frontmatterParsesJourneyColorArrays() throws {
        let source = """
        ---
        config:
          journey:
            actorColours: ["#111111", "#222222"]
            sectionFills: ["#aaaaaa", "#bbbbbb"]
            sectionColours: ["#ffffff", "#000000"]
        ---
        journey
            section S
            A: 5: Me
        """
        let graph = try MermaidParser.parse(source)
        guard case let .journey(diagram) = graph.payload else {
            XCTFail("Expected journey payload, got \(graph.payload)")
            return
        }
        XCTAssertEqual(diagram.config?.actorColours, ["#111111", "#222222"])
        XCTAssertEqual(diagram.config?.sectionFills, ["#aaaaaa", "#bbbbbb"])
        XCTAssertEqual(diagram.config?.sectionColours, ["#ffffff", "#000000"])
    }
}

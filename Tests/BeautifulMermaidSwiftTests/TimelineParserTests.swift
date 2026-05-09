import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class TimelineParserTests: XCTestCase {

    private func parse(_ source: String) throws -> TimelineDiagram {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return try parseTimelineDiagram(lines, frontmatter: nil)
    }

    // MARK: - Headers

    func test_header_basic() throws {
        let source = """
        timeline
            title History
            2020 : COVID-19
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.direction, .LR)
        XCTAssertEqual(diagram.diagramTitle, "History")
        XCTAssertEqual(diagram.tasks.count, 1)
        XCTAssertEqual(diagram.tasks[0].text, "2020")
        XCTAssertEqual(diagram.tasks[0].events.count, 1)
        XCTAssertEqual(diagram.tasks[0].events[0].text, "COVID-19")
    }

    func test_header_LR() throws {
        let source = """
        timeline LR
            2020 : COVID-19
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.direction, .LR)
    }

    func test_header_TD() throws {
        let source = """
        timeline TD
            2020 : COVID-19
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.direction, .TD)
    }

    func test_header_caseInsensitive() throws {
        let source = """
        Timeline lr
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.direction, .LR)
    }

    func test_header_invalid_throws() {
        let source = "invalid\n  2020 : Event"
        XCTAssertThrowsError(try parse(source))
    }

    // MARK: - Comments

    func test_fullLinePercentComment() throws {
        let source = """
        timeline
            %% this is a comment
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks.count, 1)
    }

    func test_trailingPercentComment() throws {
        let source = """
        timeline
            2020 : Event %% trailing comment
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks.count, 1)
        XCTAssertEqual(diagram.tasks[0].events[0].text, "Event")
    }

    func test_hashComment() throws {
        let source = """
        timeline
            # this is a comment
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks.count, 1)
    }

    // MARK: - Title

    func test_titleParsing() throws {
        let source = """
        timeline
            title History of Social Media Platform
            2002 : LinkedIn
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.diagramTitle, "History of Social Media Platform")
    }

    func test_titleWithSemicolons() throws {
        let source = """
        timeline
            title History: A Story; of Time
            2002 : LinkedIn
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.diagramTitle, "History: A Story; of Time")
    }

    // MARK: - Accessibility

    func test_accTitle() throws {
        let source = """
        timeline
            accTitle: My Timeline
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.accTitle, "My Timeline")
    }

    func test_accDescr_singleLine() throws {
        let source = """
        timeline
            accDescr: A timeline of events
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.accDescr, "A timeline of events")
    }

    func test_accDescr_multiline() throws {
        let source = """
        timeline
            accDescr {
            A timeline of
            important events
            }
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.accDescr, "A timeline of\nimportant events")
    }

    func test_accDescr_inlineSingleLine() throws {
        let source = """
        timeline
            accDescr { A one-line description }
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.accDescr, "A one-line description")
    }

    func test_bodyDirectives_caseInsensitive() throws {
        let source = """
        timeline
            TITLE Mixed Case Title
            AccTitle: Mixed Case Accessible Title
            AccDescr: Mixed Case Description
            Section Mixed Case Era
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.diagramTitle, "Mixed Case Title")
        XCTAssertEqual(diagram.accTitle, "Mixed Case Accessible Title")
        XCTAssertEqual(diagram.accDescr, "Mixed Case Description")
        XCTAssertEqual(diagram.sections, ["Mixed Case Era"])
        XCTAssertEqual(diagram.tasks[0].section, "Mixed Case Era")
    }

    func test_unfinishedAccDescr_throws() {
        let source = """
        timeline
            accDescr {
            unfinished
        """
        XCTAssertThrowsError(try parse(source))
    }

    // MARK: - Sections

    func test_sections() throws {
        let source = """
        timeline
            section First Era
            2020 : Event A
            section Second Era
            2021 : Event B
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.sections.count, 2)
        XCTAssertEqual(diagram.sections[0], "First Era")
        XCTAssertEqual(diagram.sections[1], "Second Era")
        XCTAssertEqual(diagram.tasks[0].section, "First Era")
        XCTAssertEqual(diagram.tasks[1].section, "Second Era")
    }

    func test_sectionWithBr() throws {
        let source = """
        timeline
            section 2023 Q1 <br> Release Personal Tier
            2024 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.sections[0], "2023 Q1 <br> Release Personal Tier")
    }

    func test_noSection_emptySection() throws {
        let source = """
        timeline
            2020 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.sections.count, 0)
        XCTAssertEqual(diagram.tasks[0].section, "")
    }

    func test_duplicateSections_preserved() throws {
        let source = """
        timeline
            section A
            2020 : E1
            section A
            2021 : E2
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.sections.count, 2)
        XCTAssertEqual(diagram.sections[0], "A")
        XCTAssertEqual(diagram.sections[1], "A")
    }

    // MARK: - Periods/Tasks

    func test_periods_basic() throws {
        let source = """
        timeline
            2002 : LinkedIn
            2004 : Facebook : Google
            2005 : YouTube
            2006 : Twitter
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks.count, 4)
        XCTAssertEqual(diagram.tasks[0].text, "2002")
        XCTAssertEqual(diagram.tasks[0].events.count, 1)
        XCTAssertEqual(diagram.tasks[1].text, "2004")
        XCTAssertEqual(diagram.tasks[1].events.count, 2)
        XCTAssertEqual(diagram.tasks[1].events[0].text, "Facebook")
        XCTAssertEqual(diagram.tasks[1].events[1].text, "Google")
    }

    func test_periodWithNoEvents() throws {
        let source = """
        timeline
            2020
            2021 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks.count, 2)
        XCTAssertEqual(diagram.tasks[0].events.count, 0)
        XCTAssertEqual(diagram.tasks[1].events.count, 1)
    }

    func test_multipleInlineEvents() throws {
        let source = """
        timeline
            2004 : Facebook : Google : Yahoo
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].events.count, 3)
        XCTAssertEqual(diagram.tasks[0].events[0].text, "Facebook")
        XCTAssertEqual(diagram.tasks[0].events[1].text, "Google")
        XCTAssertEqual(diagram.tasks[0].events[2].text, "Yahoo")
    }

    // MARK: - Continuation Events

    func test_continuationEvent() throws {
        let source = """
        timeline
            2020 : Event A
                : Event B
                : Event C
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks.count, 1)
        XCTAssertEqual(diagram.tasks[0].events.count, 3)
        XCTAssertEqual(diagram.tasks[0].events[0].text, "Event A")
        XCTAssertEqual(diagram.tasks[0].events[1].text, "Event B")
        XCTAssertEqual(diagram.tasks[0].events[2].text, "Event C")
    }

    func test_continuationEvent_multipleOnSameLine() throws {
        let source = """
        timeline
            2020 : Event A
                : Event B : Event C
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].events.count, 3)
        XCTAssertEqual(diagram.tasks[0].events[2].text, "Event C")
    }

    func test_strayContinuation_throws() {
        let source = """
        timeline
                : stray event
        """
        XCTAssertThrowsError(try parse(source))
    }

    // MARK: - Text edge cases

    func test_semicolonsInText() throws {
        let source = """
        timeline
            section Part 1; Part 2
            2020 : Event A; sub-event B
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.sections[0], "Part 1; Part 2")
        XCTAssertEqual(diagram.tasks[0].events[0].text, "Event A; sub-event B")
    }

    func test_hashtagsInText() throws {
        let source = """
        timeline
            section #Important Era
            2020 : #milestone event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.sections[0], "#Important Era")
        XCTAssertEqual(diagram.tasks[0].events[0].text, "#milestone event")
    }

    func test_markdownLinksInText() throws {
        let source = """
        timeline
            section [Era](http://example.com)
            2020 : [event1](http://example.com)
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.sections[0], "[Era](http://example.com)")
        XCTAssertEqual(diagram.tasks[0].events[0].text, "[event1](http://example.com)")
    }

    func test_urlsWithColons_preservedAsText() throws {
        let source = """
        timeline
            2020 : Visit http://example.com for details
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].events[0].text, "Visit http://example.com for details")
    }

    func test_brTags() throws {
        let source = """
        timeline
            section Age of<br>Industrialization
            1760 : James<br>Watt
                : Steam<br>Engine
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.sections[0], "Age of<br>Industrialization")
        XCTAssertEqual(diagram.tasks[0].text, "1760")
        XCTAssertEqual(diagram.tasks[0].events[0].text, "James<br>Watt")
    }

    func test_brTags_selfClosing() throws {
        let source = """
        timeline
            2020 : Event<br/>continued
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].events[0].text, "Event<br/>continued")
    }

    // MARK: - Blank Lines

    func test_blankLines_skipped() throws {
        let source = """
        timeline

            2020 : Event A

            2021 : Event B

        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks.count, 2)
    }

    func test_leadingWhitespaceInLines() throws {
        let source = """
        timeline
              2020 : Event A
              2021 : Event B
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks.count, 2)
    }

    // MARK: - Source Order

    func test_sourceOrder_preserved() throws {
        let source = """
        timeline
            2020 : Event A
            2010 : Event B
            2015 : Event C
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].text, "2020")
        XCTAssertEqual(diagram.tasks[1].text, "2010")
        XCTAssertEqual(diagram.tasks[2].text, "2015")
    }

    // MARK: - Task IDs

    func test_taskIds_monotonicGlobal() throws {
        let source = """
        timeline
            section A
            2020 : Event
            section B
            2021 : Event
            2022 : Event
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].id, 0)
        XCTAssertEqual(diagram.tasks[1].id, 1)
        XCTAssertEqual(diagram.tasks[2].id, 2)
    }

    // MARK: - Event IDs

    func test_eventIds_perTask() throws {
        let source = """
        timeline
            2020 : E1 : E2 : E3
            2021 : E4
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].events.count, 3)
        XCTAssertEqual(diagram.tasks[0].events[0].id, 0)
        XCTAssertEqual(diagram.tasks[0].events[1].id, 1)
        XCTAssertEqual(diagram.tasks[0].events[2].id, 2)
        XCTAssertEqual(diagram.tasks[1].events[0].id, 0)
    }

    // MARK: - Colons not followed by whitespace

    func test_colonsNotFollowedByWhitespace_literal() throws {
        let source = """
        timeline
            2020 : Visit http://example.com for info
        """
        let diagram = try parse(source)
        XCTAssertEqual(diagram.tasks[0].events[0].text, "Visit http://example.com for info")
    }
}

import Testing
import Foundation
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

@Suite("Gantt Parser")
struct GanttParserTests {

    @Test("Basic diagram with two sections")
    func basicDocument() throws {
        let source = [
            "gantt",
            "title A Gantt Diagram",
            "dateFormat YYYY-MM-DD",
            "section Section",
            "A task       :a1, 2014-01-01, 30d",
            "Another task :after a1, 20d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.title == "A Gantt Diagram")
        #expect(diagram.dateFormat == "YYYY-MM-DD")
        #expect(diagram.sections.count == 1)
        #expect(diagram.sections.first?.name == "Section")
        #expect(diagram.tasks.count == 2)
        #expect(diagram.tasks[0].task == "A task")
        #expect(diagram.tasks[0].id == "a1")
        #expect(diagram.tasks[1].task == "Another task")
        #expect(diagram.tasks[1].id.hasPrefix("task"))
    }

    @Test("dateFormat parsing")
    func dateFormat() throws {
        let source = ["gantt", "dateFormat YYYY-MM-DD"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.dateFormat == "YYYY-MM-DD")
    }

    @Test("inclusiveEndDates flag")
    func inclusiveEndDates() throws {
        let source = ["gantt", "inclusiveEndDates"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.inclusiveEndDates == true)
    }

    @Test("title parsing")
    func diagramTitle() throws {
        let source = ["gantt", "title My Gantt"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.title == "My Gantt")
    }

    @Test("Title beginning with semicolon")
    func titleWithSemicolon() throws {
        let source = ["gantt", "title ;My Title"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.title == ";My Title")
    }

    @Test("Title beginning with hash")
    func titleWithHash() throws {
        let source = ["gantt", "title #My Title"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.title == "#My Title")
    }

    @Test("section parsing")
    func sectionStatement() throws {
        let source = ["gantt", "section My Section"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.sections.count == 1)
        #expect(diagram.sections[0].name == "My Section")
    }

    @Test("Section title with semicolon")
    func sectionWithSemicolon() throws {
        let source = ["gantt", "section ;My Section"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.sections[0].name == ";My Section")
    }

    @Test("Section title with <br>")
    func sectionWithBrTag() throws {
        let source = ["gantt", "section First<br>Second"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.sections[0].name == "First<br>Second")
    }

    @Test("excludes parsing")
    func excludesStatement() throws {
        let source = ["gantt", "excludes weekends, 2024-01-01"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.excludes.contains("weekends"))
        #expect(diagram.excludes.contains("2024-01-01"))
    }

    @Test("includes parsing")
    func includesStatement() throws {
        let source = ["gantt", "includes 2024-01-01"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.includes.contains("2024-01-01"))
    }

    @Test("todayMarker parsing")
    func todayMarker() throws {
        let source = ["gantt", "todayMarker off"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.todayMarker == "off")
    }

    @Test("todayMarker with style")
    func todayMarkerStyle() throws {
        let source = ["gantt", "todayMarker stroke-width:2px,stroke:#00f"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.todayMarker == "stroke-width:2px,stroke:#00f")
    }

    @Test("weekday parsing")
    func weekdayStatement() throws {
        let source = ["gantt", "weekday monday"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.weekday == "monday")
    }

    @Test("weekend parsing")
    func weekendStatement() throws {
        let source = ["gantt", "weekend friday"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.weekend == "friday")
    }

    @Test("Default weekend saturday")
    func defaultWeekend() throws {
        let source = ["gantt"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.weekend == "saturday")
    }

    @Test("topAxis flag")
    func topAxisFlag() throws {
        let source = ["gantt", "topAxis"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.topAxis == true)
    }

    @Test("axisFormat parsing")
    func axisFormat() throws {
        let source = ["gantt", "axisFormat %Y-%m-%d"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.axisFormat == "%Y-%m-%d")
    }

    @Test("tickInterval parsing")
    func tickInterval() throws {
        let source = ["gantt", "tickInterval 1day"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tickInterval == "1day")
    }

    @Test("Task with explicit dates and ID")
    func taskWithExplicitDatesAndId() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "My Task :t1, 2024-01-01, 2024-01-10",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks.count == 1)
        #expect(diagram.tasks[0].id == "t1")
        #expect(diagram.tasks[0].task == "My Task")
        #expect(diagram.tasks[0].section == "S1")
    }

    @Test("Task with start date and duration (no ID)")
    func taskWithStartAndDurationNoId() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "My Task :2024-01-01, 10d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks.count == 1)
        #expect(diagram.tasks[0].id.hasPrefix("task"))
    }

    @Test("Task with single duration (no ID)")
    func taskWithSingleDurationNoId() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "My Task :10d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks.count == 1)
        #expect(diagram.tasks[0].id.hasPrefix("task"))
    }

    @Test("Task with active tag")
    func taskWithActiveTag() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "My Task :active, t1, 2024-01-01, 10d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].tags.contains(.active))
    }

    @Test("Task with done tag")
    func taskWithDoneTag() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "My Task :done, t1, 2024-01-01, 10d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].tags.contains(.done))
    }

    @Test("Task with crit tag")
    func taskWithCritTag() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "My Task :crit, t1, 2024-01-01, 10d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].tags.contains(.crit))
    }

    @Test("Task with milestone tag")
    func taskWithMilestoneTag() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "My Task :milestone, t1, 2024-01-01, 0d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].tags.contains(.milestone))
    }

    @Test("Task with vert tag")
    func taskWithVertTag() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "My Task :vert, t1, 2024-01-01, 0d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].tags.contains(.vert))
    }

    @Test("Task with combined tags")
    func taskWithCombinedTags() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "My Task :done, crit, t1, 2024-01-01, 10d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].tags.contains(.done))
        #expect(diagram.tasks[0].tags.contains(.crit))
    }

    @Test("Task with after dependency")
    func afterDependency() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 10d",
            "Task 2 :after t1, 5d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks.count == 2)
        #expect(diagram.tasks[1].startTime >= diagram.tasks[0].endTime)
    }

    @Test("auto-generated IDs")
    func autoGeneratedIds() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :2024-01-01, 10d",
            "Task 2 :2024-01-15, 5d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].id.hasPrefix("task"))
        #expect(diagram.tasks[1].id.hasPrefix("task"))
    }

    @Test("Multiple sections")
    func multipleSections() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section Planning",
            "Task A :a, 2024-01-01, 5d",
            "section Development",
            "Task B :b, 2024-01-06, 10d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.sections.count == 2)
        #expect(diagram.tasks[0].section == "Planning")
        #expect(diagram.tasks[1].section == "Development")
    }

    @Test("accTitle parsing")
    func accTitle() throws {
        let source = ["gantt", "accTitle: My Accessible Title"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.accTitle == "My Accessible Title")
    }

    @Test("Single-line accDescr")
    func accDescrSingleLine() throws {
        let source = ["gantt", "accDescr: A simple description"]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.accDescr == "A simple description")
    }

    @Test("Multiline accDescr")
    func accDescrMultiline() throws {
        let source = [
            "gantt",
            "accDescr: {",
            "  A multiline",
            "  description",
            "}",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.accDescr != nil)
        #expect(diagram.accDescr!.contains("A multiline"))
        #expect(diagram.accDescr!.contains("description"))
    }

    @Test("Click href statement")
    func clickHref() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 10d",
            "click t1 href \"https://example.com\"",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].classes.contains("clickable"))
    }

    @Test("Click call statement")
    func clickCall() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 10d",
            "click t1 call myCallback()",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].classes.contains("clickable"))
    }

    @Test("Task label beginning with semicolon")
    func taskLabelWithSemicolon() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            ";Special Task :t1, 2024-01-01, 10d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].task == ";Special Task")
    }

    @Test("Task label beginning with hash")
    func taskLabelWithHash() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "#Task :t1, 2024-01-01, 10d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].task == "#Task")
    }

    @Test("Duration parsing - days")
    func durationDays() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 10d",
        ]
        let diagram = try parseGanttDiagram(source)
        let cal = Calendar.current
        let expected = cal.date(byAdding: .day, value: 10, to: _date(2024, 1, 1))!
        #expect(abs(diagram.tasks[0].endTime.timeIntervalSince(expected)) < 60)
    }

    @Test("Duration parsing - weeks")
    func durationWeeks() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 2w",
        ]
        let diagram = try parseGanttDiagram(source)
        let cal = Calendar.current
        let expected = cal.date(byAdding: .day, value: 14, to: _date(2024, 1, 1))!
        #expect(abs(diagram.tasks[0].endTime.timeIntervalSince(expected)) < 60)
    }

    @Test("Duration parsing - months")
    func durationMonths() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 1M",
        ]
        let diagram = try parseGanttDiagram(source)
        let cal = Calendar.current
        let expected = cal.date(byAdding: .month, value: 1, to: _date(2024, 1, 1))!
        #expect(abs(diagram.tasks[0].endTime.timeIntervalSince(expected)) < 60)
    }

    @Test("Duration parsing - hours")
    func durationHours() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 24h",
        ]
        let diagram = try parseGanttDiagram(source)
        let expected = _date(2024, 1, 1).addingTimeInterval(86400)
        #expect(abs(diagram.tasks[0].endTime.timeIntervalSince(expected)) < 60)
    }

    @Test("Duration parsing - minutes")
    func durationMinutes() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 60m",
        ]
        let diagram = try parseGanttDiagram(source)
        let expected = _date(2024, 1, 1).addingTimeInterval(3600)
        #expect(abs(diagram.tasks[0].endTime.timeIntervalSince(expected)) < 60)
    }

    @Test("Duration parsing - decimal days")
    func durationDecimalDays() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 1.5d",
        ]
        let diagram = try parseGanttDiagram(source)
        let cal = Calendar.current
        let expected = cal.date(byAdding: .day, value: 1, to: _date(2024, 1, 1))!
        let expectedEnd = expected.addingTimeInterval(43200)
        #expect(abs(diagram.tasks[0].endTime.timeIntervalSince(expectedEnd)) < 60)
    }

    @Test("Duration parsing - invalid token defaults to zero")
    func invalidDurationToken() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 1f",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].endTime == diagram.tasks[0].startTime)
    }

    @Test("Invalid header throws error")
    func invalidHeader() {
        #expect(throws: GanttParserError.self) {
            _ = try parseGanttDiagram(["notgantt", "some content"])
        }
    }

    @Test("Comments are skipped")
    func commentsSkipped() throws {
        let source = [
            "gantt",
            "%% This is a comment",
            "title My Title",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.title == "My Title")
    }

    @Test("Until dependency")
    func untilDependency() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 20d",
            "Task 2 :t2, 2024-01-01, until t1",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks.count == 2)
    }

    @Test("Forward after dependency resolves after later task compiles")
    func forwardAfterDependency() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section sec1",
            "Task 1 :id1, 2013-01-01, 2w",
            "Task 2 :id2, after id3, 1d",
            "section sec2",
            "Task 3 :id3, after id1, 2d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[1].startTime == _date(2013, 1, 17))
        #expect(diagram.tasks[1].endTime == _date(2013, 1, 18))
    }

    @Test("Forward until dependency resolves after later task compiles")
    func forwardUntilDependency() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section sec1",
            "Task 1 :id1, 2013-01-01, until id3",
            "section sec2",
            "Task 2 :id2, 2013-01-10, until id3",
            "Task 3 :id3, 2013-02-01, 2d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].endTime == _date(2013, 2, 1))
        #expect(diagram.tasks[1].endTime == _date(2013, 2, 1))
    }

    @Test("Multiple after dependencies use latest referenced end")
    func multipleAfterDependenciesUseLatestEnd() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section sec1",
            "Task 1 :id1, after id2 id3 id4, 1d",
            "Task 2 :id2, 2013-01-01, 1d",
            "Task 3 :id3, 2013-02-01, 3d",
            "Task 4 :id4, 2013-02-01, 2d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].startTime == _date(2013, 2, 4))
        #expect(diagram.tasks[0].endTime == _date(2013, 2, 5))
    }

    @Test("Multiple until dependencies use earliest referenced start")
    func multipleUntilDependenciesUseEarliestStart() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section sec1",
            "Task 1 :id1, 2013-01-01, until id2 id3 id4",
            "Task 2 :id2, 2013-01-11, 1d",
            "Task 3 :id3, 2013-02-10, 1d",
            "Task 4 :id4, 2013-02-12, 1d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].endTime == _date(2013, 1, 11))
    }

    @Test("Weekend friday exclusion extends task and preserves render end")
    func weekendFridayExclusionExtendsTask() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "excludes weekends",
            "weekend friday",
            "section Work",
            "Task 1 :id1, 2024-02-28, 3d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].endTime == _date(2024, 3, 4))
        #expect(diagram.tasks[0].renderEndTime == _date(2024, 3, 4))
    }

    @Test("Excluded days preserve Mermaid renderEndTime")
    func excludedDaysRenderEndTime() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "excludes weekends 2019-02-06,friday",
            "section Work",
            "Task 1 :id1, 2019-02-01, 1d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].endTime == _date(2019, 2, 5))
        #expect(diagram.tasks[0].renderEndTime == _date(2019, 2, 5))
    }

    @Test("Click href and callback metadata is retained")
    func clickMetadataRetained() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 10d",
            "click t1 href \"https://example.com\" call myCallback(\"a,b\", c)",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.links["t1"] == "https://example.com")
        #expect(diagram.tasks[0].link == "https://example.com")
        #expect(diagram.tasks[0].callbackName == "myCallback")
        #expect(diagram.tasks[0].callbackArgs == ["a,b", "c"])
        #expect(diagram.tasks[0].classes.contains("clickable"))
    }

    @Test("Click callback without args defaults to task id")
    func clickCallbackDefaultArgs() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 10d",
            "click t1 call myCallback()",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].callbackName == "myCallback")
        #expect(diagram.tasks[0].callbackArgs == ["t1"])
    }

    @Test("Multiline accDescr without colon")
    func accDescrMultilineWithoutColon() throws {
        let source = [
            "gantt",
            "accDescr {",
            "  A multiline",
            "  description",
            "}",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.accDescr?.contains("A multiline") == true)
        #expect(diagram.accDescr?.contains("description") == true)
    }

    @Test("Excludes exact-match formatted dates extend task end")
    func excludesExactMatchFormattedDate() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "excludes 2024-01-01",
            "section S1",
            "Task 1 :t1, 2024-01-01, 1d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].endTime == _date(2024, 1, 3))
    }

    @Test("Includes overrides exclude with formatted date")
    func includesOverridesExclude() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "excludes weekends",
            "includes 2024-01-06",
            "section S1",
            "Task 1 :t1, 2024-01-05, 1d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].endTime == _date(2024, 1, 6))
    }

    @Test("Excludes day name matches lowercased weekday")
    func excludesDayNameLowercased() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "excludes friday weekends",
            "weekend saturday",
            "section S1",
            "Task 1 :t1, 2023-06-01, 3d",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].endTime == _date(2023, 6, 7))
    }

    @Test("Click href blocks javascript: URLs")
    func clickBlocksJavascriptUrl() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 10d",
            "click t1 href \"javascript:alert(1)\"",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].link == nil)
    }

    @Test("Click href blocks vbscript: URLs")
    func clickBlocksVbscriptUrl() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 10d",
            "click t1 href \"vbscript:msgbox(1)\"",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].link == nil)
    }

    @Test("Click href blocks file: URLs")
    func clickBlocksFileUrl() throws {
        let source = [
            "gantt",
            "dateFormat YYYY-MM-DD",
            "section S1",
            "Task 1 :t1, 2024-01-01, 10d",
            "click t1 href \"file:///etc/hosts\"",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.tasks[0].link == nil)
    }

    @Test("todayMarker commas converted to semicolons")
    func todayMarkerCommasConvertedToSemicolons() throws {
        let source = [
            "gantt",
            "todayMarker stroke-width:2px,stroke:#00f,stroke-dasharray:4",
        ]
        let diagram = try parseGanttDiagram(source)
        #expect(diagram.todayMarker == "stroke-width:2px,stroke:#00f,stroke-dasharray:4")
    }
}

private func _date(_ y: Int, _ m: Int, _ d: Int) -> Date {
    let comps = DateComponents(year: y, month: m, day: d)
    return Calendar.current.date(from: comps)!
}

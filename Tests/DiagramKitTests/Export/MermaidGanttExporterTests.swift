import Testing
import Foundation
import DiagramKitModel
import DiagramKitMermaid
import DiagramKit

@Suite struct MermaidGanttExporterTests {

    // MARK: - Header

    @Test("Empty gantt diagram emits header + dateFormat")
    func emptyDiagram() throws {
        let doc = DiagramDocument(payload: .gantt(GanttDiagram()))
        let result = try MermaidExporter().export(doc)

        #expect(result.source.contains("gantt"))
        #expect(result.source.contains("dateFormat YYYY-MM-DD"))
    }

    // MARK: - Title

    @Test("Title and accessibility fields appear in source")
    func titleAndAccessibility() throws {
        let model = GanttDiagram(
            title: "Q1 Roadmap",
            accTitle: "Roadmap chart",
            accDescr: "Quarterly initiatives"
        )
        let doc = DiagramDocument(payload: .gantt(model))
        let result = try MermaidExporter().export(doc)

        #expect(result.source.contains("title Q1 Roadmap"))
        #expect(result.source.contains("accTitle: Roadmap chart"))
        #expect(result.source.contains("accDescr: Quarterly initiatives"))
    }

    // MARK: - Sections + tasks round-trip

    @Test("Sections + tasks round-trip through MermaidImporter")
    func sectionsAndTasksRoundTrip() throws {
        let start = isoDate("2024-01-01")
        let end = isoDate("2024-01-10")
        let model = GanttDiagram(
            sections: [GanttSection(name: "Planning", index: 0)],
            tasks: [
                GanttTask(
                    id: "r1",
                    task: "Research",
                    section: "Planning",
                    startTime: start,
                    endTime: end
                )
            ]
        )
        let doc = DiagramDocument(payload: .gantt(model))
        let result = try MermaidExporter().export(doc)

        #expect(result.source.contains("section Planning"))
        #expect(result.source.contains("Research :"))
        #expect(result.source.contains("r1, 2024-01-01, 2024-01-10"))

        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .gantt(let reparsedModel) = reparsed.payload else {
            Issue.record("Expected gantt payload")
            return
        }
        #expect(reparsedModel.tasks.count == 1)
        #expect(reparsedModel.tasks.first?.id == "r1")
        #expect(reparsedModel.tasks.first?.task == "Research")
        #expect(reparsedModel.tasks.first?.section == "Planning")
    }

    // MARK: - Tags

    @Test("Tags round-trip in parser-recognized order")
    func tagsRoundTrip() throws {
        let model = GanttDiagram(
            sections: [GanttSection(name: "Build", index: 0)],
            tasks: [
                GanttTask(
                    id: "t1",
                    task: "Spike",
                    section: "Build",
                    tags: [.done, .crit, .active],
                    startTime: isoDate("2024-02-01"),
                    endTime: isoDate("2024-02-05")
                )
            ]
        )
        let result = try MermaidExporter().export(DiagramDocument(payload: .gantt(model)))
        // Parser-friendly ordering: done, active, crit (tag emission
        // order is fixed in MermaidGanttExport).
        #expect(result.source.contains("done, active, crit, t1, 2024-02-01, 2024-02-05"))

        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .gantt(let reparsedModel) = reparsed.payload,
              let task = reparsedModel.tasks.first else {
            Issue.record("Expected gantt task")
            return
        }
        #expect(task.tags.contains(.done))
        #expect(task.tags.contains(.crit))
        #expect(task.tags.contains(.active))
    }

    // MARK: - Multiple sections preserved in order

    @Test("Multiple sections preserved across re-parse")
    func multipleSectionsRoundTrip() throws {
        let model = GanttDiagram(
            sections: [
                GanttSection(name: "Plan", index: 0),
                GanttSection(name: "Build", index: 1)
            ],
            tasks: [
                GanttTask(
                    id: "p1", task: "Spec",
                    section: "Plan",
                    startTime: isoDate("2024-01-01"), endTime: isoDate("2024-01-05")
                ),
                GanttTask(
                    id: "b1", task: "Code",
                    section: "Build",
                    startTime: isoDate("2024-01-06"), endTime: isoDate("2024-01-15")
                )
            ]
        )
        let result = try MermaidExporter().export(DiagramDocument(payload: .gantt(model)))

        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .gantt(let reparsedModel) = reparsed.payload else {
            Issue.record("Expected gantt payload")
            return
        }
        #expect(reparsedModel.sections.count == 2)
        #expect(reparsedModel.tasks.map(\.id) == ["p1", "b1"])
        #expect(reparsedModel.tasks.map(\.section) == ["Plan", "Build"])
    }

    // MARK: - Click links

    @Test("Click href emits a click statement and round-trips the link")
    func clickHrefRoundTrip() throws {
        var model = GanttDiagram(
            sections: [GanttSection(name: "S", index: 0)],
            tasks: [
                GanttTask(
                    id: "t1", task: "Task",
                    section: "S",
                    startTime: isoDate("2024-03-01"), endTime: isoDate("2024-03-02"),
                    link: "https://example.com/t1"
                )
            ]
        )
        model.links = ["t1": "https://example.com/t1"]

        let result = try MermaidExporter().export(DiagramDocument(payload: .gantt(model)))
        #expect(result.source.contains("click t1 href \"https://example.com/t1\""))

        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .gantt(let reparsedModel) = reparsed.payload else {
            Issue.record("Expected gantt payload")
            return
        }
        #expect(reparsedModel.links["t1"] == "https://example.com/t1")
    }

    // MARK: - Inclusive end-date offset

    @Test("inclusiveEndDates compensated so end dates round-trip")
    func inclusiveEndDatesOffset() throws {
        let originalEnd = isoDate("2024-04-10")
        let model = GanttDiagram(
            inclusiveEndDates: true,
            sections: [GanttSection(name: "S", index: 0)],
            tasks: [
                GanttTask(
                    id: "t1", task: "Task",
                    section: "S",
                    startTime: isoDate("2024-04-01"),
                    endTime: originalEnd
                )
            ]
        )
        let result = try MermaidExporter().export(DiagramDocument(payload: .gantt(model)))
        #expect(result.source.contains("inclusiveEndDates"))

        let reparsed = try MermaidImporter().parse(result.source).document
        guard case .gantt(let reparsedModel) = reparsed.payload,
              let task = reparsedModel.tasks.first else {
            Issue.record("Expected gantt task")
            return
        }
        // Re-parsed endTime should match the original (parser adds +1
        // day for inclusive, exporter subtracted 1 day to compensate).
        let cal = Calendar(identifier: .gregorian)
        let originalDay = cal.dateComponents([.year, .month, .day], from: originalEnd)
        let parsedDay = cal.dateComponents([.year, .month, .day], from: task.endTime)
        #expect(originalDay.year == parsedDay.year)
        #expect(originalDay.month == parsedDay.month)
        #expect(originalDay.day == parsedDay.day)
    }

    // MARK: - Tasks without a section

    @Test("Tasks with no section emit before any section header")
    func unsectionedTasks() throws {
        let model = GanttDiagram(
            tasks: [
                GanttTask(
                    id: "t1", task: "Bare",
                    section: "",
                    startTime: isoDate("2024-05-01"), endTime: isoDate("2024-05-02")
                )
            ]
        )
        let result = try MermaidExporter().export(DiagramDocument(payload: .gantt(model)))
        #expect(!result.source.contains("section "))
        #expect(result.source.contains("Bare :"))
    }

    // MARK: - Helpers

    private func isoDate(_ str: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.date(from: str)!
    }
}

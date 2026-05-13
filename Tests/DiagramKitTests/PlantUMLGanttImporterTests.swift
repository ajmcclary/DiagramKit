import Foundation
import Testing
import DiagramKitModel
import DiagramKitImport
import DiagramKitPlantUML

@Suite struct PlantUMLGanttImporterTests {

    @Test("Parses a basic gantt with project start date and two durations")
    func basicGantt() throws {
        let source = """
        @startgantt
        project starts 2024-01-15
        [Design] lasts 10 days
        [Build] lasts 20 days
        @endgantt
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .gantt(let model) = result.document.payload else {
            Issue.record("Expected gantt payload, got \(result.document.payload)")
            return
        }
        #expect(model.tasks.count == 2)
        let design = model.tasks.first(where: { $0.task == "Design" })
        let build = model.tasks.first(where: { $0.task == "Build" })
        #expect(design != nil)
        #expect(build != nil)
        let calendar = utcCalendar()
        let designStart = calendar.dateComponents([.year, .month, .day], from: design!.startTime)
        #expect(designStart.year == 2024)
        #expect(designStart.month == 1)
        #expect(designStart.day == 15)
        // 10-day duration → ends 10 days later
        let designEnd = calendar.dateComponents([.year, .month, .day], from: design!.endTime)
        #expect(designEnd.day == 25)
    }

    @Test("[Task] starts at [Other]'s end resolves sequentially")
    func startsAtPrior() throws {
        let source = """
        @startgantt
        project starts 2024-01-15
        [A] lasts 5 days
        [B] starts at [A]'s end
        [B] lasts 5 days
        @endgantt
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .gantt(let model) = result.document.payload else {
            Issue.record("Expected gantt payload"); return
        }
        let a = model.tasks.first { $0.task == "A" }!
        let b = model.tasks.first { $0.task == "B" }!
        let calendar = utcCalendar()
        #expect(calendar.dateComponents([.day], from: a.endTime, to: b.startTime).day == 0)
    }

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }
}

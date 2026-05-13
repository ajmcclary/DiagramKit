import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Emits PlantUML gantt source from a `GanttDiagram`.
enum PlantUMLGanttExport {

    static func emit(_ model: GanttDiagram) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        lines.append("@startgantt")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Emit `project starts D` for the earliest task start time.
        if let firstStart = model.tasks.map(\.startTime).min() {
            lines.append("project starts \(isoString(firstStart, calendar: calendar))")
        }

        // Emit each task as `[Name] starts D` + `[Name] ends D`.
        // Using explicit dates keeps semantics simple and avoids
        // depending on parse order when re-reading.
        for task in model.tasks {
            lines.append("[\(task.task)] starts \(isoString(task.startTime, calendar: calendar))")
            lines.append("[\(task.task)] ends \(isoString(task.endTime, calendar: calendar))")
        }

        lines.append("@endgantt")

        return DiagramExportResult(
            source: lines.joined(separator: "\n"),
            diagnostics: diagnostics
        )
    }

    private static func isoString(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}

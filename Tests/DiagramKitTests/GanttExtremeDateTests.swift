import Foundation
import Testing
import DiagramKit

// Gantt layout used to loop forever when `Calendar` could not step past a
// date, and produced one axis tick per year however long the chart, so a
// long task made a 50–100 MB SVG.

@Suite("Gantt layout with extreme dates and durations")
struct GanttExtremeDateTests {

    @Test("a duration too large for a date throws or renders small")
    func overflowingDuration() async throws {
        let source = "gantt\n  dateFormat YYYY-MM-DD\n  t1: 2024-01-01, 99999999999999999999d\n"
        let svg = try await onDiagramWorker { try? DiagramPipeline.renderSVG(source: source) }
        #expect((svg?.utf8.count ?? 0) < 2_000_000)
    }

    @Test("an exclusion walk past the calendar's range ends")
    func calendarLimit() async throws {
        let source = "gantt\n  dateFormat YYYY-MM-DD\n  excludes weekends\n  Task :t1, 1000000-01-01, 14d\n"
        _ = try await onDiagramWorker { try? DiagramPipeline.renderSVG(source: source) }
    }

    @Test("a very long task renders a small SVG", arguments: [
        "gantt\n  dateFormat YYYY-MM-DD\n  Task :t1, 2024-01-01, 100000000d\n",
        "gantt\n  dateFormat YYYY-MM-DD\n  Task :t1, 2024-01-01, 3650000d\n",
        "@startgantt\n[Only] lasts 100000000 days\n@endgantt\n",
    ])
    func longTask(_ source: String) async throws {
        let svg = try await onDiagramWorker { try DiagramPipeline.renderSVG(source: source) }
        #expect(svg.utf8.count < 2_000_000, "\(svg.utf8.count) bytes")
    }
}

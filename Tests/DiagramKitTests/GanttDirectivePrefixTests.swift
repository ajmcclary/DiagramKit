import Foundation
import Testing
@testable import DiagramKit
@testable import DiagramKitModel

/// A task whose name merely starts with a directive keyword is a task.
@Suite("Gantt tasks named like directives")
struct GanttDirectivePrefixTests {

    private static func gantt(_ source: String) async throws -> GanttDiagram {
        let document = try await DiagramEngine.parse(source)
        guard case .gantt(let diagram) = document.payload else {
            Issue.record("expected a gantt chart")
            throw CancellationError()
        }
        return diagram
    }

    @Test("Weekend/Weekday tasks are tasks; Includes testing is the includes directive, as upstream")
    func reviewExample() async throws {
        let diagram = try await Self.gantt("""
        gantt
        dateFormat YYYY-MM-DD
        section S
        Prep : a1, 2024-01-01, 3d
        Weekend deploy : a2, after a1, 2d
        Weekday support : a3, after a2, 2d
        Includes testing : a4, after a3, 1d
        Done : a5, after a4, 1d
        """)
        #expect(diagram.tasks.map(\.task) == ["Prep", "Weekend deploy", "Weekday support", "Done"])
        #expect(diagram.weekday == "sunday")
        #expect(diagram.weekend == "saturday")
    }

    @Test("directives need a token boundary after the keyword")
    func keywordBoundary() async throws {
        let diagram = try await Self.gantt("""
        gantt
        dateFormat YYYY-MM-DD
        Topaxis review : t1, 2024-01-01, 1d
        Excludesfoo : t2, 2024-01-02, 1d
        """)
        #expect(diagram.tasks.map(\.task) == ["Topaxis review", "Excludesfoo"])
        #expect(diagram.topAxis == false)
        #expect(diagram.excludes.isEmpty)
    }

    @Test("real directives still apply")
    func directivesStillApply() async throws {
        let diagram = try await Self.gantt("""
        gantt
        dateFormat YYYY-MM-DD
        axisFormat %m/%d
        weekday monday
        weekend friday
        excludes weekends
        topAxis
        Task : t1, 2024-01-01, 1d
        """)
        #expect(diagram.axisFormat == "%m/%d")
        #expect(diagram.weekday == "monday")
        #expect(diagram.weekend == "friday")
        #expect(diagram.excludes == ["weekends"])
        #expect(diagram.topAxis)
        #expect(diagram.tasks.count == 1)
    }
}

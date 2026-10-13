import Testing
import Foundation
import DiagramKit

@Suite struct GanttAsciiRendererTests {

    @Test("Gantt ASCII renderer emits title and task rows")
    func basicGantt() throws {
        // Pin the today-marker so the layout is date-independent; see
        // `GanttTodayEnv` for why the variable is never unset here.
        GanttTodayEnv.set()

        let source = """
        gantt
            title Project Plan
            dateFormat YYYY-MM-DD
            section A
                Task1 :a1, 2024-06-10, 5d
                Task2 :after a1, 5d
        """
        let output = try DiagramPipeline.renderASCII(source: source).text
        #expect(output.contains("Project Plan"))
        #expect(output.contains("Task1"))
        #expect(output.contains("Task2"))
    }
}

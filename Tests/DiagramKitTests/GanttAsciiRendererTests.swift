import Testing
import Foundation
import DiagramKit

@Suite struct GanttAsciiRendererTests {

    @Test("Gantt ASCII renderer emits title and task rows")
    func basicGantt() throws {
        setenv("DIAGRAMKIT_GANTT_TODAY", "2024-06-15", 1)
        defer { unsetenv("DIAGRAMKIT_GANTT_TODAY") }

        let source = """
        gantt
            title Project Plan
            dateFormat YYYY-MM-DD
            section A
                Task1 :a1, 2024-06-10, 5d
                Task2 :after a1, 5d
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("Project Plan"))
        #expect(output.contains("Task1"))
        #expect(output.contains("Task2"))
    }
}

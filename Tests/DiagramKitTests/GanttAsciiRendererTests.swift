import Testing
import Foundation
import DiagramKit

@Suite struct GanttAsciiRendererTests {

    @Test("Gantt ASCII renderer emits title and task rows")
    func basicGantt() throws {
        // Both `GanttAsciiRendererTests` and `CorpusSnapshotTests`
        // pin `DIAGRAMKIT_GANTT_TODAY` to the same value. We set
        // without `defer { unsetenv }` so parallel `swift-testing` runs
        // can't race the unset against the corpus reader.
        setenv("DIAGRAMKIT_GANTT_TODAY", "2024-06-15", 1)

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

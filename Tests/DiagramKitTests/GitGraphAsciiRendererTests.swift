import Testing
import DiagramKit

@Suite struct GitGraphAsciiRendererTests {

    @Test("GitGraph ASCII renderer emits commits with messages")
    func basicGitGraph() throws {
        let source = """
        gitGraph
            commit id: "init"
            commit id: "feat"
        """
        let output = try DiagramPipeline.renderASCII(source: source).text
        #expect(output.contains("init"))
        #expect(output.contains("feat"))
        #expect(output.contains("*"))
    }
}

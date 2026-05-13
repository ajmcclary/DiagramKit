import Testing
import DiagramKit

@Suite struct MindmapAsciiRendererTests {

    @Test("Mindmap ASCII renderer emits a nested unicode tree")
    func basicMindmap() throws {
        let source = """
        mindmap
          root((Root))
            Child A
              Grandchild A1
            Child B
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("Root"))
        #expect(output.contains("Child A"))
        #expect(output.contains("Grandchild A1"))
        #expect(output.contains("Child B"))
        // Tree connector chars (unicode or ASCII fallback)
        let hasConnector = output.contains("├") || output.contains("└") || output.contains("|--") || output.contains("`--")
        #expect(hasConnector)
    }
}

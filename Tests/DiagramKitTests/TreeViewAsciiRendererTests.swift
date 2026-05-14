import Testing
import DiagramKit

@Suite struct TreeViewAsciiRendererTests {

    @Test("TreeView ASCII renderer emits directory + file hierarchy")
    func basicTreeView() throws {
        let source = """
        treeView-beta
        src
          DiagramKit
            DiagramEngine.swift
            DiagramPipeline.swift
          DiagramKitModel
            Types.swift
        """
        let output = try DiagramPipeline.renderASCII(source: source).text
        #expect(output.contains("src"))
        #expect(output.contains("DiagramKit"))
        #expect(output.contains("DiagramEngine.swift"))
        #expect(output.contains("Types.swift"))
        let hasConnector = output.contains("├") || output.contains("└") || output.contains("|--") || output.contains("`--")
        #expect(hasConnector)
    }
}

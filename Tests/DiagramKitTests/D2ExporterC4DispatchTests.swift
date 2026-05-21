import Foundation
import Testing
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
@testable import DiagramKit
@testable import DiagramKitD2

@Suite("D2Exporter c4 dispatch")
struct D2ExporterC4DispatchTests {

    @Test func exportsC4DiagramFromMermaidSource() throws {
        let mermaidSource = """
        C4Context
          title Wave G dispatch smoke
          Person(u, "User")
          System(s, "System")
          Rel(u, s, "uses")
        """
        let mermaidImporter = MermaidImporter()
        let imported = try mermaidImporter.parse(mermaidSource)
        let result = try D2Exporter().export(imported.document)
        #expect(result.source.contains("# diagramkit:family=c4"))
        #expect(result.source.contains("shape: person"))
        #expect(result.source.contains("shape: rectangle"))
    }

    @Test func supportedTypesIncludesC4() {
        #expect(D2Exporter().supportedDiagramTypes.contains(.c4))
    }
}

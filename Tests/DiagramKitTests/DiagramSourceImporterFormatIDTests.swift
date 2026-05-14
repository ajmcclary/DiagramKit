import Testing
@testable import DiagramKit
import DiagramKitCommon
import DiagramKitImport
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML

@Suite struct DiagramSourceImporterFormatIDTests {

    @Test("MermaidImporter declares formatID = .mermaid")
    func mermaidFormatID() {
        #expect(MermaidImporter().formatID == .mermaid)
    }

    @Test("D2Importer declares formatID = .d2")
    func d2FormatID() {
        #expect(D2Importer().formatID == .d2)
    }

    @Test("GraphvizImporter declares formatID = .graphviz")
    func graphvizFormatID() {
        #expect(GraphvizImporter().formatID == .graphviz)
    }

    @Test("StructurizrImporter declares formatID = .structurizr")
    func structurizrFormatID() {
        #expect(StructurizrImporter().formatID == .structurizr)
    }

    @Test("PlantUMLImporter declares formatID = .plantuml")
    func plantumlFormatID() {
        #expect(PlantUMLImporter().formatID == .plantuml)
    }

    @Test("Default registry importers all expose a non-empty formatID rawValue")
    func allDefaultRegistryImportersHaveNonEmptyRawValue() {
        for importer in DiagramPipeline.defaultRegistry.importers {
            #expect(!importer.formatID.rawValue.isEmpty, "\(importer.name) has empty formatID rawValue")
        }
    }
}

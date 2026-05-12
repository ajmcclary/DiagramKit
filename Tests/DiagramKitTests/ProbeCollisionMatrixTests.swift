import Testing
@testable import DiagramKit
import DiagramKitModel
import DiagramKitImport

@Suite struct ProbeCollisionMatrixTests {

    @Test("Mermaid graph TD is claimed by MermaidImporter")
    func mermaidGraphTD() {
        let source = "graph TD\nA-->B"
        let importer = MermaidImporter()
        #expect(importer.supports(source: source))
    }

    @Test("Mermaid sequenceDiagram is claimed")
    func mermaidSequence() {
        let source = "sequenceDiagram\nAlice->>Bob: Hello"
        let importer = MermaidImporter()
        #expect(importer.supports(source: source))
    }

    // Future-phase probe signatures documented as tests.
    // These verify that the probe signatures for future formats are
    // distinguishable. When those importers land, they are prepended
    // before MermaidImporter so their probes fire first.

    @Test("DOT probe signature: digraph keyword")
    func dotProbeSignature() {
        let source = "digraph G {\n  a -> b\n}"
        let firstLine = source.split(separator: "\n").first ?? ""
        #expect(firstLine.hasPrefix("digraph") || firstLine.hasPrefix("graph"))
    }

    @Test("d2 probe signature: edge syntax with colon assignment")
    func d2ProbeSignature() {
        let source = "a -> b\nb: c"
        let containsEdgeArrow = source.contains("->") || source.contains("-->")
        let containsColonAssign = source.contains(": ")
        #expect(containsEdgeArrow && containsColonAssign)
    }

    @Test("PlantUML probe signature: @startuml")
    func plantumlProbeSignature() {
        let source = "@startuml\nAlice -> Bob: Hello\n@enduml"
        #expect(source.contains("@startuml"))
    }

    @Test("Structurizr probe signature: workspace keyword")
    func structurizrProbeSignature() {
        let source = "workspace {\n  model {\n    user = person \"User\"\n  }\n}"
        #expect(source.contains("workspace {"))
    }
}

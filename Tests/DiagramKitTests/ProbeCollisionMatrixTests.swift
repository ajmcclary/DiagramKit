import Testing
@testable import DiagramKit
import DiagramKitModel
import DiagramKitImport
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitStructurizr
import DiagramKitPlantUML

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

    @Test("PlantUML probe accepts @startuml source")
    func plantumlProbeAcceptsStartuml() {
        let p = PlantUMLImporter()
        #expect(p.supports(source: "@startuml\nAlice -> Bob: Hello\n@enduml"))
    }

    @Test("PlantUML probe rejects Mermaid graph TD")
    func plantumlProbeRejectsMermaidGraphTD() {
        let p = PlantUMLImporter()
        #expect(!p.supports(source: "graph TD\nA-->B"))
    }

    @Test("PlantUML probe rejects D2 bare edge")
    func plantumlProbeRejectsD2BareEdge() {
        let p = PlantUMLImporter()
        #expect(!p.supports(source: "A -> B"))
    }

    // MARK: - Structurizr probe collision tests (Phase 5)

    @Test("Structurizr probe accepts workspace")
    func structurizrProbeAcceptsWorkspace() {
        let s = StructurizrImporter()
        #expect(s.supports(source: "workspace { }"))
    }

    @Test("Structurizr probe accepts named workspace")
    func structurizrProbeAcceptsNamedWorkspace() {
        let s = StructurizrImporter()
        #expect(s.supports(source: "workspace \"N\" { }"))
    }

    @Test("Structurizr probe accepts compact")
    func structurizrProbeAcceptsCompact() {
        let s = StructurizrImporter()
        #expect(s.supports(source: "workspace{model{}}"))
    }

    @Test("Structurizr probe accepts multiline workspace")
    func structurizrProbeAcceptsMultilineWorkspace() {
        let s = StructurizrImporter()
        #expect(s.supports(source: "workspace\n{ model {} }"))
    }

    @Test("Structurizr probe rejects workspace without brace")
    func structurizrProbeRejectsWorkspaceWithoutBrace() {
        let s = StructurizrImporter()
        #expect(!s.supports(source: "workspace"))
    }

    @Test("Structurizr probe rejects workspace name without brace")
    func structurizrProbeRejectsWorkspaceNameWithoutBrace() {
        let s = StructurizrImporter()
        #expect(!s.supports(source: "workspace \"N\""))
    }

    @Test("Structurizr probe rejects Mermaid graph TD")
    func structurizrProbeRejectsMermaidGraphTD() {
        let s = StructurizrImporter()
        #expect(!s.supports(source: "graph TD\nA-->B"))
    }

    @Test("Structurizr probe rejects Mermaid flowchart")
    func structurizrProbeRejectsMermaidFlowchart() {
        let s = StructurizrImporter()
        #expect(!s.supports(source: "flowchart LR\nA-->B"))
    }

    @Test("Structurizr probe rejects Mermaid C4")
    func structurizrProbeRejectsMermaidC4() {
        let s = StructurizrImporter()
        #expect(!s.supports(source: "C4Context\nPerson(user, \"U\")"))
    }

    @Test("Structurizr probe rejects D2 source")
    func structurizrProbeRejectsD2Source() {
        let s = StructurizrImporter()
        #expect(!s.supports(source: "A: Start\nA -> B"))
    }

    @Test("Structurizr probe rejects DOT source")
    func structurizrProbeRejectsDOTSource() {
        let s = StructurizrImporter()
        #expect(!s.supports(source: "digraph G { A -> B }"))
    }

    @Test("Structurizr probe rejects PlantUML")
    func structurizrProbeRejectsPlantUML() {
        let s = StructurizrImporter()
        #expect(!s.supports(source: "@startuml\nAlice -> Bob: Hello\n@enduml"))
    }

    @Test("Structurizr probe rejects empty string")
    func structurizrProbeRejectsEmptyString() {
        let s = StructurizrImporter()
        #expect(!s.supports(source: ""))
    }

    @Test("registry prepends Structurizr first")
    func registryPrependsStructurizrFirst() {
        let registry = DiagramPipeline.defaultRegistry
        let importer = registry.importer(for: "workspace { model { } views { } }")
        #expect(importer?.name == "Structurizr")
    }

    @Test("registry falls back to Graphviz for digraph")
    func registryFallsBackToGraphvizForDigraph() {
        let registry = DiagramPipeline.defaultRegistry
        let importer = registry.importer(for: "digraph G { A -> B }")
        #expect(importer?.name == "Graphviz")
    }

    @Test("registry with Structurizr falls back to Mermaid for graph TD")
    func structurizrRegistryFallsBackToMermaidForGraphTD() {
        let registry = DiagramPipeline.defaultRegistry
        let importer = registry.importer(for: "graph TD\nA-->B")
        #expect(importer?.name == "Mermaid")
    }

    // MARK: - DOT probe collision tests (Phase 4)

    @Test("DOT probe accepts digraph")
    func dotProbeAcceptsDigraph() {
        let dot = GraphvizImporter()
        #expect(dot.supports(source: "digraph G { A -> B }"))
    }

    @Test("DOT probe accepts graph")
    func dotProbeAcceptsGraph() {
        let dot = GraphvizImporter()
        #expect(dot.supports(source: "graph G { A -- B }"))
    }

    @Test("DOT probe accepts strict digraph")
    func dotProbeAcceptsStrictDigraph() {
        let dot = GraphvizImporter()
        #expect(dot.supports(source: "strict digraph G { }"))
    }

    @Test("DOT probe rejects Mermaid graph TD")
    func dotProbeRejectsMermaidGraphTD() {
        let dot = GraphvizImporter()
        #expect(!dot.supports(source: "graph TD\nA-->B"))
    }

    @Test("DOT probe rejects Mermaid flowchart")
    func dotProbeRejectsMermaidFlowchart() {
        let dot = GraphvizImporter()
        #expect(!dot.supports(source: "flowchart LR\nA-->B"))
    }

    @Test("DOT probe rejects D2 source")
    func dotProbeRejectsD2Source() {
        let dot = GraphvizImporter()
        #expect(!dot.supports(source: "A: Start\nA -> B"))
    }

    @Test("DOT probe rejects bare edge")
    func dotProbeRejectsBareEdge() {
        let dot = GraphvizImporter()
        #expect(!dot.supports(source: "A -> B"))
    }

    @Test("DOT probe rejects PlantUML")
    func dotProbeRejectsPlantUML() {
        let dot = GraphvizImporter()
        #expect(!dot.supports(source: "@startuml\nAlice -> Bob: Hello\n@enduml"))
    }

    @Test("DOT probe rejects Structurizr")
    func dotProbeRejectsStructurizr() {
        let dot = GraphvizImporter()
        #expect(!dot.supports(source: "workspace { model { user = person } }"))
    }

    @Test("DOT probe rejects prefix match (digraphy)")
    func dotProbeRejectsPrefixMatch() {
        let dot = GraphvizImporter()
        #expect(!dot.supports(source: "digraphy { }"))
    }

    @Test("registry prepends Graphviz before D2")
    func registryPrependsGraphvizBeforeD2() {
        let graphviz = GraphvizImporter()
        let d2 = D2Importer()
        let mermaid = MermaidImporter()
        let registry = ImporterRegistry(importers: [graphviz, d2, mermaid])
        let importer = registry.importer(for: "digraph G { A -> B }")
        #expect(importer?.name == "Graphviz")
    }

    @Test("registry falls back to D2 for bare edge")
    func registryFallsBackToD2ForBareEdge() {
        let graphviz = GraphvizImporter()
        let d2 = D2Importer()
        let mermaid = MermaidImporter()
        let registry = ImporterRegistry(importers: [graphviz, d2, mermaid])
        let importer = registry.importer(for: "A -> B")
        #expect(importer?.name == "D2")
    }

    @Test("registry falls back to Mermaid for graph TD")
    func registryFallsBackToMermaidForGraphTD() {
        let graphviz = GraphvizImporter()
        let d2 = D2Importer()
        let mermaid = MermaidImporter()
        let registry = ImporterRegistry(importers: [graphviz, d2, mermaid])
        let importer = registry.importer(for: "graph TD\nA-->B")
        #expect(importer?.name == "Mermaid")
    }

    // MARK: - D2 probe collision tests (Phase 3)

    @Test("d2 probe rejects Mermaid graph TD")
    func d2RejectsMermaidGraphTD() {
        let d2 = D2Importer()
        #expect(!d2.supports(source: "graph TD\nA-->B"))
    }

    @Test("d2 probe rejects Mermaid flowchart")
    func d2RejectsMermaidFlowchart() {
        let d2 = D2Importer()
        #expect(!d2.supports(source: "flowchart LR\nA-->B"))
    }

    @Test("d2 probe rejects Mermaid sequenceDiagram")
    func d2RejectsMermaidSequence() {
        let d2 = D2Importer()
        #expect(!d2.supports(source: "sequenceDiagram\nAlice->>Bob: Hello"))
    }

    @Test("d2 probe rejects DOT digraph")
    func d2RejectsDOTDigraph() {
        let d2 = D2Importer()
        #expect(!d2.supports(source: "digraph G {\n  a -> b\n}"))
    }

    @Test("d2 probe rejects PlantUML @startuml")
    func d2RejectsPlantUML() {
        let d2 = D2Importer()
        #expect(!d2.supports(source: "@startuml\nAlice -> Bob: Hello\n@enduml"))
    }

    @Test("d2 probe rejects Structurizr workspace")
    func d2RejectsStructurizr() {
        let d2 = D2Importer()
        #expect(!d2.supports(source: "workspace {\n  model {\n    user = person\n  }\n}"))
    }

    @Test("d2 probe accepts A -> B source")
    func d2AcceptsEdgeSource() {
        let d2 = D2Importer()
        #expect(d2.supports(source: "A -> B"))
    }

    @Test("d2 probe accepts dot-chain source")
    func d2AcceptsDotChainSource() {
        let d2 = D2Importer()
        #expect(d2.supports(source: "x.y.z: value"))
    }

    @Test("registry prepends D2 before Mermaid")
    func registryOrder() {
        let d2 = D2Importer()
        let mermaid = MermaidImporter()
        let registry = ImporterRegistry(importers: [d2, mermaid])
        let importer = registry.importer(for: "A -> B")
        #expect(importer?.name == "D2")
    }

    @Test("registry falls back to Mermaid for graph TD")
    func registryFallback() {
        let d2 = D2Importer()
        let mermaid = MermaidImporter()
        let registry = ImporterRegistry(importers: [d2, mermaid])
        let importer = registry.importer(for: "graph TD\nA-->B")
        #expect(importer?.name == "Mermaid")
    }
}

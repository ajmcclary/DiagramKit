import Testing
import Foundation
import DiagramKitCommon
import DiagramKitImport
import DiagramKitTestSupport
import DiagramKitModel
import DiagramKitD2
import DiagramKitGraphviz
import DiagramKitPlantUML

/// Asserts that vanilla foreign-format sources produce **no** import
/// diagnostics for the residual loss-cases tracked by the
/// 2026-05-20 import-coverage-residuals spec. Each fixture lives under
/// `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`.
@Suite("Import diagnostic absence — coverage residuals")
struct ImportDiagnosticAbsenceTests {

    @Test func d2ClassWithLinkTooltipStyle() throws {
        let source = try loadFixture("d2-class/02-attributed.d2")
        let result = try D2Importer().parse(source)
        #expect(result.diagnostics.isEmpty,
                "Expected zero import diagnostics, got: \(result.diagnostics)")
        guard case .classDiagram(let cd) = result.document.payload else {
            Issue.record("Expected classDiagram, got \(result.document.payload.type)")
            return
        }
        guard let animal = cd.classes.first(where: { $0.id == "Animal" }) else {
            Issue.record("Animal class missing")
            return
        }
        // Attributes must route into typed slots, not become bogus members.
        #expect(animal.link == "https://example.com/animal",
                "Expected link routed into ClassNode.link, got \(String(describing: animal.link))")
        #expect(animal.tooltip == "Base class",
                "Expected tooltip routed into ClassNode.tooltip, got \(String(describing: animal.tooltip))")
        let memberNames = Set(animal.attributes.map { $0.id } + animal.methods.map { $0.id })
        #expect(!memberNames.contains("link"), "link must not surface as a class member")
        #expect(!memberNames.contains("tooltip"), "tooltip must not surface as a class member")
        #expect(!memberNames.contains("style"), "style must not surface as a class member")
        #expect(!memberNames.contains("stroke"), "stroke must not surface as a class member")
        #expect(!memberNames.contains("fill"), "fill must not surface as a class member")
        #expect(animal.styles.contains(where: { $0.contains("stroke") }),
                "Expected stroke style in ClassNode.styles, got \(animal.styles)")
        #expect(animal.styles.contains(where: { $0.contains("fill") }),
                "Expected fill style in ClassNode.styles, got \(animal.styles)")
    }

    @Test func dotClassWithUrlTooltipStyle() throws {
        let source = try loadFixture("dot-class/02-attributed.dot")
        let result = try GraphvizImporter().parse(source)
        #expect(result.diagnostics.isEmpty,
                "Expected zero import diagnostics, got: \(result.diagnostics)")
        guard case .classDiagram(let cd) = result.document.payload else {
            Issue.record("Expected classDiagram, got \(result.document.payload.type)")
            return
        }
        guard let animal = cd.classes.first(where: { $0.id == "Animal" }) else {
            Issue.record("Animal class missing")
            return
        }
        #expect(animal.link == "https://example.com/animal")
        #expect(animal.tooltip == "Base class")
        #expect(animal.styles.contains(where: { $0.contains("style") || $0.contains("filled") }),
                "Expected style entry, got \(animal.styles)")
        #expect(animal.styles.contains(where: { $0.contains("stroke") || $0.contains("color") }),
                "Expected color entry, got \(animal.styles)")
        #expect(animal.styles.contains(where: { $0.contains("fill") || $0.contains("yellow") }),
                "Expected fill entry, got \(animal.styles)")
    }

    @Test func plantUMLClassWithStereotypeAndPackage() throws {
        let source = try loadFixture("plantuml-class/04-stereotype-package.puml")
        let result = try PlantUMLImporter().parse(source)
        #expect(result.diagnostics.isEmpty,
                "Expected zero import diagnostics, got: \(result.diagnostics)")
        guard case .classDiagram(let cd) = result.document.payload else {
            Issue.record("Expected classDiagram, got \(result.document.payload.type)")
            return
        }
        guard let animal = cd.classes.first(where: { $0.id == "Animal" }) else {
            Issue.record("Animal class missing")
            return
        }
        #expect(animal.annotations.contains("entity"),
                "Stereotype <<entity>> must surface in annotations, got \(animal.annotations)")
        #expect(cd.namespaces.contains(where: { $0.id == "model" }),
                "Package `model` must surface as ClassNamespace")
        if let model = cd.namespaces.first(where: { $0.id == "model" }) {
            #expect(model.classIds.contains("Animal"))
            #expect(model.classIds.contains("Dog"))
        }
    }

    @Test func d2StateWithNestedComposite() throws {
        let source = try loadFixture("d2-state/02-nested-composite.d2")
        let result = try D2Importer().parse(source)
        #expect(result.diagnostics.isEmpty,
                "Expected zero import diagnostics, got: \(result.diagnostics)")
        guard case .stateDiagram(let graph) = result.document.payload else {
            Issue.record("Expected stateDiagram, got \(result.document.payload.type)")
            return
        }
        // Inner states should be present as nodes.
        let nodeIds = Set(graph.nodesInOrder.map { $0.id })
        #expect(nodeIds.contains("Loading"),
                "Inner state `Loading` missing from graph nodes; got \(nodeIds)")
        #expect(nodeIds.contains("Ready"),
                "Inner state `Ready` missing from graph nodes; got \(nodeIds)")
        // The container should surface as a subgraph holding Loading and Ready.
        let active = graph.subgraphs.first(where: { $0.id == "Active" })
        #expect(active != nil,
                "Expected `Active` to surface as MermaidSubgraph; got subgraphs \(graph.subgraphs.map { $0.id })")
        if let active = active {
            #expect(active.nodeIds.contains("Loading"))
            #expect(active.nodeIds.contains("Ready"))
        }
    }

    @Test func dotStateWithCluster() throws {
        let source = try loadFixture("dot-state/02-nested-composite.dot")
        let result = try GraphvizImporter().parse(source)
        #expect(result.diagnostics.isEmpty,
                "Expected zero import diagnostics, got: \(result.diagnostics)")
        guard case .stateDiagram(let graph) = result.document.payload else {
            Issue.record("Expected stateDiagram, got \(result.document.payload.type)")
            return
        }
        let nodeIds = Set(graph.nodesInOrder.map { $0.id })
        #expect(nodeIds.contains("Loading"))
        #expect(nodeIds.contains("Ready"))
        let active = graph.subgraphs.first(where: { $0.id == "Active" || $0.id == "cluster_Active" })
        #expect(active != nil,
                "Expected cluster_Active to surface as MermaidSubgraph; got \(graph.subgraphs.map { $0.id })")
        if let active = active {
            #expect(active.nodeIds.contains("Loading"))
            #expect(active.nodeIds.contains("Ready"))
        }
    }

    @Test func d2ERWithCardinality() throws {
        let source = try loadFixture("d2-er/02-cardinality.d2")
        let result = try D2Importer().parse(source)
        #expect(result.diagnostics.isEmpty,
                "Expected zero import diagnostics, got: \(result.diagnostics)")
        guard case .erDiagram(let er) = result.document.payload else {
            Issue.record("Expected erDiagram, got \(result.document.payload.type)")
            return
        }
        guard let rel = er.relationships.first else {
            Issue.record("Expected a relationship")
            return
        }
        #expect(rel.relSpec.cardA == .onlyOne,
                "Expected cardA = onlyOne, got \(rel.relSpec.cardA)")
        #expect(rel.relSpec.cardB == .oneOrMore,
                "Expected cardB = oneOrMore, got \(rel.relSpec.cardB)")
        // Recognized cardinality should not also surface as a relationship label
        #expect(rel.roleA.isEmpty || !rel.roleA.contains("{"),
                "Cardinality label should be consumed, got roleA=\(rel.roleA)")
    }

    @Test func dotERWithCrowsFoot() throws {
        let source = try loadFixture("dot-er/02-cardinality.dot")
        let result = try GraphvizImporter().parse(source)
        #expect(result.diagnostics.isEmpty,
                "Expected zero import diagnostics, got: \(result.diagnostics)")
        guard case .erDiagram(let er) = result.document.payload else {
            Issue.record("Expected erDiagram, got \(result.document.payload.type)")
            return
        }
        guard let rel = er.relationships.first else {
            Issue.record("Expected a relationship")
            return
        }
        // arrowtail=tee → cardA=onlyOne; arrowhead=crow → cardB=oneOrMore
        #expect(rel.relSpec.cardA == .onlyOne,
                "Expected cardA = onlyOne, got \(rel.relSpec.cardA)")
        #expect(rel.relSpec.cardB == .oneOrMore,
                "Expected cardB = oneOrMore, got \(rel.relSpec.cardB)")
    }

    @Test func architectureServiceKindDefaultsToService() {
        let s = ArchitectureService(id: "Foo")
        #expect(s.kind == .service,
                "Default kind must be .service for back-compat; got \(s.kind)")
    }

    @Test func architectureServiceKindRoundTripsExplicitValue() {
        let s = ArchitectureService(id: "Bar", kind: .component)
        #expect(s.kind == .component)
    }

    @Test func plantUMLComponentWithInterface() throws {
        let source = try loadFixture("plantuml-component/02-interface.puml")
        let result = try PlantUMLImporter().parse(source)
        #expect(result.diagnostics.isEmpty,
                "Expected zero import diagnostics, got: \(result.diagnostics)")
        guard case .architecture(let arch) = result.document.payload else {
            Issue.record("Expected architecture, got \(result.document.payload.type)")
            return
        }
        let database = arch.services.first { $0.id == "Database" }
        let api = arch.services.first { $0.id == "API" }
        let rest = arch.services.first { $0.id == "REST" }
        #expect(database?.kind == .component, "Database kind = \(String(describing: database?.kind))")
        #expect(api?.kind == .component, "API kind = \(String(describing: api?.kind))")
        #expect(rest?.kind == .interface, "REST kind = \(String(describing: rest?.kind))")
    }

    // MARK: - Helpers

    private func loadFixture(_ relativePath: String) throws -> String {
        let url = roundTripResourcesRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

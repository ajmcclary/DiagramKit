import Testing
import DiagramKitModel
import DiagramKitExport
@testable import DiagramKitGraphviz

@Suite("DOT marker round-trip — class + ER")
struct DOTRecoveryRoundTripTests {

    @Test("class-stereotype: Mermaid payload → DOT export → DOT import → annotations preserved")
    func classStereotypeRoundTrip() throws {
        let order = ClassNode(
            id: "Order",
            label: "Order",
            attributes: [ClassMember(id: "id", visibility: "+", memberType: .attribute, returnType: "String")],
            methods: [],
            annotations: ["<<entity>>"]
        )
        let payload = ClassDiagram(
            classes: [order],
            classMap: ["Order": order],
            relationships: []
        )

        let exportResult = try DOTClassExport.emit(payload)
        #expect(exportResult.diagnostics.isEmpty,
                "expected zero diagnostics after marker emission; got: \(exportResult.diagnostics)")
        #expect(exportResult.source.contains("# diagramkit:class-stereotype=Order,<<entity>>"))

        let parsed = try GraphvizImporter().parse(exportResult.source)
        guard case .classDiagram(let cd) = parsed.document.payload else {
            Issue.record("expected classDiagram payload, got: \(parsed.document.payload)")
            return
        }
        let recoveredOrder = try #require(cd.classes.first(where: { $0.id == "Order" }))
        #expect(recoveredOrder.annotations.contains("<<entity>>"))
    }

    @Test("er-cardinality: Mermaid payload → DOT export → DOT import → cardinality preserved")
    func erCardinalityRoundTrip() throws {
        let relSpec = ErRelSpec(
            cardA: .zeroOrMore,
            cardB: .onlyOne,
            relType: .nonIdentifying
        )
        let rel = ErRelationship(
            entity1: "User",
            entity2: "Order",
            entityAId: "entity-User-0",
            entityBId: "entity-Order-0",
            roleA: "places",
            relSpec: relSpec
        )
        let entities = [
            ErEntity(key: "User", label: "User", attributes: []),
            ErEntity(key: "Order", label: "Order", attributes: []),
        ]
        let payload = ErDiagram(entities: entities, relationships: [rel])

        let exportResult = try DOTERExport.emit(payload)
        #expect(exportResult.diagnostics.isEmpty,
                "expected zero diagnostics after marker emission; got: \(exportResult.diagnostics)")
        #expect(exportResult.source.contains("# diagramkit:er-cardinality=User_Order,"))

        let parsed = try GraphvizImporter().parse(exportResult.source)
        guard case .erDiagram(let ed) = parsed.document.payload else {
            Issue.record("expected erDiagram payload, got: \(parsed.document.payload)")
            return
        }
        let recoveredRel = try #require(ed.relationships.first)
        #expect(recoveredRel.relSpec.cardA == .zeroOrMore,
                "expected cardA=zeroOrMore; got: \(recoveredRel.relSpec.cardA)")
        #expect(recoveredRel.relSpec.cardB == .onlyOne,
                "expected cardB=onlyOne; got: \(recoveredRel.relSpec.cardB)")
    }
}

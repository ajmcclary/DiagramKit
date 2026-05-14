import Testing
import DiagramKitModel
import DiagramKitImport
@testable import DiagramKit
@testable import DiagramKitMermaid
@testable import DiagramKitPlantUML

/// Cross-format C4 slot-semantics regression tests. The Mermaid C4 grammar
/// is shape-family-dependent:
///   Person/System macros:    (alias, label, descr?)
///   Container/Component:     (alias, label, techn?, descr?)
/// Both Mermaid and PlantUML emitters/parsers must dispatch on family or
/// technology↔description silently swap on round-trip.
@Suite struct C4SlotSemanticsTests {

    // MARK: - hasTechnologySlot

    @Test("Person/System families have no positional technology slot")
    func personSystemNoTechSlot() {
        #expect(C4ShapeType.person.hasTechnologySlot == false)
        #expect(C4ShapeType.external_person.hasTechnologySlot == false)
        #expect(C4ShapeType.system.hasTechnologySlot == false)
        #expect(C4ShapeType.system_db.hasTechnologySlot == false)
        #expect(C4ShapeType.external_system_queue.hasTechnologySlot == false)
    }

    @Test("Container/Component families have a positional technology slot")
    func containerComponentTechSlot() {
        #expect(C4ShapeType.container.hasTechnologySlot == true)
        #expect(C4ShapeType.container_db.hasTechnologySlot == true)
        #expect(C4ShapeType.external_container_queue.hasTechnologySlot == true)
        #expect(C4ShapeType.component.hasTechnologySlot == true)
        #expect(C4ShapeType.external_component_db.hasTechnologySlot == true)
    }

    // MARK: - Mermaid emit shape-family dispatch

    @Test("Mermaid Container with desc only emits empty techn placeholder")
    func mermaidContainerDescOnlyKeepsSlot() throws {
        let model = C4Diagram(
            kind: .container,
            shapes: [
                C4Shape(alias: "web", label: "Web", typeC4Shape: .container, technology: nil, description: "Public UI")
            ]
        )
        let result = try MermaidC4Export.emit(model)
        // Slot 3 must be techn (empty), slot 4 must be descr ("Public UI").
        #expect(result.source.contains("Container(web, \"Web\", \"\", \"Public UI\")"))
    }

    @Test("Mermaid Person with technology drops it with .info diagnostic")
    func mermaidPersonTechnologyDropped() throws {
        let model = C4Diagram(
            kind: .context,
            shapes: [
                C4Shape(alias: "u", label: "User", typeC4Shape: .person, technology: "iPad app", description: "End user")
            ]
        )
        let result = try MermaidC4Export.emit(model)
        // descr lands at slot 3; technology has no slot and surfaces a diagnostic.
        #expect(result.source.contains("Person(u, \"User\", \"End user\")"))
        #expect(result.diagnostics.contains { d in
            d.severity == .info
                && d.message.contains("technology")
                && d.message.contains("u")
        })
    }

    // MARK: - PlantUML round-trip

    @Test("PlantUML Container round-trips technology and description in correct slots")
    func plantUMLContainerRoundTrip() throws {
        let source = """
        @startuml
        !include <C4/C4_Container>
        Container(web, "Web", "Nginx", "Public UI")
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .c4(let model) = result.document.payload else {
            Issue.record("expected c4 payload"); return
        }
        let web = try #require(model.shapes.first { $0.alias == "web" })
        #expect(web.technology == "Nginx")
        #expect(web.description == "Public UI")
    }

    @Test("PlantUML Person reads slot 3 as description (no technology slot)")
    func plantUMLPersonSlot3IsDescription() throws {
        let source = """
        @startuml
        !include <C4/C4_Context>
        Person(u, "User", "End user of the system")
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .c4(let model) = result.document.payload else {
            Issue.record("expected c4 payload"); return
        }
        let u = try #require(model.shapes.first { $0.alias == "u" })
        #expect(u.description == "End user of the system")
        #expect(u.technology == nil)
    }

    @Test("PlantUML emit preserves technology/description split for Container")
    func plantUMLEmitContainerKeepsSlots() throws {
        let model = C4Diagram(
            kind: .container,
            shapes: [
                C4Shape(alias: "web", label: "Web", typeC4Shape: .container, technology: "Nginx", description: "Public UI")
            ]
        )
        let result = try PlantUMLC4Export.emit(model)
        #expect(result.source.contains("Container(web, \"Web\", \"Nginx\", \"Public UI\")"))
    }

    @Test("PlantUML emit drops technology silently for Person")
    func plantUMLEmitPersonDropsTechnology() throws {
        let model = C4Diagram(
            kind: .context,
            shapes: [
                C4Shape(alias: "u", label: "User", typeC4Shape: .person, technology: "iPad", description: "End user")
            ]
        )
        let result = try PlantUMLC4Export.emit(model)
        // descr at slot 3; technology has no slot.
        #expect(result.source.contains("Person(u, \"User\", \"End user\")"))
    }
}

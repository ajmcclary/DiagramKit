import Testing
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2 class-stereotype marker recovery via D2Importer")
struct D2ClassStereotypeRecoveryTests {

    @Test("class-stereotype marker is appended to ClassNode.annotations")
    func appliesClassStereotype() throws {
        let source = """
        Order: {
          shape: class
          +id: String
        }
        # diagramkit:class-stereotype=Order,<<entity>>
        """
        let result = try D2Importer().parse(source)
        guard case .classDiagram(let cd) = result.document.payload else {
            Issue.record("expected classDiagram payload, got: \(result.document.payload)")
            return
        }
        let order = try #require(cd.classes.first(where: { $0.id == "Order" }))
        #expect(order.annotations.contains("<<entity>>"),
                "expected Order.annotations to contain '<<entity>>'; got: \(order.annotations)")
    }

    @Test("absence of marker leaves annotations empty")
    func noMarkerNoAnnotation() throws {
        let source = """
        Order: {
          shape: class
          +id: String
        }
        """
        let result = try D2Importer().parse(source)
        guard case .classDiagram(let cd) = result.document.payload else {
            Issue.record("expected classDiagram payload")
            return
        }
        let order = try #require(cd.classes.first(where: { $0.id == "Order" }))
        #expect(order.annotations.isEmpty)
    }
}

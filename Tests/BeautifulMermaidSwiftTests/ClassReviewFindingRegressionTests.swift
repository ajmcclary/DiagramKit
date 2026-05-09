import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

final class ClassReviewFindingRegressionTests: XCTestCase {

    func testGenericRelationshipEndpointNormalizesClassIdentityAndType() throws {
        let source = "classDiagram\nClass1~T~ <|-- Class02"
        let diagram = try parseClassDiagram(source.splitByNewlines)

        XCTAssertNotNil(diagram.classes.first(where: { $0.id == "Class1" }))
        XCTAssertNil(diagram.classes.first(where: { $0.id == "Class1~T~" }))
        XCTAssertEqual(diagram.classMap["Class1"]?.type, "T")
        XCTAssertEqual(diagram.relationships.first?.id1, "Class1")
    }

    func testNamespaceOwnsClassesAndProducesRenderedNamespaceBox() throws {
        let source = "classDiagram\nnamespace Company {\n    class Employee\n    class Department\n}\nEmployee --> Department"
        let diagram = try parseClassDiagram(source.splitByNewlines)

        XCTAssertEqual(diagram.namespaceMap["Company"]?.classIds, ["Employee", "Department"])
        XCTAssertEqual(diagram.classMap["Employee"]?.parent, "Company")
        XCTAssertEqual(diagram.classMap["Department"]?.parent, "Company")

        let positioned = try layoutClassDiagramSync(diagram)
        XCTAssertEqual(positioned.namespaces.map(\.id), ["Company"])
        XCTAssertGreaterThan(positioned.namespaces.first?.width ?? 0, 0)

        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("class-namespace"))
        XCTAssertTrue(svg.contains("Company"))
    }

    func testLollipopNormalizationPreservesMarkerForRendering() throws {
        let source = "classDiagram\nbar ()-- foo"
        let diagram = try parseClassDiagram(source.splitByNewlines)

        XCTAssertEqual(diagram.interfaces.first?.label, "bar")
        XCTAssertEqual(diagram.relationships.first?.id1, "interface0")
        XCTAssertEqual(diagram.relationships.first?.relation.type1, ClassRelationType.lollipop.rawValue)

        let positioned = try layoutClassDiagramSync(diagram)
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("lollipop"))
        XCTAssertTrue(svg.contains("marker-start=\"url(#lollipop)\""))
    }

    func testStyleAndClassDefAffectRenderedClassBox() throws {
        let source = """
        classDiagram
        class Animal:::pink
        classDef pink fill:#f9f,stroke:#333,stroke-width:4px,color:#111
        """

        let diagram = try parseClassDiagram(source.splitByNewlines)
        let animal = try XCTUnwrap(diagram.classMap["Animal"])
        XCTAssertTrue(animal.styles.contains("fill:#f9f"))
        XCTAssertTrue(animal.styles.contains("stroke:#333"))
        XCTAssertTrue(animal.styles.contains("stroke-width:4px"))

        let positioned = try layoutClassDiagramSync(diagram)
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("fill=\"#f9f\""))
        XCTAssertTrue(svg.contains("stroke=\"#333\""))
        XCTAssertTrue(svg.contains("stroke-width=\"4\"") || svg.contains("stroke-width=\"4px\""))
        XCTAssertTrue(svg.contains("fill=\"#111\""))
    }
}

private extension String {
    var splitByNewlines: [String] {
        self.split(separator: "\n").map(String.init)
    }
}

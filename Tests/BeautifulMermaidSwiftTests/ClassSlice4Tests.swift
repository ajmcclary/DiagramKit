import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class ClassSlice4Tests: XCTestCase {

    func test_two_ended_extension() throws {
        let source = "classDiagram\nclass A\nclass B\nA <|--|> B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.type1, ClassRelationType.inheritance.rawValue)
        XCTAssertEqual(rel.relation.type2, ClassRelationType.inheritance.rawValue)
    }

    func test_two_ended_composition() throws {
        let source = "classDiagram\nclass A\nclass B\nA *--* B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.type1, ClassRelationType.composition.rawValue)
        XCTAssertEqual(rel.relation.type2, ClassRelationType.composition.rawValue)
    }

    func test_two_ended_aggregation() throws {
        let source = "classDiagram\nclass A\nclass B\nA o--o B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.type1, ClassRelationType.aggregation.rawValue)
        XCTAssertEqual(rel.relation.type2, ClassRelationType.aggregation.rawValue)
    }

    func test_solid_no_arrow() throws {
        let source = "classDiagram\nclass A\nclass B\nA -- B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.type1, ClassRelationType.none.rawValue)
        XCTAssertEqual(rel.relation.type2, ClassRelationType.none.rawValue)
        XCTAssertEqual(rel.relation.lineType, ClassLineType.solid.rawValue)
    }

    func test_dashed_no_arrow() throws {
        let source = "classDiagram\nclass A\nclass B\nA .. B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.lineType, ClassLineType.dotted.rawValue)
    }

    func test_inheritance() throws {
        let source = "classDiagram\nclass Animal\nclass Dog\nAnimal <|-- Dog"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.id1, "Animal")
        XCTAssertEqual(rel.id2, "Dog")
        XCTAssertEqual(rel.relation.type1, ClassRelationType.inheritance.rawValue)
        XCTAssertEqual(rel.relation.type2, ClassRelationType.none.rawValue)
        XCTAssertEqual(rel.relation.lineType, ClassLineType.solid.rawValue)
    }

    func test_composition() throws {
        let source = "classDiagram\nclass Car\nclass Engine\nCar *-- Engine"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.type1, ClassRelationType.composition.rawValue)
    }

    func test_aggregation_cardinality() throws {
        let source = "classDiagram\nclass A\nclass B\nA \"1\" -- \"*\" B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relationTitle1, "1")
        XCTAssertEqual(rel.relationTitle2, "*")
    }

    func test_lollipop_normalization() throws {
        let source = "classDiagram\nclass Shape\nShape ()-- Drawable"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertFalse(diagram.interfaces.isEmpty)
        // The interface should be created
        let iface = diagram.interfaces.first
        XCTAssertNotNil(iface)
        // After normalization, id1 is rewritten to the interface node
        let rel = diagram.relationships.first
        XCTAssertNotNil(rel)
    }

    func test_mixed_relations() throws {
        let source = "classDiagram\nclass A\nclass B\nA <|--* B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.type1, ClassRelationType.inheritance.rawValue)
        XCTAssertEqual(rel.relation.type2, ClassRelationType.composition.rawValue)
    }

    func test_two_ended_markers_in_svg() throws {
        let source = "classDiagram\nclass A\nclass B\nA <|--|> B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let positioned = try layoutClassDiagramSync(diagram)
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("marker-start=\"url(#extension)\""))
        XCTAssertTrue(svg.contains("marker-end=\"url(#extension)\""))
    }

    func test_lollipop_marker_in_svg() throws {
        let source = "classDiagram\nbar ()-- foo"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let positioned = try layoutClassDiagramSync(diagram)
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("lollipop"))
        XCTAssertTrue(svg.contains("marker-start=\"url(#lollipop)\""))
    }

    func test_dotted_inheritance() throws {
        let source = "classDiagram\nclass A\nclass B\nA <|.. B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.type1, ClassRelationType.inheritance.rawValue)
        XCTAssertEqual(rel.relation.type2, ClassRelationType.none.rawValue)
        XCTAssertEqual(rel.relation.lineType, ClassLineType.dotted.rawValue)
    }

    func test_dotted_target_inheritance() throws {
        let source = "classDiagram\nclass A\nclass B\nA ..|> B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.type2, ClassRelationType.inheritance.rawValue)
        XCTAssertEqual(rel.relation.lineType, ClassLineType.dotted.rawValue)
    }

    func test_dotted_aggregation() throws {
        let source = "classDiagram\nclass A\nclass B\nA o.. B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.type1, ClassRelationType.aggregation.rawValue)
        XCTAssertEqual(rel.relation.lineType, ClassLineType.dotted.rawValue)
    }

    func test_dotted_composition() throws {
        let source = "classDiagram\nclass A\nclass B\nA *.. B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.type1, ClassRelationType.composition.rawValue)
        XCTAssertEqual(rel.relation.lineType, ClassLineType.dotted.rawValue)
    }

    func test_reverse_lollipop() throws {
        let source = "classDiagram\nfoo --() Bar"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships.first
        XCTAssertNotNil(rel)
        XCTAssertEqual(rel?.relation.type2, ClassRelationType.lollipop.rawValue)
    }

    func test_dotted_two_ended_aggregation() throws {
        let source = "classDiagram\nclass A\nclass B\nA o..o B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.type1, ClassRelationType.aggregation.rawValue)
        XCTAssertEqual(rel.relation.type2, ClassRelationType.aggregation.rawValue)
        XCTAssertEqual(rel.relation.lineType, ClassLineType.dotted.rawValue)
    }

    func test_dotted_two_ended_composition() throws {
        let source = "classDiagram\nclass A\nclass B\nA *..* B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let rel = diagram.relationships[0]
        XCTAssertEqual(rel.relation.type1, ClassRelationType.composition.rawValue)
        XCTAssertEqual(rel.relation.type2, ClassRelationType.composition.rawValue)
        XCTAssertEqual(rel.relation.lineType, ClassLineType.dotted.rawValue)
    }
}

private extension String {
    var splitByNewlines: [String] {
        self.split(separator: "\n").map(String.init)
    }
}

import XCTest
@testable import BeautifulMermaid

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
}

private extension String {
    var splitByNewlines: [String] {
        self.split(separator: "\n").map(String.init)
    }
}

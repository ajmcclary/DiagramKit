import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class ClassSlice1Tests: XCTestCase {

    // MARK: - Header parsing

    func test_classDiagram_v2_header() throws {
        let source = "classDiagram-v2\nclass Animal\nclass Dog\nAnimal <|-- Dog"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.classes.count, 2)
        XCTAssertEqual(diagram.relationships.count, 1)
    }

    func test_classDiagram_header_case_insensitive() throws {
        let source = "ClAsSdIaGrAm\nclass Animal"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.classes.count, 1)
    }

    // MARK: - Square-bracket labels

    func test_square_bracket_label() throws {
        let source = "classDiagram\nclass Animal[\"Animal with a label\"]"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.classes.count, 1)
        let cls = diagram.classes[0]
        XCTAssertEqual(cls.label, "Animal with a label")
    }

    func test_square_bracket_label_with_class_body() throws {
        let source = "classDiagram\nclass Animal[\"Animal with a label\"] {\n    +name string\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.classes.count, 1)
        let cls = diagram.classes[0]
        XCTAssertEqual(cls.label, "Animal with a label")
        XCTAssertFalse(cls.attributes.isEmpty)
    }

    // MARK: - Backtick-escaped names

    func test_backtick_class_name() throws {
        let source = "classDiagram\nclass `Animal Class!`"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.classes.count, 1)
        let cls = diagram.classes[0]
        XCTAssertEqual(cls.id, "Animal Class!")
    }

    func test_backtick_relationship() throws {
        let source = "classDiagram\nclass `Animal Class!`\nclass `Car`\n`Animal Class!` --> `Car`"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.classes.count, 2)
        XCTAssertEqual(diagram.relationships.count, 1)
    }

    // MARK: - Generic type normalization

    func test_generic_declaration() throws {
        let source = "classDiagram\nclass Box~T~"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.classes.count, 1)
        let cls = diagram.classes[0]
        XCTAssertEqual(cls.type, "T")
        XCTAssertTrue(cls.text.contains("<T>"))
    }

    func test_parseGenericTypes_helper() {
        XCTAssertEqual(parseGenericTypes("List~T~"), "List<T>")
        XCTAssertEqual(parseGenericTypes("Map~K,V~"), "Map<K, V>")
        XCTAssertEqual(parseGenericTypes("Int"), "Int")
    }

    func test_splitClassNameAndType_helper() {
        let (name1, type1) = splitClassNameAndType("Box~T~")
        XCTAssertEqual(name1, "Box")
        XCTAssertEqual(type1, "T")

        let (name2, type2) = splitClassNameAndType("Animal")
        XCTAssertEqual(name2, "Animal")
        XCTAssertNil(type2)

        let (name3, type3) = splitClassNameAndType("`My Class~T~`")
        XCTAssertEqual(name3, "My Class~T~")
        XCTAssertNil(type3)
    }

    func test_cleanupLabel_helper() {
        XCTAssertEqual(cleanupLabel(": Animal"), "Animal")
        XCTAssertEqual(cleanupLabel("\"Animal\""), "Animal")
    }

    // MARK: - End-to-end

    func test_end_to_end_v2_header() throws {
        let source = "classDiagram-v2\nclass Animal\nclass Dog\nAnimal <|-- Dog"
        let positioned = try layoutClassDiagramSync(try parseClassDiagram(source.splitByNewlines))
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("<svg"))
    }
}

private extension String {
    var splitByNewlines: [String] {
        self.split(separator: "\n").map(String.init)
    }
}

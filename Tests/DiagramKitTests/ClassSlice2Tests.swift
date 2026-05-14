import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class ClassSlice2Tests: XCTestCase {

    func test_separate_line_annotation() throws {
        let source = "classDiagram\nclass Shape\n<<interface>> Shape\nclass Circle\nCircle --|> Shape"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        let shape = diagram.classes.first(where: { $0.id == "Shape" })
        XCTAssertNotNil(shape)
        XCTAssertEqual(shape!.annotations, ["interface"])
    }

    func test_inline_annotation() throws {
        let source = "classDiagram\nclass Shape <<interface>>"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        XCTAssertEqual(cls.annotations, ["interface"])
    }

    func test_inline_annotation_with_members() throws {
        let source = "classDiagram\nclass Shape <<interface>> {\n    +calculateArea() double\n}"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        XCTAssertEqual(cls.annotations, ["interface"])
        XCTAssertFalse(cls.methods.isEmpty)
    }

    func test_inline_annotation_empty_class() throws {
        let source = "classDiagram\nclass Shape <<interface>> {}"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes[0]
        XCTAssertEqual(cls.annotations, ["interface"])
        XCTAssertTrue(cls.attributes.isEmpty)
        XCTAssertTrue(cls.methods.isEmpty)
    }

    func test_multiple_annotations() throws {
        let source = "classDiagram\n<<interface>> Shape\n<<serializable>> Shape"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        let shape = diagram.classes.first(where: { $0.id == "Shape" })
        XCTAssertNotNil(shape)
        XCTAssertEqual(shape!.annotations, ["interface", "serializable"])
    }

    func test_annotations_render_in_svg() throws {
        let source = "classDiagram\nclass Shape <<interface>>"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        let positioned = try layoutClassDiagramSync(diagram)
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("&lt;&lt;interface&gt;&gt;"))
    }
}

private extension String {
    var splitByNewlines: [String] {
        self.split(separator: "\n").map(String.init)
    }
}

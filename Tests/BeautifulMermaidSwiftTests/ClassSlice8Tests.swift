import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

final class ClassSlice8Tests: XCTestCase {

    func test_style_directive() throws {
        let source = "classDiagram\nclass Animal\nstyle Animal fill:#f9f,stroke:#333,stroke-width:4px"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes.first!
        XCTAssertFalse(cls.styles.isEmpty)
        XCTAssertTrue(cls.styles.contains("fill:#f9f"))
        XCTAssertTrue(cls.styles.contains("stroke:#333"))
        XCTAssertTrue(cls.styles.contains("stroke-width:4px"))
    }

    func test_classDef_basic() throws {
        let source = "classDiagram\nclass Animal\nclassDef pink fill:#f9f,stroke:#333"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.styleClasses.count, 1)
        let sc = diagram.styleClasses[0]
        XCTAssertEqual(sc.id, "pink")
    }

    func test_classDef_default() throws {
        let source = "classDiagram\nclass Animal\nclassDef default fill:#f9f,color:#fff"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertFalse(diagram.styleClasses.isEmpty)
    }

    func test_classDef_text_styles() throws {
        let source = "classDiagram\nclass Animal\nclassDef pink fill:#f9f,color:#fff"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let sc = diagram.styleClasses[0]
        // color tokens go to textStyles
        XCTAssertFalse(sc.textStyles.isEmpty)
        XCTAssertTrue(sc.textStyles.contains(where: { $0.contains("color") }))
    }

    func test_css_class_directive() throws {
        let source = "classDiagram\nclass Animal\nclass Dog\nclassDef pink fill:#f9f\ncssClass \"Animal\" pink"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let animal = diagram.classes.first(where: { $0.id == "Animal" })
        XCTAssertNotNil(animal)
        XCTAssertTrue(animal!.cssClasses.contains("pink"))
    }

    func test_css_multi_class() throws {
        let source = "classDiagram\nclass A\nclass B\nclassDef red fill:#f00\ncssClass \"A,B\" red"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let a = diagram.classes.first(where: { $0.id == "A" })
        let b = diagram.classes.first(where: { $0.id == "B" })
        XCTAssertTrue(a!.cssClasses.contains("red"))
        XCTAssertTrue(b!.cssClasses.contains("red"))
    }

    func test_shorthand_style() throws {
        let source = "classDiagram\nclass Shape\nclassDef exClass fill:#f9f\nclass Shape ::: exClass"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let shape = diagram.classes.first!
        XCTAssertTrue(shape.cssClasses.contains("exClass"))
    }
}

private extension String {
    var splitByNewlines: [String] {
        self.split(separator: "\n").map(String.init)
    }
}

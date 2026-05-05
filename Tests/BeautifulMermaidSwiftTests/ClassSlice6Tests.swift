import XCTest
@testable import BeautifulMermaid

final class ClassSlice6Tests: XCTestCase {

    func test_general_note() throws {
        let source = "classDiagram\nclass A\nclass B\nnote \"This is a general note\"\nA --> B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.notes.count, 1)
        let note = diagram.notes[0]
        XCTAssertEqual(note.text, "This is a general note")
        XCTAssertNil(note.class_)
    }

    func test_class_attached_note() throws {
        let source = "classDiagram\nclass A\nclass B\nnote for A \"This note is for class A\"\nA --> B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.notes.count, 1)
        let note = diagram.notes[0]
        XCTAssertEqual(note.class_, "A")
    }

    func test_note_in_namespace() throws {
        let source = "classDiagram\nnamespace Group {\n    class A\n    note \"Note inside namespace\"\n}"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.notes.count, 1)
    }

    func test_note_renders_in_svg() throws {
        let source = "classDiagram\nclass A\nclass B\nnote \"Hello\"\nA --> B"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let positioned = try layoutClassDiagramSync(diagram)
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("class-note"))
        XCTAssertTrue(svg.contains("Hello"))
    }
}

private extension String {
    var splitByNewlines: [String] {
        self.split(separator: "\n").map(String.init)
    }
}

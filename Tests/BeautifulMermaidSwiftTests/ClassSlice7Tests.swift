import XCTest
@testable import BeautifulMermaid

final class ClassSlice7Tests: XCTestCase {

    func test_direction_tb_default() throws {
        let source = "classDiagram\nclass A"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.direction, "TB")
    }

    func test_direction_lr() throws {
        let source = "classDiagram\ndirection LR\nclass A"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.direction, "LR")
    }

    func test_direction_bt() throws {
        let source = "classDiagram\ndirection BT\nclass A"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.direction, "BT")
    }

    func test_direction_rl() throws {
        let source = "classDiagram\ndirection RL\nclass A"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.direction, "RL")
    }

    func test_acctitle() throws {
        let source = "classDiagram\naccTitle: \"My Diagram\"\nclass A"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.accTitle, "\"My Diagram\"")
    }

    func test_accdescr() throws {
        let source = "classDiagram\naccDescr: \"Description\"\nclass A"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.accDescription, "\"Description\"")
    }

    func test_accdescr_multiline() throws {
        let source = "classDiagram\naccDescr {\n  Line 1\n  Line 2\n}\nclass A"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        XCTAssertNotNil(diagram.accDescription)
        XCTAssertTrue(diagram.accDescription!.contains("Line 1"))
    }

    func test_frontmatter_config_class_hide_empty() throws {
        let source = "---\nclass:\n  hideEmptyMembersBox: true\n---\nclassDiagram\nclass A"
        let (processed, fm) = _parseFrontMatterAndStripped(source)
        XCTAssertNotNil(fm)
        XCTAssertTrue(fm!.classConfig?.hideEmptyMembersBox ?? false)
    }

    func test_frontmatter_config_hierarchical() throws {
        let source = "---\nclass:\n  hierarchicalNamespaces: false\n---\nclassDiagram\nclass A"
        let (processed, fm) = _parseFrontMatterAndStripped(source)
        XCTAssertNotNil(fm)
        XCTAssertEqual(fm!.classConfig?.hierarchicalNamespaces, false)
    }

    func test_frontmatter_padding() throws {
        let source = "---\nclass:\n  padding: 20\n---\nclassDiagram\nclass A"
        let (processed, fm) = _parseFrontMatterAndStripped(source)
        XCTAssertNotNil(fm)
        XCTAssertEqual(fm!.classConfig?.padding, 20)
    }
}

private extension String {
    var splitByNewlines: [String] {
        self.split(separator: "\n").map(String.init)
    }
}

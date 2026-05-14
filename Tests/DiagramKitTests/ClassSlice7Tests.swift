import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class ClassSlice7Tests: XCTestCase {

    func test_direction_tb_default() throws {
        let source = "classDiagram\nclass A"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.direction, .TB)
    }

    func test_direction_lr() throws {
        let source = "classDiagram\ndirection LR\nclass A"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.direction, .LR)
    }

    func test_direction_bt() throws {
        let source = "classDiagram\ndirection BT\nclass A"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.direction, .BT)
    }

    func test_direction_rl() throws {
        let source = "classDiagram\ndirection RL\nclass A"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.direction, .RL)
    }

    func test_acctitle() throws {
        let source = "classDiagram\naccTitle: \"My Diagram\"\nclass A"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.accTitle, "\"My Diagram\"")
    }

    func test_accdescr() throws {
        let source = "classDiagram\naccDescr: \"Description\"\nclass A"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        XCTAssertEqual(diagram.accDescription, "\"Description\"")
    }

    func test_accdescr_multiline() throws {
        let source = "classDiagram\naccDescr {\n  Line 1\n  Line 2\n}\nclass A"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        XCTAssertNotNil(diagram.accDescription)
        XCTAssertTrue(diagram.accDescription!.contains("Line 1"))
    }

    func test_frontmatter_config_class_hide_empty() throws {
        let source = "---\nclass:\n  hideEmptyMembersBox: true\n---\nclassDiagram\nclass A"
        let (_, fm) = _parseFrontMatterAndStripped(source)
        XCTAssertNotNil(fm)
        XCTAssertTrue(fm!.classConfig?.hideEmptyMembersBox ?? false)
    }

    func test_frontmatter_config_hierarchical() throws {
        let source = "---\nclass:\n  hierarchicalNamespaces: false\n---\nclassDiagram\nclass A"
        let (_, fm) = _parseFrontMatterAndStripped(source)
        XCTAssertNotNil(fm)
        XCTAssertEqual(fm!.classConfig?.hierarchicalNamespaces, false)
    }

    func test_frontmatter_padding() throws {
        let source = "---\nclass:\n  padding: 20\n---\nclassDiagram\nclass A"
        let (_, fm) = _parseFrontMatterAndStripped(source)
        XCTAssertNotNil(fm)
        XCTAssertEqual(fm!.classConfig?.padding, 20)
    }

    func test_accessibility_in_svg() throws {
        let source = "classDiagram\naccTitle: \"Diagram Title\"\naccDescr: \"Diagram Description\"\nclass A"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        let positioned = try layoutClassDiagramSync(diagram)
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("<title>"))
        XCTAssertTrue(svg.contains("Diagram Title"))
        XCTAssertTrue(svg.contains("<desc>"))
        XCTAssertTrue(svg.contains("Diagram Description"))
    }

    func test_direction_lr_layout() throws {
        let source = "classDiagram\ndirection LR\nclass A\nclass B\nA --> B"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines)
        let positioned = try layoutClassDiagramSync(diagram)
        guard positioned.classes.count >= 2 else { XCTFail("Need at least 2 positioned classes"); return }
        let a = positioned.classes.first(where: { $0.id == "A" })!
        let b = positioned.classes.first(where: { $0.id == "B" })!
        XCTAssertGreaterThan(b.x, a.x, "With LR direction, B should be to the right of A")
    }

    func test_hide_empty_rendered() throws {
        let fm = DiagramFrontmatter(classConfig: ClassConfig(hideEmptyMembersBox: true))
        let source = "classDiagram\nclass Animal\nAnimal --> Dog"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines, frontmatter: fm)
        let positioned = try layoutClassDiagramSync(diagram)
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        // With hideEmptyMembersBox and no members, there should be NO divider lines
        let lineCount = svg.components(separatedBy: "<line").count - 1
        XCTAssertEqual(lineCount, 0, "hideEmptyMembersBox with no members should produce zero <line elements, got \(lineCount)")
    }

    func test_hide_empty_not_applied_when_members_present() throws {
        let fm = DiagramFrontmatter(classConfig: ClassConfig(hideEmptyMembersBox: true))
        let source = "classDiagram\nclass Animal {\n    +species string\n}\nAnimal --> Dog"
        let (diagram, _) = try parseClassDiagram(source.splitByNewlines, frontmatter: fm)
        let positioned = try layoutClassDiagramSync(diagram)
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        // Has members, so dividers should still appear
        XCTAssertTrue(svg.contains("<line"), "With members present, dividers should still render")
    }
}

private extension String {
    var splitByNewlines: [String] {
        self.split(separator: "\n").map(String.init)
    }
}

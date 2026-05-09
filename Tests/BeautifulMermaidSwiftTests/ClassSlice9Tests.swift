import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

final class ClassSlice9Tests: XCTestCase {

    func test_link_directive() throws {
        let source = "classDiagram\nclass Animal\nlink Animal \"https://example.com\" \"Click to learn more\""
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes.first!
        XCTAssertEqual(cls.link, "https://example.com")
        XCTAssertEqual(cls.tooltip, "Click to learn more")
        XCTAssertTrue(cls.cssClasses.contains("clickable"))
    }

    func test_link_with_target() throws {
        let source = "classDiagram\nclass Animal\nlink Animal \"https://example.com\" \"Click me\" _blank"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes.first!
        XCTAssertEqual(cls.linkTarget, "_blank")
    }

    func test_click_href() throws {
        let source = "classDiagram\nclass Animal\nclick Animal href \"https://example.com\" \"Animal info\" _self"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes.first!
        XCTAssertEqual(cls.link, "https://example.com")
        XCTAssertEqual(cls.tooltip, "Animal info")
        XCTAssertEqual(cls.linkTarget, "_self")
    }

    func test_click_callback() throws {
        let source = "classDiagram\nclass Animal\nclick Animal call callback() \"Click tooltip\""
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes.first!
        XCTAssertTrue(cls.haveCallback)
        XCTAssertEqual(cls.tooltip, "Click tooltip")
        XCTAssertTrue(cls.cssClasses.contains("clickable"))
    }

    func test_callback_directive() throws {
        let source = "classDiagram\nclass Animal\ncallback Animal \"myCallback\" \"Tooltip text\""
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let cls = diagram.classes.first!
        XCTAssertTrue(cls.haveCallback)
        XCTAssertEqual(cls.tooltip, "Tooltip text")
    }

    func test_interaction_data_in_svg() throws {
        let source = "classDiagram\nclass Animal\nlink Animal \"https://example.com\" \"Click to learn more\""
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let positioned = try layoutClassDiagramSync(diagram)
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("data-link"))
        XCTAssertTrue(svg.contains("https://example.com"))
    }

    func test_link_target_in_svg() throws {
        let source = "classDiagram\nclass Animal\nlink Animal \"https://example.com\" \"Click me\" _blank"
        let diagram = try parseClassDiagram(source.splitByNewlines)
        let positioned = try layoutClassDiagramSync(diagram)
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"))
        XCTAssertTrue(svg.contains("data-link-target=\"_blank\""))
    }

    func test_security_sandbox_suppresses_link_attrs() throws {
        let fm = DiagramFrontmatter(securityLevel: "sandbox")
        let source = "classDiagram\nclass Animal\nlink Animal \"https://example.com\" \"Click me\" _self"
        let diagram = try parseClassDiagram(source.splitByNewlines, frontmatter: fm)
        let positioned = try layoutClassDiagramSync(diagram)
        let svg = try renderClassSvg(positioned, DiagramColors(bg: "#fff", fg: "#000"), securityLevel: "sandbox")
        XCTAssertFalse(svg.contains("data-link="), "Sandbox mode should suppress data-link attributes")
        XCTAssertFalse(svg.contains("data-link-target="), "Sandbox mode should suppress data-link-target attributes")
        XCTAssertFalse(svg.contains("data-tooltip="), "Sandbox mode should suppress data-tooltip attributes")
    }

    func test_security_sandbox_target_top() throws {
        let fm = DiagramFrontmatter(securityLevel: "sandbox")
        let source = "classDiagram\nclass Animal\nlink Animal \"https://example.com\" \"Click me\" _blank"
        let diagram = try parseClassDiagram(source.splitByNewlines, frontmatter: fm)
        let cls = diagram.classes.first!
        XCTAssertEqual(cls.linkTarget, "_top", "Sandbox mode should force linkTarget to _top")
    }
}

private extension String {
    var splitByNewlines: [String] {
        self.split(separator: "\n").map(String.init)
    }
}

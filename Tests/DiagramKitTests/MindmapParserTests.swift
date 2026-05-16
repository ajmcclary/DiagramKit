import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class MindmapParserTests: XCTestCase {

    private func rawLines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    func test_simpleRoot() throws {
        let source = "mindmap\n  root"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertNotNil(diagram.root)
        XCTAssertEqual(diagram.root?.descr, "root")
        XCTAssertEqual(diagram.root?.level, 0)
        XCTAssertEqual(diagram.root?.type, .default)
        XCTAssertTrue(diagram.root?.isRoot ?? false)
    }

    func test_hierarchy() throws {
        let source = "mindmap\n  root\n    child1\n    child2"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.root?.children.count, 2)
        XCTAssertEqual(diagram.root?.children[0].descr, "child1")
        XCTAssertEqual(diagram.root?.children[1].descr, "child2")
    }

    func test_deepHierarchy() throws {
        let source = "mindmap\n  root\n    child1\n      leaf1\n    child2"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.nodes.count, 4)
        XCTAssertEqual(diagram.root?.children[0].children.count, 1)
        XCTAssertEqual(diagram.root?.children[0].children[0].descr, "leaf1")
    }

    func test_rootWithRectShape() throws {
        let source = "mindmap\n  root[The root]"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.root?.type, .rect)
        XCTAssertEqual(diagram.root?.descr, "The root")
        XCTAssertEqual(diagram.root?.nodeId, "root")
    }

    func test_roundedRect() throws {
        let source = "mindmap\n  root\n    theId(child1)"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        let child = diagram.root?.children.first
        XCTAssertEqual(child?.type, .roundedRect)
        XCTAssertEqual(child?.nodeId, "theId")
        XCTAssertEqual(child?.descr, "child1")
    }

    func test_circle() throws {
        let source = "mindmap\n root((the root))"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.root?.type, .circle)
        XCTAssertEqual(diagram.root?.descr, "the root")
    }

    func test_cloud() throws {
        let source = "mindmap\n root)the root("
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.root?.type, .cloud)
    }

    func test_bang() throws {
        let source = "mindmap\n root))the root(("
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.root?.type, .bang)
    }

    func test_hexagon() throws {
        let source = "mindmap\n root{{the root}}"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.root?.type, .hexagon)
    }

    func test_defaultShape() throws {
        let source = "mindmap\n  I am default"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.root?.type, .default)
        XCTAssertEqual(diagram.root?.descr, "I am default")
        XCTAssertEqual(diagram.root?.nodeId, "I am default")
    }

    func test_iconDecoration() throws {
        let source = "mindmap\n  root[Root]\n  ::icon(bomb)"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.nodes.first?.icon, "bomb")
    }

    func test_classDecoration() throws {
        let source = "mindmap\n  root[Root]\n  :::m-4 p-8"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.nodes.first?.cssClass, "m-4 p-8")
    }

    func test_bothDecorations_iconFirst() throws {
        let source = "mindmap\n  root\n  ::icon(bomb)\n  :::m-4 p-8"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.nodes.first?.icon, "bomb")
        XCTAssertEqual(diagram.nodes.first?.cssClass, "m-4 p-8")
    }

    func test_bothDecorations_classFirst() throws {
        let source = "mindmap\n  root\n  :::m-4 p-8\n  ::icon(bomb)"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.nodes.first?.icon, "bomb")
        XCTAssertEqual(diagram.nodes.first?.cssClass, "m-4 p-8")
    }

    func test_childrenAfterDecorations() throws {
        let source = "mindmap\n  root(Root)\n    Child(Child)\n    :::hot\n      a(a)"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        let root = diagram.root
        let child = root?.children.first
        XCTAssertEqual(child?.cssClass, "hot")
        XCTAssertEqual(child?.children.count, 1)
        XCTAssertEqual(child?.children[0].type, .roundedRect)
    }

    func test_bracketsInDescr() throws {
        let source = "mindmap\n  root[\"String containing []\"]"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.root?.descr, "String containing []")
    }

    func test_parensInDescr() throws {
        let source = "mindmap\n  root[\"String containing ()\"]"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.root?.descr, "String containing ()")
    }

    func test_markdownStrings() throws {
        let source = "mindmap\n  id1[\"`**bold** text`\"]"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertTrue(diagram.root?.descr.contains("**bold**") ?? false)
    }

    func test_multilineLabelInsideShape() throws {
        let source = "mindmap\n  root[First line\nsecond line]\n    child"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.nodes.count, 2)
        XCTAssertEqual(diagram.root?.descr, "First line\nsecond line")
        XCTAssertEqual(diagram.root?.children.first?.descr, "child")
    }

    func test_sanitizesNodeTextAndDecorations() throws {
        let source = "mindmap\n  root[<script>alert(1)</script>Root]\n  :::bad\" onclick=\"evil\n  ::icon(fa fa-book\" onload=\"evil)"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertFalse(diagram.root?.descr.contains("<script") ?? true)
        XCTAssertFalse(diagram.root?.cssClass?.contains("\"") ?? true)
        XCTAssertFalse(diagram.root?.icon?.contains("\"") ?? true)
    }

    func test_brInDescr() throws {
        let source = "mindmap\n  root[A<br/>B]"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertTrue(diagram.root?.descr.contains("<br/>") ?? false)
    }

    func test_emptyRows() throws {
        let source = "mindmap\n  root\n    A\n\n    B"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.nodes.count, 3)
    }

    func test_percentComments() throws {
        let source = "mindmap\n  root\n    A\n    %% comment\n    B"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.nodes.count, 3)
    }

    func test_inlineComments() throws {
        let source = "mindmap\n  root\n    A %% comment"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        let aNode = diagram.root?.children.first
        XCTAssertEqual(aNode?.descr, "A")
    }

    func test_spacesOnlyRows() throws {
        let source = "mindmap\nroot\n A\n   \n B"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertEqual(diagram.nodes.count, 3)
    }

    func test_leadingWhitespace() throws {
        let source = "\n \nmindmap\nroot\n A"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        XCTAssertNotNil(diagram.root)
    }

    func test_multipleRootsError() throws {
        let source = "mindmap\n  root\n  fakeRoot"
        XCTAssertThrowsError(try parseMindmap(rawLines(source), frontmatter: nil)) { error in
            guard let mindmapError = error as? MindmapParserError else {
                XCTFail("Expected MindmapParserError, got \(error)")
                return
            }
            if case .multipleRoots(let desc) = mindmapError {
                XCTAssertEqual(desc, "fakeRoot")
            } else {
                XCTFail("Expected multipleRoots, got \(mindmapError)")
            }
        }
    }

    func test_unclearIndentation() throws {
        let source = "mindmap\n  root\n        B\n      C"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        let children = diagram.root?.children ?? []
        XCTAssertEqual(children.count, 2)
        XCTAssertTrue(children.contains(where: { $0.descr == "B" }))
        XCTAssertTrue(children.contains(where: { $0.descr == "C" }))
    }

    func test_emptyDocumentError() throws {
        let source = "mindmap"
        XCTAssertThrowsError(try parseMindmap(rawLines(source), frontmatter: nil)) { error in
            guard let mindmapError = error as? MindmapParserError else {
                XCTFail("Expected MindmapParserError, got \(error)")
                return
            }
            if case .emptyDocument = mindmapError { } else {
                XCTFail("Expected emptyDocument, got \(mindmapError)")
            }
        }
    }

    func test_labelContainingGraph() throws {
        let source = "mindmap\n  root\n    Photograph"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: nil)
        let child = diagram.root?.children.first
        XCTAssertEqual(child?.descr, "Photograph")
    }

    func test_frontmatterConfig() throws {
        let fm = DiagramFrontmatter.with { $0.perDiagram.mindmap.config = MindmapConfig(padding: 20, maxNodeWidth: 300) }
        let source = "mindmap\n  root\n    A"
        let (diagram, _) = try parseMindmap(rawLines(source), frontmatter: fm)
        XCTAssertEqual(diagram.config.padding, 20)
        XCTAssertEqual(diagram.config.maxNodeWidth, 300)
    }
}

import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class MindmapModelTests: XCTestCase {

    func test_sectionAssignment_rootNil() throws {
        let source = "mindmap\n  root\n    A\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        XCTAssertNil(diagram.root?.section)
    }

    func test_sectionAssignment_childrenNumbered() throws {
        let source = "mindmap\n  root\n    A\n    B\n    C"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let children = diagram.root?.children ?? []
        XCTAssertEqual(children.count, 3)
        XCTAssertEqual(children[0].section, 0)
        XCTAssertEqual(children[1].section, 1)
        XCTAssertEqual(children[2].section, 2)
    }

    func test_sectionAssignment_grandchildInherits() throws {
        let source = "mindmap\n  root\n    A\n      A1\n    B\n      B1"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let children = diagram.root?.children ?? []
        let a = children.first(where: { $0.descr == "A" })
        let b = children.first(where: { $0.descr == "B" })
        XCTAssertEqual(a?.section, 0)
        XCTAssertEqual(b?.section, 1)
        XCTAssertEqual(a?.children.first?.section, 0)
        XCTAssertEqual(b?.children.first?.section, 1)
    }

    func test_sectionWrappingAfter11() throws {
        var source = "mindmap\n  root"
        for i in 0..<15 {
            source += "\n    Node\(i)"
        }
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let children = diagram.root?.children ?? []
        XCTAssertEqual(children.count, 15)
        XCTAssertEqual(children[0].section, 0)
        XCTAssertEqual(children[10].section, 10)
        XCTAssertEqual(children[11].section, 0)
        XCTAssertEqual(children[14].section, 3)
    }

    func test_edgeIdGeneration() throws {
        let source = "mindmap\n  root\n    A\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let (_, edges) = generateMindmapLayoutData(diagram)
        XCTAssertEqual(edges.count, 2)
        XCTAssertTrue(edges.allSatisfy { $0.id.hasPrefix("edge_") })
        let ids = Set(edges.map(\.id))
        XCTAssertEqual(ids.count, 2)
    }

    func test_edgeClassGeneration() throws {
        let source = "mindmap\n  root\n    A\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let (_, edges) = generateMindmapLayoutData(diagram)
        let edge = edges.first!
        XCTAssertTrue(edge.edgeCssClass.contains("edge"))
        XCTAssertTrue(edge.edgeCssClass.contains("edge-depth-"))
    }

    func test_shapeNameMapping_default() {
        let pn = PositionedMindmapNode(id: 0, nodeId: "test", descr: "test", type: .default, level: 0, section: nil, cssClass: nil, icon: nil, isRoot: true, shapeName: MindmapNodeType.default.rendererShapeName)
        XCTAssertEqual(pn.shapeName, "defaultMindmapNode")
    }

    func test_shapeNameMapping_circle() {
        XCTAssertEqual(MindmapNodeType.circle.rendererShapeName, "mindmapCircle")
    }

    func test_shapeNameMapping_rect() {
        XCTAssertEqual(MindmapNodeType.rect.rendererShapeName, "rect")
    }

    func test_noFakeRootNode() throws {
        let source = "mindmap\n  root\n    A"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        XCTAssertFalse(diagram.nodes.contains(where: { $0.descr == "mindmap" }))
    }

    func test_flatNodesIncludesAll() throws {
        let source = "mindmap\n  root\n    A\n      A1\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        guard let root = diagram.root else { XCTFail("No root"); return }
        let flat = flattenMindmapNodes(root)
        XCTAssertEqual(flat.count, 4)
    }
}

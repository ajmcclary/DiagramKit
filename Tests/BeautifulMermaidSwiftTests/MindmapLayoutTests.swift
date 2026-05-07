import XCTest
@testable import BeautifulMermaid

final class MindmapLayoutTests: XCTestCase {

    func test_singleRoot_noChildren() throws {
        let source = "mindmap\n  root"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let positioned = try layoutMindmap(diagram)
        XCTAssertEqual(positioned.nodes.count, 1)
        XCTAssertEqual(positioned.edges.count, 0)
        let root = positioned.nodes.first!
        XCTAssertEqual(root.x, positioned.width / 2, accuracy: 5)
        XCTAssertEqual(root.y, positioned.height / 2, accuracy: 5)
    }

    func test_rootWithTwoChildren_oppositeSides() throws {
        let source = "mindmap\n  root\n    A\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let positioned = try layoutMindmap(diagram)
        XCTAssertEqual(positioned.nodes.count, 3)
        XCTAssertEqual(positioned.edges.count, 2)

        let root = positioned.nodes.first(where: { $0.isRoot })!
        let a = positioned.nodes.first(where: { $0.descr == "A" })!
        let b = positioned.nodes.first(where: { $0.descr == "B" })!

        XCTAssertTrue(a.x < root.x, "A should be on left side")
        XCTAssertTrue(b.x > root.x, "B should be on right side")
    }

    func test_deepHierarchy_positionsDescendantsFartherFromRoot() throws {
        let source = "mindmap\n  root\n    A\n      A1\n        A2\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let positioned = try layoutMindmap(diagram)

        let root = positioned.nodes.first(where: { $0.isRoot })!
        let a = positioned.nodes.first(where: { $0.descr == "A" })!
        let a1 = positioned.nodes.first(where: { $0.descr == "A1" })!
        let a2 = positioned.nodes.first(where: { $0.descr == "A2" })!

        XCTAssertGreaterThan(abs(a1.x - root.x), abs(a.x - root.x))
        XCTAssertGreaterThan(abs(a2.x - root.x), abs(a1.x - root.x))
    }

    func test_defaultLayout_usesTidyTree() throws {
        // No explicit config.layout — default layoutAlgorithm "tidy-tree" takes effect.
        let source = "mindmap\n  root\n    A"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let positioned = try layoutMindmap(diagram)
        XCTAssertTrue(positioned.width > 0)
        XCTAssertTrue(positioned.height > 0)
    }

    func test_explicitCoseBilkent_throwsNotYetImplemented() throws {
        let source = "mindmap\n  root\n    A"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        var configured = diagram
        configured.config.layout = "cose-bilkent"
        XCTAssertThrowsError(try layoutMindmap(configured)) { error in
            guard let bmError = error as? BeautifulMermaidError else {
                XCTFail("Expected BeautifulMermaidError, got \(error)")
                return
            }
            if case .notYetImplemented(let msg) = bmError {
                XCTAssertTrue(msg.contains("cose-bilkent"))
            } else {
                XCTFail("Expected notYetImplemented, got \(bmError)")
            }
        }
    }

    func test_explicitTidyTree_succeeds() throws {
        let source = "mindmap\n  root\n    A\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let positioned = try layoutMindmap(diagram)
        XCTAssertTrue(positioned.width > 0)
        XCTAssertTrue(positioned.height > 0)
    }

    func test_edgePaths_produced() throws {
        let source = "mindmap\n  root\n    A\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let positioned = try layoutMindmap(diagram)
        for edge in positioned.edges {
            XCTAssertNotNil(edge.path)
            XCTAssertFalse(edge.path?.isEmpty ?? true)
        }
    }

    func test_viewport_largerThanNodes() throws {
        let source = "mindmap\n  root\n    child1\n      grandchild1\n    child2\n      grandchild2"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let positioned = try layoutMindmap(diagram)
        let maxNodeX = positioned.nodes.map { $0.x + $0.width / 2 }.max() ?? 0
        let maxNodeY = positioned.nodes.map { $0.y + $0.height / 2 }.max() ?? 0
        XCTAssertGreaterThan(positioned.width, maxNodeX)
        XCTAssertGreaterThan(positioned.height, maxNodeY)
    }

    func test_frontmatterTidyTreeLayout() throws {
        let fm = DiagramFrontmatter(
            mindmapConfig: MindmapConfig(padding: 10, maxNodeWidth: 200),
            layout: "tidy-tree"
        )
        let source = "mindmap\n  root\n    A\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: fm)
        let positioned = try layoutMindmap(diagram)
        XCTAssertTrue(positioned.width > 0)
    }
}

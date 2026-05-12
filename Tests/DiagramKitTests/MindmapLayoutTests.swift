import CoreGraphics
import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

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
            guard let bmError = error as? DiagramError else {
                XCTFail("Expected DiagramError, got \(error)")
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

    func test_tidyTreeSeparatesNodeBoundsForWideAndDeepExamples() throws {
        let sources = [
            "wide siblings": "mindmap\n  id1[**Root** with\na second line]\n    id2[The dog in **the** hog]\n    id3[Regular labels still works]",
            "deep branches": "mindmap\n  root\n    child1\n      grandchild1\n        greatgrandchild1\n      grandchild2\n    child2\n      grandchild3\n      grandchild4\n    child3\n      grandchild5\n      grandchild6",
            "many siblings": "mindmap\n  root\n    Node1\n    Node2\n    Node3\n    Node4\n    Node5\n    Node6\n    Node7\n    Node8\n    Node9\n    Node10\n    Node11\n    Node12\n    Node13\n    Node14\n    Node15"
        ]

        for (name, source) in sources {
            let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
            let positioned = try layoutMindmap(diagram)
            assertNoMindmapNodeIntersections(positioned, name: name)
        }
    }

    func test_tidyTreeSizesLongLabelsToAvoidClipping() throws {
        let source = "mindmap\n  root((mindmap))\n    Origins\n      British popular psychology author Tony Buzan"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: nil)
        let positioned = try layoutMindmap(diagram)

        let longLabel = try XCTUnwrap(positioned.nodes.first { $0.descr == "British popular psychology author Tony Buzan" })
        XCTAssertGreaterThan(longLabel.width, diagram.config.maxNodeWidth * 1.5)
    }

    // MARK: - Frontmatter layoutAlgorithm tests

    func test_frontmatterLayoutAlgorithm_tidyTree_succeeds() throws {
        // config.mindmap.layoutAlgorithm: tidy-tree should work
        let fm = DiagramFrontmatter(
            mindmapConfig: MindmapConfig(padding: 10, maxNodeWidth: 200, layoutAlgorithm: "tidy-tree"),
            layout: nil
        )
        let source = "mindmap\n  root\n    A\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: fm)
        let positioned = try layoutMindmap(diagram)
        XCTAssertTrue(positioned.width > 0)
        XCTAssertTrue(positioned.height > 0)
    }

    func test_frontmatterLayoutAlgorithm_coseBilkent_throws() throws {
        // config.mindmap.layoutAlgorithm: cose-bilkent should throw notYetImplemented
        let fm = DiagramFrontmatter(
            mindmapConfig: MindmapConfig(padding: 10, maxNodeWidth: 200, layoutAlgorithm: "cose-bilkent"),
            layout: nil
        )
        let source = "mindmap\n  root\n    A\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: fm)
        XCTAssertThrowsError(try layoutMindmap(diagram)) { error in
            guard let bmError = error as? DiagramError else {
                XCTFail("Expected DiagramError, got \(error)")
                return
            }
            if case .notYetImplemented(let msg) = bmError {
                XCTAssertTrue(msg.contains("cose-bilkent"), "Message should mention cose-bilkent, got: \(msg)")
                XCTAssertTrue(msg.contains("tidy-tree"), "Message should suggest tidy-tree, got: \(msg)")
            } else {
                XCTFail("Expected notYetImplemented, got \(bmError)")
            }
        }
    }

    // MARK: - Global layout precedence tests

    func test_globalLayout_tidyTree_overrides_layoutAlgorithm_coseBilkent() throws {
        // config.layout: tidy-tree should override config.mindmap.layoutAlgorithm: cose-bilkent
        let fm = DiagramFrontmatter(
            mindmapConfig: MindmapConfig(padding: 10, maxNodeWidth: 200, layoutAlgorithm: "cose-bilkent"),
            layout: "tidy-tree"
        )
        let source = "mindmap\n  root\n    A\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: fm)
        // resolvedLayout = layout ?? layoutAlgorithm = "tidy-tree"
        XCTAssertEqual(diagram.config.resolvedLayout, "tidy-tree", "Global layout should override mindmap.layoutAlgorithm")
        let positioned = try layoutMindmap(diagram)
        XCTAssertTrue(positioned.width > 0)
    }

    func test_globalLayout_coseBilkent_overrides_layoutAlgorithm_tidyTree() throws {
        // config.layout: cose-bilkent should override config.mindmap.layoutAlgorithm: tidy-tree
        let fm = DiagramFrontmatter(
            mindmapConfig: MindmapConfig(padding: 10, maxNodeWidth: 200, layoutAlgorithm: "tidy-tree"),
            layout: "cose-bilkent"
        )
        let source = "mindmap\n  root\n    A\n    B"
        let diagram = try parseMindmap(source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), frontmatter: fm)
        // resolvedLayout = layout ?? layoutAlgorithm = "cose-bilkent"
        XCTAssertEqual(diagram.config.resolvedLayout, "cose-bilkent", "Global layout should override mindmap.layoutAlgorithm")
        XCTAssertThrowsError(try layoutMindmap(diagram)) { error in
            guard let bmError = error as? DiagramError else {
                XCTFail("Expected DiagramError, got \(error)")
                return
            }
            if case .notYetImplemented(let msg) = bmError {
                XCTAssertTrue(msg.contains("cose-bilkent"))
            } else {
                XCTFail("Expected notYetImplemented, got \(bmError)")
            }
        }
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

    private func assertNoMindmapNodeIntersections(
        _ positioned: PositionedMindmapDiagram,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let boxes = positioned.nodes.map { node in
            (
                node: node,
                rect: CGRect(
                    x: node.x - node.width / 2,
                    y: node.y - node.height / 2,
                    width: node.width,
                    height: node.height
                )
            )
        }

        for lhsIndex in boxes.indices {
            for rhsIndex in boxes.index(after: lhsIndex)..<boxes.endIndex {
                let lhs = boxes[lhsIndex]
                let rhs = boxes[rhsIndex]
                if lhs.rect.intersects(rhs.rect) {
                    XCTFail(
                        "\(name): node '\(lhs.node.descr)' intersects '\(rhs.node.descr)' (\(lhs.rect) vs \(rhs.rect))",
                        file: file,
                        line: line
                    )
                }
            }
        }
    }
}

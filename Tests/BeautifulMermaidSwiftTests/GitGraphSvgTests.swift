import XCTest
@testable import BeautifulMermaid

final class GitGraphSvgTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func renderSvg(_ source: String) throws -> String {
        let diagram = try parseGitGraph(lines(source), frontmatter: nil)
        let positioned = layoutGitGraph(diagram)
        return renderGitGraphSvg(positioned)
    }

    // MARK: - SVG structure

    func testRootSvgViewBox() throws {
        let svg = try renderSvg("gitGraph\n   commit\n   commit")
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("viewBox="))
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func testCommitBulletsGroup() throws {
        let svg = try renderSvg("gitGraph\n   commit")
        XCTAssertTrue(svg.contains("<g class=\"commit-bullets\">"))
        XCTAssertTrue(svg.contains("</g>"))
    }

    func testCommitBulletCircles() throws {
        let svg = try renderSvg("gitGraph\n   commit\n   commit")
        XCTAssertTrue(svg.contains("<circle"))
    }

    // MARK: - Commit types

    func testHighlightCommitRendersRect() throws {
        let svg = try renderSvg("gitGraph\n   commit type:HIGHLIGHT")
        XCTAssertTrue(svg.contains("<rect"))
    }

    func testReverseCommitRendersCross() throws {
        let svg = try renderSvg("gitGraph\n   commit type:REVERSE")
        XCTAssertTrue(svg.contains("M "))
    }

    func testMergeCommitRendersDoubleCircle() throws {
        let svg = try renderSvg("gitGraph\n   commit\n   branch dev\n   commit\n   checkout main\n   merge dev")
        XCTAssertTrue(svg.contains("commit-merge"))
    }

    func testCherryPickCommitRendersCherry() throws {
        let svg = try renderSvg("gitGraph\n   commit id:\"A\"\n   branch dev\n   commit id:\"B\"\n   checkout main\n   cherry-pick id:\"B\"")
        XCTAssertTrue(svg.contains("commit-cherry-pick"))
    }

    // MARK: - Labels

    func testCommitLabelsGroup() throws {
        let svg = try renderSvg("gitGraph\n   commit id:\"myId\"\n   commit id:\"yourId\"")
        XCTAssertTrue(svg.contains("<g class=\"commit-labels\">"))
    }

    func testShowCommitLabelFalse() throws {
        var config = GitGraphConfig()
        config.showCommitLabel = false
        let diagram = try parseGitGraph(lines("gitGraph\n   commit id:\"X\""), frontmatter: DiagramFrontmatter(gitGraphConfig: config))
        let positioned = layoutGitGraph(diagram)
        let svg = renderGitGraphSvg(positioned)
        XCTAssertFalse(svg.contains("commit-labels"))
    }

    // MARK: - Arrows

    func testCommitArrowsGroup() throws {
        let svg = try renderSvg("gitGraph\n   commit\n   commit")
        XCTAssertTrue(svg.contains("<g class=\"commit-arrows\">"))
        XCTAssertTrue(svg.contains("<path"))
    }

    // MARK: - Branches

    func testBranchLinesPresent() throws {
        let svg = try renderSvg("gitGraph\n   commit\n   commit")
        XCTAssertTrue(svg.contains("class=\"branch branch"))
        XCTAssertTrue(svg.contains("<line"))
    }

    func testShowBranchesFalse() throws {
        var config = GitGraphConfig()
        config.showBranches = false
        let diagram = try parseGitGraph(lines("gitGraph\n   commit"), frontmatter: DiagramFrontmatter(gitGraphConfig: config))
        let positioned = layoutGitGraph(diagram)
        let svg = renderGitGraphSvg(positioned)
        XCTAssertFalse(svg.contains("stroke-dasharray"))
    }

    // MARK: - Branch labels

    func testBranchLabelsPresent() throws {
        let svg = try renderSvg("gitGraph\n   commit\n   branch dev\n   commit")
        XCTAssertTrue(svg.contains("branchLabel"))
        XCTAssertTrue(svg.contains("branch-label"))
    }

    // MARK: - Accessibility

    func testAccTitleInSvg() throws {
        let svg = try renderSvg("gitGraph\n   accTitle: Test Title\n   commit")
        XCTAssertTrue(svg.contains("<title>Test Title</title>"))
    }

    func testAccDescrInSvg() throws {
        let svg = try renderSvg("gitGraph\n   accDescr: Test Desc\n   commit")
        XCTAssertTrue(svg.contains("<desc>Test Desc</desc>"))
    }

    func testDiagramTitleInSvg() throws {
        let svg = try renderSvg("gitGraph\n   title My Title\n   commit")
        XCTAssertTrue(svg.contains("gitTitleText"))
        XCTAssertTrue(svg.contains("My Title"))
    }

    // MARK: - Tags

    func testTagPresent() throws {
        let svg = try renderSvg("gitGraph\n   commit tag:\"v1.0\"")
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("<g class=\"commit-bullets\">"))
    }

    // MARK: - Viewport

    func testViewPortDimensions() throws {
        let svg = try renderSvg("gitGraph\n   commit\n   commit\n   commit")
        XCTAssertTrue(svg.contains("width="))
        XCTAssertTrue(svg.contains("height="))
    }
}

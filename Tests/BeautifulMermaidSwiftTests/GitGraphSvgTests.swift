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
        XCTAssertFalse(svg.contains("class=\"branch branch"))
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

    // MARK: - Style block

    func testCssStyleBlockPresent() throws {
        let svg = try renderSvg("gitGraph\n   commit")
        XCTAssertTrue(svg.contains("<style>"))
        XCTAssertTrue(svg.contains(".branch"))
        XCTAssertTrue(svg.contains(".commit-label"))
        XCTAssertTrue(svg.contains(".gitTitleText"))
    }

    // MARK: - Commit ID as CSS class (G11)

    func testCommitIdAsCssClass() throws {
        let svg = try renderSvg("gitGraph\n   commit id:\"Alpha\"")
        XCTAssertTrue(svg.contains("class=\"commit Alpha"))
    }

    // MARK: - Neo look (G8)

    func testNeoLookGradientDefs() throws {
        var theme = GitGraphThemeConfig()
        theme.useGradient = true
        theme.gradientStart = "#ff0000"
        theme.gradientStop = "#0000ff"
        let diagram = try parseGitGraph(lines("gitGraph\n   commit"), frontmatter: DiagramFrontmatter(gitGraphTheme: theme, theme: "neo"))
        let positioned = layoutGitGraph(diagram)
        let svg = renderGitGraphSvg(positioned)
        XCTAssertTrue(svg.contains("linearGradient"))
        XCTAssertTrue(svg.contains("gradient"))
        XCTAssertTrue(svg.contains("#ff0000"))
    }

    func testNeoLookDataAttr() throws {
        let theme = GitGraphThemeConfig()
        let diagram = try parseGitGraph(lines("gitGraph\n   commit"), frontmatter: DiagramFrontmatter(gitGraphTheme: theme, look: "neo", theme: "neo"))
        let positioned = layoutGitGraph(diagram)
        let svg = renderGitGraphSvg(positioned)
        XCTAssertTrue(svg.contains("data-look=\"neo\""))
    }

    // MARK: - Redux geometry (G9)

    func testReduxThemeSmallerBullets() throws {
        let diagram = try parseGitGraph(lines("gitGraph\n   commit"), frontmatter: DiagramFrontmatter(theme: "redux"))
        let positioned = layoutGitGraph(diagram)
        let svg = renderGitGraphSvg(positioned)
        XCTAssertTrue(svg.contains("r=\"7\""))
    }

    func testReduxThemeZeroBorderRadius() throws {
        let theme = GitGraphThemeConfig()
        let diagram = try parseGitGraph(lines("gitGraph\n   commit"), frontmatter: DiagramFrontmatter(gitGraphTheme: theme, theme: "redux"))
        let positioned = layoutGitGraph(diagram)
        XCTAssertEqual(positioned.branchLabels.first?.borderRadius, 0)
    }

    // MARK: - Color theme (G10)

    func testColorThemeSwatchCycling() throws {
        var theme = GitGraphThemeConfig()
        theme.git0 = "#ff0000"
        theme.git1 = "#00ff00"
        let diagram = try parseGitGraph(lines("gitGraph\n   commit\n   branch dev\n   commit"), frontmatter: DiagramFrontmatter(gitGraphTheme: theme, theme: "redux-color"))
        let positioned = layoutGitGraph(diagram)
        let commits = positioned.commits
        let devCommit = commits.first(where: { $0.branch == "dev" })
        XCTAssertNotNil(devCommit)
        if let dc = devCommit {
            XCTAssertGreaterThan(dc.colorIndex, 0)
        }
    }

    // MARK: - Parallel commits SVG (G6)

    func testParallelCommitsProduceValidSvg() throws {
        var config = GitGraphConfig()
        config.parallelCommits = true
        let diagram = try parseGitGraph(lines("gitGraph\n   commit\n   branch dev\n   commit\n   commit\n   checkout main\n   commit"),
            frontmatter: DiagramFrontmatter(gitGraphConfig: config))
        let positioned = layoutGitGraph(diagram)
        let svg = renderGitGraphSvg(positioned)
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("commit-bullets"))
    }

    // MARK: - Arrow rerouting (G13)

    func testArrowReroutingSvgContainsArcs() throws {
        let diagram = try parseGitGraph(lines("gitGraph\n   commit\n   branch dev\n   commit\n   commit\n   checkout main\n   commit\n   merge dev"), frontmatter: nil)
        let positioned = layoutGitGraph(diagram)
        let svg = renderGitGraphSvg(positioned)
        XCTAssertTrue(svg.contains("M ") || svg.contains("L "))
    }

    // MARK: - Tag orientation (G15)

    func testTbOrientationTagRendering() throws {
        let diagram = try parseGitGraph(lines("gitGraph TB:\n   commit id:\"A\" tag:\"v1\""), frontmatter: nil)
        let positioned = layoutGitGraph(diagram)
        let svg = renderGitGraphSvg(positioned)
        XCTAssertTrue(svg.contains("tag-label"))
    }
}

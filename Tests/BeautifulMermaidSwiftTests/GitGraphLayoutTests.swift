import XCTest
@testable import BeautifulMermaid

final class GitGraphLayoutTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func parseAndLayout(_ source: String) throws -> PositionedGitGraphDiagram {
        let diagram = try parseGitGraph(lines(source), frontmatter: nil)
        return layoutGitGraph(diagram)
    }

    // MARK: - Branch positioning

    func testLRBranchVerticalStacking() throws {
        let positioned = try parseAndLayout("gitGraph\n   commit\n   branch dev\n   commit")
        XCTAssertEqual(positioned.branchLines.count, 2)
        let mainLine = positioned.branchLines.first(where: { $0.branch == "main" })!
        let devLine = positioned.branchLines.first(where: { $0.branch == "dev" })!
        XCTAssertNotEqual(mainLine.y1, devLine.y1)
    }

    func testBranchLabelsPresent() throws {
        let positioned = try parseAndLayout("gitGraph\n   commit\n   branch dev\n   commit")
        XCTAssertFalse(positioned.branchLabels.isEmpty)
        let mainLabel = positioned.branchLabels.first(where: { $0.branch == "main" })
        let devLabel = positioned.branchLabels.first(where: { $0.branch == "dev" })
        XCTAssertNotNil(mainLabel)
        XCTAssertNotNil(devLabel)
    }

    // MARK: - Commit positioning

    func testCommitSequentialPositionsLR() throws {
        let positioned = try parseAndLayout("gitGraph\n   commit\n   commit\n   commit")
        let commits = positioned.commits.sorted { $0.posWithOffset < $1.posWithOffset }
        XCTAssertEqual(commits.count, 3)
        for i in 1..<commits.count {
            XCTAssertGreaterThan(commits[i].x, commits[i - 1].x)
        }
    }

    func testCommitPositionsAvailable() throws {
        let positioned = try parseAndLayout("gitGraph\n   commit\n   commit")
        XCTAssertEqual(positioned.commits.count, 2)
        for commit in positioned.commits {
            XCTAssertFalse(commit.id.isEmpty)
        }
    }

    // MARK: - Branch lines

    func testBranchLinesSpan() throws {
        let positioned = try parseAndLayout("gitGraph\n   commit\n   commit")
        let mainLine = positioned.branchLines.first(where: { $0.branch == "main" })!
        XCTAssertNotNil(mainLine)
        XCTAssertGreaterThan(mainLine.x2, mainLine.x1)
    }

    // MARK: - Arrow routing

    func testArrowBetweenParentChild() throws {
        let positioned = try parseAndLayout("gitGraph\n   commit\n   commit")
        let commits = positioned.commits.sorted { $0.posWithOffset < $1.posWithOffset }
        let arrows = positioned.arrows.filter { $0.parentCommitID == commits[0].id && $0.childCommitID == commits[1].id }
        XCTAssertFalse(arrows.isEmpty)
    }

    func testArrowSegmentsNotEmpty() throws {
        let positioned = try parseAndLayout("gitGraph\n   commit\n   commit")
        for arrow in positioned.arrows {
            XCTAssertFalse(arrow.segments.isEmpty)
        }
    }

    // MARK: - Merge arrows

    func testMergeArrowFromTwoParents() throws {
        let positioned = try parseAndLayout("gitGraph\n   commit\n   branch dev\n   commit\n   checkout main\n   merge dev")
        let mergeCommit = positioned.commits.first(where: { $0.type == .merge })!
        let mergeArrows = positioned.arrows.filter { $0.childCommitID == mergeCommit.id }
        XCTAssertEqual(mergeArrows.count, 2)
    }

    // MARK: - Viewport sizing

    func testViewBoxNonZero() throws {
        let positioned = try parseAndLayout("gitGraph\n   commit\n   commit")
        XCTAssertGreaterThan(positioned.width, 0)
        XCTAssertGreaterThan(positioned.height, 0)
    }

    // MARK: - Config: showBranches false

    func testShowBranchesFalse() throws {
        var config = GitGraphConfig()
        config.showBranches = false
        let diagram = try parseGitGraph(lines("gitGraph\n   commit"), frontmatter: DiagramFrontmatter(gitGraphConfig: config))
        let positioned = layoutGitGraph(diagram)
        XCTAssertEqual(positioned.branchLines.count, 1)
    }

    // MARK: - Parallel commits (G6)

    func testParallelCommitsAlignsRoots() throws {
        var config = GitGraphConfig()
        config.parallelCommits = true
        let diagram = try parseGitGraph(lines("gitGraph\n   commit id:\"A\"\n   branch dev\n   commit id:\"B\"\n   checkout main\n   commit id:\"C\""), frontmatter: DiagramFrontmatter(gitGraphConfig: config))
        let positioned = layoutGitGraph(diagram)
        let posA = positioned.commits.first(where: { $0.id == "A" })
        let posB = positioned.commits.first(where: { $0.id == "B" })
        let posC = positioned.commits.first(where: { $0.id == "C" })
        XCTAssertNotNil(posA)
        XCTAssertNotNil(posB)
        XCTAssertNotNil(posC)
        if let a = posA, let b = posB {
            XCTAssertGreaterThan(b.x, a.x)
        }
    }

    func testParallelCommitsBtOrientationDoesNotCrash() throws {
        var config = GitGraphConfig()
        config.parallelCommits = true
        let diagram = try parseGitGraph(lines("gitGraph BT:\n   commit\n   branch dev\n   commit\n   commit\n   checkout main\n   commit"),
            frontmatter: DiagramFrontmatter(gitGraphConfig: config))
        let positioned = layoutGitGraph(diagram)
        XCTAssertGreaterThan(positioned.commits.count, 0)
    }

    func testParallelCommitsTbOrientation() throws {
        var config = GitGraphConfig()
        config.parallelCommits = true
        let diagram = try parseGitGraph(lines("gitGraph TB:\n   commit\n   commit\n   branch dev\n   commit"),
            frontmatter: DiagramFrontmatter(gitGraphConfig: config))
        let positioned = layoutGitGraph(diagram)
        XCTAssertEqual(positioned.commits.count, 3)
    }

    // MARK: - Theme geometry layout

    func testReduxThemeBranchLabelNoBorderRadius() throws {
        let diagram = try parseGitGraph(lines("gitGraph\n   commit\n   branch dev\n   commit"),
            frontmatter: DiagramFrontmatter(theme: "redux"))
        let positioned = layoutGitGraph(diagram)
        XCTAssertEqual(positioned.branchLabels.first?.borderRadius, 0)
    }

    func testReduxThemeBranchLabelPadding() throws {
        let diagram = try parseGitGraph(lines("gitGraph\n   commit\n   branch dev\n   commit"),
            frontmatter: DiagramFrontmatter(theme: "redux"))
        let positioned = layoutGitGraph(diagram)
        for label in positioned.branchLabels {
            XCTAssertGreaterThan(label.bkgWidth, 20)
        }
    }

    // MARK: - Diagram types

    func testBTOrientation() throws {
        let positioned = try parseAndLayout("gitGraph BT:\n   commit\n   commit")
        XCTAssertGreaterThan(positioned.width, 0)
        XCTAssertGreaterThan(positioned.height, 0)
    }

    // MARK: - Title

    func testTitleInLayout() throws {
        let positioned = try parseAndLayout("gitGraph\n   title Test Title\n   commit")
        XCTAssertNotNil(positioned.title)
        XCTAssertEqual(positioned.title?.text, "Test Title")
    }
}

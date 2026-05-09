import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class GitGraphLayoutTests: XCTestCase {

    private struct Bounds {
        var minX: Double = .infinity
        var minY: Double = .infinity
        var maxX: Double = -.infinity
        var maxY: Double = -.infinity

        mutating func include(x1: Double, y1: Double, x2: Double, y2: Double) {
            minX = min(minX, x1, x2)
            minY = min(minY, y1, y2)
            maxX = max(maxX, x1, x2)
            maxY = max(maxY, y1, y2)
        }
    }

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func parseAndLayout(_ source: String) throws -> PositionedGitGraphDiagram {
        let diagram = try parseGitGraph(lines(source), frontmatter: nil)
        return layoutGitGraph(diagram)
    }

    private func renderedBounds(_ positioned: PositionedGitGraphDiagram) -> Bounds {
        var bounds = Bounds()
        let isVertical = positioned.direction == .TB || positioned.direction == .BT
        let nodeRadius: Double = _gitGraphIsReduxGeometry(positioned.themeName) ? 7 : 10

        for commit in positioned.commits {
            bounds.include(
                x1: commit.x - nodeRadius,
                y1: commit.y - nodeRadius,
                x2: commit.x + nodeRadius,
                y2: commit.y + nodeRadius
            )

            if positioned.config.showCommitLabel, commit.showLabel {
                let labelLen = Double(commit.id.count) * 4
                if isVertical {
                    let lx = commit.x - labelLen * 2 - 20
                    let ly = commit.y
                    bounds.include(x1: lx - 4, y1: ly - 8, x2: lx - 4 + labelLen * 4 + 8, y2: ly + 8)
                } else {
                    let lx = commit.x - labelLen
                    let ly = commit.y + 20
                    bounds.include(x1: lx - 4, y1: ly - 4, x2: lx + labelLen * 2 + 4, y2: ly + 14)
                }
            }

            for (index, tag) in commit.tags.reversed().enumerated() {
                let tagWidth = Double(max(tag.count, 1)) * 7 + 22
                let tagHeight: Double = 16
                if isVertical {
                    let xOrigin = commit.x + 20
                    let yOrigin = commit.y - 16 - Double(index) * 20
                    bounds.include(
                        x1: xOrigin,
                        y1: yOrigin - tagHeight / 2 - 2,
                        x2: xOrigin + 10 + tagWidth,
                        y2: yOrigin + tagHeight / 2 + 2
                    )
                } else {
                    let x = commit.x - tagWidth / 2
                    let y = commit.y - 34 - Double(index) * 20
                    bounds.include(x1: x, y1: y, x2: x + tagWidth, y2: y + tagHeight)
                }
            }
        }

        for line in positioned.branchLines {
            bounds.include(x1: line.x1, y1: line.y1, x2: line.x2, y2: line.y2)
        }

        for label in positioned.branchLabels {
            bounds.include(
                x1: label.x + label.bkgX,
                y1: label.y + label.bkgY,
                x2: label.x + label.bkgX + label.bkgWidth,
                y2: label.y + label.bkgY + label.bkgHeight
            )
        }

        for arrow in positioned.arrows {
            for segment in arrow.segments {
                switch segment {
                case .line(let from, let to), .arc(let from, let to, _, _, _, _, _):
                    bounds.include(x1: from.x, y1: from.y, x2: to.x, y2: to.y)
                case .cubic(let from, let c1, let c2, let to):
                    bounds.include(x1: from.x, y1: from.y, x2: to.x, y2: to.y)
                    bounds.include(x1: c1.x, y1: c1.y, x2: c2.x, y2: c2.y)
                }
            }
        }

        if let title = positioned.title {
            bounds.include(x1: title.x - 120, y1: title.y, x2: title.x + 120, y2: title.y + 24)
        }

        return bounds
    }

    private func assertRenderedContentFitsViewport(
        _ positioned: PositionedGitGraphDiagram,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let bounds = renderedBounds(positioned)
        XCTAssertGreaterThanOrEqual(bounds.minX, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(bounds.minY, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(bounds.maxX, positioned.width, file: file, line: line)
        XCTAssertLessThanOrEqual(bounds.maxY, positioned.height, file: file, line: line)
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

    func testBranchLabelTextAnchorFallsInsideBackground() throws {
        let cases = [
            "gitGraph\n   commit id:\"A\"\n   branch dev\n   commit id:\"B\"",
            "gitGraph TB:\n   commit id:\"A\"\n   branch dev\n   commit id:\"B\"",
            "gitGraph BT:\n   commit id:\"A\"\n   branch dev\n   commit id:\"B\""
        ]

        for source in cases {
            let positioned = try parseAndLayout(source)
            for label in positioned.branchLabels {
                let minX = label.x + label.bkgX
                let maxX = minX + label.bkgWidth
                let minY = label.y + label.bkgY
                let maxY = minY + label.bkgHeight
                XCTAssertGreaterThanOrEqual(label.x, minX)
                XCTAssertLessThanOrEqual(label.x, maxX)
                XCTAssertGreaterThanOrEqual(label.y, minY)
                XCTAssertLessThanOrEqual(label.y, maxY)
            }
        }
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

    func testRenderedGeometryFitsViewportForAllOrientations() throws {
        let cases = [
            "gitGraph\n   commit id:\"ZERO\"\n   commit id:\"ONE\"",
            "gitGraph\n   commit id:\"Alpha\" tag:\"v1.0\"\n   commit id:\"Beta\"",
            "gitGraph TB:\n   commit id:\"Alpha\"\n   branch feature\n   commit id:\"Beta\"\n   checkout main\n   merge feature",
            "gitGraph BT:\n   commit id:\"Alpha\"\n   commit id:\"Beta\"\n   branch hotfix\n   commit id:\"Gamma\"\n   checkout main\n   merge hotfix",
            "gitGraph\n   commit id:\"ZERO\"\n   branch develop\n   commit id:\"A\"\n   checkout main\n   commit id:\"ONE\"\n   checkout develop\n   commit id:\"B\"\n   checkout main\n   merge develop id:\"MERGE\"\n   branch release\n   cherry-pick id:\"MERGE\" parent:\"B\""
        ]

        for source in cases {
            assertRenderedContentFitsViewport(try parseAndLayout(source))
        }
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

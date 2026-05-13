import Foundation
import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class GitGraphReviewRegressionTests: XCTestCase {

    private struct PlaygroundDiagram: Decodable {
        let id: String
        let category: String
        let name: String
        let source: String
    }

    private struct PlaygroundFixture: Decodable {
        let diagrams: [PlaygroundDiagram]
    }

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func parse(_ source: String) throws -> GitGraphDiagram {
        try parseGitGraph(lines(source), frontmatter: nil)
    }

    private static func projectRoot() -> String {
        var url = URL(fileURLWithPath: #file).deletingLastPathComponent()
        while url.path != "/" {
            let package = url.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                return url.path
            }
            url.deleteLastPathComponent()
        }
        return FileManager.default.currentDirectoryPath
    }

    func testPlaygroundFixtureJsonIsValidAndContainsGitGraphExamples() throws {
        let path = (Self.projectRoot() as NSString).appendingPathComponent(
            "Examples/DiagramPlayground/Resources/test-diagrams.json"
        )
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let fixture = try JSONDecoder().decode(PlaygroundFixture.self, from: data)
        let gitGraphs = fixture.diagrams.filter { $0.category == "gitGraph" }

        XCTAssertEqual(gitGraphs.count, 18)
        XCTAssertEqual(gitGraphs.first?.id, "git-1-basic")
        XCTAssertTrue(gitGraphs.allSatisfy { $0.source.hasPrefix("gitGraph") })
    }

    func testBranchOrderingUsesMermaidFractionalSourceOrderForUnorderedBranches() throws {
        let diagram = try parse("""
        gitGraph
           branch beta
           branch alpha order:1
           branch zeta
        """)

        XCTAssertEqual(diagram.branches, ["main", "beta", "zeta", "alpha"])
    }

    func testBTOrientationPlacesLaterCommitsTowardTop() throws {
        let diagram = try parse("""
        gitGraph BT:
           commit id:"A"
           commit id:"B"
           commit id:"C"
        """)
        let positioned = layoutGitGraph(diagram)
        let byID = Dictionary(uniqueKeysWithValues: positioned.commits.map { ($0.id, $0) })

        XCTAssertGreaterThan(byID["A"]!.y, byID["B"]!.y)
        XCTAssertGreaterThan(byID["B"]!.y, byID["C"]!.y)
    }

    func testSvgRendersCommitTagElements() throws {
        let diagram = try parse("""
        gitGraph
           commit id:"A" tag:"v1.0"
        """)
        let svg = renderGitGraphSvg(layoutGitGraph(diagram))

        XCTAssertTrue(svg.contains("class=\"tag-label-bkg\""))
        XCTAssertTrue(svg.contains("class=\"tag-hole\""))
        XCTAssertTrue(svg.contains("class=\"tag-label\""))
        XCTAssertTrue(svg.contains(">v1.0</text>"))
    }

    func testTitleLayoutAndSvgDoNotOverlapFirstCommitLane() throws {
        var config = GitGraphConfig()
        config.titleTopMargin = 42
        let diagram = try parseGitGraph(lines("""
        gitGraph
           title Release Flow
           commit id:"A"
        """), frontmatter: DiagramFrontmatter(gitGraphConfig: config))
        let positioned = layoutGitGraph(diagram)
        let title = try XCTUnwrap(positioned.title)
        let firstCommit = try XCTUnwrap(positioned.commits.first)
        let svg = renderGitGraphSvg(positioned)

        XCTAssertGreaterThanOrEqual(title.y, 0)
        XCTAssertGreaterThan(firstCommit.y, title.y + 5)
        XCTAssertTrue(svg.contains("class=\"gitTitleText\""))
        XCTAssertTrue(svg.contains("y=\"\(title.y)\""))
    }

    func testUnterminatedQuotedPropertyThrowsParserError() {
        XCTAssertThrowsError(try parse(#"""
        gitGraph
           commit id:"unterminated
        """#)) { error in
            XCTAssertTrue(error is GitGraphParserError)
        }
    }

    func testUnknownCommitPropertyThrowsParserDiagnostic() {
        XCTAssertThrowsError(try parse("""
        gitGraph
           commit foo:"bar"
        """)) { error in
            XCTAssertTrue(error is GitGraphParserError)
        }
    }

    func testInvalidBareBranchReferenceThrowsParserError() {
        XCTAssertThrowsError(try parse("""
        gitGraph
           branch feature/
        """)) { error in
            XCTAssertTrue(error is GitGraphParserError)
        }
    }

    func testInvalidMergeTypeThrowsParserError() {
        XCTAssertThrowsError(try parse("""
        gitGraph
           commit
           branch dev
           commit
           checkout main
           merge dev type:BROKEN
        """)) { error in
            XCTAssertTrue(error is GitGraphParserError)
        }
    }

    func testRotateCommitLabelAddsSvgRotation() throws {
        var config = GitGraphConfig()
        config.rotateCommitLabel = true
        let diagram = try parseGitGraph(lines("""
        gitGraph
           commit id:"A"
        """), frontmatter: DiagramFrontmatter(gitGraphConfig: config))
        let svg = renderGitGraphSvg(layoutGitGraph(diagram))

        XCTAssertTrue(svg.contains("rotate(-45"))
    }

    func testShowBranchesFalseSuppressesBranchLinesAndLabels() throws {
        var config = GitGraphConfig()
        config.showBranches = false
        let diagram = try parseGitGraph(lines("""
        gitGraph
           commit
           branch dev
           commit
        """), frontmatter: DiagramFrontmatter(gitGraphConfig: config))
        let svg = renderGitGraphSvg(layoutGitGraph(diagram))

        XCTAssertFalse(svg.contains("class=\"branch branch"))
        XCTAssertFalse(svg.contains("branchLabel"))
    }

    func testGitGraphFrontmatterThemeVariablesReachModelAndSvg() throws {
        let source = """
        ---
        config:
          themeVariables:
            git0: "#123456"
            gitBranchLabel0: "#654321"
            commitLabelColor: "#abcdef"
            commitLabelBackground: "#fedcba"
            tagLabelColor: "#112233"
            tagLabelBackground: "#332211"
            tagLabelBorder: "#445566"
        ---
        gitGraph
           commit id:"A" tag:"v1"
        """
        let preprocessed = _preprocessMermaidSource(source)
        let diagram = try parseGitGraph(_mermaidSourceLines(from: preprocessed.source), frontmatter: preprocessed.frontmatter)
        let svg = renderGitGraphSvg(layoutGitGraph(diagram))

        XCTAssertEqual(diagram.theme.git0, "#123456")
        XCTAssertEqual(diagram.theme.gitBranchLabel0, "#654321")
        XCTAssertEqual(diagram.theme.commitLabelColor, "#abcdef")
        XCTAssertTrue(svg.contains("#123456"))
        XCTAssertTrue(svg.contains("#fedcba"))
        XCTAssertTrue(svg.contains("#332211"))
    }
}

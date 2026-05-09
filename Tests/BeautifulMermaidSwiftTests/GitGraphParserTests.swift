import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class GitGraphParserTests: XCTestCase {

    private func lines(_ source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func parse(_ source: String) throws -> GitGraphDiagram {
        try parseGitGraph(lines(source), frontmatter: nil)
    }

    // MARK: - Header tests

    func testBareHeader() throws {
        let diagram = try parse("gitGraph")
        XCTAssertEqual(diagram.direction, .LR)
        XCTAssertEqual(diagram.statements.count, 0)
    }

    func testHeaderWithColon() throws {
        let diagram = try parse("gitGraph:")
        XCTAssertEqual(diagram.direction, .LR)
    }

    func testLRDirection() throws {
        let diagram = try parse("gitGraph LR:")
        XCTAssertEqual(diagram.direction, .LR)
    }

    func testTBDirection() throws {
        let diagram = try parse("gitGraph TB:")
        XCTAssertEqual(diagram.direction, .TB)
    }

    func testBTDirection() throws {
        let diagram = try parse("gitGraph BT:")
        XCTAssertEqual(diagram.direction, .BT)
    }

    // MARK: - Commit tests

    func testSimpleCommit() throws {
        let diagram = try parse("gitGraph\n   commit")
        XCTAssertEqual(diagram.statements.count, 1)
        guard case .commit(let c) = diagram.statements[0] else {
            XCTFail("Expected commit statement"); return
        }
        XCTAssertNil(c.id)
        XCTAssertNil(c.message)
        XCTAssertNil(c.type)
    }

    func testCommitWithBareMessage() throws {
        let diagram = try parse("gitGraph\n   commit \"hello world\"")
        guard case .commit(let c) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(c.message, "hello world")
    }

    func testCommitWithMsgProperty() throws {
        let diagram = try parse("gitGraph\n   commit msg:\"hello\"")
        guard case .commit(let c) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(c.message, "hello")
    }

    func testCommitWithId() throws {
        let diagram = try parse("gitGraph\n   commit id:\"abc\"")
        guard case .commit(let c) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(c.id, "abc")
    }

    func testCommitWithTag() throws {
        let diagram = try parse("gitGraph\n   commit tag:\"v1.0\"")
        guard case .commit(let c) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(c.tags, ["v1.0"])
    }

    func testCommitMultipleTags() throws {
        let diagram = try parse("gitGraph\n   commit tag:\"a\" tag:\"b\"")
        guard case .commit(let c) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(c.tags, ["a", "b"])
    }

    func testCommitTypeNormal() throws {
        let diagram = try parse("gitGraph\n   commit type:NORMAL")
        guard case .commit(let c) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(c.type, .normal)
    }

    func testCommitTypeReverse() throws {
        let diagram = try parse("gitGraph\n   commit type:REVERSE")
        guard case .commit(let c) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(c.type, .reverse)
    }

    func testCommitTypeHighlight() throws {
        let diagram = try parse("gitGraph\n   commit type:HIGHLIGHT")
        guard case .commit(let c) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(c.type, .highlight)
    }

    func testCommitPropertiesAnyOrder() throws {
        let diagram = try parse("gitGraph\n   commit tag:\"t\" type:HIGHLIGHT id:\"x\" msg:\"m\"")
        guard case .commit(let c) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(c.tags, ["t"])
        XCTAssertEqual(c.type, .highlight)
        XCTAssertEqual(c.id, "x")
        XCTAssertEqual(c.message, "m")
    }

    // MARK: - Branch tests

    func testBranch() throws {
        let diagram = try parse("gitGraph\n   branch develop")
        guard case .branch(let b) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(b.name, "develop")
    }

    func testBranchWithOrder() throws {
        let diagram = try parse("gitGraph\n   branch first order:3")
        guard case .branch(let b) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(b.name, "first")
        XCTAssertEqual(b.order, 3)
    }

    func testQuotedBranch() throws {
        let diagram = try parse("gitGraph\n   branch \"cherry-pick\"")
        guard case .branch(let b) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(b.name, "cherry-pick")
    }

    // MARK: - Checkout/Switch tests

    func testCheckout() throws {
        let diagram = try parse("gitGraph\n   branch dev\n   checkout dev")
        guard case .checkout(let c) = diagram.statements[1] else { XCTFail(); return }
        XCTAssertEqual(c.branch, "dev")
    }

    func testSwitch() throws {
        let diagram = try parse("gitGraph\n   branch dev\n   switch dev")
        guard case .checkout(let c) = diagram.statements[1] else { XCTFail(); return }
        XCTAssertEqual(c.branch, "dev")
    }

    // MARK: - Merge tests

    func testMergeBasic() throws {
        let diagram = try parse("gitGraph\n   commit\n   branch dev\n   commit\n   checkout main\n   merge dev")
        guard case .merge(let m) = diagram.statements[4] else { XCTFail(); return }
        XCTAssertEqual(m.branch, "dev")
    }

    func testMergeWithProperties() throws {
        let diagram = try parse("gitGraph\n   commit\n   branch dev\n   commit\n   checkout main\n   merge dev id:\"m1\" tag:\"t1\" type:REVERSE")
        guard case .merge(let m) = diagram.statements[4] else { XCTFail(); return }
        XCTAssertEqual(m.id, "m1")
        XCTAssertEqual(m.tags, ["t1"])
        XCTAssertEqual(m.type, .reverse)
    }

    // MARK: - Cherry-pick tests

    func testCherryPickBasic() throws {
        let diagram = try parse("gitGraph\n   commit id:\"A\"\n   branch dev\n   commit id:\"B\"\n   checkout main\n   cherry-pick id:\"B\"")
        guard case .cherryPick(let cp) = diagram.statements[4] else { XCTFail(); return }
        XCTAssertEqual(cp.id, "B")
    }

    func testCherryPickWithParent() throws {
        let diagram = try parse("gitGraph\n   commit id:\"A\"\n   branch dev\n   commit id:\"B\"\n   checkout main\n   cherry-pick id:\"B\" parent:\"A\"")
        guard case .cherryPick(let cp) = diagram.statements[4] else { XCTFail(); return }
        XCTAssertEqual(cp.parent, "A")
    }

    func testCherryPickWithTags() throws {
        let diagram = try parse("gitGraph\n   commit id:\"A\"\n   branch dev\n   commit id:\"B\"\n   checkout main\n   cherry-pick id:\"B\" tag:\"custom\"")
        guard case .cherryPick(let cp) = diagram.statements[4] else { XCTFail(); return }
        XCTAssertEqual(cp.tags, ["custom"])
    }

    func testCherryPickEmptyTag() throws {
        let diagram = try parse("gitGraph\n   commit id:\"A\"\n   branch dev\n   commit id:\"B\"\n   checkout main\n   cherry-pick id:\"B\" tag:\"\"")
        guard case .cherryPick(let cp) = diagram.statements[4] else { XCTFail(); return }
        XCTAssertEqual(cp.tags, [""])
    }

    func testCherryPickWithoutId() throws {
        let diagram = try parse("gitGraph\n   commit id:\"A\"\n   branch dev\n   commit id:\"B\"\n   checkout main\n   cherry-pick id:\"B\" tag:\"custom\"")
        guard case .cherryPick(let cp) = diagram.statements[4] else { XCTFail(); return }
        XCTAssertEqual(cp.id, "B")
        XCTAssertEqual(cp.tags, ["custom"])
    }

    // MARK: - Title and accessibility

    func testInlineTitle() throws {
        let diagram = try parse("gitGraph title My Graph\n   commit")
        XCTAssertEqual(diagram.diagramTitle, "My Graph")
    }

    func testAccTitle() throws {
        let diagram = try parse("gitGraph\n   accTitle: AT\n   commit")
        XCTAssertEqual(diagram.accTitle, "AT")
    }

    func testAccDescrSingle() throws {
        let diagram = try parse("gitGraph\n   accDescr: AD\n   commit")
        XCTAssertEqual(diagram.accDescr, "AD")
    }

    func testAccDescrMultiline() throws {
        let diagram = try parse("gitGraph accDescr { L1\nL2 }\n   commit")
        XCTAssertEqual(diagram.accDescr, "L1\nL2")
    }

    // MARK: - Comments

    func testCommentsIgnored() throws {
        let diagram = try parse("gitGraph\n   %% comment\n   commit")
        XCTAssertEqual(diagram.statements.count, 1)
    }

    // MARK: - Whitespace

    func testTabWhitespace() throws {
        let diagram = try parse("gitGraph\n\tcommit\tid:\"x\"\tmsg:\"y\"")
        guard case .commit(let c) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(c.id, "x")
        XCTAssertEqual(c.message, "y")
    }

    func testWhitespaceAfterColon() throws {
        let diagram = try parse("gitGraph\n   commit id: \"x\" msg: \"y\" tag: \"z\" type: HIGHLIGHT")
        guard case .commit(let c) = diagram.statements[0] else { XCTFail(); return }
        XCTAssertEqual(c.id, "x")
        XCTAssertEqual(c.message, "y")
        XCTAssertEqual(c.tags, ["z"])
        XCTAssertEqual(c.type, .highlight)
    }

    // MARK: - Empty source

    func testEmptySource() throws {
        XCTAssertThrowsError(try parse("")) { error in
            XCTAssertTrue(error is GitGraphParserError)
        }
    }

    func testMissingGitGraphHeader() {
        let source = "commit\ncommit"
        XCTAssertThrowsError(try parse(source)) { error in
            XCTAssertTrue(error is GitGraphParserError)
        }
    }

    // MARK: - Model population basics

    func testCommitAutoId() throws {
        let diagram = try parse("gitGraph\n   commit")
        XCTAssertEqual(diagram.commits.count, 1)
        let commit = diagram.commits[0]
        XCTAssertTrue(commit.id.contains("-"))
        XCTAssertEqual(commit.branch, "main")
        XCTAssertEqual(commit.type, .normal)
    }

    func testBranchAutoCheckout() throws {
        let diagram = try parse("gitGraph\n   commit\n   branch develop\n   commit")
        XCTAssertEqual(diagram.branches.count, 2)
        XCTAssertEqual(diagram.currentBranch, "develop")
        let secondCommit = diagram.commits[1]
        XCTAssertEqual(secondCommit.branch, "develop")
    }

    // MARK: - Prototype-hazard names (G4)

    func testProtoAsBranchName() throws {
        let diagram = try parse("gitGraph\n   branch __proto__\n   checkout __proto__\n   commit")
        XCTAssertTrue(diagram.branches.contains("__proto__"))
        XCTAssertEqual(diagram.currentBranch, "__proto__")
    }

    func testConstructorAsCommitId() throws {
        let diagram = try parse("gitGraph\n   commit id:\"constructor\"")
        XCTAssertEqual(diagram.commits.count, 1)
        XCTAssertEqual(diagram.commits[0].id, "constructor")
    }

    func testConstructorAndProtoBranchMerge() throws {
        let diagram = try parse("gitGraph\n   commit\n   branch constructor\n   commit\n   checkout main\n   merge constructor")
        XCTAssertEqual(diagram.commits.count, 3)
        XCTAssertTrue(diagram.branches.contains("constructor"))
    }

    // MARK: - Duplicate commit ID warnings (G3)

    func testDuplicateCommitIdWarning() throws {
        let diagram = try parse("gitGraph\n   commit id:\"dup\"\n   commit id:\"dup\"")
        XCTAssertFalse(diagram.warnings.isEmpty)
        XCTAssertTrue(diagram.warnings[0].contains("already exists"))
    }

    // MARK: - mainBranchName config (G7)

    func testMainBranchNameFromConfig() throws {
        var config = GitGraphConfig()
        config.mainBranchName = "trunk"
        let diagram = try parseGitGraph(lines("gitGraph\n   commit"), frontmatter: DiagramFrontmatter(gitGraphConfig: config))
        XCTAssertEqual(diagram.currentBranch, "trunk")
        XCTAssertEqual(diagram.commits[0].branch, "trunk")
    }

    func testMainBranchOrderFromConfig() throws {
        var config = GitGraphConfig()
        config.mainBranchOrder = 99
        let diagram = try parseGitGraph(lines("gitGraph\n   branch dev\n   commit"), frontmatter: DiagramFrontmatter(gitGraphConfig: config))
        XCTAssertEqual(diagram.branches, ["dev", "main"])
    }
}

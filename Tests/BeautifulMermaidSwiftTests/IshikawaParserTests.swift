import Testing
@testable import BeautifulMermaid

@Suite("Ishikawa Parser")
struct IshikawaParserTests {

    // MARK: - Header variants

    @Test("Parses ishikawa-beta header")
    func ishikawaBetaHeader() throws {
        let lines = ["ishikawa-beta", "Problem", "    Cause A"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
        #expect(result.root?.children.count == 1)
        #expect(result.root?.children[0].text == "Cause A")
    }

    @Test("Parses ishikawa header")
    func ishikawaHeader() throws {
        let lines = ["ishikawa", "Problem", "Cause A", "  Subcause A1", "Cause B"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
        #expect(result.root?.children.count == 2)
    }

    @Test("Parses case-insensitive header ISHIKAWA-BETA")
    func caseInsensitiveHeader() throws {
        let lines = ["ISHIKAWA-BETA", "Problem", "    Cause A"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
        #expect(result.root?.children.first?.text == "Cause A")
    }

    @Test("Parses case-insensitive header Ishikawa")
    func mixedCaseHeader() throws {
        let lines = ["Ishikawa", "Problem", "    Cause A"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
    }

    // MARK: - Hierarchy

    @Test("Parses basic hierarchy from Mermaid spec")
    func basicHierarchy() throws {
        let lines = ["ishikawa-beta", "    Blurry Photo", "        Process", "            Out of focus", "        User", "            Shaky hands"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Blurry Photo")
        #expect(result.root?.children.count == 2)
        #expect(result.root?.children[0].text == "Process")
        #expect(result.root?.children[0].children.first?.text == "Out of focus")
        #expect(result.root?.children[1].text == "User")
        #expect(result.root?.children[1].children.first?.text == "Shaky hands")
    }

    @Test("Parses unindented root with nested causes")
    func unindentedRootWithNestedCauses() throws {
        let lines = ["ishikawa", "Problem", "Cause A", "  Subcause A1", "Cause B"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
        #expect(result.root?.children.count == 2)
        #expect(result.root?.children[0].text == "Cause A")
        #expect(result.root?.children[0].children.first?.text == "Subcause A1")
        #expect(result.root?.children[1].text == "Cause B")
    }

    @Test("Parses root indented more than causes")
    func rootIndentedMoreThanCauses() throws {
        let lines = ["ishikawa-beta", "    Problem", "Cause A", "  Subcause A1", "  Subcause A2", "Cause B"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
        #expect(result.root?.children.count == 2)
        #expect(result.root?.children[0].text == "Cause A")
        #expect(result.root?.children[0].children.count == 2)
    }

    // MARK: - Comments and blank lines

    @Test("Parses with leading blank lines")
    func leadingBlankLines() throws {
        let lines = ["", "", "ishikawa-beta", "Problem", "    Cause A"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
        #expect(result.root?.children.first?.text == "Cause A")
    }

    @Test("Parses with leading %% comments")
    func leadingComments() throws {
        let lines = ["%% leading comment", "ishikawa-beta", "Problem", "    Cause A"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
    }

    @Test("Parses with %% separator comments")
    func separatorComments() throws {
        let lines = ["%% leading comment", "ishikawa-beta", "Problem", "    Cause A", "%% separator comment", "    Cause B"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.children.count == 2)
        #expect(result.root?.children[0].text == "Cause A")
        #expect(result.root?.children[1].text == "Cause B")
    }

    // MARK: - Edge cases

    @Test("Parses root-only diagram")
    func rootOnly() throws {
        let lines = ["ishikawa-beta", "Problem"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
        #expect(result.root?.children.isEmpty == true)
    }

    @Test("Root-only with trailing blank")
    func rootOnlyWithTrailingBlank() throws {
        let lines = ["ishikawa-beta", "Problem", ""]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
        #expect(result.root?.children.isEmpty == true)
    }

    @Test("Deep nesting 4+ levels")
    func deepNesting() throws {
        let lines = ["ishikawa-beta", "Effect", "  Cause1", "    Sub1", "      SubSub1", "        Leaf1"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.children.first?.text == "Cause1")
        let sub1 = result.root?.children.first?.children.first
        #expect(sub1?.text == "Sub1")
        let subSub1 = sub1?.children.first
        #expect(subSub1?.text == "SubSub1")
        #expect(subSub1?.children.first?.text == "Leaf1")
    }

    @Test("Trims whitespace from labels")
    func trimsWhitespace() throws {
        let lines = ["ishikawa-beta", "  Problem  ", "    Cause A  "]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
        #expect(result.root?.children.first?.text == "Cause A")
    }

    @Test("Diagram title is set from root label")
    func diagramTitleFromRoot() throws {
        let lines = ["ishikawa-beta", "Defect Analysis", "    Materials"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.diagramTitle == "Defect Analysis")
    }

    @Test("Frontmatter title overrides root title")
    func frontmatterTitleOverrides() throws {
        let fm = DiagramFrontmatter(diagramTitle: "Custom Title")
        let lines = ["ishikawa-beta", "Defect Analysis", "    Materials"]
        let result = try parseIshikawaDiagram(lines, frontmatter: fm)
        #expect(result.diagramTitle == "Custom Title")
    }

    // MARK: - Error cases

    @Test("Throws on empty source")
    func emptySourceThrows() {
        #expect(throws: IshikawaParserError.self) {
            try parseIshikawaDiagram([])
        }
    }

    @Test("Throws on missing header")
    func missingHeaderThrows() {
        #expect(throws: IshikawaParserError.self) {
            try parseIshikawaDiagram(["Problem", "Cause"])
        }
    }

    @Test("Throws missingRoot on header-only source")
    func headerOnlyThrowsMissingRoot() throws {
        do {
            _ = try parseIshikawaDiagram(["ishikawa-beta"])
            Issue.record("Expected header-only Ishikawa source to throw missingRoot.")
        } catch let error as IshikawaParserError {
            guard case .missingRoot = error else {
                Issue.record("Expected missingRoot, got \(error).")
                return
            }
        }
    }

    @Test("Throws missingRoot when header has only comments and blanks")
    func headerOnlyWithCommentsThrowsMissingRoot() throws {
        do {
            _ = try parseIshikawaDiagram(["ishikawa", "", "%% no root"])
            Issue.record("Expected Ishikawa source without an effect/root line to throw missingRoot.")
        } catch let error as IshikawaParserError {
            guard case .missingRoot = error else {
                Issue.record("Expected missingRoot, got \(error).")
                return
            }
        }
    }

    // MARK: - Trailing text on header line

    @Test("Parses trailing text after header as root node")
    func trailingTextOnHeaderLine() throws {
        let lines = ["ishikawa-beta lingering text", "Problem", "  Cause A"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "lingering text")
        #expect(result.root?.children.first?.text == "Problem")
    }

    // MARK: - Whitespace and blank line edge cases

    @Test("Parses with whitespace-only line between statements")
    func whitespaceOnlyLineBetweenStatements() throws {
        let lines = ["ishikawa-beta", "Problem", "  Cause A", "   ", "  Cause B"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.children.count == 2)
        #expect(result.root?.children[0].text == "Cause A")
        #expect(result.root?.children[1].text == "Cause B")
    }

    @Test("Parses with multiple consecutive blank lines")
    func multipleConsecutiveBlankLines() throws {
        let lines = ["ishikawa-beta", "", "", "Problem", "    Cause A"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
        #expect(result.root?.children.first?.text == "Cause A")
    }

    @Test("Parses with %% comment immediately after header")
    func commentImmediatelyAfterHeader() throws {
        let lines = ["ishikawa-beta", "%% right after header", "Problem", "    Cause A"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.text == "Problem")
        #expect(result.root?.children.first?.text == "Cause A")
    }

    @Test("Parses with tab-indented causes")
    func tabIndentedCauses() throws {
        let lines = ["ishikawa-beta", "Problem", "\tCause A", "\t\tSub A1"]
        let result = try parseIshikawaDiagram(lines)
        #expect(result.root?.children.first?.text == "Cause A")
        #expect(result.root?.children.first?.children.first?.text == "Sub A1")
    }
}

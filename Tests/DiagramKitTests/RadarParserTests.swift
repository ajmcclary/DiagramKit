import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

private func parse(_ source: String) throws -> RadarDiagram {
    try parseRadarDiagram(source: source, frontmatter: nil).0
}

private func parseWithFrontmatter(_ source: String, frontmatter: DiagramFrontmatter) throws -> RadarDiagram {
    try parseRadarDiagram(source: source, frontmatter: frontmatter).0
}

// MARK: - Radar Parser Suite

@Suite("Radar Parser")
struct RadarParserTests {

    // MARK: - Header tests

    @Test("Bare radar-beta header parses")
    func bareHeader() throws {
        let d = try parse("radar-beta")
        #expect(d.axes.isEmpty)
        #expect(d.curves.isEmpty)
    }

    @Test("Header with colon radar-beta")
    func headerWithColon() throws {
        let d = try parse("radar-beta:")
        #expect(d.axes.isEmpty)
        #expect(d.curves.isEmpty)
    }

    @Test("Header with space before colon radar-beta :")
    func headerWithSpaceColon() throws {
        let d = try parse("radar-beta :")
        #expect(d.axes.isEmpty)
        #expect(d.curves.isEmpty)
    }

    @Test("Header with leading whitespace and tabs")
    func leadingWhitespaceHeader() throws {
        let d = try parse("  \tradar-beta\n  axis A\n  curve c1{1}")
        #expect(d.axes.count == 1)
        #expect(d.axes[0].name == "A")
    }

    @Test("Header with trailing whitespace")
    func trailingWhitespaceHeader() throws {
        let d = try parse("radar-beta   \n  axis A")
        #expect(d.axes.count == 1)
    }

    @Test("Blank lines before header")
    func blankLinesBeforeHeader() throws {
        let d = try parse("\n\nradar-beta\n  axis A")
        #expect(d.axes.count == 1)
    }

    @Test("Case-insensitive header detection")
    func caseInsensitiveHeader() throws {
        let d = try parse("RADAR-BETA\n  axis A")
        #expect(d.axes.count == 1)
    }

    @Test("Mixed-case header with colon")
    func mixedCaseHeaderWithColon() throws {
        let d = try parse("Radar-Beta:\n  axis A")
        #expect(d.axes.count == 1)
    }

    @Test("Invalid header throws error with line number")
    func invalidHeader() throws {
        do {
            _ = try parse("garbage")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
            #expect(error.errorDescription?.contains("line 1") ?? false)
        }
    }

    @Test("No radar-beta header in input throws with line number")
    func missingHeader() throws {
        do {
            _ = try parse("axis A\n  curve c1{1}")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
        }
    }

    // MARK: - Title tests

    @Test("Title on same line as header")
    func titleOnHeaderLine() throws {
        let d = try parse("radar-beta title Radar diagram\n  axis A")
        #expect(d.diagramTitle == "Radar diagram")
    }

    @Test("Title with colon on header line")
    func titleWithColonOnHeaderLine() throws {
        let d = try parse("radar-beta title: Radar diagram\n  axis A")
        #expect(d.diagramTitle == "Radar diagram")
    }

    @Test("Title, accTitle, accDescr all on header line")
    func allMetadataOnHeaderLine() throws {
        let d = try parse("radar-beta title My Title accTitle: AT accDescr: AD\n  axis A")
        #expect(d.diagramTitle == "My Title")
        #expect(d.accTitle == "AT")
        #expect(d.accDescr == "AD")
    }

    // MARK: - Accessibility tests

    @Test("Single-line accTitle")
    func accTitleSingleLine() throws {
        let d = try parse("radar-beta\n  accTitle: Test Title\n  axis A")
        #expect(d.accTitle == "Test Title")
    }

    @Test("Single-line accDescr")
    func accDescrSingleLine() throws {
        let d = try parse("radar-beta\n  accDescr: Test Description\n  axis A")
        #expect(d.accDescr == "Test Description")
    }

    @Test("Case-insensitive accTitle")
    func accTitleCaseInsensitive() throws {
        let d = try parse("radar-beta\n  AcCtItLe: Test Title\n  axis A")
        #expect(d.accTitle == "Test Title")
    }

    @Test("Case-insensitive accDescr")
    func accDescrCaseInsensitive() throws {
        let d = try parse("radar-beta\n  AcCdEsCr: Test Description\n  axis A")
        #expect(d.accDescr == "Test Description")
    }

    @Test("Multiline accDescr with braces")
    func accDescrMultiline() throws {
        let d = try parse("radar-beta\n  accDescr {\n  Line one\n  Line two\n  }\n  axis A")
        #expect(d.accDescr == "Line one\nLine two")
    }

    @Test("Multiline accDescr with case-insensitive keyword")
    func accDescrMultilineCaseInsensitive() throws {
        let d = try parse("radar-beta\n  AcCdEsCr {\n  Description\n  }\n  axis A")
        #expect(d.accDescr == "Description")
    }

    @Test("Multiline accDescr with blank lines inside braces")
    func accDescrMultilineBlankLines() throws {
        let d = try parse("radar-beta\n  accDescr {\n\n  Line one\n\n  Line two\n\n  }\n  axis A")
        #expect(d.accDescr == "Line one\nLine two")
    }

    @Test("Multiline accDescr with nested braces")
    func accDescrNestedBraces() throws {
        let d = try parse("radar-beta\n  accDescr {\n  Text {with} braces\n  }\n  axis A")
        #expect(d.accDescr == "Text {with} braces")
    }

    @Test("accTitle on header line")
    func accTitleOnHeaderLine() throws {
        let d = try parse("radar-beta accTitle: Test Title\n  axis A")
        #expect(d.accTitle == "Test Title")
    }

    @Test("accDescr on header line")
    func accDescrOnHeaderLine() throws {
        let d = try parse("radar-beta accDescr: Test Description\n  axis A")
        #expect(d.accDescr == "Test Description")
    }

    // MARK: - Simple diagram tests

    @Test("Simple radar diagram with axes and one curve")
    func simpleDiagram() throws {
        let d = try parse("radar-beta\n  axis A,B,C\n  curve mycurve{1,2,3}")
        #expect(d.axes.map(\.name) == ["A", "B", "C"])
        #expect(d.curves.count == 1)
        #expect(d.curves[0].name == "mycurve")
        #expect(d.curves[0].entries == [1, 2, 3])
    }

    @Test("Diagram with axis and curve on same line as header")
    func diagramAfterHeaderColon() throws {
        let d = try parse("radar-beta:\n  axis A\n  curve c1{1}")
        #expect(d.axes.count == 1)
        #expect(d.curves.count == 1)
    }

    // MARK: - Axis declaration tests

    @Test("Single axis declaration")
    func singleAxis() throws {
        let d = try parse("radar-beta\n  axis A")
        #expect(d.axes.count == 1)
        #expect(d.axes[0].name == "A")
        #expect(d.axes[0].label == "A")
    }

    @Test("Multiple axes comma-separated")
    func multipleAxes() throws {
        let d = try parse("radar-beta\n  axis A, B, C")
        #expect(d.axes.map(\.name) == ["A", "B", "C"])
        #expect(d.axes.map(\.label) == ["A", "B", "C"])
    }

    @Test("Axis with double-quoted bracket label")
    func axisWithDoubleQuoteBracketLabel() throws {
        let d = try parse("radar-beta\n  axis A[\"Axis A\"]")
        #expect(d.axes[0].name == "A")
        #expect(d.axes[0].label == "Axis A")
    }

    @Test("Axis with single-quoted bracket label")
    func axisWithSingleQuoteBracketLabel() throws {
        let d = try parse("radar-beta\n  axis A['Axis A']")
        #expect(d.axes[0].name == "A")
        #expect(d.axes[0].label == "Axis A")
    }

    @Test("Axis with unquoted bracket label")
    func axisWithUnquotedBracketLabel() throws {
        let d = try parse("radar-beta\n  axis A[Axis A]")
        #expect(d.axes[0].name == "A")
        #expect(d.axes[0].label == "Axis A")
    }

    @Test("Multiple axes with mixed bracket labels")
    func multipleAxesWithLabels() throws {
        let d = try parse("radar-beta\n  axis A[\"Axis A\"], B['Axis B'], C[Axis C]")
        #expect(d.axes.count == 3)
        #expect(d.axes[0].name == "A")
        #expect(d.axes[0].label == "Axis A")
        #expect(d.axes[1].name == "B")
        #expect(d.axes[1].label == "Axis B")
        #expect(d.axes[2].name == "C")
        #expect(d.axes[2].label == "Axis C")
    }

    @Test("Axis names trimmed")
    func axisNamesTrimmed() throws {
        let d = try parse("radar-beta\n  axis  A ,  B ,  C ")
        #expect(d.axes.map(\.name) == ["A", "B", "C"])
    }

    @Test("Empty axis declaration throws with line number")
    func emptyAxisDeclaration() throws {
        do {
            _ = try parse("radar-beta\n  axis")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
            #expect(error.errorDescription?.contains("line") ?? false)
        }
    }

    @Test("Empty axis with only commas throws with line number")
    func emptyAxisCommaOnly() throws {
        do {
            _ = try parse("radar-beta\n  axis ,")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
        }
    }

    @Test("Axis with only whitespace throws with line number")
    func axisWhitespaceOnly() throws {
        do {
            _ = try parse("radar-beta\n  axis  ")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
        }
    }

    // MARK: - Numeric curve tests

    @Test("Numeric curve with three entries")
    func numericCurve() throws {
        let d = try parse("radar-beta\n  axis A,B,C\n  curve c1{1, 2, 3}")
        #expect(d.curves.count == 1)
        #expect(d.curves[0].name == "c1")
        #expect(d.curves[0].label == "c1")
        #expect(d.curves[0].entries == [1, 2, 3])
    }

    @Test("Numeric curve with floating-point values")
    func numericCurveFloats() throws {
        let d = try parse("radar-beta\n  axis A,B\n  curve c1{1.5, 2.75}")
        #expect(d.curves[0].entries == [1.5, 2.75])
    }

    @Test("Numeric curve with negative values")
    func numericCurveNegatives() throws {
        let d = try parse("radar-beta\n  axis A,B\n  curve c1{-1, -2.5}")
        #expect(d.curves[0].entries == [-1, -2.5])
    }

    @Test("Numeric curve with zero values")
    func numericCurveZeros() throws {
        let d = try parse("radar-beta\n  axis A,B\n  curve c1{0, 0}")
        #expect(d.curves[0].entries == [0, 0])
    }

    @Test("Numeric curve with extra whitespace inside braces")
    func numericCurveWhitespace() throws {
        let d = try parse("radar-beta\n  axis A,B\n  curve c1{  1  ,  2  }")
        #expect(d.curves[0].entries == [1, 2])
    }

    @Test("Curve with label via bracket syntax")
    func curveWithLabel() throws {
        let d = try parse("radar-beta\n  axis A,B\n  curve c1[\"My Curve\"]{1,2}")
        #expect(d.curves[0].name == "c1")
        #expect(d.curves[0].label == "My Curve")
        #expect(d.curves[0].entries == [1, 2])
    }

    @Test("Curve with single entry")
    func curveSingleEntry() throws {
        let d = try parse("radar-beta\n  axis A\n  curve c1{42}")
        #expect(d.curves[0].entries == [42])
    }

    @Test("Multiple curves on separate lines")
    func multipleCurvesSeparateLines() throws {
        let d = try parse("radar-beta\n  axis A,B\n  curve c1{1,2}\n  curve c2{3,4}")
        #expect(d.curves.count == 2)
        #expect(d.curves[0].name == "c1")
        #expect(d.curves[0].entries == [1, 2])
        #expect(d.curves[1].name == "c2")
        #expect(d.curves[1].entries == [3, 4])
    }

    @Test("Multiple curves on same line via comma after brace")
    func multipleCurvesSameLine() throws {
        let d = try parse("radar-beta\n  axis A,B\n  curve c1{1,2}, c2{3,4}")
        #expect(d.curves.count == 2)
        #expect(d.curves[0].name == "c1")
        #expect(d.curves[0].entries == [1, 2])
        #expect(d.curves[1].name == "c2")
        #expect(d.curves[1].entries == [3, 4])
    }

    @Test("Multiline curve entries with blank lines inside braces")
    func multilineCurveBlankLines() throws {
        let d = try parse("radar-beta\n  axis A,B\n  curve c1{\n  1,\n\n  2\n  }")
        #expect(d.curves[0].entries == [1, 2])
    }

    // MARK: - Detailed curve tests

    @Test("Detailed curve with colon separator")
    func detailedCurveWithColon() throws {
        let d = try parse("radar-beta\n  axis A,B,C\n  curve c1{C: 3, A: 1, B: 2}")
        #expect(d.curves[0].entries == [1, 2, 3])
    }

    @Test("Detailed curve with space separator instead of colon")
    func detailedCurveSpaceSeparator() throws {
        let d = try parse("radar-beta\n  axis A,B\n  curve c1{A 1, B 2}")
        #expect(d.curves[0].entries == [1, 2])
    }

    @Test("Detailed curve with sparse colon after space")
    func detailedCurveSparseColon() throws {
        let d = try parse("radar-beta\n  axis A,B\n  curve c1{A : 1, B : 2}")
        #expect(d.curves[0].entries == [1, 2])
    }

    @Test("Detailed curve entries reordered to axis order")
    func detailedCurveReordered() throws {
        let d = try parse("radar-beta\n  axis Z,Y,X\n  curve c1{X: 30, Z: 10, Y: 20}")
        #expect(d.curves[0].entries == [10, 20, 30])
    }

    @Test("Detailed curve with floating-point values")
    func detailedCurveFloats() throws {
        let d = try parse("radar-beta\n  axis A,B\n  curve c1{A: 1.5, B: 2.75}")
        #expect(d.curves[0].entries == [1.5, 2.75])
    }

    @Test("Multiple detailed curves")
    func multipleDetailedCurves() throws {
        let d = try parse("radar-beta\n  axis A,B\n  curve c1{A: 1, B: 2}\n  curve c2{A: 3, B: 4}")
        #expect(d.curves.count == 2)
        #expect(d.curves[0].entries == [1, 2])
        #expect(d.curves[1].entries == [3, 4])
    }

    // MARK: - Curve error tests

    @Test("Empty curve declaration throws with line number")
    func emptyCurveDeclaration() throws {
        do {
            _ = try parse("radar-beta\n  axis A\n  curve")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
        }
    }

    @Test("Curve without entries throws with line number")
    func curveWithoutEntries() throws {
        do {
            _ = try parse("radar-beta\n  axis A\n  curve c1{}")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
        }
    }

    @Test("Mixed numeric and detailed entry modes throws with line number")
    func mixedEntryModes() throws {
        do {
            _ = try parse("radar-beta\n  axis A,B\n  curve c1{1, A: 2}")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
        }
    }

    @Test("Mixed entry modes reversed throws with line number")
    func mixedEntryModesReversed() throws {
        do {
            _ = try parse("radar-beta\n  axis A,B\n  curve c1{A: 1, 2}")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
        }
    }

    @Test("Detailed entries without declared axes throws with line number")
    func detailedEntriesWithoutAxes() throws {
        do {
            _ = try parse("radar-beta\n  curve c1{A: 1, B: 2}")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line >= 0)
            #expect(error.errorDescription?.contains("line") ?? false)
        }
    }

    @Test("Missing entry for declared axis throws with line number")
    func missingEntryForAxis() throws {
        do {
            _ = try parse("radar-beta\n  axis A,B,C\n  curve c1{A: 1, B: 2}")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line >= 0)
            #expect(error.errorDescription?.contains("line") ?? false)
        }
    }

    // MARK: - Options tests

    @Test("ticks option")
    func ticksOption() throws {
        let d = try parse("radar-beta\n  ticks 10")
        #expect(d.options.ticks == 10)
    }

    @Test("ticks default value")
    func ticksDefault() throws {
        let d = try parse("radar-beta")
        #expect(d.options.ticks == 5)
    }

    @Test("ticks invalid value throws with line number")
    func ticksInvalid() throws {
        do {
            _ = try parse("radar-beta\n  ticks abc")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
        }
    }

    @Test("showLegend true")
    func showLegendTrue() throws {
        let d = try parse("radar-beta\n  showLegend true")
        #expect(d.options.showLegend == true)
    }

    @Test("showLegend false")
    func showLegendFalse() throws {
        let d = try parse("radar-beta\n  showLegend false")
        #expect(d.options.showLegend == false)
    }

    @Test("showLegend default")
    func showLegendDefault() throws {
        let d = try parse("radar-beta")
        #expect(d.options.showLegend == true)
    }

    @Test("graticule circle")
    func graticuleCircle() throws {
        let d = try parse("radar-beta\n  graticule circle")
        #expect(d.options.graticule == .circle)
    }

    @Test("graticule polygon")
    func graticulePolygon() throws {
        let d = try parse("radar-beta\n  graticule polygon")
        #expect(d.options.graticule == .polygon)
    }

    @Test("graticule default")
    func graticuleDefault() throws {
        let d = try parse("radar-beta")
        #expect(d.options.graticule == .circle)
    }

    @Test("graticule invalid value throws with line number")
    func graticuleInvalid() throws {
        do {
            _ = try parse("radar-beta\n  graticule invalid")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
        }
    }

    @Test("min option")
    func minOption() throws {
        let d = try parse("radar-beta\n  min 10")
        #expect(d.options.min == 10)
    }

    @Test("max option")
    func maxOption() throws {
        let d = try parse("radar-beta\n  max 100")
        #expect(d.options.max == 100)
    }

    @Test("min and max together")
    func minAndMaxTogether() throws {
        let d = try parse("radar-beta\n  min 5\n  max 50")
        #expect(d.options.min == 5)
        #expect(d.options.max == 50)
    }

    @Test("min default")
    func minDefault() throws {
        let d = try parse("radar-beta")
        #expect(d.options.min == 0)
    }

    @Test("max default")
    func maxDefault() throws {
        let d = try parse("radar-beta")
        #expect(d.options.max == nil)
    }

    @Test("Multiple options last-write-wins")
    func optionsLastWriteWins() throws {
        let d = try parse("radar-beta\n  ticks 5\n  ticks 10\n  showLegend true\n  showLegend false\n  min 0\n  min 5\n  graticule circle\n  graticule polygon")
        #expect(d.options.ticks == 10)
        #expect(d.options.showLegend == false)
        #expect(d.options.min == 5)
        #expect(d.options.graticule == .polygon)
    }

    @Test("Options interleaved with other statements")
    func optionsInterleaved() throws {
        let d = try parse("radar-beta\n  axis A\n  ticks 10\n  curve c1{1}\n  showLegend false")
        #expect(d.options.ticks == 10)
        #expect(d.options.showLegend == false)
        #expect(d.axes.count == 1)
        #expect(d.curves.count == 1)
    }

    // MARK: - Comment tests

    @Test("%% comment lines are ignored")
    func commentsIgnored() throws {
        let d = try parse("radar-beta\n  %% This is a comment\n  axis A\n  %% Another comment\n  curve c1{1}")
        #expect(d.axes.count == 1)
        #expect(d.curves.count == 1)
    }

    @Test("%% comment before header")
    func commentBeforeHeader() throws {
        let d = try parse("%% Pre-header comment\nradar-beta\n  axis A")
        #expect(d.axes.count == 1)
    }

    // MARK: - End-to-end DiagramPipeline.parse tests

    @Test("End-to-end parsing through DiagramPipeline")
    func endToEndParsing() async throws {
        let graph = try await DiagramEngine.parse("radar-beta\n  axis A,B\n  curve c1{1,2}")
        guard case .radar(let diagram) = graph.payload else {
            #expect(Bool(false), "Expected .radar payload")
            return
        }
        #expect(diagram.axes.map(\.name) == ["A", "B"])
        #expect(diagram.curves.count == 1)
        #expect(diagram.curves[0].entries == [1, 2])
    }

    @Test("End-to-end parsing with title and accessibility")
    func endToEndWithTitleAndAccessibility() async throws {
        let graph = try await DiagramEngine.parse("radar-beta title My Radar accTitle: AT\n  axis A\n  curve c1{1}")
        guard case .radar(let diagram) = graph.payload else {
            #expect(Bool(false), "Expected .radar payload")
            return
        }
        #expect(diagram.diagramTitle == "My Radar")
        #expect(diagram.accTitle == "AT")
    }

    @Test("End-to-end parsing with options")
    func endToEndWithOptions() async throws {
        let graph = try await DiagramEngine.parse("radar-beta\n  ticks 8\n  showLegend false\n  graticule polygon\n  min 1\n  max 200\n  axis A\n  curve c1{1}")
        guard case .radar(let diagram) = graph.payload else {
            #expect(Bool(false), "Expected .radar payload")
            return
        }
        #expect(diagram.options.ticks == 8)
        #expect(diagram.options.showLegend == false)
        #expect(diagram.options.graticule == .polygon)
        #expect(diagram.options.min == 1)
        #expect(diagram.options.max == 200)
    }

    @Test("Init directive frontmatter parsing preserves radar config and theme")
    func initDirectiveFrontmatterParsing() throws {
        let source = """
        %%{init: {'radar': {'marginTop': 80, 'axisLabelFactor': 1.25}, 'theme': 'base', 'themeVariables': {'fontSize': 10, 'cScale0': '#123456', 'radar': {'axisColor': '#FF0000'}}}}%%
        radar-beta
          axis A,B,C
          curve mycurve{1,2,3}
        """

        let (processed, frontmatter) = _parseFrontMatterAndStripped(source)
        #expect(processed.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("radar-beta"))
        let parsedFrontmatter = try #require(frontmatter)
        let radarConfig = try #require(parsedFrontmatter.perDiagram.radar.config)
        let radarTheme = try #require(parsedFrontmatter.perDiagram.radar.theme)
        #expect(parsedFrontmatter.theme == "base")
        #expect(radarConfig.marginTop == 80)
        #expect(radarConfig.axisLabelFactor == 1.25)
        #expect(radarTheme.fontSize == 10)
        #expect(radarTheme.cScale[0] == "#123456")
        #expect(radarTheme.axisColor == "#FF0000")
    }

    @Test("End-to-end parsing applies init directive radar config and theme")
    func endToEndWithInitDirectiveConfigAndTheme() async throws {
        let source = """
        %%{init: {'radar': {'marginTop': 80, 'axisLabelFactor': 1.25}, 'theme': 'base', 'themeVariables': {'fontSize': 10, 'cScale0': '#123456', 'radar': {'axisColor': '#FF0000'}}}}%%
        radar-beta
          axis A,B,C
          curve mycurve{1,2,3}
        """

        let graph = try await DiagramEngine.parse(source)
        guard case .radar(let diagram) = graph.payload else {
            #expect(Bool(false), "Expected .radar payload")
            return
        }
        #expect(diagram.config.marginTop == 80)
        #expect(diagram.config.axisLabelFactor == 1.25)
        #expect(diagram.theme.fontSize == 10)
        #expect(diagram.theme.cScale[0] == "#123456")
        #expect(diagram.theme.axisColor == "#FF0000")
    }

    @Test("End-to-end full radar example")
    func endToEndFullExample() async throws {
        let source = """
        radar-beta title Sales Performance
          accTitle: Sales Performance Radar
          accDescr {
            A radar chart showing sales across
            regions for Q1 and Q2.
          }
          axis Revenue["Revenue"], Growth["Growth %"], Satisfaction["Satisfaction"]
          curve Q1{90, 70, 80}
          curve Q2{95, 85, 75}
          ticks 10
          showLegend true
          graticule polygon
          min 0
          max 100
        """
        let graph = try await DiagramEngine.parse(source)
        guard case .radar(let diagram) = graph.payload else {
            #expect(Bool(false), "Expected .radar payload")
            return
        }
        #expect(diagram.diagramTitle == "Sales Performance")
        #expect(diagram.accTitle == "Sales Performance Radar")
        #expect(diagram.accDescr == "A radar chart showing sales across\nregions for Q1 and Q2.")
        #expect(diagram.axes.map(\.name) == ["Revenue", "Growth", "Satisfaction"])
        #expect(diagram.axes.map(\.label) == ["Revenue", "Growth %", "Satisfaction"])
        #expect(diagram.curves.count == 2)
        #expect(diagram.curves[0].name == "Q1")
        #expect(diagram.curves[0].entries == [90, 70, 80])
        #expect(diagram.curves[1].name == "Q2")
        #expect(diagram.curves[1].entries == [95, 85, 75])
        #expect(diagram.options.ticks == 10)
        #expect(diagram.options.showLegend == true)
        #expect(diagram.options.graticule == .polygon)
        #expect(diagram.options.min == 0)
        #expect(diagram.options.max == 100)
    }

    // MARK: - Frontmatter tests

    @Test("Frontmatter radarConfig overrides defaults")
    func frontmatterConfig() throws {
        var fm = DiagramFrontmatter()
        var config = RadarDiagramConfig.default
        config.width = 800
        config.height = 800
        config.marginTop = 20
        config.curveTension = 0.25
        fm.perDiagram.radar.config = config

        let d = try parseWithFrontmatter("radar-beta\n  axis A\n  curve c1{1}", frontmatter: fm)
        #expect(d.config.width == 800)
        #expect(d.config.height == 800)
        #expect(d.config.marginTop == 20)
        #expect(d.config.curveTension == 0.25)
    }

    @Test("Frontmatter radarTheme overrides defaults")
    func frontmatterTheme() throws {
        var fm = DiagramFrontmatter()
        var theme = RadarThemeConfig.default
        theme.fontSize = 24
        theme.axisColor = "#FF0000"
        theme.curveOpacity = 0.8
        fm.perDiagram.radar.theme = theme

        let d = try parseWithFrontmatter("radar-beta\n  axis A\n  curve c1{1}", frontmatter: fm)
        #expect(d.theme.fontSize == 24)
        #expect(d.theme.axisColor == "#FF0000")
        #expect(d.theme.curveOpacity == 0.8)
    }

    @Test("Frontmatter diagramTitle when diagram has no title")
    func frontmatterDiagramTitleFallback() throws {
        var fm = DiagramFrontmatter()
        fm.shared.diagramTitle = "Fallback Title"

        let d = try parseWithFrontmatter("radar-beta\n  axis A\n  curve c1{1}", frontmatter: fm)
        #expect(d.diagramTitle == "Fallback Title")
    }

    @Test("Frontmatter title does not override diagram title")
    func frontmatterTitleNoOverride() throws {
        var fm = DiagramFrontmatter()
        fm.shared.diagramTitle = "Fallback Title"

        let d = try parseWithFrontmatter("radar-beta title My Title\n  axis A\n  curve c1{1}", frontmatter: fm)
        #expect(d.diagramTitle == "My Title")
    }

    // MARK: - Edge case tests

    @Test("Curve name with leading/trailing whitespace trimmed")
    func curveNameTrimmed() throws {
        let d = try parse("radar-beta\n  axis A\n  curve  c1 {1}")
        #expect(d.curves[0].name == "c1")
    }

    @Test("Axis with special characters in name")
    func axisNameSpecialCharacters() throws {
        let d = try parse("radar-beta\n  axis axis_1, axis-2\n  curve c1{1,2}")
        #expect(d.axes.map(\.name) == ["axis_1", "axis-2"])
    }

    @Test("Curve with special characters in name")
    func curveNameSpecialCharacters() throws {
        let d = try parse("radar-beta\n  axis A\n  curve my_curve-1{1}")
        #expect(d.curves[0].name == "my_curve-1")
    }

    @Test("Header with only tabs before it")
    func headerWithTabsOnly() throws {
        let d = try parse("\t\tradar-beta\n  axis A\n  curve c1{1}")
        #expect(d.axes.count == 1)
    }

    @Test("Indented axis and curve with consistent whitespace")
    func indentedContent() throws {
        let d = try parse("radar-beta\n    axis A, B, C\n    curve c1{1, 2, 3}")
        #expect(d.axes.map(\.name) == ["A", "B", "C"])
        #expect(d.curves[0].entries == [1, 2, 3])
    }

    @Test("Full example with detailed entries")
    func fullDetailedExample() throws {
        let source = """
        radar-beta title Skills Assessment
          accTitle: Skills Radar
          axis Coding["Coding"], Design["Design"], Communication["Communication"], Leadership["Leadership"]
          curve Alice{Coding: 90, Design: 60, Communication: 80, Leadership: 70}
          curve Bob{Coding: 75, Design: 85, Communication: 65, Leadership: 80}
          showLegend true
          graticule polygon
          min 0
          max 100
        """
        let d = try parse(source)
        #expect(d.diagramTitle == "Skills Assessment")
        #expect(d.accTitle == "Skills Radar")
        #expect(d.axes.map(\.name) == ["Coding", "Design", "Communication", "Leadership"])
        #expect(d.axes.map(\.label) == ["Coding", "Design", "Communication", "Leadership"])
        #expect(d.curves.count == 2)
        #expect(d.curves[0].name == "Alice")
        #expect(d.curves[0].entries == [90, 60, 80, 70])
        #expect(d.curves[1].name == "Bob")
        #expect(d.curves[1].entries == [75, 85, 65, 80])
        #expect(d.options.showLegend == true)
        #expect(d.options.graticule == .polygon)
    }

    @Test("Unclosed curve brace throws with line number")
    func unclosedCurveBrace() throws {
        do {
            _ = try parse("radar-beta\n  axis A\n  curve c1{1")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
        }
    }

    @Test("Non-numeric entry in numeric mode throws with line number")
    func invalidNumericEntry() throws {
        do {
            _ = try parse("radar-beta\n  axis A,B\n  curve c1{1, abc}")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
        }
    }

    @Test("Non-numeric value in detailed mode throws with line number")
    func invalidDetailedValue() throws {
        do {
            _ = try parse("radar-beta\n  axis A,B\n  curve c1{A: abc, B: 2}")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            #expect(error.line > 0)
        }
    }

    @Test("Error message includes Parse error on line prefix")
    func errorMessageFormat() throws {
        do {
            _ = try parse("radar-beta\n  axis")
            #expect(Bool(false), "Expected error")
        } catch let error as RadarParserError {
            let desc = try #require(error.errorDescription)
            #expect(desc.hasPrefix("Parse error on line"))
            #expect(desc.contains("column ?:"))
            #expect(desc.contains("Empty axis declaration"))
        }
    }

    @Test("Curve entries with commas inside quoted strings pass through")
    func curveEntriesInQuotes() throws {
        let d = try parse("radar-beta\n  axis A\n  curve c1{1}\n  curve c2{2}")
        #expect(d.curves.count == 2)
        #expect(d.curves[0].entries == [1])
        #expect(d.curves[1].entries == [2])
    }

    @Test("Single curve before axis declarations")
    func curveBeforeAxis() throws {
        let d = try parse("radar-beta\n  curve c1{1}\n  axis A")
        #expect(d.curves.count == 1)
        #expect(d.axes.count == 1)
    }
}

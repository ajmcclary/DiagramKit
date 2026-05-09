import XCTest
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

final class WardleyMapFrontmatterTests: XCTestCase {
    func testYamlFrontmatterAppliesWardleyConfigAndTheme() throws {
        let source = """
        ---
        title: Wardley Frontmatter
        config:
          wardley-beta:
            width: 1024
            height: 640
            padding: 72
            nodeRadius: 11
            nodeLabelOffset: 17
            axisFontSize: 18
            labelFontSize: 13
            showGrid: true
            useMaxWidth: false
        themeVariables:
          wardley:
            backgroundColor: "#112233"
            axisColor: "#abcdef"
            componentFill: "#fedcba"
          wardleyEvolutionColor: "#00ff00"
        ---
        wardley-beta
        component A [0.5, 0.5]
        evolve A 0.7
        """

        let graph = try MermaidParser.parse(source)
        guard case .wardleyBeta(let diagram) = graph.payload else {
            return XCTFail("Expected Wardley payload")
        }

        XCTAssertEqual(diagram.config.width, 1024)
        XCTAssertEqual(diagram.config.height, 640)
        XCTAssertEqual(diagram.config.padding, 72)
        XCTAssertEqual(diagram.config.nodeRadius, 11)
        XCTAssertEqual(diagram.config.nodeLabelOffset, 17)
        XCTAssertEqual(diagram.config.axisFontSize, 18)
        XCTAssertEqual(diagram.config.labelFontSize, 13)
        XCTAssertTrue(diagram.config.showGrid)
        XCTAssertFalse(diagram.config.useMaxWidth)
        XCTAssertEqual(diagram.diagramTitle, "Wardley Frontmatter")
        XCTAssertEqual(diagram.theme?.backgroundColor, "#112233")
        XCTAssertEqual(diagram.theme?.axisColor, "#abcdef")
        XCTAssertEqual(diagram.theme?.componentFill, "#fedcba")
        XCTAssertEqual(diagram.theme?.evolutionStroke, "#00ff00")
        XCTAssertEqual(diagram.theme?.evolutionColor, "#00ff00")

        let positioned = try GraphLayout().layout(graph)
        XCTAssertEqual(positioned.wardleyMapData?.width, 1024)
        XCTAssertTrue(positioned.wardleyMapData?.showGrid ?? false)
    }

    func testInitDirectiveAppliesWardleyConfigAndTheme() throws {
        let source = """
        %%{init: {'config': {'wardley-beta': {'width': 720, 'showGrid': true}, 'themeVariables': {'wardley': {'componentFill': '#ffcc00'}, 'wardleyEvolutionColor': '#123456'}}}}%%
        wardley-beta
        component A [0.5, 0.5]
        evolve A 0.8
        """

        let graph = try MermaidParser.parse(source)
        guard case .wardleyBeta(let diagram) = graph.payload else {
            return XCTFail("Expected Wardley payload")
        }

        XCTAssertEqual(diagram.config.width, 720)
        XCTAssertTrue(diagram.config.showGrid)
        XCTAssertEqual(diagram.theme?.componentFill, "#ffcc00")
        XCTAssertEqual(diagram.theme?.evolutionStroke, "#123456")
        XCTAssertEqual(diagram.theme?.evolutionColor, "#123456")
    }
}

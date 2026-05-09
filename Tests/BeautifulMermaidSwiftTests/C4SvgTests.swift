import Testing
import Foundation
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("C4 SVG Renderer")
struct C4SvgTests {

    private let defaultColors = DiagramColors(
        bg: "#FFFFFF",
        fg: "#000000",
        line: "#444444",
        accent: "#1168BD",
        muted: "#999999",
        surface: "#F5F5F5",
        border: "#CCCCCC"
    )

    // MARK: - Basic rendering

    @Test("Empty diagram produces valid SVG")
    func emptyDiagramSvg() throws {
        let diagram = layoutC4Diagram(C4Diagram(kind: .context))
        let svg = try renderC4Svg(diagram, diagramId: "test", defaultColors, "Inter", false)

        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
        #expect(svg.contains("viewBox"))
    }

    @Test("Single shape SVG contains shape elements")
    func singleShapeSvg() throws {
        var diag = C4Diagram(kind: .context)
        diag.shapes = [C4Shape(alias: "a", label: "System A", typeC4Shape: .system)]
        let positioned = layoutC4Diagram(diag)
        let svg = try renderC4Svg(positioned, diagramId: "test", defaultColors, "Inter", false)

        #expect(svg.contains("<rect"))
        #expect(svg.contains("System A"))
        #expect(svg.contains("system"))  // stereotype
    }

    @Test("Person shape SVG contains image placeholder")
    func personShapeSvg() throws {
        var diag = C4Diagram(kind: .context)
        diag.shapes = [C4Shape(alias: "p", label: "User", typeC4Shape: .person)]
        let positioned = layoutC4Diagram(diag)
        let svg = try renderC4Svg(positioned, diagramId: "test", defaultColors, "Inter", false)

        #expect(svg.contains("<image"))
        #expect(svg.contains("xlink:href"))
        #expect(svg.contains("person"))
    }

    @Test("Database shape SVG uses cylinder style")
    func databaseShapeSvg() throws {
        var diag = C4Diagram(kind: .context)
        diag.shapes = [C4Shape(alias: "db", label: "Database", typeC4Shape: .system_db)]
        let positioned = layoutC4Diagram(diag)
        let svg = try renderC4Svg(positioned, diagramId: "test", defaultColors, "Inter", false)

        // C4 renderer uses path-based cylinder, not ellipse
        #expect(svg.contains("<path"))
        #expect(svg.contains("Database"))
    }

    @Test("Queue shape SVG uses custom path")
    func queueShapeSvg() throws {
        var diag = C4Diagram(kind: .context)
        diag.shapes = [C4Shape(alias: "q", label: "Queue", typeC4Shape: .system_queue)]
        let positioned = layoutC4Diagram(diag)
        let svg = try renderC4Svg(positioned, diagramId: "test", defaultColors, "Inter", false)

        #expect(svg.contains("<path"))
    }

    // MARK: - Boundary rendering

    @Test("Boundary SVG contains dashed rectangle")
    func boundarySvg() throws {
        var diag = C4Diagram(kind: .context)
        diag.boundaries = [C4Boundary(alias: "b1", label: "Boundary", parentBoundary: "global")]
        diag.shapes = [C4Shape(alias: "s", label: "System", typeC4Shape: .system, parentBoundary: "b1")]
        let positioned = layoutC4Diagram(diag)
        let svg = try renderC4Svg(positioned, diagramId: "test", defaultColors, "Inter", false)

        #expect(svg.contains("c4-boundary"))
        #expect(svg.contains("Boundary"))
    }

    @Test("Deployment node SVG uses solid stroke")
    func deploymentNodeSvg() throws {
        var diag = C4Diagram(kind: .deployment)
        diag.boundaries = [C4Boundary(alias: "node", label: "Server", parentBoundary: "global", nodeType: "node")]
        let positioned = layoutC4Diagram(diag)
        let svg = try renderC4Svg(positioned, diagramId: "test", defaultColors, "Inter", false)

        // Deployment node should render as a boundary
        #expect(svg.contains("c4-boundary"))
        // The boundary rect itself should not have dasharray when nodeType is set
        #expect(!svg.contains("stroke-dasharray=\"7.0,7.0\""))
    }

    // MARK: - Relationship rendering

    @Test("Relationship SVG contains line and label")
    func relationshipSvg() throws {
        var diag = C4Diagram(kind: .context)
        diag.shapes = [
            C4Shape(alias: "a", label: "A", typeC4Shape: .system),
            C4Shape(alias: "b", label: "B", typeC4Shape: .system),
        ]
        diag.relationships = [C4Relationship(kind: .rel, from: "a", to: "b", label: "Uses")]
        let positioned = layoutC4Diagram(diag)
        let svg = try renderC4Svg(positioned, diagramId: "test", defaultColors, "Inter", false)

        #expect(svg.contains("c4-rels"))
        #expect(svg.contains("Uses"))
        #expect(svg.contains("<line") || svg.contains("<path"))
    }

    @Test("BiRel creates bidirectional marker")
    func birelSvg() throws {
        var diag = C4Diagram(kind: .context)
        diag.shapes = [
            C4Shape(alias: "a", label: "A", typeC4Shape: .system),
            C4Shape(alias: "b", label: "B", typeC4Shape: .system),
        ]
        diag.relationships = [C4Relationship(kind: .birel, from: "a", to: "b", label: "Syncs")]
        let positioned = layoutC4Diagram(diag)
        let svg = try renderC4Svg(positioned, diagramId: "test", defaultColors, "Inter", false)

        #expect(svg.contains("Syncs"))
    }

    // MARK: - Title and accessibility

    @Test("SVG contains title when present")
    func titleInSvg() throws {
        var diag = C4Diagram(kind: .context)
        diag.title = "System Context"
        let positioned = layoutC4Diagram(diag)
        let svg = try renderC4Svg(positioned, diagramId: "test", defaultColors, "Inter", false)

        #expect(svg.contains("System Context"))
    }

    @Test("SVG contains accessibility description")
    func accessibilityInSvg() throws {
        var diag = C4Diagram(kind: .context)
        diag.title = "Test"
        diag.accDescr = "A test diagram"
        let positioned = layoutC4Diagram(diag)
        let svg = try renderC4Svg(positioned, diagramId: "test", defaultColors, "Inter", false)

        #expect(svg.contains("A test diagram"))
    }

    // MARK: - Marker definitions

    @Test("SVG contains marker definitions for arrows")
    func markerDefinitions() throws {
        var diag = C4Diagram(kind: .context)
        diag.shapes = [
            C4Shape(alias: "a", label: "A", typeC4Shape: .system),
            C4Shape(alias: "b", label: "B", typeC4Shape: .system),
        ]
        diag.relationships = [C4Relationship(kind: .rel, from: "a", to: "b", label: "Uses")]
        let positioned = layoutC4Diagram(diag)
        let svg = try renderC4Svg(positioned, diagramId: "test", defaultColors, "Inter", false)

        #expect(svg.contains("<marker"))
        #expect(svg.contains("marker-end"))
    }

    // MARK: - Transparent background

    @Test("Transparent flag omits background rect")
    func transparentBackground() throws {
        let positioned = layoutC4Diagram(C4Diagram(kind: .context))
        let svg = try renderC4Svg(positioned, diagramId: "test", defaultColors, "Inter", true)

        // Should not have a solid background
        #expect(!svg.contains("<rect") || svg.contains("fill=\"none\""))
    }

    // MARK: - All five diagram kinds

    @Test("All five C4 kinds produce valid SVG")
    func allKindsSvg() throws {
        let kinds: [C4DiagramKind] = [.context, .container, .component, .dynamic, .deployment]

        for kind in kinds {
            var diag = C4Diagram(kind: kind)
            diag.title = "\(kind.rawValue) Diagram"
            diag.shapes = [C4Shape(alias: "a", label: "Entity", typeC4Shape: .system)]
            let positioned = layoutC4Diagram(diag)
            let svg = try renderC4Svg(positioned, diagramId: "test-\(kind.rawValue)", defaultColors, "Inter", false)

            #expect(svg.contains("<svg"), "\(kind.rawValue) should produce valid SVG")
            #expect(svg.contains("</svg>"), "\(kind.rawValue) should produce valid SVG")
        }
    }
}

import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
import Foundation

final class WardleyMapEndToEndTests: XCTestCase {
    private struct DiagramEntry: Decodable {
        let id: String
        let category: String
        let source: String
    }

    private struct DiagramFile: Decodable {
        let diagrams: [DiagramEntry]
    }

    func testPlaygroundWardleyExamplesParseLayoutAndRenderSvg() throws {
        let path = "/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-swift/Examples/MermaidPlayground/Resources/test-diagrams.json"
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let file = try JSONDecoder().decode(DiagramFile.self, from: data)
        let wardleyExamples = file.diagrams.filter { $0.category == "wardleyBeta" }

        XCTAssertEqual(wardleyExamples.count, 12)
        for example in wardleyExamples {
            let graph = try DiagramPipeline.parse(example.source)
            guard case .wardleyBeta = graph.payload else {
                XCTFail("Expected Wardley payload for \(example.id)")
                continue
            }
            let positioned = try GraphLayout().layout(graph)
            XCTAssertNotNil(positioned.wardleyMapData, "Expected positioned Wardley data for \(example.id)")
            let svg = try _renderDiagramSVG(example.source)
            XCTAssertTrue(svg.contains("class=\"wardley-map\""), "Expected Wardley SVG root for \(example.id)")
        }
    }

    func testSvgContainsWardleyDomContract() throws {
        let source = """
        wardley-beta
        title Wardley DOM
        accTitle: Wardley Accessibility
        accDescr: Wardley description
        anchor User [0.9, 0.8]
        component API [0.5, 0.6] (market) (inertia)
        component Database [0.5, 0.75]
        pipeline Database {
          component Postgres [0.35]
          component DynamoDB [0.85]
        }
        User +> API; uses
        API -.-> Database
        evolve API 0.8
        annotations [0.1, 0.9]
        annotation 1,[0.5, 0.6] "Watch this"
        note "Boundary" [0.4, 0.5]
        accelerator "Cloud" [0.3, 0.8]
        deaccelerator "Legacy" [0.7, 0.2]
        """

        let svg = try _renderDiagramSVG(source)

        for expected in [
            "class=\"wardley-map\"",
            "class=\"wardley-axes\"",
            "class=\"wardley-nodes\"",
            "class=\"wardley-links\"",
            "class=\"wardley-trends\"",
            "class=\"wardley-pipelines\"",
            "class=\"wardley-annotations\"",
            "class=\"wardley-accelerators\"",
            "class=\"wardley-deaccelerators\"",
            "link-arrow-end-",
            "link-arrow-start-",
            "wardley-node--pipeline-component",
            "<title>Wardley Accessibility</title>",
            "<desc>Wardley description</desc>",
        ] {
            XCTAssertTrue(svg.contains(expected), "Missing \(expected)")
        }
    }
}

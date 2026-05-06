import XCTest
@testable import BeautifulMermaid

final class XYChartCrashRegressionTests: XCTestCase {

    func test_dataLongerThanCategories_doesNotCrash() async throws {
        let variants = [
            // vertical (default)
            """
            xychart-beta
                title "Vertical mixed"
                x-axis [Jan, Feb, Mar]
                y-axis "Revenue" 0 --> 1000
                bar [100, 200, 300, 400, 500]
                line [150, 250, 350, 450, 550]
            """,
            // horizontal
            """
            xychart-beta horizontal
                title "Horizontal mixed"
                x-axis [Jan, Feb, Mar]
                y-axis "Revenue" 0 --> 1000
                bar [100, 200, 300, 400, 500]
                line [150, 250, 350, 450, 550]
            """,
        ]

        for source in variants {
            let svg = try await renderMermaidSVG(source, RenderOptions())
            XCTAssertFalse(svg.isEmpty, "Expected non-empty SVG for source:\n\(source)")
        }
    }

    func test_renderer_handlesInfiniteAndOverflowCoordinates() async throws {
        // Tiny y-axis range with large values can yield non-finite scaled coordinates.
        let infSource = """
        xychart-beta
            title "Inf coords"
            x-axis [A, B, C]
            y-axis "v" 0 --> 0
            bar [1, 2, 3]
            line [1, 2, 3]
        """
        let svg1 = try await renderMermaidSVG(infSource, RenderOptions())
        XCTAssertFalse(svg1.isEmpty)

        // Very large Mermaid-valid decimal literals can overflow when multiplied by scaling factors.
        let huge = String(repeating: "9", count: 400)
        let overflowSource = """
        xychart-beta
            title "Overflow coords"
            x-axis [A, B, C]
            y-axis "v" 0 --> \(huge)
            bar [\(huge), \(huge), \(huge)]
            line [\(huge), \(huge), \(huge)]
        """
        let svg2 = try await renderMermaidSVG(overflowSource, RenderOptions())
        XCTAssertFalse(svg2.isEmpty)
    }

    func test_ascii_handlesInfiniteAndNaNValues() async throws {
        // The ASCII path uses Int(round(...)) which traps on Inf/NaN; verify the guard works.
        let source = """
        xychart-beta
            title "ASCII guard"
            x-axis [A, B, C]
            y-axis "v" 0 --> 0
            bar [1, 2, 3]
            line [1, 2, 3]
        """
        let ascii = try await MermaidRenderer.renderASCII(source: source)
        XCTAssertFalse(ascii.isEmpty)
    }
}

import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

final class DiagramPipelineReviewRegressionTests: XCTestCase {

    // Critical 1: `DiagramPipeline.renderSVG` must not round-trip theme colors
    // through `hexString` — that strips alpha. A non-opaque theme background
    // must survive into the SVG output as `rgba(...)` (or `#RRGGBBAA`).

    func testRenderSVGFromSourcePreservesNonOpaqueThemeAlpha() throws {
        let translucentRed = BMColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)
        let theme = DiagramTheme(
            background: translucentRed,
            foreground: BMColor(hex: "#000000")
        )

        let svg = try DiagramPipeline.renderSVG(
            source: "flowchart LR\n  A --> B\n",
            theme: theme
        )

        XCTAssertTrue(
            svg.contains("rgba(") || svg.range(of: #"#[0-9A-Fa-f]{8}\b"#, options: .regularExpression) != nil,
            "Expected SVG to encode non-opaque theme color as rgba(...) or #RRGGBBAA. Got:\n\(svg)"
        )
    }

    func testRenderSVGFromPositionedPreservesNonOpaqueThemeAlpha() throws {
        let translucentBlue = BMColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.25)
        let theme = DiagramTheme(
            background: BMColor(hex: "#FFFFFF"),
            foreground: BMColor(hex: "#000000"),
            line: translucentBlue
        )

        let positioned = try DiagramPipeline.layout("flowchart LR\n  A --> B\n")
        let svg = try DiagramPipeline.renderSVG(positioned: positioned, theme: theme)

        XCTAssertTrue(
            svg.contains("rgba("),
            "Expected SVG to encode non-opaque theme `line` color as rgba(...). Got:\n\(svg)"
        )
    }
}

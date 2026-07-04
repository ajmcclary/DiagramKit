import Testing
@testable import DiagramKitSample

@Suite struct PlatformParityMatrixTests {
    @Test func shapeMatchesComp() {
        #expect(PlatformParityMatrix.columns == ["macOS", "iOS", "Linux"])
        #expect(PlatformParityMatrix.rows.count == 6)
        let svg = PlatformParityMatrix.rows.first { $0.feature == "SVG render" }
        #expect(svg?.cells == [.full, .full, .partial])
        let img = PlatformParityMatrix.rows.first { $0.feature == "Image render" }
        #expect(img?.cells == [.full, .full, .unsupported])
        #expect(img?.mono == "CG")
    }
}

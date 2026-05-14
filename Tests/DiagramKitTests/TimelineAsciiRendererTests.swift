import Testing
import DiagramKit

@Suite struct TimelineAsciiRendererTests {

    @Test("Timeline ASCII renderer emits sections and events")
    func basicTimeline() throws {
        let source = """
        timeline
            title History
            2021 : Started
            2022 : Grew
        """
        let output = try DiagramPipeline.renderASCII(source: source).text
        #expect(output.contains("History"))
        #expect(output.contains("2021"))
        #expect(output.contains("Started"))
        #expect(output.contains("2022"))
        #expect(output.contains("Grew"))
    }
}

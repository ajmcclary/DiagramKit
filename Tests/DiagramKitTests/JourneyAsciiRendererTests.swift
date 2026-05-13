import Testing
import DiagramKit

@Suite struct JourneyAsciiRendererTests {

    @Test("Journey ASCII renderer emits tasks with scores")
    func basicJourney() throws {
        let source = """
        journey
            title My Journey
            section Morning
                Coffee: 5: Me
                Commute: 2: Me, Train
            section Work
                Code: 4: Me
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("My Journey"))
        #expect(output.contains("Morning"))
        #expect(output.contains("Coffee"))
        #expect(output.contains("Work"))
        #expect(output.contains("5"))
    }
}

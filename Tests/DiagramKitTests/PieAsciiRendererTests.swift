import Testing
import DiagramKit

@Suite struct PieAsciiRendererTests {

    @Test("Pie ASCII renderer emits title and per-slice percentage rows")
    func basicPie() throws {
        let source = """
        pie title Fruit
            "Apple" : 30
            "Banana" : 20
            "Cherry" : 10
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("Fruit"))
        #expect(output.contains("Apple"))
        #expect(output.contains("Banana"))
        #expect(output.contains("Cherry"))
        // 30 / 60 = 50%
        #expect(output.contains("50"))
        #expect(output.contains("%"))
    }

    @Test("Pie ASCII renderer handles a single-slice chart")
    func singleSlice() throws {
        let source = """
        pie
            "Alone" : 100
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("Alone"))
        #expect(output.contains("100"))
    }

    @Test("Pie ASCII renderer returns empty/safe output for empty pie")
    func emptyPie() throws {
        let source = """
        pie title Nothing
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        // Should at least include the title without crashing.
        #expect(output.contains("Nothing"))
    }
}

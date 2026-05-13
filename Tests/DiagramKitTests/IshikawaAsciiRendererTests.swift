import Testing
import DiagramKit

@Suite struct IshikawaAsciiRendererTests {

    @Test("Ishikawa ASCII renderer emits effect plus cause branches")
    func basicIshikawa() throws {
        let source = """
        ishikawa-beta
          [Problem]
            [Method]
              [Cause M1]
            [Material]
              [Cause Mat1]
        """
        let output = try DiagramPipeline.renderASCII(source: source)
        #expect(output.contains("Problem"))
        #expect(output.contains("Method"))
        #expect(output.contains("Material"))
    }
}

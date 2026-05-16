import Testing
import IssueReporting
import DiagramKit

@Suite("XY Chart ASCII Renderer")
struct XYChartAsciiRendererTests {

    @Test("Renders a basic vertical bar chart")
    func basicBarChart() throws {
        let source = """
        xychart-beta
            title "Sales"
            x-axis [Jan, Feb, Mar]
            y-axis "Units" 0 --> 100
            bar [30, 50, 70]
        """
        let output = try DiagramPipeline.renderASCII(source: source).text
        #expect(output.contains("Sales"))
        #expect(output.contains("Jan") || output.contains("Feb") || output.contains("Mar"))
        // No legacy sentinel: the previous buggy code returned
        // `"XY Chart parse error: ..."` on any internal failure.
        #expect(!output.contains("XY Chart parse error"))
    }

    @Test("Malformed XY chart source throws instead of returning a sentinel string")
    func malformedSourceThrows() {
        // `xychart-beta` claims the format probe so the import path
        // dispatches to the XY chart parser, which then fails on the
        // malformed body. Pre-fix: `renderXYChartAscii` returned
        // `"XY Chart parse error: ..."` as the rendered text. Post-fix:
        // the function throws; `DiagramPipeline.renderASCII` re-throws
        // through `_withDiagramIssueReporting` (which records an
        // expected issue captured by `withKnownIssue`).
        let source = """
        xychart-beta
        this is not a valid xychart body
        """
        var didThrow = false
        withKnownIssue {
            do {
                _ = try DiagramPipeline.renderASCII(source: source)
            } catch {
                didThrow = true
            }
        }
        #expect(didThrow, "renderASCII should throw on malformed XY chart source instead of returning a sentinel")
    }
}

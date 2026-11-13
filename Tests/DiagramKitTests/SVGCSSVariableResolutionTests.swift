import Foundation
import Testing
import DiagramKit

// `var(--…)` resolution used to rescan the document from the start after
// each replacement and give up after 4096, so a large diagram rendered its
// tail gray on gray (and the pass was quadratic); it also rewrote label
// text that happened to contain `var(`.

@Suite("SVG CSS variable resolution")
struct SVGCSSVariableResolutionTests {

    private func chain(_ count: Int) -> String {
        "flowchart TD\n" + (0..<(count - 1)).map { "  N\($0)[Node \($0)] --> N\($0 + 1)[Node \($0 + 1)]" }.joined(separator: "\n")
    }

    @Test("a 1,400-node chain resolves every variable")
    func largeChainResolves() async throws {
        let (small, large) = try await onDiagramWorker {
            (try DiagramPipeline.renderSVG(source: self.chain(5), idPolicy: .stable),
             try DiagramPipeline.renderSVG(source: self.chain(1400), idPolicy: .stable))
        }
        // The fallback gray in a fill/stroke attribute means a variable was
        // not resolved (the style block's own comments may mention it).
        let smallGray = small.contains("=\"#666666\"")
        let largeGray = large.contains("=\"#666666\"")
        let largeVar = large.contains("var(")
        #expect(smallGray == false)
        #expect(largeGray == false, "unresolved variables were flattened to gray")
        #expect(largeVar == false)
    }

    @Test("label text is not treated as CSS")
    func labelTextUntouched() async throws {
        let source = #"flowchart TD"# + "\n" + #"  A["use var(--bg) and var(x) and color-mix(in srgb, red, blue) here"]"#
        let svg = try await onDiagramWorker { try DiagramPipeline.renderSVG(source: source, idPolicy: .stable) }
        #expect(svg.contains("use var(--bg) and var(x) and color-mix(in srgb, red, blue) here"))
    }
}

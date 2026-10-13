// Visual editor plan 6 — adaptive layout preset changes geometry.

import Testing
@testable import DiagramKit
@testable import DiagramKitModel

@Suite
struct LayoutPresetTests {

    private let denseFlow = """
    graph TD
      A --> B
      A --> C
      B --> D
      C --> D
      D --> E
      B --> E
    """

    @Test("adaptive preset produces different geometry than hierarchical")
    func adaptiveDiffers() async throws {
        let hierarchical = try await DiagramEngine.renderSVG(source: denseFlow)
        let adaptive = try await DiagramEngine.renderSVG(
            source: "---\nconfig:\n  layout: adaptive\n---\n" + denseFlow
        )
        #expect(hierarchical.contains("<svg"))
        #expect(adaptive.contains("<svg"))
        #expect(hierarchical != adaptive, "adaptive preset must change layout output")
    }

    @Test("adaptive option dictionary widens spacing and sets the preset marker")
    func adaptiveOptions() {
        let opts = ElkLayoutOptions.root(direction: .TD, preset: .adaptive)
        #expect(opts["elk.spacing.nodeNode"] == "40")
        #expect(opts["elk.layered.spacing.nodeNodeBetweenLayers"] == "64")
        #expect(opts["diagramkit.layoutPreset"] == "adaptive")
        let defaults = ElkLayoutOptions.root(direction: .TD)
        #expect(defaults["elk.spacing.nodeNode"] == "28")
        #expect(defaults["diagramkit.layoutPreset"] == nil)
    }

    @Test("unknown layout value falls back to hierarchical without crashing")
    func unknownValue() async throws {
        let svg = try await DiagramEngine.renderSVG(
            source: "---\nconfig:\n  layout: bananas\n---\n" + denseFlow
        )
        #expect(svg.contains("<svg"))
    }
}

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

    @Test("adaptive option dictionary relaxes model order and widens spacing")
    func adaptiveOptions() {
        let opts = ElkLayoutOptions.root(
            direction: .TD, hierarchy: .includeChildren, preset: .adaptive
        )
        #expect(opts["elk.layered.considerModelOrder.strategy"] == "NONE")
        #expect(opts["elk.spacing.nodeNode"] == "40")
        #expect(opts["elk.layered.spacing.nodeNodeBetweenLayers"] == "64")
        let defaults = ElkLayoutOptions.root(direction: .TD, hierarchy: .includeChildren)
        #expect(defaults["elk.layered.considerModelOrder.strategy"] == "NODES_AND_EDGES")
    }

    @Test("unknown layout value falls back to hierarchical without crashing")
    func unknownValue() async throws {
        let svg = try await DiagramEngine.renderSVG(
            source: "---\nconfig:\n  layout: bananas\n---\n" + denseFlow
        )
        #expect(svg.contains("<svg"))
    }
}

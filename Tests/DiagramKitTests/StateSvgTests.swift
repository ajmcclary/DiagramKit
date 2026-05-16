import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

@Suite(.serialized)
@MainActor
struct StateSvgTests {

    @Test func emitsSvgWrapperAndStateStateClass() async throws {
        let svg = try await DiagramEngine.renderSVG(source: """
        stateDiagram-v2
            [*] --> A
            A --> [*]
        """)
        #expect(svg.contains("<svg"))
        #expect(svg.contains("xmlns"))
        #expect(svg.contains("statediagram-state"))
    }

    @Test func compositeStateEmitsClusterClass() async throws {
        let svg = try await DiagramEngine.renderSVG(source: """
        stateDiagram-v2
            state Active {
                A --> B
            }
            [*] --> Active
        """)
        #expect(svg.contains("statediagram-cluster"))
    }

    @Test func startPseudostateEmitsStateStartDataShape() async throws {
        let svg = try await DiagramEngine.renderSVG(source: """
        stateDiagram-v2
            [*] --> A
        """)
        #expect(svg.contains("data-shape=\"state-start\""))
    }

    @Test func endPseudostateEmitsStateEndDataShape() async throws {
        let svg = try await DiagramEngine.renderSVG(source: """
        stateDiagram-v2
            A --> [*]
        """)
        #expect(svg.contains("data-shape=\"state-end\""))
    }

    @Test func choiceForkJoinEmitDistinctDataShapes() async throws {
        let svg = try await DiagramEngine.renderSVG(source: """
        stateDiagram-v2
            state c <<choice>>
            state f <<fork>>
            state j <<join>>
            [*] --> c
            c --> f
            f --> j
            j --> [*]
        """)
        #expect(svg.contains("data-shape=\"choice\""))
        #expect(svg.contains("data-shape=\"fork\""))
        #expect(svg.contains("data-shape=\"join\""))
    }

    @Test func noteEmitsStatediagramNoteClass() async throws {
        let svg = try await DiagramEngine.renderSVG(source: """
        stateDiagram-v2
            S1 : Active
            note right of S1
                Important info
            end note
        """)
        #expect(svg.contains("statediagram-note"))
    }

    @Test func transitionEdgesGetTransitionClass() async throws {
        let svg = try await DiagramEngine.renderSVG(source: """
        stateDiagram-v2
            [*] --> A
            A --> B
            B --> [*]
        """)
        #expect(svg.contains("class=\"edge transition") || svg.contains("transition"))
    }

    @Test func accTitleAndAccDescrEmitTitleAndDescElements() async throws {
        let svg = try await DiagramEngine.renderSVG(source: """
        stateDiagram-v2
            accTitle: State machine title
            accDescr: A detailed description of states
            [*] --> A
        """)
        #expect(svg.contains("<title>State machine title</title>"))
        #expect(svg.contains("<desc>A detailed description of states</desc>"))
    }

    @Test func concurrencyDividerEmitsRegionSubgraph() async throws {
        let svg = try await DiagramEngine.renderSVG(source: """
        stateDiagram-v2
            state Composite {
                [*] --> A1
                A1 --> A2
                --
                [*] --> B1
            }
        """)
        #expect(svg.contains("Composite_region") || svg.contains("region"))
        // Divider node IDs are an internal artifact and must not leak.
        #expect(!svg.contains("_divider_"))
    }

    @Test func emptyStateDiagramStillEmitsSvgWrapper() async throws {
        let svg = try await DiagramEngine.renderSVG(source: "stateDiagram-v2")
        #expect(svg.contains("<svg"))
        #expect(svg.contains("</svg>"))
    }

    @Test func clickDirectiveEmitsInteractionMarkup() async throws {
        let svg = try await DiagramEngine.renderSVG(source: """
        stateDiagram-v2
            [*] --> A
            click A href "https://example.com"
        """)
        // The renderer encodes click metadata; precise emission shape is
        // internal, but the destination href must surface in the SVG output.
        #expect(svg.contains("example.com"))
    }

    @Test func multilineDescriptionStateUsesRectWithTitleShape() async throws {
        let svg = try await DiagramEngine.renderSVG(source: """
        stateDiagram-v2
            state Active {
                parse : Parsing
                parse : Input
                validate --> execute
            }
            [*] --> Active
        """)
        #expect(svg.contains("rect-with-title"))
    }
}

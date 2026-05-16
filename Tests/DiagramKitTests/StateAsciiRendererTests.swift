import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitModel

struct StateAsciiRendererTests {

    @Test func basicChainRendersStateLabels() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        stateDiagram-v2
            [*] --> A
            A --> B
            B --> [*]
        """)
        #expect(output.text.contains("A"))
        #expect(output.text.contains("B"))
        #expect(!output.text.isEmpty)
    }

    @Test func startPseudostateRendersStartGlyph() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        stateDiagram-v2
            [*] --> Active
        """)
        // src_ascii_shapes_state.swift draws either `●` (unicode) or `*` (ascii).
        let hasStart = output.text.contains("●") || output.text.contains("*")
        #expect(hasStart)
    }

    @Test func endPseudostateRendersDoubleRingGlyph() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        stateDiagram-v2
            Active --> [*]
        """)
        // End uses `◎` (unicode) or `#` border (ascii).
        let hasEnd = output.text.contains("◎") || output.text.contains("#") || output.text.contains("═")
        #expect(hasEnd)
    }

    @Test func compositeStateContentsAppearInOutput() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        stateDiagram-v2
            state Active {
                Open --> Closed
            }
            [*] --> Active
        """)
        #expect(output.text.contains("Open"))
        #expect(output.text.contains("Closed"))
    }

    @Test func transitionLabelsAppear() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        stateDiagram-v2
            Idle --> Ready : start
            Ready --> Idle : reset
        """)
        // Edge labels are surfaced in ASCII output.
        #expect(output.text.contains("start") || output.text.contains("reset"))
    }

    @Test func emptyStateDiagramReturnsEmptyTextWithoutThrow() async throws {
        let output = try await DiagramEngine.renderASCII(source: "stateDiagram-v2")
        // No nodes → empty (or near-empty) canvas, but the call must not throw.
        #expect(output.text.isEmpty || output.text.allSatisfy { $0.isWhitespace || $0.isNewline })
    }
}

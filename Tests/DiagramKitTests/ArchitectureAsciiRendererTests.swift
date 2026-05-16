import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitModel

struct ArchitectureAsciiRendererTests {

    @Test func singleServiceRendersBullet() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        architecture-beta
            service db1(database)[Database]
        """)
        // The renderer prefixes services with `•` and uses the service title.
        #expect(output.text.contains("Database"))
        #expect(output.text.contains("•"))
    }

    @Test func groupWithServicesNestsUnderBracketedGroupTitle() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        architecture-beta
            group api(cloud)[API Layer]
            service db1(database)[Database] in api
            service web1(server)[Web Server] in api
        """)
        // Group title surfaces inside square brackets, services indented below.
        #expect(output.text.contains("[API Layer]"))
        #expect(output.text.contains("Database"))
        #expect(output.text.contains("Web Server"))
    }

    @Test func edgeProducesArrowLineAfterServiceBlock() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        architecture-beta
            service a(server)[A]
            service b(server)[B]
            a:R --> L:b
        """)
        // The renderer emits `lhs → rhs` after a blank separator.
        #expect(output.text.contains("→"))
        #expect(output.text.contains("a"))
        #expect(output.text.contains("b"))
    }

    @Test func junctionRendersAsJunctionBullet() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        architecture-beta
            service a(server)[A]
            junction j1
            a:R --> L:j1
        """)
        #expect(output.text.contains("junction"))
        #expect(output.text.contains("j1"))
    }

    @Test func diagramTitleAppearsWithUnderline() async throws {
        let output = try await DiagramEngine.renderASCII(source: """
        ---
        title: My Architecture
        ---
        architecture-beta
            service a(server)[A]
        """)
        // Title line is followed by an `=`-underline of matching length.
        #expect(output.text.contains("My Architecture"))
        #expect(output.text.contains("="))
    }

    @Test func emptyArchitectureRendersWithoutCrash() async throws {
        let output = try await DiagramEngine.renderASCII(source: "architecture-beta")
        // Empty diagram returns an empty (or whitespace-only) string; the
        // renderer must not crash on it.
        #expect(output.text.allSatisfy { $0.isWhitespace || $0.isNewline })
    }
}

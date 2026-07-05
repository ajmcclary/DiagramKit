import Testing
import Foundation

/// Guards against fake status-bar telemetry being reintroduced. The status bar
/// must show only real signals — no hardcoded snapshot count or placeholder
/// last-render em dash. Because the offending values were `private` computed
/// properties, this asserts at the source level (in the style of the repo's
/// discipline-check scripts).
@Suite("Statusbar shows no fake telemetry")
struct StatusbarSignalsTests {
    @Test("StatusbarView contains no hardcoded 1044 / em-dash telemetry")
    func noHardcodedTelemetry() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // DiagramKitTests
            .deletingLastPathComponent()      // Tests
            .deletingLastPathComponent()      // repo root
            .appendingPathComponent("Sources/DiagramKitSample/Views/Workspace/StatusbarView.swift")
        let src = try String(contentsOf: url, encoding: .utf8)
        #expect(!src.contains("\"1044\""), "Remove the hardcoded snapshotCount placeholder")
        #expect(!src.contains("mirror the design's em dash"), "Remove the placeholder lastRenderText")
    }
}

import XCTest
import Foundation

/// Opt-in gate for the exporter tooling suites (`VisualComparisonExporterTests`,
/// `VerificationStepExporterTests`, `VisualReportGenerator`,
/// `AsciiVisualReportGenerator`, `ExampleImageExporter`), which generate
/// report/export files for humans to inspect rather than assert.
///
/// Tools-namespace convention: these five files are maintenance tooling, not
/// behavior tests. They skip (via `XCTSkip`) unless
/// `RUN_MERMAID_EXPORT_TESTS=1` is set. They intentionally stay in the flat
/// `DiagramKitTests` target because their `#filePath`-based fixture/output
/// path math assumes the current directory layout; do not move them into a
/// subdirectory without re-deriving those paths.
func requireMermaidExporterTestsEnabled() throws {
    guard ProcessInfo.processInfo.environment["RUN_MERMAID_EXPORT_TESTS"] == "1" else {
        throw XCTSkip("Exporter tests are opt-in. Set RUN_MERMAID_EXPORT_TESTS=1 to generate files.")
    }
}

func requireFixtureExists(atPath path: String) throws {
    guard FileManager.default.fileExists(atPath: path) else {
        throw XCTSkip("Missing verification fixture: \(path)")
    }
}

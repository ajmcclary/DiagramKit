import XCTest
import Foundation

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

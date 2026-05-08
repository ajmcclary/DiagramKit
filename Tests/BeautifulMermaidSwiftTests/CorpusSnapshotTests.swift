import Foundation
import Testing
import SnapshotTesting
@testable import BeautifulMermaid

/// Snapshot tests for the entire diagram corpus.
///
/// These tests render every diagram in `test-diagrams.json` through
/// the SVG, image, and ASCII paths and compare against committed baselines.
///
/// ## Recording new baselines
/// ```bash
/// SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests
/// ```
///
/// ## Verifying in CI
/// ```bash
/// swift test --filter CorpusSnapshotTests
/// ```
@Suite("Diagram corpus snapshots")
struct CorpusSnapshotTests {

    // MARK: - Model

    struct DiagramEntry: Decodable, Sendable {
        let id: String
        let category: String
        let name: String
        let source: String
    }

    private struct DiagramFile: Decodable {
        let diagrams: [DiagramEntry]
    }

    // MARK: - Helpers

    private static func projectRoot() -> URL {
        var url = URL(fileURLWithPath: #file).deletingLastPathComponent()
        while url.path != "/" {
            let package = url.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private static func loadDiagrams() throws -> [DiagramEntry] {
        let jsonURL = projectRoot()
            .appendingPathComponent("Examples/MermaidPlayground/Resources/test-diagrams.json")
        let data = try Data(contentsOf: jsonURL)
        let file = try JSONDecoder().decode(DiagramFile.self, from: data)
        return file.diagrams
    }

    // MARK: - SVG snapshots

    @Test("SVG snapshot", arguments: try loadDiagrams())
    func svgSnapshot(_ diagram: DiagramEntry) async throws {
        let svg = try await MermaidRenderer.renderSVG(source: diagram.source)
        assertSnapshot(of: svg, as: .lines, named: diagram.id)
    }

    // MARK: - Image snapshots

    @Test("Image snapshot", arguments: try loadDiagrams())
    @MainActor
    func imageSnapshot(_ diagram: DiagramEntry) async throws {
        let image = try #require(await MermaidRenderer.renderImage(source: diagram.source))
        assertSnapshot(of: image, as: .image(precision: 0.99), named: diagram.id)
    }

    // MARK: - ASCII snapshots

    @Test("ASCII snapshot", arguments: try loadDiagrams())
    func asciiSnapshot(_ diagram: DiagramEntry) async throws {
        let ascii = try await MermaidRenderer.renderASCII(source: diagram.source)
        assertSnapshot(of: ascii, as: .lines, named: diagram.id + "-ascii")
    }
}

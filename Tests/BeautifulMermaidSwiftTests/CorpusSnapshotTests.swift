import Foundation
import Testing
import SnapshotTesting
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// Snapshot tests for the entire diagram corpus.
///
/// These tests render every diagram in `test-diagrams.json` through
/// the SVG, image, and ASCII paths and compare against committed baselines.
///
/// ## Recording new baselines
/// ```bash
/// SNAPSHOT_TESTING_RECORD=all swift test --filter CorpusSnapshotTests
/// SNAPSHOT_DIAGRAM_IDS=architecture-basic swift test --filter CorpusSnapshotTests/imageSnapshot
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
        guard let rawIds = ProcessInfo.processInfo.environment["SNAPSHOT_DIAGRAM_IDS"], !rawIds.isEmpty else {
            return file.diagrams
        }
        let ids = Set(rawIds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        return file.diagrams.filter { ids.contains($0.id) }
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
        // Allow a small margin for floating-point differences in CoreText path
        // rasterization across CPU architectures (Apple Silicon vs Intel) and
        // OS minor versions. `perceptualPrecision` smooths over imperceptible
        // sub-pixel-antialiasing drift; `precision` gates the strict-pixel-match
        // count. Tighten if you need stricter regression catching.
        assertSnapshot(
            of: image,
            as: .image(precision: 0.99, perceptualPrecision: 0.98),
            named: diagram.id
        )
    }

    // MARK: - ASCII snapshots

    @Test("ASCII snapshot", arguments: try loadDiagrams())
    func asciiSnapshot(_ diagram: DiagramEntry) async throws {
        let ascii = try await MermaidRenderer.renderASCII(source: diagram.source)
        assertSnapshot(of: ascii, as: .lines, named: diagram.id + "-ascii")
    }
}

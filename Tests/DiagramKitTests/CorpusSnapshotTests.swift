import Foundation
import Testing
import SnapshotTesting
import DiagramKitTestSupport
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

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

    // MARK: - Helpers

    static func projectRoot() -> URL {
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

    static func loadDiagrams() throws -> [CorpusEntry] {
        // Pin the Gantt today-marker to a fixed date so SVG snapshots are
        // deterministic regardless of when the suite runs. Honored by
        // `_ganttReferenceToday()` in `src_gantt_layout.swift`.
        setenv("DIAGRAMKIT_GANTT_TODAY", "2024-06-15", 1)

        let jsonURL = projectRoot()
            .appendingPathComponent("Examples/DiagramPlayground/Resources/test-diagrams.json")
        let data = try Data(contentsOf: jsonURL)
        let file = try JSONDecoder().decode(CorpusFile.self, from: data)
        for entry in file.diagrams {
            try entry.validate()
        }
        guard let rawIds = ProcessInfo.processInfo.environment["SNAPSHOT_DIAGRAM_IDS"], !rawIds.isEmpty else {
            return file.diagrams
        }
        let ids = Set(rawIds.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        return file.diagrams.filter { ids.contains($0.id) }
    }

    // MARK: - SVG snapshots

    @Test("SVG snapshot", arguments: try loadDiagrams())
    func svgSnapshot(_ diagram: CorpusEntry) async throws {
        let svg = try await DiagramEngine.renderSVG(source: diagram.source, idPolicy: .stable)
        assertSnapshot(of: svg, as: .lines, named: diagram.id)
    }

    // MARK: - Image snapshots

    @Test("Image snapshot", arguments: try loadDiagrams())
    @MainActor
    func imageSnapshot(_ diagram: CorpusEntry) async throws {
        let image = try #require(await DiagramEngine.renderImage(source: diagram.source))
        assertSnapshot(
            of: image,
            as: .image(precision: 0.99, perceptualPrecision: 0.98),
            named: diagram.id
        )
    }

    // MARK: - ASCII snapshots

    @Test("ASCII snapshot", arguments: try loadDiagrams())
    func asciiSnapshot(_ diagram: CorpusEntry) async throws {
        let ascii = try await DiagramEngine.renderASCII(source: diagram.source)
        assertSnapshot(of: ascii, as: .lines, named: diagram.id + "-ascii")
    }
}

// MARK: - Multi-format snapshot tests

/// Multi-format snapshot tests that iterate over `entry.availableFormats`.
/// In a separate suite to avoid `@Test` macro symbol conflicts with
/// the Mermaid-only snapshot tests above.
///
/// Snapshot names use a format suffix (e.g. `flow-1-simple-mermaid`,
/// `d2-1-simple-edge-d2`) so baselines for different formats never collide.
///
/// ## Recording (chunked to avoid signal-10 in parameterized harness)
/// ```bash
/// SNAPSHOT_DIAGRAM_IDS=<id1,id2,...> SNAPSHOT_TESTING_RECORD=true \
///   swift test --filter CorpusMultiFormatSnapshotTests/multiFormatSvgSnapshot
/// SNAPSHOT_DIAGRAM_IDS=<id1,id2,...> SNAPSHOT_TESTING_RECORD=true \
///   swift test --filter CorpusMultiFormatSnapshotTests/multiFormatImageSnapshot
/// ```
@Suite("Multi-format corpus snapshots")
struct CorpusMultiFormatSnapshotTests {

    private static func loadDiagrams() throws -> [CorpusEntry] {
        try CorpusSnapshotTests.loadDiagrams()
    }

    // MARK: - Multi-format SVG snapshots

    @Test("Multi-format SVG snapshot", arguments: try loadDiagrams())
    func multiFormatSvgSnapshot(_ diagram: CorpusEntry) async throws {
        for format in diagram.availableFormats where format != "mermaid" {
            guard !diagram.shouldSkipSnapshot(for: format) else { continue }
            guard let source = diagram.source(for: format) else { continue }
            let svg = try await DiagramEngine.renderSVG(source: source, idPolicy: .stable)
            let snapshotName = "\(diagram.id)-\(format)"
            assertSnapshot(of: svg, as: .lines, named: snapshotName)
        }
    }

    // MARK: - Multi-format image snapshots

    @Test("Multi-format image snapshot", arguments: try loadDiagrams())
    @MainActor
    func multiFormatImageSnapshot(_ diagram: CorpusEntry) async throws {
        for format in diagram.availableFormats where format != "mermaid" {
            guard !diagram.shouldSkipSnapshot(for: format) else { continue }
            guard let source = diagram.source(for: format) else { continue }
            let image = try #require(await DiagramEngine.renderImage(source: source))
            assertSnapshot(
                of: image,
                as: .image(precision: 0.99, perceptualPrecision: 0.98),
                named: "\(diagram.id)-\(format)"
            )
        }
    }
}

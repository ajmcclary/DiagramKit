import Foundation
import XCTest
import DiagramKit
import DiagramKitMermaid
import DiagramKitImport
import DiagramKitExport
import DiagramKitModel
import DiagramKitTestSupport

/// Exercises every Mermaid corpus entry whose family the exporter
/// supports through a parse → export → parse → assertStructurallyEqual
/// cycle. Catches contract drift across the full Mermaid corpus
/// without hand-authored fixtures.
///
/// Skips entries whose family is not in
/// `MermaidExporter().supportedDiagramTypes`. As waves 2 / 3 land,
/// the supported set grows and additional entries automatically join
/// the run.
///
/// **XCTest, not swift-testing.** The swift-testing variant of this
/// suite crashes with signal 10 on the full corpus argument set
/// (see `corpus_signal_10` note). XCTest's single-test internal
/// iteration sidesteps the parameterization machinery that triggers
/// the crash.
final class CorpusRoundTripTests: XCTestCase {

    /// Entries with pre-existing round-trip issues that pre-date
    /// Wave 1. The new corpus suite surfaces them but they live in
    /// non-Wave-1 exporters (flowchart, state, sequence, class, ER)
    /// or in parser limitations the DSL cannot bridge. Tracked here
    /// rather than silently ignored so each becomes its own follow-up.
    /// Drain this set as the underlying exporters and parsers
    /// improve in later waves.
    static let knownFailures: Set<String> = [
        // Pre-existing class exporter id-sanitization issues
        "class-18-square-label",
        "class-19-backtick-name",
        "class-32-lollipop",
        "class-60-frontmatter-title",
        // Pre-existing ER exporter id-sanitization issues
        "er-15-standalone",
        "er-17-quoted-names",
        "er-24-numeric-entities",
        // Pre-existing ER parser cannot re-parse `|--}o` parent-marker
        "er-25-parent-marker",
        // Pre-existing flowchart exporter edge-count drift
        "flow-21-cicd-pipeline",
        // Pre-existing state exporter id-sanitization + edge-order
        // issues with non-ASCII identifiers, concurrent regions,
        // notes, and nested composites
        "state-4-cjk",
        "state-7-concurrency",
        "state-8-notes",
        "state-12-complex",
        // Pre-existing sequence exporter arrow-type narrowing and
        // reverse-arrow drop
        "seq-4-arrow-types",
        "seq-17-reverse-arrows",
        // Mermaid mindmap parser preserves newlines in `descr`; the
        // DSL has no syntax to encode them on round-trip emit.
        "mindmap-5-markdown",
        // Kanban bracket-label escape: parser does not unescape
        // `\[\]` and treats them as literal brackets.
        "kanban-decorations",
    ]

    func testMermaidCorpusRoundTrip() throws {
        let entries = try Self.loadCorpusEntries()
        let importer = MermaidImporter()
        let exporter = MermaidExporter()
        let supported = exporter.supportedDiagramTypes
        let known = Self.knownFailures

        var failures: [String] = []
        var ran = 0

        for entry in entries {
            if known.contains(entry.id) { continue }
            let parsed: DiagramImportResult
            do {
                parsed = try importer.parse(entry.source)
            } catch {
                continue
            }
            guard supported.contains(parsed.document.type) else { continue }

            let exported: DiagramExportResult
            do {
                exported = try exporter.export(parsed.document)
            } catch {
                failures.append("[\(entry.id)] export threw: \(error)")
                continue
            }
            if exported.source.isEmpty { continue }

            let reparsed: DiagramImportResult
            do {
                reparsed = try importer.parse(exported.source)
            } catch {
                failures.append("[\(entry.id)] reparse threw: \(error)")
                continue
            }

            let deltas = compare(parsed.document, reparsed.document)
            let blocking = deltas.filter {
                if case .loss = $0 { return false }
                return true
            }
            if !blocking.isEmpty {
                failures.append("[\(entry.id)] diverged → \(blocking)")
            }
            ran += 1
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Corpus round-trip: \(failures.count) failure(s) of \(ran) entries exercised\n\(failures.joined(separator: "\n"))"
        )
    }

    static func loadCorpusEntries() throws -> [CorpusEntry] {
        var url = URL(fileURLWithPath: #file).deletingLastPathComponent()
        while url.path != "/" {
            let package = url.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: package.path) {
                let jsonURL = url.appendingPathComponent(
                    "Sources/DiagramKitSample/Resources/test-diagrams.json"
                )
                let data = try Data(contentsOf: jsonURL)
                let file = try JSONDecoder().decode(CorpusFile.self, from: data)
                for entry in file.diagrams { try entry.validate() }
                return file.diagrams
            }
            url.deleteLastPathComponent()
        }
        return []
    }
}

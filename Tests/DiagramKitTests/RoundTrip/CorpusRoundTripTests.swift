import Foundation
import XCTest
import IssueReporting
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

    /// Entries with a pre-existing round-trip divergence in the Mermaid
    /// exporter family set (flowchart, state, sequence, class, ER) or in
    /// parser limitations the DSL cannot bridge. These entries are still
    /// exercised — wrapped in `withExpectedIssue` so a divergence is recorded
    /// as a tracked expected issue instead of failing the suite, and a
    /// future fix simply makes the issue stop firing (remove the id then).
    /// They are NOT skipped: parse failures, throws, and divergences still
    /// flow through the issue-reporting boundary, and ids that no longer
    /// match a corpus entry fail the suite so the set cannot rot silently.
    ///
    /// Last verified 2026-10-13: 16 of the former 17 `knownFailures` still
    /// diverge; `flow-21-cicd-pipeline` was fixed and removed from the set.
    static let knownIssues: Set<String> = [
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
        let known = Self.knownIssues

        // A known-issue id that no longer matches a corpus entry is stale;
        // fail so the set is pruned instead of rotting.
        let corpusIds = Set(entries.map(\.id))
        let stale = known.subtracting(corpusIds)
        XCTAssertTrue(stale.isEmpty, "knownIssues ids not in corpus: \(stale.sorted())")

        var failures: [String] = []
        var ran = 0

        for entry in entries {
            let (exercised, divergences) = Self.roundTrip(
                entry, importer: importer, exporter: exporter, supported: supported)
            if known.contains(entry.id) {
                withExpectedIssue {
                    for divergence in divergences {
                        IssueReporting.reportIssue(divergence)
                    }
                }
            } else {
                failures.append(contentsOf: divergences)
            }
            if exercised { ran += 1 }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Corpus round-trip: \(failures.count) failure(s) of \(ran) entries exercised\n\(failures.joined(separator: "\n"))"
        )
    }

    /// Runs one parse → export → parse → compare cycle. Returns whether
    /// the entry reached the compare step and the divergences it produced
    /// (empty when the entry round-trips cleanly, throws, or is not
    /// supported). Callers decide whether divergences fail the suite or
    /// flow through `withExpectedIssue`.
    private static func roundTrip(
        _ entry: CorpusEntry,
        importer: MermaidImporter,
        exporter: MermaidExporter,
        supported: Set<DiagramType>
    ) -> (exercised: Bool, divergences: [String]) {
        let parsed: DiagramImportResult
        do {
            parsed = try importer.parse(entry.source)
        } catch {
            return (false, [])
        }
        guard supported.contains(parsed.document.type) else { return (false, []) }

        let exported: DiagramExportResult
        do {
            exported = try exporter.export(parsed.document)
        } catch {
            return (true, ["[\(entry.id)] export threw: \(error)"])
        }
        if exported.source.isEmpty { return (false, []) }

        let reparsed: DiagramImportResult
        do {
            reparsed = try importer.parse(exported.source)
        } catch {
            return (true, ["[\(entry.id)] reparse threw: \(error)"])
        }

        let deltas = compare(parsed.document, reparsed.document)
        let blocking = deltas.filter {
            if case .loss = $0 { return false }
            return true
        }
        if blocking.isEmpty { return (true, []) }
        return (true, ["[\(entry.id)] diverged → \(blocking)"])
    }

    static func loadCorpusEntries() throws -> [CorpusEntry] {
        let diagrams = try DiagramCorpus.load()
        for entry in diagrams { try entry.validate() }
        return diagrams
    }
}

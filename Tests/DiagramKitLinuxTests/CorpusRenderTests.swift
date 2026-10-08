import Testing
import DiagramKit
import DiagramKitTestSupport

/// Every corpus entry — all 28 diagram families, Mermaid and the other
/// source formats — renders to SVG and ASCII through the public engine.
///
/// The point is Linux: the corpus snapshot suites are Apple-only, so this is
/// what proves the portable SVG/ASCII surface end to end. Output is not
/// compared (Linux measures text by estimation, so geometry legitimately
/// differs from the Apple snapshots); it must render, be well-formed, and
/// contain no NaN/Infinity.
@Suite("Corpus renders on every platform")
struct CorpusRenderTests {

    static let corpus: [CorpusEntry] = (try? DiagramCorpus.load()) ?? []

    @Test func corpusIsLoaded() {
        #expect(Self.corpus.count >= 400)
    }

    @Test("SVG", arguments: corpus)
    func rendersSVG(_ entry: CorpusEntry) async throws {
        for format in entry.availableFormats {
            guard let source = entry.source(for: format) else { continue }
            let svg = try await DiagramEngine.renderSVG(source: source)
            #expect(svg.contains("<svg"), "\(entry.id) [\(format)]")
            #expect(svg.contains("</svg>"), "\(entry.id) [\(format)]")
            #expect(svgHasNoSerializedNaN(svg), "\(entry.id) [\(format)] has NaN/Infinity")
        }
    }

    /// Must render without throwing. Output may legitimately be empty for
    /// degenerate entries (e.g. `packet-5-empty`, `pie-11-all-zero`), whose
    /// Apple ASCII snapshots are empty too.
    @Test("ASCII", arguments: corpus)
    func rendersASCII(_ entry: CorpusEntry) async throws {
        guard !entry.shouldSkipSnapshot(for: "ascii") else { return }
        _ = try await DiagramEngine.renderASCII(source: entry.source)
    }
}

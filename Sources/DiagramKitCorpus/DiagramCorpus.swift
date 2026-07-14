import Foundation

/// Single-source accessor for the canonical diagram corpus fixture
/// (`test-diagrams.json`).
///
/// `DiagramKitCorpus` owns the corpus schema (`CorpusEntry` / `CorpusFile`)
/// and the one canonical copy of `test-diagrams.json`, bundled as a SwiftPM
/// resource. It exists for the workspace's own test and tooling consumers —
/// DiagramKit's corpus-driven test suites and the `apps/DiagramStudio`
/// playground — so they share one decoder and one data file instead of
/// carrying parallel copies. It is **not** advertised as public API for
/// external reuse; it ships as a library product only so the path-dependency
/// app can import it.
public enum DiagramCorpus {

    /// Error raised when the bundled corpus resource cannot be located.
    public enum LoadError: Error, CustomStringConvertible, Sendable {
        case resourceMissing

        public var description: String {
            switch self {
            case .resourceMissing:
                return "DiagramKitCorpus: bundled resource test-diagrams.json was not found."
            }
        }
    }

    /// URL of the bundled canonical `test-diagrams.json`.
    ///
    /// Prefer ``load()`` or ``file()`` for typed access; this URL is for
    /// callers that decode the corpus into their own local schema type or
    /// need the raw file path.
    public static var resourceURL: URL {
        get throws {
            guard let url = Bundle.module.url(forResource: "test-diagrams", withExtension: "json") else {
                throw LoadError.resourceMissing
            }
            return url
        }
    }

    /// Raw bytes of the bundled canonical `test-diagrams.json`.
    public static func data() throws -> Data {
        try Data(contentsOf: resourceURL)
    }

    /// The decoded top-level corpus container.
    public static func file() throws -> CorpusFile {
        try JSONDecoder().decode(CorpusFile.self, from: data())
    }

    /// All corpus entries, decoded from the bundled canonical fixture.
    public static func load() throws -> [CorpusEntry] {
        try file().diagrams
    }
}

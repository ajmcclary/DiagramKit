import Foundation
import Testing
import DiagramKitCorpus
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// Loads the canonical corpus and feeds deterministically perturbed sources
/// through `DiagramEngine.renderSVG` and `DiagramEngine.renderASCII`. Every
/// render must terminate without a fatal trap or hang; throwing a typed error
/// is acceptable. No snapshot assertions.
@Suite("Corpus perturbation smoke", .serialized)
struct CorpusPerturbationTests {

    /// Maximum total renders to keep the suite bounded. Each selected entry
    /// gets a small fixed set of perturbations.
    private static let maxRenders = 500

    @Test("perturbed corpus entries terminate without crashing")
    func perturbedCorpusTerminates() async throws {
        let corpus = try DiagramCorpus.load()

        // Deterministic perturbations applied to each selected entry.
        let perturbations: [(String) -> String] = [
            { s in "0" + s },
            { s in s + "\n" },
            { s in s.replacingOccurrences(of: "\n", with: "\n ") },
            { s in s.replacingOccurrences(of: "\"", with: "'") },
        ]

        var renderCount = 0
        for entry in corpus {
            guard renderCount < Self.maxRenders else { break }

            let baseSource = entry.source
            let sources = [baseSource] + perturbations.map { $0(baseSource) }

            for source in sources {
                guard renderCount < Self.maxRenders else { break }

                _ = try? await DiagramEngine.renderSVG(source: source)
                renderCount += 1

                guard renderCount < Self.maxRenders else { break }
                _ = try? await DiagramEngine.renderASCII(source: source)
                renderCount += 1
            }
        }

        // The suite is meaningful only if it actually exercised the engine.
        #expect(renderCount > 0)
    }
}

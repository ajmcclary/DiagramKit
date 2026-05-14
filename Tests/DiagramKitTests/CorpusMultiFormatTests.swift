import Foundation
import Testing
import DiagramKitCommon
import DiagramKitTestSupport
@testable import DiagramKit
#if canImport(CoreGraphics)
@testable import DiagramPlayground
#endif

// MARK: - Decode Tests

/// Verify that both legacy and multi-format JSON schemas decode correctly
/// through `CorpusEntry`.
@Suite("Multi-format decoding")
struct MultiFormatDecodingTests {

    @Test("Old schema decodes")
    func testOldSchemaDecodes() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "flow-1-simple",
                    "category": "flowchart",
                    "name": "Simple Flow",
                    "source": "graph TD\\n  A --> B"
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.id == "flow-1-simple")
        #expect(entry.source == "graph TD\n  A --> B")
        #expect(entry.sources == nil)
        #expect(entry.availableFormats == ["mermaid"])
    }

    @Test("New schema decodes")
    func testNewSchemaDecodes() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "multi-format-flow-simple",
                    "category": "flowchart",
                    "name": "Multi-Format: Simple Flow",
                    "source": "graph TD\\n  A[Start] --> B[End]",
                    "sources": {
                        "mermaid": "graph TD\\n  A[Start] --> B[End]",
                        "d2": "A -> B"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.id == "multi-format-flow-simple")
        #expect(entry.source == "graph TD\n  A[Start] --> B[End]")
        #expect(entry.sources?["mermaid"] == "graph TD\n  A[Start] --> B[End]")
        #expect(entry.sources?["d2"] == "A -> B")
    }

    @Test("source derivation from sources")
    func testSourceDerivationFromSources() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "test",
                    "category": "flowchart",
                    "name": "Test",
                    "source": "graph TD\\n  A --> B",
                    "sources": {
                        "mermaid": "graph TD\\n  A --> B",
                        "d2": "A -> B"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        // `source` derives from `sources["mermaid"]` when both match
        #expect(entry.source == "graph TD\n  A --> B")
        #expect(entry.source(for: "d2") == "A -> B")
    }

    @Test("source fallback")
    func testSourceFallback() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "flow-1-simple",
                    "category": "flowchart",
                    "name": "Simple Flow",
                    "source": "graph TD\\n  A --> B"
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        // No `sources`: `source` is the top-level value.
        #expect(entry.source == "graph TD\n  A --> B")
        #expect(entry.source(for: "mermaid") == "graph TD\n  A --> B")
    }

    @Test("sources without mermaid key throws")
    func testSourcesWithoutMermaidKeyThrows() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "test",
                    "category": "flowchart",
                    "name": "Test",
                    "source": "graph TD\\n  A --> B",
                    "sources": {
                        "d2": "A -> B"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        #expect(throws: CorpusEntryError.self) {
            let _ = try JSONDecoder().decode(CorpusFile.self, from: json)
        }
    }
}

// MARK: - Metadata Tests

/// Verify that optional fixture metadata fields are available when present.
@Suite("Multi-format fixture metadata")
struct MultiFormatFixtureMetadataTests {

    @Test("expectedImporters available")
    func testExpectedImportersAvailable() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "test",
                    "category": "flowchart",
                    "name": "Test",
                    "source": "graph TD\\n  A --> B",
                    "expectedImporters": {
                        "mermaid": "mermaid",
                        "d2": "d2"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.expectedImporters?[.mermaid] == .mermaid)
        #expect(entry.expectedImporters?[.d2] == .d2)
    }

    @Test("expectedDiagnostics available")
    func testExpectedDiagnosticsAvailable() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "test",
                    "category": "flowchart",
                    "name": "Test",
                    "source": "graph TD\\n  A --> B",
                    "expectedDiagnostics": [
                        { "severity": "unsupported", "messageContains": "layers" }
                    ]
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        let diag = try #require(entry.expectedDiagnostics?.first)
        #expect(diag.severity == "unsupported")
        #expect(diag.messageContains == "layers")
    }

    @Test("availableFormats")
    func testAvailableFormats() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "test",
                    "category": "flowchart",
                    "name": "Test",
                    "source": "graph TD\\n  A --> B",
                    "sources": {
                        "mermaid": "graph TD\\n  A --> B",
                        "d2": "A -> B",
                        "graphviz": "digraph {}"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.availableFormats == ["d2", "graphviz", "mermaid"])
    }

    @Test("hasSource for format")
    func testHasSourceForFormat() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "test",
                    "category": "flowchart",
                    "name": "Test",
                    "source": "graph TD\\n  A --> B",
                    "sources": {
                        "mermaid": "graph TD\\n  A --> B",
                        "d2": "A -> B"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.hasSource(for: "mermaid"))
        #expect(entry.hasSource(for: "d2"))
        #expect(!entry.hasSource(for: "graphviz"))
        // Case-insensitive lookup
        #expect(entry.hasSource(for: "MERMAID"))
        #expect(entry.hasSource(for: "D2"))
    }

    @Test("mermaid source always available")
    func testMermaidSourceAlwaysAvailable() throws {
        // Legacy entry with no `sources`
        let legacyJSON = """
        {
            "diagrams": [
                {
                    "id": "test",
                    "category": "flowchart",
                    "name": "Test",
                    "source": "graph TD\\n  A --> B"
                }
            ]
        }
        """.data(using: .utf8)!
        let legacyFile = try JSONDecoder().decode(CorpusFile.self, from: legacyJSON)
        let legacyEntry = try #require(legacyFile.diagrams.first)
        #expect(legacyEntry.source(for: "mermaid") == "graph TD\n  A --> B")

        // Multi-format entry with `sources`
        let multiJSON = """
        {
            "diagrams": [
                {
                    "id": "test",
                    "category": "flowchart",
                    "name": "Test",
                    "source": "graph TD\\n  A --> B",
                    "sources": {
                        "mermaid": "graph TD\\n  A --> B",
                        "d2": "A -> B"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        let multiFile = try JSONDecoder().decode(CorpusFile.self, from: multiJSON)
        let multiEntry = try #require(multiFile.diagrams.first)
        #expect(multiEntry.source(for: "mermaid") == "graph TD\n  A --> B")
    }

    @Test("format keys are normalized to lowercase")
    func testFormatKeysAreNormalizedToLowercase() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "test",
                    "category": "flowchart",
                    "name": "Test",
                    "source": "graph TD\\n  A --> B",
                    "sources": {
                        "Mermaid": "graph TD\\n  A --> B",
                        "D2": "A -> B"
                    },
                    "expectedImporters": {
                        "Mermaid": "Mermaid",
                        "D2": "D2"
                    },
                    "skipSnapshots": ["D2"]
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)

        #expect(entry.availableFormats == ["d2", "mermaid"])
        #expect(entry.sources?["mermaid"] == "graph TD\n  A --> B")
        #expect(entry.sources?["d2"] == "A -> B")
        #expect(entry.source(for: "D2") == "A -> B")
        #expect(entry.expectedImporters?[.mermaid] == .mermaid)
        #expect(entry.expectedImporters?[.d2] == .d2)
        #expect(entry.shouldSkipSnapshot(for: "d2"))
    }
}

#if canImport(CoreGraphics)
// MARK: - Playground Schema Parity Tests

/// Verify the playground's duplicated corpus decoder preserves the same schema
/// invariants as `DiagramKitTestSupport.CorpusEntry`.
@Suite("Playground corpus decoding")
struct PlaygroundCorpusDecodingTests {

    @Test("playground rejects source/mermaid mismatch")
    func testPlaygroundRejectsSourceMermaidMismatch() throws {
        let json = """
        {
            "version": "2.0.0",
            "description": "Test",
            "diagrams": [
                {
                    "id": "bad-entry",
                    "category": "flowchart",
                    "name": "Bad Entry",
                    "source": "graph TD\\n  A --> B",
                    "sources": {
                        "mermaid": "graph TD\\n  X --> Y"
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        #expect(throws: (any Error).self) {
            let _ = try JSONDecoder().decode(TestDiagramsFile.self, from: json)
        }
    }
}
#endif

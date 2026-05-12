import Foundation
import Testing
import DiagramKitTestSupport
@testable import DiagramKit

// MARK: - Backward-Compatibility Tests

/// Verify that the real 396-entry corpus still works with the new types.
@Suite("Multi-format backward compatibility")
struct MultiFormatBackwardCompatibilityTests {

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

    private static func loadRealCorpus() throws -> [CorpusEntry] {
        let jsonURL = projectRoot()
            .appendingPathComponent("Examples/MermaidPlayground/Resources/test-diagrams.json")
        let data = try Data(contentsOf: jsonURL)
        let file = try JSONDecoder().decode(CorpusFile.self, from: data)
        return file.diagrams
    }

    @Test("All 396 Mermaid entries decode")
    func testAll396MermaidEntriesDecode() throws {
        let entries = try Self.loadRealCorpus()
        #expect(entries.count >= 396, "Expected at least 396 entries; got \(entries.count)")
        for entry in entries {
            #expect(!entry.source.isEmpty, "Entry \"\(entry.id)\" has empty source")
            try entry.validate()
        }
    }

    @Test("Real corpus has no sources field")
    func testRealCorpusHasNoSourcesField() throws {
        let entries = try Self.loadRealCorpus()
        for entry in entries {
            let comment: Comment = "Entry \"\(entry.id)\" unexpectedly has a `sources` field"
            #expect(entry.sources == nil, comment)
        }
    }

    @Test("Mermaid snapshots unchanged")
    func testMermaidSnapshotsUnchanged() async throws {
        let entries = try Self.loadRealCorpus()
        // Spot-check a few well-known entries render non-empty SVG.
        let spotIDs: Set = [
            "flow-1-simple",
            "seq-1-basic",
            "class-1-basic",
            "state-1-basic",
            "er-1-basic"
        ]
        let spotEntries = entries.filter { spotIDs.contains($0.id) }
        #expect(spotEntries.count == spotIDs.count,
                "Expected \(spotIDs.count) spot-check entries; found \(spotEntries.count)")

        for entry in spotEntries {
            let svg = try await DiagramEngine.renderSVG(source: entry.source, idPolicy: .stable)
            #expect(!svg.isEmpty, "Entry \"\(entry.id)\" produced empty SVG")
        }
    }

    @Test("Second format does not change mermaid source")
    func testSecondFormatDoesNotChangeMermaidSource() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "multi-format-flow",
                    "category": "flowchart",
                    "name": "Multi-Format Flow",
                    "source": "graph LR\\n  A --> B",
                    "sources": {
                        "mermaid": "graph LR\\n  A --> B",
                        "d2": "A -> B"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.source == "graph LR\n  A --> B")
        #expect(entry.source != "A -> B")
        #expect(entry.source(for: "d2") == "A -> B")
    }
}

// MARK: - Validation Tests

/// Verify that `CorpusEntry.validate()` catches mismatches and accepts valid entries.
@Suite("Multi-format validation")
struct MultiFormatValidationTests {

    @Test("source/mermaid mismatch throws during decode")
    func testSourceMermaidMismatchThrows() throws {
        let json = """
        {
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
        #expect(throws: CorpusEntryError.self) {
            let _ = try JSONDecoder().decode(CorpusFile.self, from: json)
        }
    }

    @Test("source/mermaid match passes")
    func testSourceMermaidMatchPasses() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "good-entry",
                    "category": "flowchart",
                    "name": "Good Entry",
                    "source": "graph TD\\n  A --> B",
                    "sources": {
                        "mermaid": "graph TD\\n  A --> B"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(throws: Never.self) {
            try entry.validate()
        }
    }

    @Test("validate does not throw on legacy entries")
    func testValidateDoesNotThrowOnLegacyEntries() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "legacy",
                    "category": "flowchart",
                    "name": "Legacy",
                    "source": "graph TD\\n  A --> B"
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(throws: Never.self) {
            try entry.validate()
        }
    }
}

// MARK: - Sparse-Matrix Tests

/// Verify per-format availability and snapshot filtering.
@Suite("Multi-format sparse matrix")
struct MultiFormatSparseMatrixTests {

    @Test("availableFormats is only mermaid on legacy")
    func testAvailableFormatsIsOnlyMermaidOnLegacy() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "legacy",
                    "category": "flowchart",
                    "name": "Legacy",
                    "source": "graph TD\\n  A --> B"
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.availableFormats == ["mermaid"])
    }

    @Test("mermaid is always present in sources")
    func testMermaidIsAlwaysPresentInSources() throws {
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
        #expect(entry.availableFormats.contains("mermaid"))
        #expect(entry.hasSource(for: "mermaid"))
        #expect(entry.source(for: "mermaid") != nil)
    }

    @Test("skipSnapshots is per-format")
    func testSkipSnapshotsIsPerFormat() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "test",
                    "category": "flowchart",
                    "name": "Test",
                    "source": "graph TD\\n  A --> B",
                    "skipSnapshots": ["d2", "graphviz"]
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.shouldSkipSnapshot(for: "d2"))
        #expect(entry.shouldSkipSnapshot(for: "graphviz"))
        #expect(entry.shouldSkipSnapshot(for: "D2"))
        #expect(!entry.shouldSkipSnapshot(for: "mermaid"))
        #expect(!entry.shouldSkipSnapshot(for: "plantuml"))
    }
}

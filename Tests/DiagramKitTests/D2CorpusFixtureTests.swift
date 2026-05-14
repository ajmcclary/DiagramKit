import Foundation
import Testing
import DiagramKitCommon
import DiagramKitTestSupport
@testable import DiagramKit
import DiagramKitD2

/// Inline d2 fixtures with `skipSnapshots: ["d2"]` to avoid snapshot
/// machinery trying to create D2 baselines.
@Suite("D2 inline multi-format fixtures")
struct D2FixtureTests {

    @Test("D2 simple flow fixture decodes")
    func d2SimpleFlowDecodes() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "multi-format-d2-simple-flow",
                    "category": "flowchart",
                    "name": "D2: Simple Flow",
                    "source": "graph LR\\n  A[Start] --> B[End]",
                    "sources": {
                        "mermaid": "graph LR\\n  A[Start] --> B[End]",
                        "d2": "direction: right\\nA: Start\\nB: End\\nA -> B"
                    },
                    "expectedImporters": {
                        "mermaid": "mermaid",
                        "d2": "d2"
                    },
                    "skipSnapshots": ["d2"]
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.id == "multi-format-d2-simple-flow")
        #expect(entry.expectedImporters?[.d2] == .d2)
        #expect(entry.shouldSkipSnapshot(for: "d2"))
        #expect(entry.hasSource(for: "d2"))
    }

    @Test("D2 containers fixture decodes")
    func d2ContainersDecode() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "multi-format-d2-containers",
                    "category": "flowchart",
                    "name": "D2: Containers",
                    "source": "graph TD\\n  subgraph Group\\n    A --> B\\n  end",
                    "sources": {
                        "mermaid": "graph TD\\n  subgraph Group\\n    A --> B\\n  end",
                        "d2": "Group {\\n  A -> B\\n}"
                    },
                    "expectedImporters": {
                        "mermaid": "mermaid",
                        "d2": "d2"
                    },
                    "skipSnapshots": ["d2"]
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.id == "multi-format-d2-containers")
        #expect(entry.source(for: "d2") == "Group {\n  A -> B\n}")
    }

    @Test("D2 shapes fixture decodes")
    func d2ShapesDecode() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "multi-format-d2-shapes",
                    "category": "flowchart",
                    "name": "D2: Shape Hints",
                    "source": "graph LR\\n  A[(Database)]",
                    "sources": {
                        "mermaid": "graph LR\\n  A[(Database)]",
                        "d2": "A: Database\\nA.shape: cylinder"
                    },
                    "expectedImporters": {
                        "mermaid": "mermaid",
                        "d2": "d2"
                    },
                    "skipSnapshots": ["d2"]
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.id == "multi-format-d2-shapes")
    }

    @Test("D2 unsupported fixture has diagnostics")
    func d2UnsupportedFixtureHasDiagnostics() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "multi-format-d2-unsupported",
                    "category": "flowchart",
                    "name": "D2: Unsupported Constructs",
                    "source": "graph TD\\n  A[Start] --> B[End]",
                    "sources": {
                        "mermaid": "graph TD\\n  A[Start] --> B[End]",
                        "d2": "A: Start\\nA.shape: sql_table\\nA -> B\\nstyle.fill: red"
                    },
                    "expectedImporters": {
                        "mermaid": "mermaid",
                        "d2": "d2"
                    },
                    "expectedDiagnostics": [
                        { "severity": "unsupported", "messageContains": "sql_table" },
                        { "severity": "unsupported", "messageContains": "style" }
                    ],
                    "skipSnapshots": ["d2"]
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.expectedDiagnostics?.count == 2)
        #expect(entry.expectedDiagnostics?[0].messageContains == "sql_table")
        #expect(entry.expectedDiagnostics?[1].messageContains == "style")
    }

    @Test("D2 source for format lookup")
    func d2SourceForFormat() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "test-d2",
                    "category": "flowchart",
                    "name": "Test D2",
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
        #expect(entry.source(for: "d2") == "A -> B")
    }

    @Test("D2 parse through importer")
    func d2ParseThroughImporter() throws {
        let d2Source = "direction: right\nA: Start\nB: End\nA -> B"
        let importer = D2Importer()
        let result = try importer.parse(d2Source)
        #expect(result.document.type == .flowchart)

        let positioned = try DiagramPipeline.layout(result.document)
        #expect(!(positioned.flowchartNodes?.isEmpty ?? true))
    }
}

import Foundation
import Testing
import DiagramKitTestSupport
@testable import DiagramKit
import DiagramKitGraphviz

/// Inline DOT fixtures with `skipSnapshots: ["graphviz"]` to avoid snapshot
/// machinery trying to create Graphviz baselines.
@Suite("DOT inline multi-format fixtures")
struct DOTFixtureTests {

    @Test("DOT simple flow fixture decodes")
    func dotSimpleFlowFixtureDecodes() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "multi-format-dot-simple-flow",
                    "category": "flowchart",
                    "name": "DOT: Simple Flow",
                    "source": "graph LR\\n  A[Start] --> B[End]",
                    "sources": {
                        "mermaid": "graph LR\\n  A[Start] --> B[End]",
                        "graphviz": "digraph G {\\n  rankdir=LR;\\n  A [label=Start];\\n  B [label=End];\\n  A -> B;\\n}"
                    },
                    "expectedImporters": {
                        "mermaid": "Mermaid",
                        "graphviz": "Graphviz"
                    },
                    "skipSnapshots": ["graphviz"]
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.id == "multi-format-dot-simple-flow")
        #expect(entry.expectedImporters?["graphviz"] == "Graphviz")
        #expect(entry.shouldSkipSnapshot(for: "graphviz"))
        #expect(entry.hasSource(for: "graphviz"))
    }

    @Test("DOT containers fixture decodes")
    func dotContainersFixtureDecodes() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "multi-format-dot-containers",
                    "category": "flowchart",
                    "name": "DOT: Containers",
                    "source": "graph TD\\n  subgraph Cluster\\n    A --> B\\n  end",
                    "sources": {
                        "mermaid": "graph TD\\n  subgraph Cluster\\n    A --> B\\n  end",
                        "graphviz": "digraph G {\\n  subgraph cluster_0 {\\n    label=\\"Cluster\\";\\n    A; B;\\n  }\\n}"
                    },
                    "expectedImporters": {
                        "mermaid": "Mermaid",
                        "graphviz": "Graphviz"
                    },
                    "skipSnapshots": ["graphviz"]
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.id == "multi-format-dot-containers")
        #expect(entry.source(for: "graphviz")?.contains("subgraph cluster_0") == true)
    }

    @Test("DOT undirected fixture decodes")
    func dotUndirectedFixtureDecodes() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "multi-format-dot-undirected",
                    "category": "flowchart",
                    "name": "DOT: Undirected Graph",
                    "source": "graph TD\\n  A --- B",
                    "sources": {
                        "mermaid": "graph TD\\n  A --- B",
                        "graphviz": "graph G {\\n  A -- B;\\n}"
                    },
                    "expectedImporters": {
                        "mermaid": "Mermaid",
                        "graphviz": "Graphviz"
                    },
                    "skipSnapshots": ["graphviz"]
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.id == "multi-format-dot-undirected")
    }

    @Test("DOT unsupported fixture has diagnostics")
    func dotUnsupportedFixtureHasDiagnostics() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "multi-format-dot-unsupported",
                    "category": "flowchart",
                    "name": "DOT: Unsupported Constructs",
                    "source": "graph TD\\n  A[Start] --> B[End]",
                    "sources": {
                        "mermaid": "graph TD\\n  A[Start] --> B[End]",
                        "graphviz": "digraph G {\\n  A [shape=record, color=red];\\n}"
                    },
                    "expectedImporters": {
                        "mermaid": "Mermaid",
                        "graphviz": "Graphviz"
                    },
                    "expectedDiagnostics": [
                        { "severity": "unsupported", "messageContains": "shape" }
                    ],
                    "skipSnapshots": ["graphviz"]
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.expectedDiagnostics?.count == 1)
        #expect(entry.expectedDiagnostics?[0].messageContains == "shape")
    }

    @Test("DOT source for format lookup")
    func dotSourceForFormat() throws {
        let json = """
        {
            "diagrams": [
                {
                    "id": "test-dot",
                    "category": "flowchart",
                    "name": "Test DOT",
                    "source": "graph TD\\n  A --> B",
                    "sources": {
                        "mermaid": "graph TD\\n  A --> B",
                        "graphviz": "digraph G { A -> B; }"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(CorpusFile.self, from: json)
        let entry = try #require(file.diagrams.first)
        #expect(entry.source(for: "graphviz") == "digraph G { A -> B; }")
    }

    @Test("DOT parse through importer")
    func dotParseThroughImporter() throws {
        let dotSource = "digraph G { rankdir=LR; A [label=\"Start\"]; B [label=\"End\"]; A -> B; }"
        let importer = GraphvizImporter()
        let result = try importer.parse(dotSource)
        #expect(result.document.type == .flowchart)

        let positioned = try DiagramPipeline.layout(result.document)
        #expect(!(positioned.flowchartNodes?.isEmpty ?? true))
    }
}

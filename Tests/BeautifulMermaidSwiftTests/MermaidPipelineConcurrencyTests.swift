import CustomDump
import Testing
@testable import BeautifulMermaid
@testable import DiagramKitCommon
@testable import DiagramKitModel

@Suite("Mermaid pipeline concurrency")
struct MermaidPipelineConcurrencyTests {
    struct Snapshot: Equatable, Sendable {
        var index: Int
        var type: DiagramType
        var width: Int
        var height: Int
        var svg: String
        var ascii: String
    }

    @Test
    func rendersDeterministicNonemptyResultsConcurrently() async throws {
        let diagrams: [(name: String, source: String)] = [
            (
                "flow",
                """
                graph TD
                  A[Start] --> B{Ready?}
                  B -->|yes| C[Ship]
                  B -->|no| D[Fix]
                  D --> B
                """
            ),
            (
                "state",
                """
                stateDiagram-v2
                  [*] --> Idle
                  Idle --> Active : start
                  Active --> Idle : stop
                """
            ),
            (
                "sequence",
                """
                sequenceDiagram
                  Alice->>Bob: ping
                  Bob-->>Alice: pong
                """
            ),
            (
                "class",
                """
                classDiagram
                  class Animal
                  class Dog
                  Animal <|-- Dog
                """
            ),
            (
                "er",
                """
                erDiagram
                  USER ||--o{ POST : writes
                """
            ),
        ]

        let first = try await renderSnapshots(diagrams)
        let second = try await renderSnapshots(diagrams)

        expectNoDifference(first, second)
        expectNoDifference(first.map { !$0.svg.isEmpty && !$0.ascii.isEmpty }, Array(repeating: true, count: diagrams.count))
    }

    private func renderSnapshots(_ diagrams: [(name: String, source: String)]) async throws -> [Snapshot] {
        try await withThrowingTaskGroup(of: Snapshot.self) { group in
            for (index, diagram) in diagrams.enumerated() {
                let source = diagram.source
                group.addTask {
                    let graph = try await MermaidRenderer.parse(source)
                    let positioned = try await MermaidRenderer.layout(source)
                    let svg = try await MermaidRenderer.renderSVG(source: source)
                    let ascii = try await MermaidRenderer.renderASCII(source: source)
                    return Snapshot(
                        index: index,
                        type: graph.type,
                        width: Int(positioned.width.rounded()),
                        height: Int(positioned.height.rounded()),
                        svg: svg,
                        ascii: ascii
                    )
                }
            }

            var snapshots: [Snapshot] = []
            for try await snapshot in group {
                snapshots.append(snapshot)
            }
            return snapshots.sorted { $0.index < $1.index }
        }
    }
}

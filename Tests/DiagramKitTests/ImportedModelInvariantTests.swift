import Foundation
import Testing
import DiagramKit
import DiagramKitExport

// A D2 or DOT file with every line written twice (an ordinary copy-paste
// accident) gave the block and C4 importers a block or boundary inside
// itself; layout, SVG, ASCII and every exporter recursed until the stack
// overflowed. DiagramLoader now repairs containment for every importer.

private let duplicatedD2Block = """
# diagramkit:family=block
# diagramkit:family=block
frontend: "Frontend" {
frontend: "Frontend" {
  webapp: "Web App"
  webapp: "Web App"
  mobile: "Mobile App"
  mobile: "Mobile App"
}
}
# diagramkit:block-cols=frontend,1
# diagramkit:block-cols=frontend,1
backend: "Backend" {
backend: "Backend" {
  api: "API"
  api: "API"
  worker: "Worker"
  worker: "Worker"
}
}
# diagramkit:block-cols=backend,1
# diagramkit:block-cols=backend,1
# diagramkit:block-cols=root,3
# diagramkit:block-cols=root,3
frontend -> backend
frontend -> backend
# diagramkit:block-edge-attrs=0,normal,solid,arrow_open,arrow_point
# diagramkit:block-edge-attrs=0,normal,solid,arrow_open,arrow_point
"""

private let duplicatedDOTC4 = """
digraph G {
digraph G {
    # diagramkit:family=c4
    # diagramkit:family=c4
    # diagramkit:c4-diagram-kind=C4Context
    # diagramkit:c4-diagram-kind=C4Context


    subgraph cluster_b0 {
    subgraph cluster_b0 {
        label = "Group 0";
        label = "Group 0";
        u [shape=oval, label="User"];
        u [shape=oval, label="User"];
        # diagramkit:c4-shape-kind=u,person
        # diagramkit:c4-shape-kind=u,person
        app [shape=box, label="My App"];
        app [shape=box, label="My App"];
    }
    }
    # diagramkit:c4-boundary-kind=b0,system
    # diagramkit:c4-boundary-kind=b0,system
    u -> app [label="Uses"];
    u -> app [label="Uses"];
}
}
"""

@Suite("Containment invariants for imported models")
struct ImportedModelInvariantTests {

    @Test("duplicated D2 blocks and DOT boundaries render and export", arguments: [
        (duplicatedD2Block, DiagramFormatID.d2), (duplicatedDOTC4, .graphviz),
    ])
    func duplicatedContainers(source: String, format: DiagramFormatID) async throws {
        let diagnostics = try await onDiagramWorker { () -> [String] in
            let result = try DiagramPipeline.parseImportResult(source, sourceFormat: format)
            _ = try DiagramPipeline.renderSVG(source: source, sourceFormat: format)
            _ = try DiagramPipeline.renderASCII(source: source, sourceFormat: format)
            for target in [DiagramFormatID.mermaid, .d2, .graphviz, .structurizr, .plantuml] {
                _ = try? DiagramExportLoader.export(result.document, to: target, registry: DiagramPipeline.defaultExportRegistry)
            }
            return result.diagnostics.map(\.message)
        }
        #expect(diagnostics.contains { $0.contains("more than once") || $0.contains("declared twice") }, "\(diagnostics)")
    }

    @Test("a negative C4 relationship-kind marker index is ignored")
    func negativeRelKind() throws {
        let source = "# diagramkit:family=c4\na: \"A\"\nb: \"B\"\na -> b: \"uses\"\n# diagramkit:c4-rel-kind=-1,birel\n"
        _ = try DiagramPipeline.renderSVG(source: source, sourceFormat: .d2)
    }
}

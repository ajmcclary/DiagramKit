import Testing
import Foundation
@testable import DiagramKitModel

/// Regression for REVIEW.md C1: parallel `TextMetrics.estimateTextWidth`
/// callers used to stall on the CoreText font-provider XPC because
/// `DiagramFontResolver.proportionalFont(size:weight:)` went through an
/// unlocked `BMFont(name:size:)` path. The locked `fontLock` covers both
/// CTFont and BMFont construction now; this test exercises the public
/// model-layer layout entry points that bypass `DiagramPipeline`.
@Suite("DiagramFontResolver concurrency")
struct DiagramFontResolverConcurrencyTests {

    @Test("Parallel C4 + treemap layouts complete without stalling")
    func parallelModelLayoutsComplete() async throws {
        try await withThrowingTaskGroup(of: (Double, Double).self) { group in
            for _ in 0..<32 {
                group.addTask {
                    var c4 = C4Diagram(kind: .container)
                    c4.shapes = [
                        C4Shape(alias: "a", label: "Service A", typeC4Shape: .container),
                        C4Shape(alias: "b", label: "Service B", typeC4Shape: .container),
                        C4Shape(alias: "c", label: "Service C", typeC4Shape: .container),
                    ]
                    c4.relationships = [
                        C4Relationship(kind: .rel, from: "a", to: "b", label: "calls"),
                        C4Relationship(kind: .rel, from: "b", to: "c", label: "writes"),
                    ]
                    let positionedC4 = layoutC4Diagram(c4)

                    var treemap = TreemapDiagram()
                    treemap.diagramTitle = "Sample tree"
                    treemap.nodes = [
                        TreemapNode(name: "root", children: [
                            TreemapNode(name: "leaf-a", value: 4),
                            TreemapNode(name: "leaf-b", value: 6),
                        ]),
                    ]
                    let positionedTreemap = layoutTreemapDiagram(treemap)

                    return (positionedC4.width, positionedTreemap.svgWidth)
                }
            }

            for try await (c4Width, treemapWidth) in group {
                #expect(c4Width > 0)
                #expect(treemapWidth > 0)
            }
        }
    }
}

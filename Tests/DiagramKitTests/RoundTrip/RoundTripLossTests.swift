import Testing
import DiagramKitTestSupport
import DiagramKitModel

@Suite("RoundTripLoss")
struct RoundTripLossTests {

    @Test("Every RoundTripLoss case maps to a unique RoundTripLossKind")
    func kindMapping() {
        let cases: [(RoundTripLoss, RoundTripLossKind)] = [
            (.idSanitization(original: "a", sanitized: "b"), .idSanitization),
            (.shapeDowngrade(nodeID: "n", from: original_src_types.NodeShape.rectangle, to: original_src_types.NodeShape.rectangle), .shapeDowngrade),
            (.subgraphFlatten(subgraphID: "s", depth: 1), .subgraphFlatten),
            (.boundaryFlatten(boundaryID: "b", depth: 1), .boundaryFlatten),
            (.c4SlotDrop(shapeID: "p", slot: .technology), .c4SlotDrop),
            (.titleDrop, .titleDrop),
            (.configDrop(key: "look"), .configDrop),
            (.styleDrop(target: "x", attribute: "fill"), .styleDrop),
            (.accessibilityDrop(field: .title), .accessibilityDrop),
            (.anonymousSubgraphRename(old: "subgraph_0", new: "subgraph_1"), .anonymousSubgraphRename),
            (.d2DuplicateOverride(nodeID: "x", attribute: "label"), .d2DuplicateOverride),
            (.classStereotypeDrop(classID: "Foo", stereotype: "interface"), .classStereotypeDrop),
            (.stateActionDrop(stateID: "Idle", phase: .entry), .stateActionDrop),
            (.cardinalityDrop(relationshipID: "Order_Customer", side: .source), .cardinalityDrop),
            (.deploymentShapeFlattened(serviceID: "s", kindRawValue: "node"), .deploymentShapeFlattened),
            (.deploymentDecorationDropped(serviceID: "s", decoration: "color"), .deploymentDecorationDropped),
            (.deploymentLegendDropped, .deploymentLegendDropped),
            (.syntheticRootFlattened, .syntheticRootFlattened),
        ]
        for (loss, expectedKind) in cases {
            #expect(loss.kind == expectedKind)
        }
        #expect(Set(cases.map(\.1)).count == RoundTripLossKind.allCases.count,
                "Every RoundTripLossKind must have at least one case covered by the mapping test")
    }

    @Test("RoundTripLoss is Hashable")
    func hashable() {
        let a: RoundTripLoss = .idSanitization(original: "x", sanitized: "y")
        let b: RoundTripLoss = .idSanitization(original: "x", sanitized: "y")
        let c: RoundTripLoss = .idSanitization(original: "x", sanitized: "z")
        #expect(Set([a, b, c]).count == 2)
    }

    @Test("CustomStringConvertible renders payload")
    func description() {
        let loss: RoundTripLoss = .shapeDowngrade(nodeID: "n1", from: original_src_types.NodeShape.rectangle, to: original_src_types.NodeShape.circle)
        #expect(String(describing: loss).contains("shapeDowngrade"))
        #expect(String(describing: loss).contains("n1"))
    }
}

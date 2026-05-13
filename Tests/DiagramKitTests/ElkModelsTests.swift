import Testing
@testable import DiagramKitModel

@Suite("ElkLayoutOptions")
struct ElkLayoutOptionsTests {

    @Test("Hierarchical-root options for INCLUDE_CHILDREN match the legacy literal")
    func rootIncludeChildrenLR() {
        let opts = ElkLayoutOptions.root(
            direction: original_src_types.Direction.LR,
            hierarchy: .includeChildren
        )
        #expect(opts["elk.algorithm"] == "layered")
        #expect(opts["elk.direction"] == "RIGHT")
        #expect(opts["elk.hierarchyHandling"] == "INCLUDE_CHILDREN")
        #expect(opts["elk.padding"] == "[top=40,left=40,bottom=40,right=40]")
        #expect(opts["elk.layered.wrapping.strategy"] == "OFF")
        #expect(opts["elk.spacing.nodeNode"] == "28")
        #expect(opts["elk.spacing.edgeEdge"] == "12")
        #expect(opts["elk.layered.spacing.nodeNodeBetweenLayers"] == "48")
        #expect(opts["elk.layered.spacing.edgeEdgeBetweenLayers"] == "12")
        #expect(opts["elk.layered.spacing.edgeNodeBetweenLayers"] == "12")
        #expect(opts["elk.edgeRouting"] == "ORTHOGONAL")
        #expect(opts["elk.contentAlignment"] == "H_CENTER V_CENTER")
        #expect(opts["elk.layered.nodePlacement.bk.fixedAlignment"] == "BALANCED")
        #expect(opts["elk.layered.considerModelOrder.strategy"] == "NODES_AND_EDGES")
        #expect(opts["elk.layered.thoroughness"] == "3")
        #expect(opts["elk.layered.compaction.postCompaction.strategy"] == "LEFT_RIGHT_CONSTRAINT_LOCKING")
        #expect(opts["elk.layered.highDegreeNodes.treatment"] == "true")
        #expect(opts["elk.layered.highDegreeNodes.threshold"] == "8")
        #expect(opts.count == 18)
    }

    @Test("Hierarchical-root options for SEPARATE flip only hierarchyHandling")
    func rootSeparateTD() {
        let opts = ElkLayoutOptions.root(
            direction: original_src_types.Direction.TD,
            hierarchy: .separate
        )
        #expect(opts["elk.direction"] == "DOWN")
        #expect(opts["elk.hierarchyHandling"] == "SEPARATE")
        #expect(opts["elk.layered.wrapping.strategy"] == "OFF")
        #expect(opts.count == 18)
    }

    @Test("Flat-fallback root drops hierarchy/wrapping and adds randomSeed")
    func flatRootLR() {
        let opts = ElkLayoutOptions.flatRoot(direction: original_src_types.Direction.LR)
        #expect(opts["elk.direction"] == "RIGHT")
        #expect(opts["elk.randomSeed"] == "1")
        #expect(opts["elk.hierarchyHandling"] == nil)
        #expect(opts["elk.layered.wrapping.strategy"] == nil)
        #expect(opts["elk.algorithm"] == "layered")
        #expect(opts["elk.padding"] == "[top=40,left=40,bottom=40,right=40]")
        #expect(opts.count == 17)
    }

    @Test("Subgraph options omit direction when no override")
    func subgraphNoDirection() {
        let opts = ElkLayoutOptions.subgraph(direction: nil)
        #expect(opts["elk.algorithm"] == "layered")
        #expect(opts["elk.padding"] == "[top=44,left=16,bottom=16,right=16]")
        #expect(opts["elk.spacing.nodeNode"] == "28")
        #expect(opts["elk.layered.spacing.nodeNodeBetweenLayers"] == "48")
        #expect(opts["elk.direction"] == nil)
        #expect(opts.count == 10)
    }

    @Test("Subgraph options carry direction when override set")
    func subgraphWithDirection() {
        let opts = ElkLayoutOptions.subgraph(direction: original_src_types.Direction.BT)
        #expect(opts["elk.direction"] == "UP")
        #expect(opts.count == 11)
    }

    @Test("Direction mapping matches legacy _mapDirection semantics")
    func directionMapping() {
        #expect(ElkLayoutOptions.mapDirection(.LR) == "RIGHT")
        #expect(ElkLayoutOptions.mapDirection(.RL) == "LEFT")
        #expect(ElkLayoutOptions.mapDirection(.BT) == "UP")
        #expect(ElkLayoutOptions.mapDirection(.TD) == "DOWN")
        #expect(ElkLayoutOptions.mapDirection(.TB) == "DOWN")
    }
}

@Suite("ElkGraphNode dictionary encoders")
struct ElkGraphNodeDictionaryTests {

    @Test("Round-trip through toDictionary + init(from:) preserves structure")
    func roundTripPreservesStructure() {
        let node = ElkGraphNode(
            id: "root",
            children: [
                ElkGraphNode(
                    id: "a",
                    layoutOptions: ["elk.algorithm": "layered"],
                    labels: [ElkGraphLabel(text: "A")],
                    width: 60,
                    height: 36
                )
            ],
            edges: [
                ElkGraphEdge(
                    id: "e0",
                    sources: ["a"],
                    targets: ["b"],
                    labels: [
                        ElkGraphLabel(
                            text: "hi",
                            width: 8,
                            height: 6,
                            layoutOptions: ["elk.edgeLabels.inline": "true"]
                        )
                    ]
                )
            ],
            layoutOptions: ["elk.direction": "RIGHT"]
        )

        let dict = node.toDictionary()
        let roundTrip = ElkGraphNode(from: dict)

        #expect(roundTrip.id == "root")
        #expect(roundTrip.children.count == 1)
        #expect(roundTrip.children.first?.id == "a")
        #expect(roundTrip.children.first?.width == 60)
        #expect(roundTrip.children.first?.labels.first?.text == "A")
        #expect(roundTrip.edges.count == 1)
        #expect(roundTrip.edges.first?.id == "e0")
        #expect(roundTrip.edges.first?.sources == ["a"])
        #expect(roundTrip.edges.first?.targets == ["b"])
        #expect(roundTrip.edges.first?.labels.first?.text == "hi")
        #expect(roundTrip.edges.first?.labels.first?.layoutOptions["elk.edgeLabels.inline"] == "true")
        #expect(roundTrip.layoutOptions["elk.direction"] == "RIGHT")
    }

    @Test("Node toDictionary omits empty children/edges/ports for legacy parity")
    func nodeDictionaryOmitsEmptyCollections() {
        let node = ElkGraphNode(id: "leaf", width: 12, height: 8)
        let dict = node.toDictionary()
        #expect(dict["id"] as? String == "leaf")
        #expect(dict["width"] as? Double == 12)
        #expect(dict["height"] as? Double == 8)
        #expect(dict["children"] == nil)
        #expect(dict["edges"] == nil)
        #expect(dict["ports"] == nil)
        #expect(dict["labels"] == nil)
    }

    @Test("Edge toDictionary preserves sources, targets, and labels")
    func edgeDictionary() {
        let edge = ElkGraphEdge(
            id: "e1",
            sources: ["a"],
            targets: ["b"],
            labels: [
                ElkGraphLabel(
                    text: "lbl",
                    width: 12,
                    height: 8,
                    layoutOptions: ["elk.edgeLabels.placement": "CENTER"]
                )
            ]
        )
        let dict = edge.toDictionary()
        #expect(dict["id"] as? String == "e1")
        #expect(dict["sources"] as? [String] == ["a"])
        #expect(dict["targets"] as? [String] == ["b"])
        let labels = dict["labels"] as? [[String: Any]]
        #expect(labels?.count == 1)
        #expect(labels?.first?["text"] as? String == "lbl")
        let lblOpts = labels?.first?["layoutOptions"] as? [String: String]
        #expect(lblOpts?["elk.edgeLabels.placement"] == "CENTER")
    }

    @Test("Label toDictionary preserves geometry and layoutOptions")
    func labelDictionary() {
        let label = ElkGraphLabel(
            text: "lbl",
            x: 1,
            y: 2,
            width: 10,
            height: 6,
            layoutOptions: ["elk.edgeLabels.inline": "true"]
        )
        let dict = label.toDictionary()
        #expect(dict["text"] as? String == "lbl")
        #expect(dict["x"] as? Double == 1)
        #expect(dict["y"] as? Double == 2)
        #expect(dict["width"] as? Double == 10)
        #expect(dict["height"] as? Double == 6)
        let opts = dict["layoutOptions"] as? [String: String]
        #expect(opts?["elk.edgeLabels.inline"] == "true")
    }
}

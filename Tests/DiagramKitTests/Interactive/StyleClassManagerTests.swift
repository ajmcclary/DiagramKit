// Apple-only test (CoreGraphics renderer, AppKit/UIKit, image snapshots or the
// UndoManager-based interactive editor). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
// Visual editor plan 1 — generated-classDef lifecycle.

import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitInteractive

private func graph(
    nodes: [String],
    classDefs: [String: [String: String]] = [:],
    classAssignments: [String: [String]] = [:],
    nodeStyles: [String: [String: String]] = [:]
) -> original_src_types.MermaidGraph {
    original_src_types.MermaidGraph(
        direction: .TD,
        nodesInOrder: nodes.map {
            (id: $0, node: original_src_types.MermaidNode(id: $0, label: $0, shape: .rectangle))
        },
        edges: [],
        classDefs: classDefs,
        classAssignments: classAssignments,
        nodeStyles: nodeStyles
    )
}

private let greenSpec = NodeStyleSpec(fill: "#e8f5e9", stroke: "#2e7d32")

@Suite
struct StyleClassManagerTests {

    @Test("generated-name detection")
    func generatedNames() {
        #expect(StyleClassManager.isGeneratedClassName("vs1"))
        #expect(StyleClassManager.isGeneratedClassName("vs42"))
        #expect(!StyleClassManager.isGeneratedClassName("vs"))
        #expect(!StyleClassManager.isGeneratedClassName("vsx"))
        #expect(!StyleClassManager.isGeneratedClassName("important"))
        #expect(!StyleClassManager.isGeneratedClassName("vs1b"))
    }

    @Test("first style mints vs1 and assigns it")
    func mintsFirstClass() {
        let (result, diags) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: graph(nodes: ["A"]))
        #expect(result.classDefs["vs1"] == greenSpec.classDefProperties)
        #expect(result.classAssignments["A"] == ["vs1"])
        #expect(diags.isEmpty)
    }

    @Test("identical style on a second node reuses the class")
    func dedup() {
        var g = graph(nodes: ["A", "B"])
        (g, _) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
        let (result, _) = StyleClassManager.applyStyle(greenSpec, toNode: "B", in: g)
        #expect(result.classDefs.count == 1)
        #expect(result.classAssignments["B"] == ["vs1"])
    }

    @Test("restyling the sole member GCs the orphaned class")
    func garbageCollection() {
        var g = graph(nodes: ["A"])
        (g, _) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
        let orange = NodeStyleSpec(fill: "#fff3e0")
        let (result, _) = StyleClassManager.applyStyle(orange, toNode: "A", in: g)
        #expect(result.classDefs["vs1"] == nil)
        #expect(result.classDefs["vs2"] == orange.classDefProperties)
        #expect(result.classAssignments["A"] == ["vs2"])
    }

    @Test("mint skips names taken by user classDefs")
    func skipsUserNames() {
        let g = graph(nodes: ["A"], classDefs: ["vs1": ["fill": "#123456"]])
        let (result, _) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
        // "vs1" is occupied by a (user) class with different props → mint vs2.
        #expect(result.classDefs["vs2"] == greenSpec.classDefProperties)
        #expect(result.classAssignments["A"] == ["vs2"])
    }

    @Test("user-authored class assignments and defs survive restyling")
    func userClassesUntouched() {
        let g = graph(
            nodes: ["A"],
            classDefs: ["important": ["fill": "#ff0000"]],
            classAssignments: ["A": ["important"]]
        )
        let (result, _) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
        #expect(result.classDefs["important"] == ["fill": "#ff0000"])
        #expect(result.classAssignments["A"] == ["important", "vs1"])
    }

    @Test("inline style migrates to generated class with info diagnostic")
    func inlineMigration() {
        let g = graph(nodes: ["A"], nodeStyles: ["A": ["fill": "#ff0000"]])
        let (result, diags) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
        #expect(result.nodeStyles["A"] == nil)
        #expect(diags.count == 1)
        #expect(diags.first?.category == .styleClassMigration)
        #expect(diags.first?.severity == .info)
    }

    @Test("empty spec clears generated assignment and GCs")
    func clearStyling() {
        var g = graph(nodes: ["A"])
        (g, _) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
        let (result, _) = StyleClassManager.applyStyle(NodeStyleSpec(), toNode: "A", in: g)
        #expect(result.classDefs.isEmpty)
        #expect(result.classAssignments["A"] == nil)
    }

    @Test("effectiveStyle resolves classes then inline overrides")
    func effectiveStyleResolution() {
        let g = graph(
            nodes: ["A"],
            classDefs: ["vs1": ["fill": "#e8f5e9", "stroke": "#2e7d32"]],
            classAssignments: ["A": ["vs1"]],
            nodeStyles: ["A": ["fill": "#ffffff"]]
        )
        let spec = StyleClassManager.effectiveStyle(forNode: "A", in: g)
        #expect(spec.fill == "#ffffff")      // inline wins
        #expect(spec.stroke == "#2e7d32")    // class survives
    }

    @Test("effectiveStyle on unstyled node is empty")
    func effectiveStyleEmpty() {
        let spec = StyleClassManager.effectiveStyle(forNode: "A", in: graph(nodes: ["A"]))
        #expect(spec.isEmpty)
    }

    @Test("identical edit sequences produce identical graphs")
    func deterministicNaming() {
        func run() -> original_src_types.MermaidGraph {
            var g = graph(nodes: ["A", "B"])
            (g, _) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
            (g, _) = StyleClassManager.applyStyle(NodeStyleSpec(fill: "#fff3e0"), toNode: "B", in: g)
            return g
        }
        let a = run(), b = run()
        #expect(a.classDefs == b.classDefs)
        #expect(a.classAssignments == b.classAssignments)
    }
}
#endif

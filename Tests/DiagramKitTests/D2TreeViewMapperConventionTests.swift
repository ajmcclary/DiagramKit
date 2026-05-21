import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2TreeViewMapper — multi-root convention")
struct D2TreeViewMapperConventionTests {

    private func parseAndMap(_ source: String) throws -> (TreeViewDiagram?, [DiagramDiagnostic]) {
        // Mirrors D2Importer.swift:48-50 — parser sees raw source
        // (D2's `#` is a comment so markers are tolerated); scanner
        // extracts typed markers separately.
        let parser = D2Parser()
        let (doc, _) = try parser.parse(source)
        let scan = D2RecoveryMarker.scanner.scan(source: source)
        return D2TreeViewMapper().map(doc, markers: scan.markers)
    }

    @Test("single-root D2 input maps to real-root payload (existing behavior)")
    func singleRootRealRoot() throws {
        let src = """
        # diagramkit:family=treeView
        # diagramkit:tree-root=alpha
        alpha: "alpha"
        leaf: "leaf"
        alpha -> leaf
        """
        let (diagram, diagnostics) = try parseAndMap(src)
        #expect(diagram != nil)
        #expect(diagnostics.isEmpty)
        #expect(diagram?.root.name == "alpha")
        #expect(diagram?.root.level == 0)
    }

    @Test("multi-root D2 input synthesizes `/` container; alphabetical order")
    func multiRootSynthesizes() throws {
        let src = """
        # diagramkit:family=treeView
        beta: "beta"
        alpha: "alpha"
        """
        let (diagram, _) = try parseAndMap(src)
        #expect(diagram != nil)
        #expect(diagram?.root.name == "/")
        #expect(diagram?.root.level == -1)
        let kidNames = (diagram?.root.children ?? []).map(\.name)
        #expect(kidNames == ["alpha", "beta"], "alphabetical fallback ordering")
    }

    @Test("multi-root D2 input with tree-root marker hoists pinned root first")
    func multiRootMarkerHoist() throws {
        let src = """
        # diagramkit:family=treeView
        # diagramkit:tree-root=beta
        alpha: "alpha"
        beta: "beta"
        gamma: "gamma"
        """
        let (diagram, _) = try parseAndMap(src)
        #expect(diagram?.root.name == "/")
        let kidNames = (diagram?.root.children ?? []).map(\.name)
        #expect(kidNames == ["beta", "alpha", "gamma"], "marker pins beta first; rest alphabetical")
    }

    @Test("multi-root preserves each subtree's children")
    func multiRootSubtrees() throws {
        let src = """
        # diagramkit:family=treeView
        alpha: "alpha"
        beta: "beta"
        a_leaf: "a_leaf"
        b_leaf: "b_leaf"
        alpha -> a_leaf
        beta -> b_leaf
        """
        let (diagram, _) = try parseAndMap(src)
        let alpha = diagram?.root.children.first { $0.name == "alpha" }
        let beta = diagram?.root.children.first { $0.name == "beta" }
        #expect(alpha?.children.map(\.name) == ["a_leaf"])
        #expect(beta?.children.map(\.name) == ["b_leaf"])
    }
}

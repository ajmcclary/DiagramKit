import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitGraphviz

@Suite("DOTTreeViewMapper — multi-root convention")
struct DOTTreeViewMapperConventionTests {

    private func parseAndMap(_ source: String) throws -> (TreeViewDiagram?, [DiagramDiagnostic]) {
        // Mirrors GraphvizImporter.swift:42-47 — lex first, then parser
        // sees tokens; scanner extracts typed markers from raw source.
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, _) = try parser.parse(tokens)
        let scan = DOTRecoveryMarker.scanner.scan(source: source)
        return DOTTreeViewMapper().map(doc, markers: scan.markers)
    }

    @Test("single-root DOT input maps to real-root payload (existing behavior)")
    func singleRootRealRoot() throws {
        let src = """
        digraph G {
          # diagramkit:family=treeView
          # diagramkit:tree-root=alpha
          alpha [label="alpha"];
          leaf [label="leaf"];
          alpha -> leaf;
        }
        """
        let (diagram, diagnostics) = try parseAndMap(src)
        #expect(diagram != nil)
        #expect(diagnostics.isEmpty)
        #expect(diagram?.root.name == "alpha")
    }

    @Test("multi-root DOT input synthesizes `/` container; alphabetical order")
    func multiRootSynthesizes() throws {
        let src = """
        digraph G {
          # diagramkit:family=treeView
          beta [label="beta"];
          alpha [label="alpha"];
        }
        """
        let (diagram, _) = try parseAndMap(src)
        #expect(diagram?.root.name == "/")
        #expect(diagram?.root.level == -1)
        let kidNames = (diagram?.root.children ?? []).map(\.name)
        #expect(kidNames == ["alpha", "beta"])
    }

    @Test("multi-root DOT input with tree-root marker hoists pinned root first")
    func multiRootMarkerHoist() throws {
        let src = """
        digraph G {
          # diagramkit:family=treeView
          # diagramkit:tree-root=beta
          alpha [label="alpha"];
          beta [label="beta"];
          gamma [label="gamma"];
        }
        """
        let (diagram, _) = try parseAndMap(src)
        let kidNames = (diagram?.root.children ?? []).map(\.name)
        #expect(kidNames == ["beta", "alpha", "gamma"])
    }
}

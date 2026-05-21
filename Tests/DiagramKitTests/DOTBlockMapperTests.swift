import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitGraphviz

@Suite("DOTBlockMapper")
struct DOTBlockMapperTests {

    @Test("Single root block")
    func singleBlock() throws {
        let source = """
        # diagramkit:family=block
        digraph G {
          a [label="A"];
        }
        """
        let (diag, _) = try map(source)
        #expect(diag.rootChildren == ["a"])
        #expect(diag.blockDatabase["a"]?.label == "A")
        #expect(diag.blockDatabase["a"]?.type == .square)
    }

    @Test("Cluster maps to composite with prefix stripped")
    func clusterStrip() throws {
        let source = """
        # diagramkit:family=block
        digraph G {
          subgraph cluster_g {
            label="G";
            a [label="A"];
          }
        }
        """
        let (diag, _) = try map(source)
        #expect(diag.rootChildren == ["g"])
        #expect(diag.blockDatabase["g"]?.type == .composite)
        #expect(diag.blockDatabase["g"]?.label == "G")
        #expect(diag.blockDatabase["g"]?.children == ["a"])
    }

    @Test("Block-cols marker applies to container")
    func columnsViaMarker() throws {
        let source = """
        # diagramkit:family=block
        digraph G {
          subgraph cluster_g {
            a; b;
          }
        }
        # diagramkit:block-cols=g,2
        """
        let (diag, _) = try map(source)
        #expect(diag.blockDatabase["g"]?.columns == 2)
    }

    @Test("Shape fallback marker restores leanLeft")
    func shapeFallback() throws {
        let source = """
        # diagramkit:family=block
        digraph G {
          a [label="A", shape=parallelogram];
        }
        # diagramkit:block-shape-fallback=a,lean_left
        """
        let (diag, _) = try map(source)
        #expect(diag.blockDatabase["a"]?.type == .leanLeft)
    }

    @Test("Block arrow reconstructs")
    func blockArrowReconstruction() throws {
        let source = """
        # diagramkit:family=block
        digraph G {
          arrow1 [label="Sync"];
        }
        # diagramkit:block-shape-fallback=arrow1,block_arrow
        # diagramkit:block-arrow-dir=arrow1,right,up
        """
        let (diag, _) = try map(source)
        #expect(diag.blockDatabase["arrow1"]?.type == .blockArrow)
        #expect(diag.blockDatabase["arrow1"]?.directions == [.right, .up])
    }

    @Test("Edge attrs marker applies")
    func edgeAttrsApplied() throws {
        let source = """
        # diagramkit:family=block
        digraph G {
          a; b;
          a -> b;
        }
        # diagramkit:block-edge-attrs=0,thick,dashed,arrow_open,arrow
        """
        let (diag, _) = try map(source)
        #expect(diag.edges.count == 1)
        #expect(diag.edges[0].thickness == "thick")
        #expect(diag.edges[0].pattern == "dashed")
    }

    @Test("ClassDef + class apply markers")
    func classDefAndApply() throws {
        let source = """
        # diagramkit:family=block
        digraph G {
          a [label="A"];
        }
        # diagramkit:block-classdef=blue,fill:#6cf;stroke:#333
        # diagramkit:block-class-apply=a,blue
        """
        let (diag, _) = try map(source)
        #expect(diag.classes["blue"]?.styles == ["fill:#6cf", "stroke:#333"])
        #expect(diag.blockDatabase["a"]?.classes == ["blue"])
    }

    @Test("Accessibility metadata markers")
    func accessibilityMarkers() throws {
        let source = """
        # diagramkit:family=block
        digraph G {
          a;
        }
        # diagramkit:block-acc-title=Wave J fixture
        # diagramkit:block-acc-descr=DOT block accessibility descr
        """
        let (diag, _) = try map(source)
        #expect(diag.accTitle == "Wave J fixture")
        #expect(diag.accDescr == "DOT block accessibility descr")
    }

    private func map(_ source: String) throws -> (BlockDiagram, [DiagramDiagnostic]) {
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, _) = try parser.parse(tokens)
        let markers = DOTRecoveryMarker.scanner.scan(source: source).markers
        return DOTBlockMapper().map(doc, markers: markers)
    }
}

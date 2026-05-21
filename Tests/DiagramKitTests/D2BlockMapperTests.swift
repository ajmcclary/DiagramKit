import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2BlockMapper")
struct D2BlockMapperTests {

    @Test("Single root block")
    func singleBlock() throws {
        let source = """
        # diagramkit:family=block
        a: "A"
        """
        let (diag, _) = try map(source)
        #expect(diag.rootChildren == ["a"])
        #expect(diag.blockDatabase["a"]?.label == "A")
        #expect(diag.blockDatabase["a"]?.type == .square)
    }

    @Test("Nested composite")
    func nestedComposite() throws {
        let source = """
        # diagramkit:family=block
        g: "G" {
          x: "X"
          y: "Y"
        }
        """
        let (diag, _) = try map(source)
        #expect(diag.rootChildren == ["g"])
        #expect(diag.blockDatabase["g"]?.type == .composite)
        #expect(diag.blockDatabase["g"]?.children == ["x", "y"])
        #expect(diag.blockDatabase["x"]?.type == .square)
        #expect(diag.blockDatabase["y"]?.label == "Y")
    }

    @Test("Columns via marker")
    func columnsViaMarker() throws {
        let source = """
        # diagramkit:family=block
        g: "G" {
          a: "A"
          b: "B"
        }
        # diagramkit:block-cols=g,2
        """
        let (diag, _) = try map(source)
        #expect(diag.blockDatabase["g"]?.columns == 2)
    }

    @Test("Width span via marker")
    func widthSpanViaMarker() throws {
        let source = """
        # diagramkit:family=block
        a: "A"
        # diagramkit:block-width=a,2
        """
        let (diag, _) = try map(source)
        #expect(diag.blockDatabase["a"]?.widthInColumns == 2)
    }

    @Test("Shape fallback via marker restores leanLeft")
    func shapeFallbackLeanLeft() throws {
        let source = """
        # diagramkit:family=block
        a: "A"
        a.shape: rectangle
        # diagramkit:block-shape-fallback=a,lean_left
        """
        let (diag, _) = try map(source)
        #expect(diag.blockDatabase["a"]?.type == .leanLeft)
    }

    @Test("Block arrow reconstructs from fallback + dir marker")
    func blockArrowReconstructs() throws {
        let source = """
        # diagramkit:family=block
        arrow1: "Sync"
        # diagramkit:block-shape-fallback=arrow1,block_arrow
        # diagramkit:block-arrow-dir=arrow1,right,up
        """
        let (diag, _) = try map(source)
        #expect(diag.blockDatabase["arrow1"]?.type == .blockArrow)
        #expect(diag.blockDatabase["arrow1"]?.directions == [.right, .up])
    }

    @Test("Space marker inserts synthetic node")
    func spaceReconstructs() throws {
        let source = """
        # diagramkit:family=block
        a: "A"
        b: "B"
        # diagramkit:block-space=root,1
        """
        let (diag, _) = try map(source)
        let rc = diag.rootChildren
        #expect(rc.count == 3)
        #expect(rc[1].hasPrefix("space_"))
        if let spaceID = rc.first(where: { $0.hasPrefix("space_") }) {
            #expect(diag.blockDatabase[spaceID]?.type == .space)
        }
    }

    @Test("Edge attrs marker applies to indexed edge")
    func edgeAttrsApplied() throws {
        let source = """
        # diagramkit:family=block
        a: "A"
        b: "B"
        a -> b
        # diagramkit:block-edge-attrs=0,thick,dashed,arrow_open,arrow
        """
        let (diag, _) = try map(source)
        #expect(diag.edges.count == 1)
        #expect(diag.edges[0].thickness == "thick")
        #expect(diag.edges[0].pattern == "dashed")
        #expect(diag.edges[0].arrowTypeStart == "arrow_open")
        #expect(diag.edges[0].arrowTypeEnd == "arrow")
    }

    @Test("ClassDef + class apply markers")
    func classDefAndApply() throws {
        let source = """
        # diagramkit:family=block
        a: "A"
        # diagramkit:block-classdef=blue,fill:#6cf;stroke:#333
        # diagramkit:block-class-apply=a,blue
        """
        let (diag, _) = try map(source)
        #expect(diag.classes["blue"]?.styles == ["fill:#6cf", "stroke:#333"])
        #expect(diag.blockDatabase["a"]?.classes == ["blue"])
    }

    @Test("Inline style marker")
    func inlineStyle() throws {
        let source = """
        # diagramkit:family=block
        a: "A"
        # diagramkit:block-style=a,fill:#f00;color:white
        """
        let (diag, _) = try map(source)
        #expect(diag.blockDatabase["a"]?.styles == ["fill:#f00", "color:white"])
    }

    @Test("Accessibility title + descr markers")
    func accessibilityMarkers() throws {
        let source = """
        # diagramkit:family=block
        a: "A"
        # diagramkit:block-acc-title=Wave J fixture
        # diagramkit:block-acc-descr=Long accessibility descr
        """
        let (diag, _) = try map(source)
        #expect(diag.accTitle == "Wave J fixture")
        #expect(diag.accDescr == "Long accessibility descr")
    }

    // MARK: - Helper

    private func map(_ source: String) throws -> (BlockDiagram, [DiagramDiagnostic]) {
        let parser = D2Parser()
        let (doc, _) = try parser.parse(source)
        let markers = D2RecoveryMarker.scanner.scan(source: source).markers
        return D2BlockMapper().map(doc, markers: markers)
    }
}

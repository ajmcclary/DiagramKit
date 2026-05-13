import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("TreeView Public Pipeline")
struct TreeViewPipelineTests {

    @Test("Public parse, layout, SVG, and ASCII dispatch route TreeView")
    func publicPipelineRoutesTreeView() async throws {
        let source = """
        treeView-beta
            src/
                index.js
            package.json
        """

        let graph = try await DiagramEngine.parse(source)
        guard case .treeView = graph.payload else {
            Issue.record("Expected TreeView payload, got \(graph.payload)")
            return
        }

        let positioned = try await DiagramEngine.layout(source)
        guard case .treeView(let data) = positioned.content else {
            Issue.record("Expected positioned TreeView content, got \(positioned.content)")
            return
        }
        #expect(data.nodes.contains { $0.name == "src" })
        #expect(data.nodes.contains { $0.name == "package.json" })

        let svg = try await renderDiagramSVG(source)
        #expect(svg.contains("class=\"tree-view\""))
        #expect(svg.contains("package.json"))

        do {
            _ = try original_src_ascii_index.renderMermaidASCII(source)
            Issue.record("Expected TreeView ASCII to be explicitly not implemented")
        } catch let error as DiagramError {
            guard case .notYetImplemented(let message) = error else {
                Issue.record("Expected notYetImplemented, got \(error)")
                return
            }
            #expect(message.contains("TreeView ASCII rendering"))
        }
    }

    @Test("SVG TreeView detection is case-sensitive")
    func svgTreeViewDetectionIsCaseSensitive() async throws {
        do {
            _ = try await renderDiagramSVG("TreeView-beta\n    file.js\n")
        } catch {
            #expect(!String(describing: error).contains("Invalid treeView header"))
        }
    }

    @Test("ASCII TreeView detection is case-sensitive")
    func asciiTreeViewDetectionIsCaseSensitive() {
        do {
            _ = try original_src_ascii_index.renderMermaidASCII("treeview-beta\n    file.js\n")
        } catch let error as DiagramError {
            if case .notYetImplemented(let message) = error {
                #expect(!message.contains("TreeView ASCII rendering"))
            }
        } catch {
            #expect(!String(describing: error).contains("TreeView ASCII rendering"))
        }
    }

    @Test("Init directive applies TreeView config and theme")
    func initDirectiveAppliesTreeViewConfigAndTheme() async throws {
        let source = """
        %%{init: {'treeView': {'rowIndent': 24, 'showIcons': false}, 'themeVariables': {'treeView': {'labelColor': '#123456', 'lineColor': '#654321'}}}}%%
        treeView-beta
            file.js
        """

        let graph = try await DiagramEngine.parse(source)
        guard case .treeView(let diagram) = graph.payload else {
            Issue.record("Expected TreeView payload, got \(graph.payload)")
            return
        }

        #expect(diagram.config.rowIndent == 24)
        #expect(diagram.config.showIcons == false)
        #expect(diagram.theme?.labelColor == "#123456")
        #expect(diagram.theme?.lineColor == "#654321")
    }

    @Test("Public SVG applies TreeView frontmatter config and theme")
    func publicSvgAppliesFrontmatterConfigAndTheme() async throws {
        let source = """
        ---
        config:
          treeView:
            showIcons: false
          themeVariables:
            treeView:
              labelFontSize: '18px'
              labelColor: '#AA0000'
        ---
        treeView-beta
            file.js
        """

        let svg = try await renderDiagramSVG(source)
        #expect(svg.contains("font-size:18px"))
        #expect(svg.contains("fill:#AA0000"))
        #expect(!svg.contains("<use"))
    }

    @Test("SVG applies useMaxWidth when config.useMaxWidth is true")
    func svgUseMaxWidth() async throws {
        let source = """
        ---
        config:
          treeView:
            useMaxWidth: true
        ---
        treeView-beta
            file.js
        """

        let svg = try await renderDiagramSVG(source)
        #expect(svg.contains("width=\"100%\""))
    }

    @Test("SVG uses explicit width when useMaxWidth is false")
    func svgExplicitWidth() async throws {
        let source = """
        treeView-beta
            file.js
        """

        let svg = try await renderDiagramSVG(source)
        #expect(svg.contains("width=\""))
        #expect(!svg.contains("width=\"100%\""))
    }
}

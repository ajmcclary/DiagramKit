import CoreGraphics
import Testing
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("TreeView Renderer")
struct TreeViewRendererTests {

    private func _makeContext(width: Int = 400, height: Int = 200) -> CGContext? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private func _parseAndLayout(_ source: String) throws -> PositionedGraph {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let graph = DiagramDocument(payload: .treeView(diagram))
        return PositionedGraph(diagram: graph, width: positioned.viewBoxWidth, height: positioned.viewBoxHeight, content: .treeView(positioned))
    }

    @Test("Renderer handles empty tree")
    func emptyTree() throws {
        let positioned = try _parseAndLayout("treeView-beta\n")
        let context = _makeContext()
        #expect(context != nil)
        if let ctx = context {
            DiagramRenderer().render(positioned, in: ctx, bounds: CGRect(x: 0, y: 0, width: 400, height: 200))
        }
    }

    @Test("Renderer produces image for basic tree")
    func basicTree() throws {
        let positioned = try _parseAndLayout("""
        treeView-beta
            src/
                index.js
            package.json
        """)
        let context = _makeContext()
        #expect(context != nil)
        if let ctx = context {
            DiagramRenderer().render(positioned, in: ctx, bounds: CGRect(x: 0, y: 0, width: 400, height: 200))
        }
    }

    @Test("Renderer produces image with icons")
    func withIcons() throws {
        let positioned = try _parseAndLayout("""
        treeView-beta
            App.tsx
        """)
        let context = _makeContext()
        #expect(context != nil)
        if let ctx = context {
            DiagramRenderer().render(positioned, in: ctx, bounds: CGRect(x: 0, y: 0, width: 400, height: 200))
        }
    }

    @Test("Renderer produces image with highlights")
    func withHighlights() throws {
        let positioned = try _parseAndLayout("""
        treeView-beta
            file.js :::highlight
        """)
        let context = _makeContext()
        #expect(context != nil)
        if let ctx = context {
            DiagramRenderer().render(positioned, in: ctx, bounds: CGRect(x: 0, y: 0, width: 400, height: 200))
        }
    }

    @Test("Renderer produces image with descriptions")
    func withDescriptions() throws {
        let positioned = try _parseAndLayout("""
        treeView-beta
            file.js ## entry point
        """)
        let context = _makeContext()
        #expect(context != nil)
        if let ctx = context {
            DiagramRenderer().render(positioned, in: ctx, bounds: CGRect(x: 0, y: 0, width: 400, height: 200))
        }
    }

    @Test("Renderer produces image with custom theme colors")
    func customThemeColors() throws {
        let source = "treeView-beta\n    file.js\n"
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        diagram.theme = TreeViewThemeVariables(
            labelColor: "#FF0000",
            lineColor: "#00FF00",
            iconColor: "#0000FF"
        )
        let positioned = layoutTreeViewDiagram(diagram)
        let graph = DiagramDocument(payload: .treeView(diagram))
        let positionedGraph = PositionedGraph(diagram: graph, width: positioned.viewBoxWidth, height: positioned.viewBoxHeight, content: .treeView(positioned))
        let context = _makeContext()
        #expect(context != nil)
        if let ctx = context {
            DiagramRenderer().render(positionedGraph, in: ctx, bounds: CGRect(x: 0, y: 0, width: 400, height: 200))
        }
    }

    @Test("Core Graphics renders complex SVG icon paths")
    func complexIconPathRendersPixels() throws {
        let source = "treeView-beta\n    Dockerfile icon(docker)\n"
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let (diagram, _) = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let positioned = layoutTreeViewDiagram(diagram)
        let graph = DiagramDocument(payload: .treeView(diagram))
        let positionedGraph = PositionedGraph(
            diagram: graph,
            width: positioned.viewBoxWidth,
            height: positioned.viewBoxHeight,
            content: .treeView(positioned)
        )

        let width = max(120, Int(ceil(positioned.viewBoxWidth)))
        let height = max(80, Int(ceil(positioned.viewBoxHeight)))
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        let didRender = pixels.withUnsafeMutableBytes { rawBuffer in
            guard let context = CGContext(
                data: rawBuffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }

            DiagramRenderer().render(
                positionedGraph,
                in: context,
                bounds: CGRect(x: 0, y: 0, width: width, height: height)
            )
            return true
        }
        guard didRender else {
            Issue.record("Failed to create bitmap context")
            return
        }

        let iconNode = try #require(positioned.nodes.first(where: { $0.name == "Dockerfile" }))
        let iconX = try #require(iconNode.iconX)
        let iconY = try #require(iconNode.iconY)
        let contentWidth = max(1.0, positioned.viewBoxWidth)
        let contentHeight = max(1.0, positioned.viewBoxHeight)
        let scale = min(Double(width) / contentWidth, Double(height) / contentHeight)
        let offsetX = (Double(width) - contentWidth * scale) / 2.0
        let offsetY = (Double(height) - contentHeight * scale) / 2.0
        let iconMinX = offsetX + iconX * scale
        let iconMaxX = offsetX + (iconX + ICON_SIZE) * scale
        let iconMinY = offsetY + iconY * scale
        let iconMaxY = offsetY + (iconY + ICON_SIZE) * scale
        let xRange = Int(floor(iconMinX))..<Int(ceil(iconMaxX))
        let yRange = Int(floor(Double(height) - iconMaxY))..<Int(ceil(Double(height) - iconMinY))
        var nonWhitePixels = 0
        for y in yRange where y >= 0 && y < height {
            for x in xRange where x >= 0 && x < width {
                let index = (y * width + x) * 4
                if pixels[index] < 245 || pixels[index + 1] < 245 || pixels[index + 2] < 245 {
                    nonWhitePixels += 1
                }
            }
        }

        #expect(nonWhitePixels > 8)
    }
}

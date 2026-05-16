import Testing
import Foundation
import CoreGraphics
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite(.serialized)
@MainActor
struct EventModelingEndToEndTests {

    @Test func e2e_simpleStateChange() async throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let graph = try await DiagramEngine.parse(source)
        guard case let .eventModeling(diagram) = graph.payload else {
            Issue.record("Expected eventModeling payload")
            return
        }
        #expect(diagram.frames.count == 3)
    }

    @Test func e2e_frontmatterConfig() async throws {
        let source = """
        ---
        config:
          eventmodeling:
            padding: 50
        ---
        eventmodeling
        tf 01 ui CartUI
        tf 02 cmd AddItem
        """
        let graph = try await DiagramEngine.parse(source)
        guard case let .eventModeling(diagram) = graph.payload else {
            Issue.record("Expected eventModeling payload")
            return
        }
        #expect(diagram.config.padding == 50)
    }

    @Test func e2e_frontmatterTheme() async throws {
        let source = """
        ---
        config:
          themeVariables:
            emCommandFill: '#e3f2fd'
            emCommandStroke: '#1565c0'
        ---
        eventmodeling
        tf 01 ui CartUI
        tf 02 cmd AddItem
        """
        let graph = try await DiagramEngine.parse(source)
        guard case let .eventModeling(diagram) = graph.payload else {
            Issue.record("Expected eventModeling payload")
            return
        }
        #expect(diagram.themeVariables.emCommandFill == "#e3f2fd")
        #expect(diagram.themeVariables.emCommandStroke == "#1565c0")
    }

    @Test func e2e_asciiRenders() throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem"
        let ascii = try original_src_ascii_index.renderMermaidASCII(source)
        #expect(ascii.contains("CartUI"))
        #expect(ascii.contains("AddItem"))
    }

    @Test func e2e_svgRendering() async throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let svg = try await DiagramEngine.renderSVG(source: source)
        #expect(svg.contains("em-swimlane"))
        #expect(svg.contains("svg"))
    }

    @Test func e2e_layout() async throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem"
        let positioned = try await DiagramEngine.layout(source)
        guard case .eventModeling = positioned.content else {
            Issue.record("Expected eventModeling positioned content")
            return
        }
        #expect(positioned.width > 0)
    }

    @Test func e2e_initDirectiveThemeVariables() async throws {
        let source = """
        %%{init: { "themeVariables": { "emCommandFill": "#abc123", "emEventStroke": "#def456" } } }%%
        eventmodeling
        tf 01 ui CartUI
        tf 02 cmd AddItem
        tf 03 evt ItemAdded
        """
        let graph = try await DiagramEngine.parse(source)
        guard case let .eventModeling(diagram) = graph.payload else {
            Issue.record("Expected eventModeling payload")
            return
        }
        #expect(diagram.themeVariables.emCommandFill == "#abc123")
        #expect(diagram.themeVariables.emEventStroke == "#def456")
    }

    @Test func e2e_initDirectiveConfig() async throws {
        let source = """
        %%{init: { "config": { "eventmodeling": { "padding": 60 } } } }%%
        eventmodeling
        tf 01 ui CartUI
        tf 02 cmd AddItem
        """
        let graph = try await DiagramEngine.parse(source)
        guard case let .eventModeling(diagram) = graph.payload else {
            Issue.record("Expected eventModeling payload")
            return
        }
        #expect(diagram.config.padding == 60)
    }

    @Test func e2e_cgDoesNotThrow() async throws {
        let source = "eventmodeling\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded"
        let positioned = try await DiagramEngine.layout(source)
        let renderer = DiagramRenderer(theme: .default)
        let width = 800
        let height = 600
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            Issue.record("Could not create CGContext")
            return
        }
        renderer.render(positioned, in: ctx, bounds: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        let image = ctx.makeImage()
        #expect(image != nil)
    }
}

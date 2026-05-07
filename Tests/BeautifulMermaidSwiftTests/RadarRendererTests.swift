import Testing
import Foundation
import CoreGraphics
@testable import BeautifulMermaid

@Suite("Radar Renderer")
struct RadarRendererTests {

    @Test("DiagramRenderer.render handles radar type without crashing")
    func rendererHandlesRadar() throws {
        let source = "radar-beta\n  axis A,B,C\n  curve c1{1,2,3}"
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)

        let renderer = DiagramRenderer()
        let size = CGSize(width: CGFloat(positioned.width), height: CGFloat(positioned.height))
        let bounds = CGRect(origin: .zero, size: size)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            #expect(Bool(false), "Could not create CGContext")
            return
        }

        renderer.render(positioned, in: context, bounds: bounds)
        #expect(Bool(true))
    }

    @Test("DiagramRenderer handles radar with polygon graticule")
    func rendererHandlesPolygonGraticule() throws {
        let source = "radar-beta\n  axis A,B,C,D\n  curve c1{1,2,3,4}\n  graticule polygon"
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)

        let renderer = DiagramRenderer()
        let size = CGSize(width: CGFloat(positioned.width), height: CGFloat(positioned.height))
        let bounds = CGRect(origin: .zero, size: size)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            #expect(Bool(false), "Could not create CGContext")
            return
        }

        renderer.render(positioned, in: context, bounds: bounds)
        #expect(Bool(true))
    }

    @Test("DiagramRenderer handles radar with showLegend false")
    func rendererHandlesNoLegend() throws {
        let source = "radar-beta\n  axis A,B,C\n  curve c1{1,2,3}\n  showLegend false"
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)

        let renderer = DiagramRenderer()
        let size = CGSize(width: CGFloat(positioned.width), height: CGFloat(positioned.height))
        let bounds = CGRect(origin: .zero, size: size)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            #expect(Bool(false), "Could not create CGContext")
            return
        }

        renderer.render(positioned, in: context, bounds: bounds)
        #expect(Bool(true))
    }

    @Test("DiagramRenderer handles radar without curves")
    func rendererHandlesNoCurves() throws {
        let source = "radar-beta\n  axis A,B,C"
        let graph = try MermaidParser.parse(source)
        let positioned = try GraphLayout().layout(graph)

        let renderer = DiagramRenderer()
        let size = CGSize(width: CGFloat(positioned.width), height: CGFloat(positioned.height))
        let bounds = CGRect(origin: .zero, size: size)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            #expect(Bool(false), "Could not create CGContext")
            return
        }

        renderer.render(positioned, in: context, bounds: bounds)
        #expect(Bool(true))
    }

    @Test("DiagramRenderer handles radar with empty diagram")
    func rendererHandlesEmpty() throws {
        let diagram = MermaidGraph(type: .radar)
        let positioned = PositionedGraph(diagram: diagram)

        let renderer = DiagramRenderer()
        let size = CGSize(width: 700, height: 700)
        let bounds = CGRect(origin: .zero, size: size)

        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            #expect(Bool(false), "Could not create CGContext")
            return
        }

        renderer.render(positioned, in: context, bounds: bounds)
        #expect(Bool(true))
    }
}

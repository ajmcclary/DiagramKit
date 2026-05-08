import Testing
import Foundation
import CoreGraphics
import Dispatch
@testable import BeautifulMermaid

@Suite("Radar Renderer", .serialized)
struct RadarRendererTests {
    private enum RenderError: Error {
        case contextCreationFailed
        case missingWorkerResult
    }

    private final class RenderResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<Void, Error>?

        func set(_ result: Result<Void, Error>) {
            lock.lock()
            self.result = result
            lock.unlock()
        }

        func get() -> Result<Void, Error>? {
            lock.lock()
            defer { lock.unlock() }
            return result
        }
    }

    private func renderOnWorker(_ work: @escaping @Sendable () throws -> Void) throws {
        let resultBox = RenderResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        let thread = Thread {
            resultBox.set(Result { try work() })
            semaphore.signal()
        }
        thread.name = "BeautifulMermaid radar CG test worker"
        thread.stackSize = 8 * 1024 * 1024
        thread.start()
        semaphore.wait()

        guard let result = resultBox.get() else {
            throw RenderError.missingWorkerResult
        }
        try result.get()
    }

    private func render(source: String) throws {
        try renderOnWorker {
            let graph = try MermaidParser.parse(source)
            let positioned = try GraphLayout().layout(graph)
            try render(positioned: positioned)
        }
    }

    private func render(positioned: PositionedGraph, size overrideSize: CGSize? = nil) throws {
        let renderer = DiagramRenderer()
        let size = overrideSize ?? CGSize(
            width: CGFloat(max(1, positioned.width)),
            height: CGFloat(max(1, positioned.height))
        )
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
            throw RenderError.contextCreationFailed
        }

        renderer.render(positioned, in: context, bounds: bounds)
    }

    @Test("DiagramRenderer.render handles radar type without crashing")
    func rendererHandlesRadar() throws {
        try render(source: "radar-beta\n  axis A,B,C\n  curve c1{1,2,3}")
    }

    @Test("DiagramRenderer handles radar with polygon graticule")
    func rendererHandlesPolygonGraticule() throws {
        try render(source: "radar-beta\n  axis A,B,C,D\n  curve c1{1,2,3,4}\n  graticule polygon")
    }

    @Test("DiagramRenderer handles radar with showLegend false")
    func rendererHandlesNoLegend() throws {
        try render(source: "radar-beta\n  axis A,B,C\n  curve c1{1,2,3}\n  showLegend false")
    }

    @Test("DiagramRenderer handles radar without curves")
    func rendererHandlesNoCurves() throws {
        try render(source: "radar-beta\n  axis A,B,C")
    }

    @Test("DiagramRenderer handles radar with empty diagram")
    func rendererHandlesEmpty() throws {
        try renderOnWorker {
            let diagram = MermaidGraph(type: .radar)
            let positioned = PositionedGraph(diagram: diagram)
            try render(positioned: positioned, size: CGSize(width: 700, height: 700))
        }
    }
}

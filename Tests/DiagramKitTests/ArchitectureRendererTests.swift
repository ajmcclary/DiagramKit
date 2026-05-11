import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
import CoreGraphics

final class ArchitectureRendererTests: XCTestCase {

    func testCgRenderDoesNotCrash() throws {
        let source = "architecture-beta\n    service srv[Server]"
        let diagram = try parseArchitectureDiagram(source)
        let positioned = layoutArchitectureDiagram(diagram)
        let graph = MermaidGraph(payload: .architecture(diagram))
        let positionedGraph = PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .architecture(positioned))

        let width = max(Int(positioned.width), 1)
        let height = max(Int(positioned.height), 1)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create CGContext")
            return
        }

        let renderer = DiagramRenderer()
        renderer.render(positionedGraph, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func testCgRenderEdgeDiagram() throws {
        let source = "architecture-beta\n    service db[DB]\n    service srv[Server]\n    db:R --> L:srv"
        let diagram = try parseArchitectureDiagram(source)
        let positioned = layoutArchitectureDiagram(diagram)
        let graph = MermaidGraph(payload: .architecture(diagram))
        let positionedGraph = PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .architecture(positioned))

        let width = max(Int(positioned.width), 1)
        let height = max(Int(positioned.height), 1)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create CGContext")
            return
        }

        let renderer = DiagramRenderer()
        renderer.render(positionedGraph, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func testCgRenderWithGroups() throws {
        let source = "architecture-beta\n    group api(cloud)[API]\n    service db(database)[DB] in api\n    service srv(server)[Server] in api\n    db:R --> L:srv"
        let diagram = try parseArchitectureDiagram(source)
        let positioned = layoutArchitectureDiagram(diagram)
        let graph = MermaidGraph(payload: .architecture(diagram))
        let positionedGraph = PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .architecture(positioned))

        let width = max(Int(positioned.width), 1)
        let height = max(Int(positioned.height), 1)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create CGContext")
            return
        }

        let renderer = DiagramRenderer()
        renderer.render(positionedGraph, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func testCgRenderWithJunctions() throws {
        let source = "architecture-beta\n    service left[Left]\n    junction center\n    left:R --> L:center"
        let diagram = try parseArchitectureDiagram(source)
        let positioned = layoutArchitectureDiagram(diagram)
        let graph = MermaidGraph(payload: .architecture(diagram))
        let positionedGraph = PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .architecture(positioned))

        let width = max(Int(positioned.width), 1)
        let height = max(Int(positioned.height), 1)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create CGContext")
            return
        }

        let renderer = DiagramRenderer()
        renderer.render(positionedGraph, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func testCgRenderEmptyDiagram() throws {
        let diagram = ArchitectureDiagram.empty
        let positioned = layoutArchitectureDiagram(diagram)
        let graph = MermaidGraph(payload: .architecture(diagram))
        let positionedGraph = PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .architecture(positioned))

        let width = max(Int(positioned.width), 1)
        let height = max(Int(positioned.height), 1)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Could not create CGContext")
            return
        }

        let renderer = DiagramRenderer()
        renderer.render(positionedGraph, in: context, bounds: CGRect(x: 0, y: 0, width: width, height: height))
    }

    func testCgRenderPreservesPlacement() throws {
        let source = "architecture-beta\n    service db[DB]\n    service srv[Server]\n    db:R --> L:srv"
        let diagram = try parseArchitectureDiagram(source)
        let positioned = layoutArchitectureDiagram(diagram)

        XCTAssertEqual(positioned.services.count, 2)
        XCTAssertEqual(positioned.edges.count, 1)
        let edge = positioned.edges[0]
        XCTAssertNotEqual(edge.startX, edge.endX, "Edge should have non-zero length horizontally")
    }

    func testCgRenderUsesArchitectureThemeColorsAndKeepsArrowAtEndpoint() throws {
        var diagram = try parseArchitectureDiagram("""
        architecture-beta
            group api(cloud)[API]
            service db(database)[DB] in api
            service srv(server)[Server] in api
            db:R --> L:srv
        """)
        diagram.theme = ArchitectureThemeConfig(
            archEdgeColor: "#FF0000",
            archEdgeArrowColor: "#0000FF",
            archEdgeWidth: "8",
            archGroupBorderColor: "#00AA00",
            archGroupBorderWidth: "6px"
        )
        let (pixels, width, _) = try renderCgPixels(diagram)

        XCTAssertGreaterThan(Self.countPixels(in: pixels, matching: { $0.red > 220 && $0.green < 60 && $0.blue < 60 && $0.alpha > 220 }), 20)
        XCTAssertGreaterThan(Self.countPixels(in: pixels, matching: { $0.green > 120 && $0.red < 80 && $0.blue < 80 && $0.alpha > 220 }), 20)
        XCTAssertGreaterThan(Self.countPixels(in: pixels, matching: { $0.blue > 180 && $0.red < 80 && $0.green < 80 && $0.alpha > 220 }), 5)
        XCTAssertEqual(
            Self.countPixels(in: pixels, width: width, xRange: 0..<12, yRange: 0..<12) {
                $0.blue > 180 && $0.red < 80 && $0.green < 80 && $0.alpha > 220
            },
            0,
            "Arrowhead fill should stay near the edge endpoint, not include the canvas origin"
        )
    }

    func testCgRenderDrawsServiceIconInterior() throws {
        let diagram = try parseArchitectureDiagram("architecture-beta\n    service db(database)")
        let positioned = layoutArchitectureDiagram(diagram)
        let service = try XCTUnwrap(positioned.services.first)
        let graph = MermaidGraph(payload: .architecture(diagram))
        let positionedGraph = PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .architecture(positioned))
        let width = max(Int(positioned.width), 1)
        let height = max(Int(positioned.height), 1)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        XCTAssertNotNil(context)
        DiagramRenderer(theme: DiagramTheme(background: BMColor.white, foreground: BMColor.black)).render(
            positionedGraph,
            in: context!,
            bounds: CGRect(x: 0, y: 0, width: width, height: height)
        )

        let inset = Int(positioned.config.iconSize * 0.25)
        let xRange = max(0, Int(service.x - positioned.config.iconSize / 2) + inset)..<min(width, Int(service.x + positioned.config.iconSize / 2) - inset)
        let yRange = max(0, Int(service.y - positioned.config.iconSize / 2) + inset)..<min(height, Int(service.y + positioned.config.iconSize / 2) - inset)
        let interiorDarkPixels = Self.countPixels(in: pixels, width: width, xRange: xRange, yRange: yRange) {
            $0.red < 80 && $0.green < 80 && $0.blue < 80 && $0.alpha > 220
        }
        XCTAssertGreaterThan(interiorDarkPixels, 10)
    }

    private func renderCgPixels(_ diagram: ArchitectureDiagram) throws -> ([UInt8], Int, Int) {
        let positioned = layoutArchitectureDiagram(diagram)
        let graph = MermaidGraph(payload: .architecture(diagram))
        let positionedGraph = PositionedGraph(diagram: graph, width: positioned.width, height: positioned.height, content: .architecture(positioned))
        let width = max(Int(positioned.width), 1)
        let height = max(Int(positioned.height), 1)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        let ctx = try XCTUnwrap(context)
        DiagramRenderer(theme: DiagramTheme(background: BMColor.white, foreground: BMColor.black)).render(
            positionedGraph,
            in: ctx,
            bounds: CGRect(x: 0, y: 0, width: width, height: height)
        )
        return (pixels, width, height)
    }

    private typealias Pixel = (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)

    private static func countPixels(in pixels: [UInt8], matching predicate: (Pixel) -> Bool) -> Int {
        var count = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            if predicate((pixels[index], pixels[index + 1], pixels[index + 2], pixels[index + 3])) {
                count += 1
            }
        }
        return count
    }

    private static func countPixels(
        in pixels: [UInt8],
        width: Int,
        xRange: Range<Int>,
        yRange: Range<Int>,
        matching predicate: (Pixel) -> Bool
    ) -> Int {
        var count = 0
        for y in yRange {
            for x in xRange {
                let index = ((y * width) + x) * 4
                if predicate((pixels[index], pixels[index + 1], pixels[index + 2], pixels[index + 3])) {
                    count += 1
                }
            }
        }
        return count
    }
}

final class ArchitectureSvgRendererTests: XCTestCase {

    private func renderSvg(_ source: String, diagramId: String = "test-id") throws -> String {
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var d: ArchitectureDiagram
        if rawLines.first?.lowercased().hasPrefix("architecture-beta") ?? false {
            d = try parseArchitectureDiagram(rawLines, frontmatter: nil)
        } else {
            let (stripped, fm) = _parseFrontMatterAndStripped(source)
            let fmLines = stripped.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            d = try parseArchitectureDiagram(fmLines, frontmatter: fm)
        }
        let p = layoutArchitectureDiagram(d)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        return try renderArchitectureSvg(p, diagramId: diagramId, colors, "Inter", false)
    }

    func testSvgWrapper() throws {
        let svg = try renderSvg("architecture-beta\n    service srv")
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("viewBox"))
    }

    func testServiceSvgId() throws {
        let svg = try renderSvg("architecture-beta\n    service mySrv")
        XCTAssertTrue(svg.contains("id=\"test-id-service-mySrv\""))
        XCTAssertTrue(svg.contains("id=\"test-id-node-mySrv\""))
        XCTAssertTrue(svg.contains("architecture-service"))
    }

    func testGroupSvgId() throws {
        let svg = try renderSvg("architecture-beta\n    group api(cloud)[API]\n    service db(database)[DB] in api")
        XCTAssertTrue(svg.contains("test-id-group-api"))
        XCTAssertTrue(svg.contains("architecture-groups"))
        XCTAssertTrue(svg.contains("node-bkg"))
    }

    func testEdgeSvgPath() throws {
        let svg = try renderSvg("architecture-beta\n    service db[DB]\n    service srv[Server]\n    db:R --> L:srv")
        XCTAssertTrue(svg.contains("architecture-edges"))
        XCTAssertTrue(svg.contains("class=\"edge\""))
        XCTAssertTrue(svg.contains("M "))
    }

    func testArrowPolygons() throws {
        let svg = try renderSvg("architecture-beta\n    service db[DB]\n    service srv[Server]\n    db:R --> L:srv")
        XCTAssertTrue(svg.contains("arrow"))
    }

    func testDashedGroupBorders() throws {
        let svg = try renderSvg("architecture-beta\n    group api(cloud)[API]\n    service db[DB] in api")
        XCTAssertTrue(svg.contains("stroke-dasharray: 8"))
    }

    func testAccessibilityMetadata() throws {
        let svg = try renderSvg("architecture-beta\n    accTitle: Test\n    accDescr: Description\n    service srv")
        XCTAssertTrue(svg.contains("<title>Test</title>"))
        XCTAssertTrue(svg.contains("<desc>Description</desc>"))
    }

    func testDiagramTitleRendersVisiblyInSvg() throws {
        let svg = try renderSvg("architecture-beta title Simple Architecture\n    service srv[Service]")
        XCTAssertTrue(svg.contains("arch-diagram-title"))
        XCTAssertTrue(svg.contains(">Simple Architecture</text>"))
    }

    func testJunctionHitBox() throws {
        let svg = try renderSvg("architecture-beta\n    junction j1\n    service srv[Server]")
        XCTAssertTrue(svg.contains("architecture-junction"))
        XCTAssertTrue(svg.contains("fill-opacity=\"0\""))
    }

    func testServiceLabel() throws {
        let svg = try renderSvg("architecture-beta\n    service db(database)[Database]")
        XCTAssertTrue(svg.contains("arch-service-label"))
    }

    func testGroupLabel() throws {
        let svg = try renderSvg("architecture-beta\n    group api(cloud)[API]\n    service db[DB] in api")
        XCTAssertTrue(svg.contains("arch-group-label"))
    }

    func testEdgeLabel() throws {
        let svg = try renderSvg("architecture-beta\n    service db[DB]\n    service srv[Server]\n    db:R -[HTTPS]- L:srv")
        XCTAssertTrue(svg.contains("HTTPS"))
        XCTAssertTrue(svg.contains("arch-edge-label"))
    }

    func testUseMaxWidth() throws {
        let source = """
        ---
        config:
          architecture:
            useMaxWidth: true
        ---
        architecture-beta
            service srv
        """
        let svg = try renderSvg(source)
        XCTAssertTrue(svg.contains("max-width:"))
    }

    func testThemeEdgeColor() throws {
        let source = """
        ---
        config:
          themeVariables:
            archEdgeColor: "#FF0000"
        ---
        architecture-beta
            service db[DB]
            service srv[Server]
            db:R --> L:srv
        """
        let (stripped, fm) = _parseFrontMatterAndStripped(source)
        let rawLines = stripped.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var d = try parseArchitectureDiagram(rawLines, frontmatter: fm)
        if let fmc = fm?.archConfig { d.config = fmc }
        if let fmt = fm?.archTheme { d.theme = fmt }
        let p = layoutArchitectureDiagram(d)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderArchitectureSvg(p, diagramId: "test-id", colors, "Inter", false)
        XCTAssertTrue(svg.contains("stroke: #FF0000"))
    }

    func testThemeGroupBorder() throws {
        let source = """
        ---
        config:
          themeVariables:
            archGroupBorderColor: "#00FF00"
        ---
        architecture-beta
            group api(cloud)[API]
            service db[DB] in api
        """
        let (stripped, fm) = _parseFrontMatterAndStripped(source)
        let rawLines = stripped.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var d = try parseArchitectureDiagram(rawLines, frontmatter: fm)
        if let fmc = fm?.archConfig { d.config = fmc }
        if let fmt = fm?.archTheme { d.theme = fmt }
        let p = layoutArchitectureDiagram(d)
        let colors = DiagramColors(bg: "#FFF", fg: "#000")
        let svg = try renderArchitectureSvg(p, diagramId: "test-id", colors, "Inter", false)
        XCTAssertTrue(svg.contains("stroke: #00FF00"))
    }

    func testEmptyDiagramSvg() throws {
        let svg = try renderSvg("architecture-beta")
        XCTAssertTrue(svg.contains("<svg"))
        XCTAssertTrue(svg.contains("</svg>"))
    }

    func testMultiDiagramIdUniqueness() throws {
        let svg1 = try renderSvg("architecture-beta\n    service a", diagramId: "id1")
        let svg2 = try renderSvg("architecture-beta\n    service b", diagramId: "id2")
        XCTAssertTrue(svg1.contains("id1"))
        XCTAssertTrue(svg2.contains("id2"))
    }

    func testPipelineArchitectureIdsAreStable() throws {
        let source = "architecture-beta\n    service a"
        let svg1 = try _renderMermaidSVG(source, RenderOptions(idPolicy: .stable))
        let svg2 = try _renderMermaidSVG(source, RenderOptions(idPolicy: .stable))
        XCTAssertEqual(svg1, svg2)
        XCTAssertTrue(svg1.contains("id=\""))
    }

    func testConfigApplied() throws {
        let source = """
        ---
        config:
          architecture:
            padding: 20
            iconSize: 60
        ---
        architecture-beta
            service srv[Server]
        """
        let (stripped, fm) = _parseFrontMatterAndStripped(source)
        let rawLines = stripped.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var d = try parseArchitectureDiagram(rawLines, frontmatter: fm)
        if let fmc = fm?.archConfig { d.config = fmc }
        if let fmt = fm?.archTheme { d.theme = fmt }
        XCTAssertEqual(d.config.padding, 20)
        XCTAssertEqual(d.config.iconSize, 60)
    }

    func testDefaultThemeUsesLineColorForArchitectureEdges() throws {
        let source = "architecture-beta\n    service db[DB]\n    service srv[Server]\n    db:R --> L:srv"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let d = try parseArchitectureDiagram(rawLines, frontmatter: nil)
        let p = layoutArchitectureDiagram(d)
        let svg = try renderArchitectureSvg(
            p,
            diagramId: "test-id",
            DiagramColors(bg: "#FFF", fg: "#000", line: "#123456"),
            "Inter",
            false
        )
        XCTAssertTrue(svg.contains("stroke: #123456"))
        XCTAssertTrue(svg.contains("fill: #123456"))
    }

    func testGroupIconRendersInSvg() throws {
        let svg = try renderSvg("architecture-beta\n    group api(cloud)[API]\n    service db[DB] in api")
        XCTAssertTrue(svg.contains("arch-group-icon"))
        XCTAssertTrue(svg.contains("<path"))
    }

    func testDirectionArrowPolygonL() throws {
        let svg = try renderSvg("architecture-beta\n    service a[A]\n    service b[B]\n    a:R <-- L:b")
        XCTAssertTrue(svg.contains("arrow"))
        XCTAssertTrue(svg.contains("polygon"))
    }

    func testDirectionArrowPolygonT() throws {
        let svg = try renderSvg("architecture-beta\n    service top[A]\n    service bot[B]\n    top:T <-- B:bot")
        XCTAssertTrue(svg.contains("arrow"))
    }

    func testXYEdgeLabelRotated() throws {
        let svg = try renderSvg("architecture-beta\n    service a[A]\n    service b[B]\n    a:T -[Data]- B:b")
        XCTAssertTrue(svg.contains("Data"))
        XCTAssertTrue(svg.contains("rotate"))
    }

    func testIconTextSanitized() throws {
        let svg = try renderSvg("architecture-beta\n    service srv(\"<b>bold</b>\")")
        XCTAssertFalse(svg.contains("<b>"))
        XCTAssertTrue(svg.contains("&lt;b&gt;"))
    }

    func testExternalIconRegistered() throws {
        ArchitectureIconRegistry.shared.register(pack: ArchitectureIconPack(
            prefix: "custom",
            icons: ["aws-s3": ArchitectureIconEntry(body: "<circle cx=\"40\" cy=\"40\" r=\"30\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/>")]
        ))
        let svg = try renderSvg("architecture-beta\n    service s3(custom:aws-s3)[Store]")
        XCTAssertTrue(svg.contains("circle"))
    }

    func testKnownExternalS3IconRendersWithoutRegistration() throws {
        let svg = ArchitectureIconRegistry().iconSVG(for: "logos:aws-s3")
        XCTAssertTrue(svg?.contains("architecture-icon-aws-s3") ?? false)
        XCTAssertFalse(svg?.contains("M24 4C13") ?? false, "Known bundled external icon should not fall back to the unknown icon")
    }

    func testExternalIconFallsBackToUnknown() throws {
        let svg = try renderSvg("architecture-beta\n    service x(nonexistent:icon)")
        XCTAssertTrue(svg.contains("M24 4C13"), "Should render unknown icon path for unrecognized icon")
    }

    func testJunctionEdgeEndpointShift() throws {
        let svg = try renderSvg("architecture-beta\n    junction j1\n    service a[A]\n    a:R --> L:j1")
        XCTAssertTrue(svg.contains("architecture-junction"))
        XCTAssertTrue(svg.contains("edge"))
    }

    func testVerticalEdgeLabelRotated() throws {
        let svg = try renderSvg("architecture-beta\n    service top[A]\n    service bot[B]\n    top:T -[Pipe]- B:bot")
        XCTAssertTrue(svg.contains("Pipe"))
        XCTAssertTrue(svg.contains("rotate(-90"))
    }
}

final class ArchitectureIconRegistryTests: XCTestCase {

    func testRegisterPack() {
        let registry = ArchitectureIconRegistry.shared
        let pack = ArchitectureIconPack(prefix: "test", icons: ["icon1": ArchitectureIconEntry(body: "<rect/>")])
        registry.register(pack: pack)
        XCTAssertTrue(registry.isAvailable("test:icon1"))
    }

    func testLookupByPrefix() {
        ArchitectureIconRegistry.shared.register(pack: ArchitectureIconPack(
            prefix: "custom",
            icons: ["aws-s3": ArchitectureIconEntry(body: "<circle cx=\"40\" cy=\"40\" r=\"30\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/>")]
        ))
        let svg = ArchitectureIconRegistry.shared.iconSVG(for: "custom:aws-s3")
        XCTAssertNotNil(svg)
    }

    func testFallbackPrefix() {
        XCTAssertTrue(ArchitectureIconRegistry.shared.hasBuiltInIcon("server"))
        XCTAssertTrue(ArchitectureIconRegistry.shared.hasBuiltInIcon("database"))
    }

    func testSanitizeIconText() {
        let sanitized = _sanitizeIconText("<script>alert(1)</script>")
        XCTAssertNotNil(sanitized)
        XCTAssertFalse(sanitized?.contains("<script>") ?? false)
        XCTAssertTrue(sanitized?.contains("&lt;script&gt;") ?? false)
    }

    func testRejectMaliciousSvg() {
        ArchitectureIconRegistry.shared.register(pack: ArchitectureIconPack(
            prefix: "evil",
            icons: ["icon": ArchitectureIconEntry(body: "<script>alert(1)</script>")]
        ))
        let svg = ArchitectureIconRegistry.shared.iconSVG(for: "evil:icon")
        XCTAssertNil(svg, "Malicious SVG should be rejected")
    }
}

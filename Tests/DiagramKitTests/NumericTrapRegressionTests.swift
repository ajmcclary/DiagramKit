import Foundation
import Testing
import DiagramKit
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

// Numbers from diagram text, frontmatter and host configuration must not
// reach `Int(Double)`, a range, or an allocation unclamped.

@Suite("Numeric traps in layout, render and export")
struct NumericTrapRegressionTests {

    @Test("integer text for any double", arguments: [
        (0.0, "0"), (42.0, "42"), (-7.0, "-7"), (1e20, "100000000000000000000"),
        (-1e20, "-100000000000000000000"), (Double.infinity, "0"), (Double.nan, "0"),
    ])
    func integralText(value: Double, text: String) {
        #expect(_integralText(value) == text)
    }

    @Test("a huge sankey value renders and exports", arguments: ["99999999999999999999", "1e300"])
    func hugeSankeyValue(_ value: String) async throws {
        let source = "sankey-beta\nA,B,\(value)\nB,C,1\n"
        try await onDiagramWorker {
            _ = try DiagramPipeline.renderSVG(source: source)
            _ = try DiagramPipeline.renderASCII(source: source)
            _ = try DiagramExportLoader.export(DiagramPipeline.parse(source), to: .mermaid, registry: DiagramPipeline.defaultExportRegistry)
        }
    }

    @Test("a huge autonumber start exports")
    func hugeAutonumber() async throws {
        let source = "sequenceDiagram\n  autonumber 99999999999999999999\n  A->>B: hi\n"
        let exported = try await onDiagramWorker {
            try DiagramExportLoader.export(DiagramPipeline.parse(source), to: .mermaid, registry: DiagramPipeline.defaultExportRegistry).source
        }
        #expect(exported.contains("autonumber 1"))
    }

    @Test("radar tick counts out of range are clamped in layout", arguments: [-1, 0, 100_000_000])
    func radarTicks(_ ticks: Int) throws {
        var diagram = try #require({ () -> RadarDiagram? in
            if case .radar(let model) = try DiagramPipeline.parse("radar-beta\n  axis A,B,C\n  curve c{1,2,3}\n").payload { return model }
            return nil
        }())
        diagram.options.ticks = ticks
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.graticules.count <= 100)
    }

    @Test("a negative C4 recovery-marker index is ignored", arguments: [DiagramFormatID.d2])
    func negativeC4MarkerIndex(format: DiagramFormatID) throws {
        let source = "# diagramkit:family=c4\n# diagramkit:c4-technology=-1,SMTP\na: \"A\"\nb: \"B\"\na -> b: \"uses\"\n"
        _ = try DiagramPipeline.parse(source, as: format)
    }

    @Test("render-config spacing values are clamped", arguments: [1e19, -1e19, Double.nan, Double.infinity, 99999999999999999999.0])
    func layoutConfigClamped(_ value: Double) async throws {
        let config = LayoutConfig(padding: value, nodeSpacing: value, layerSpacing: value, componentSpacing: value)
        let svg = try await onDiagramWorker {
            try DiagramPipeline.renderSVG(source: "flowchart TD\n  A --> B\n  C --> D\n", layoutConfig: config)
        }
        #expect(svg.hasPrefix("<svg"))
    }

    @Test("the xychart grid gap is finite and at least 2 points", arguments: [
        (0.0, 300.0), (1e-12, 300.0), (1e300, 300.0), (Double.nan, 300.0), (40.0, 0.0), (40.0, Double.infinity),
    ])
    func xyChartGridGap(base: Double, extent: Double) {
        let gap = _xyChartGridGap(base: base, extent: extent)
        #expect(gap.isFinite && gap >= 2)
    }
}

import XCTest
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
import Foundation

final class VerificationStepExporterTests: XCTestCase {
    struct TestDiagram: Codable {
        let id: String
        let category: String
        let name: String
        let source: String
        let options: [String: Bool]?
    }

    struct TestDiagrams: Codable {
        let diagrams: [TestDiagram]
    }

    func testExportVerificationSteps() async throws {
        try requireMermaidExporterTestsEnabled()

        let env = ProcessInfo.processInfo.environment
        let inputDir = env["VERIFICATION_INPUT_DIR"] ?? defaultVerificationPath(component: "shared")
        let outputDir = env["VERIFICATION_OUTPUT_DIR"] ?? defaultVerificationPath(component: "output/swift")

        let diagramsPath = (inputDir as NSString).appendingPathComponent("test-diagrams.json")
        try requireFixtureExists(atPath: diagramsPath)

        let data = try Data(contentsOf: URL(fileURLWithPath: diagramsPath))
        let testDiagrams = try JSONDecoder().decode(TestDiagrams.self, from: data)
        let diagramFilter = env["VERIFICATION_DIAGRAM_FILTER"]
        let categoryFilter = env["VERIFICATION_CATEGORY_FILTER"]

        let filtered = testDiagrams.diagrams.filter { diagram in
            if let diagramFilter, !diagram.id.contains(diagramFilter) { return false }
            if let categoryFilter, diagram.category != categoryFilter { return false }
            return true
        }

        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        var success = 0
        var failed = 0
        for diagram in filtered {
            let outPath = (outputDir as NSString).appendingPathComponent("\(diagram.id).json")
            do {
                let steps = try await exportSteps(diagram: diagram)
                let payload = try JSONSerialization.data(withJSONObject: steps, options: [.prettyPrinted, .sortedKeys])
                try payload.write(to: URL(fileURLWithPath: outPath))
                success += 1
            } catch {
                failed += 1
                let errorSteps: [[String: Any]] = [[
                    "diagramId": diagram.id,
                    "step": "error",
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "data": ["message": String(describing: error)],
                ]]
                if let payload = try? JSONSerialization.data(withJSONObject: errorSteps, options: [.prettyPrinted, .sortedKeys]) {
                    try? payload.write(to: URL(fileURLWithPath: outPath))
                }
                fputs("Verification export failed (\(diagram.id)): \(error)\n", stderr)
            }
        }

        let summary: [String: Any] = [
            "totalDiagrams": filtered.count,
            "successful": success,
            "failed": failed,
        ]
        let summaryData = try JSONSerialization.data(withJSONObject: summary, options: .prettyPrinted)
        let summaryPath = (outputDir as NSString).appendingPathComponent("_summary.json")
        try summaryData.write(to: URL(fileURLWithPath: summaryPath))
    }

    private func exportSteps(diagram: TestDiagram) async throws -> [[String: Any]] {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let lines = preprocessLines(diagram.source)

        switch diagram.category {
        case "sequence":
            let (parsed, _) = try parseSequenceDiagram(lines)
            let positioned = try layoutSequenceDiagram(parsed, RenderOptions())
            return [
                ["diagramId": diagram.id, "step": "1-parsed", "timestamp": timestamp, "data": serializeSequenceParsed(parsed)],
                ["diagramId": diagram.id, "step": "3-final", "timestamp": timestamp, "data": serializeSequencePositioned(positioned)],
            ]

        case "class":
            let (parsed, _) = try parseClassDiagram(lines)
            let positioned = try layoutClassDiagramSync(parsed, options: RenderOptions())
            let posData = serializeClassPositionedDetailed(positioned)
            let classes = (posData["classes"] as? [[String: Any]] ?? [])
                .sorted { ($0["id"] as! String) < ($1["id"] as! String) }
            return [
                ["diagramId": diagram.id, "step": "1-parsed", "timestamp": timestamp, "data": serializeClassParsed(parsed)],
                ["diagramId": diagram.id, "step": "2-positioned", "timestamp": timestamp, "data": posData],
                ["diagramId": diagram.id, "step": "2.1-class-boxes", "timestamp": timestamp, "data": ["classes": classes]],
                ["diagramId": diagram.id, "step": "2.2-class-relationships", "timestamp": timestamp, "data": ["relationships": posData["relationships"] as? [[String: Any]] ?? []]],
            ]

        case "er":
            let (parsed, _) = try parseErDiagram(lines)
            let positioned = try layoutErDiagramSync(parsed, options: RenderOptions())
            return [
                ["diagramId": diagram.id, "step": "1-parsed", "timestamp": timestamp, "data": serializeErParsed(parsed)],
                ["diagramId": diagram.id, "step": "3-final", "timestamp": timestamp, "data": serializeErPositioned(positioned)],
            ]

        case "xychart":
            let (parsed, _) = try parseXYChart(lines)
            let positioned = layoutXYChart(parsed)
            return [
                ["diagramId": diagram.id, "step": "1-parsed", "timestamp": timestamp, "data": serializeXYChartParsed(parsed)],
                ["diagramId": diagram.id, "step": "3-final", "timestamp": timestamp, "data": serializeXYChartPositioned(positioned)],
            ]

        default:
            let parsed = try parseMermaid(diagram.source)
            let svg = try await renderDiagramSVG(diagram.source, RenderOptions())
            let size = extractSvgSize(svg)
            return [
                ["diagramId": diagram.id, "step": "1-parsed", "timestamp": timestamp, "data": ["type": parsed.type.rawValue]],
                ["diagramId": diagram.id, "step": "3-final", "timestamp": timestamp, "data": [
                    "graphWidth": size.width,
                    "graphHeight": size.height,
                    "nodes": [],
                    "edges": [],
                ]],
            ]
        }
    }

    private func preprocessLines(_ source: String) -> [String] {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
    }

    private func extractSvgSize(_ svg: String) -> (width: Double, height: Double) {
        let width = extractSvgAttr(svg, name: "width") ?? 0
        let height = extractSvgAttr(svg, name: "height") ?? 0
        return (width: width, height: height)
    }

    private func extractSvgAttr(_ svg: String, name: String) -> Double? {
        let pattern = "<svg[^>]*\\b\(name)=\\\"([^\\\"]+)\\\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = svg as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: svg, range: range), match.numberOfRanges > 1 else { return nil }
        let raw = ns.substring(with: match.range(at: 1))
        return Double(raw)
    }

    private func serializeSequenceParsed(_ diagram: SequenceDiagram) -> [String: Any] {
        [
            "actors": diagram.actors.map { ["id": $0.id, "label": $0.label, "type": $0.type] },
            "messages": diagram.messages.map {
                [
                    "from": $0.from, "to": $0.to, "label": $0.label,
                    "lineStyle": $0.lineStyle, "arrowHead": $0.arrowHead,
                    "activate": $0.activate, "deactivate": $0.deactivate,
                ] as [String: Any]
            },
            "blocks": diagram.blocks.map {
                [
                    "type": $0.type, "label": $0.label, "startIndex": $0.startIndex, "endIndex": $0.endIndex,
                    "dividers": $0.dividers.map { ["index": $0.index, "label": $0.label] },
                ] as [String: Any]
            },
            "notes": diagram.notes.map {
                [
                    "actorIds": $0.actorIds, "text": $0.text, "position": $0.position, "afterIndex": $0.afterIndex,
                ] as [String: Any]
            },
        ]
    }

    private func serializeSequencePositioned(_ diagram: PositionedSequenceDiagram) -> [String: Any] {
        [
            "graphWidth": diagram.width,
            "graphHeight": diagram.height,
            "actors": diagram.actors.map {
                [
                    "id": $0.id, "x": $0.x, "y": $0.y, "width": $0.width, "height": $0.height,
                ] as [String: Any]
            },
            "messages": diagram.messages.map {
                [
                    "from": $0.from, "to": $0.to, "x1": $0.x1, "x2": $0.x2, "y": $0.y, "isSelf": $0.isSelf,
                ] as [String: Any]
            },
            "notes": diagram.notes.map {
                [
                    "text": $0.text, "x": $0.x, "y": $0.y, "width": $0.width, "height": $0.height,
                ] as [String: Any]
            },
        ]
    }

    private func serializeClassParsed(_ diagram: ClassDiagram) -> [String: Any] {
        let relTypeStr: (ClassRelationEndpoint) -> String = { rel in
            let t = rel.type1 != ClassRelationType.none.rawValue ? rel.type1 : rel.type2
            switch t {
            case ClassRelationType.inheritance.rawValue: return "inheritance"
            case ClassRelationType.composition.rawValue: return "composition"
            case ClassRelationType.aggregation.rawValue: return "aggregation"
            case ClassRelationType.dependency.rawValue: return "association"
            case ClassRelationType.lollipop.rawValue: return "lollipop"
            default: return "association"
            }
        }
        let markerAtStr: (ClassRelationEndpoint) -> String = { rel in
            rel.type1 != ClassRelationType.none.rawValue ? "from" : "to"
        }
        return [
            "classes": diagram.classes.map { ["id": $0.id, "label": $0.label] },
            "relationships": diagram.relationships.map {
                [
                    "from": $0.id1, "to": $0.id2, "type": relTypeStr($0.relation), "markerAt": markerAtStr($0.relation), "label": $0.title as Any,
                ] as [String: Any]
            },
        ]
    }

    private func serializeClassPositioned(_ diagram: PositionedClassDiagram) -> [String: Any] {
        let relTypeStr: (ClassRelationEndpoint) -> String = { rel in
            let t = rel.type1 != ClassRelationType.none.rawValue ? rel.type1 : rel.type2
            switch t {
            case ClassRelationType.inheritance.rawValue: return "inheritance"
            case ClassRelationType.composition.rawValue: return "composition"
            case ClassRelationType.aggregation.rawValue: return "aggregation"
            case ClassRelationType.dependency.rawValue: return "association"
            case ClassRelationType.lollipop.rawValue: return "lollipop"
            default: return "association"
            }
        }
        return [
            "graphWidth": diagram.width,
            "graphHeight": diagram.height,
            "classes": diagram.classes.map {
                [
                    "id": $0.id, "x": $0.x, "y": $0.y, "width": $0.width, "height": $0.height,
                ] as [String: Any]
            },
            "relationships": diagram.relationships.map {
                [
                    "from": $0.from, "to": $0.to, "type": relTypeStr($0.relation),
                    "points": $0.points.map { ["x": $0.x, "y": $0.y] },
                ] as [String: Any]
            },
        ]
    }

    /// Detailed serialization matching the OSS repo's format for comparison.
    /// Includes headerHeight, attrHeight, methodHeight, label positions, etc.
    private func serializeClassPositionedDetailed(_ diagram: PositionedClassDiagram) -> [String: Any] {
        let relTypeStr: (ClassRelationEndpoint) -> String = { rel in
            let t = rel.type1 != ClassRelationType.none.rawValue ? rel.type1 : rel.type2
            switch t {
            case ClassRelationType.inheritance.rawValue: return "inheritance"
            case ClassRelationType.composition.rawValue: return "composition"
            case ClassRelationType.aggregation.rawValue: return "aggregation"
            case ClassRelationType.dependency.rawValue: return "association"
            case ClassRelationType.lollipop.rawValue: return "lollipop"
            default: return "association"
            }
        }
        let markerAtStr: (ClassRelationEndpoint) -> String = { rel in
            rel.type1 != ClassRelationType.none.rawValue ? "from" : "to"
        }
        return [
            "width": diagram.width,
            "height": diagram.height,
            "classes": diagram.classes.map { cls -> [String: Any] in
                var dict: [String: Any] = [
                    "id": cls.id,
                    "label": cls.label,
                    "x": cls.x,
                    "y": cls.y,
                    "width": cls.width,
                    "height": cls.height,
                    "headerHeight": cls.headerHeight,
                    "attrHeight": cls.attrHeight,
                    "methodHeight": cls.methodHeight,
                ]
                if let annotation = cls.annotations.first {
                    dict["annotation"] = annotation
                }
                return dict
            },
            "relationships": diagram.relationships.map { rel -> [String: Any] in
                var dict: [String: Any] = [
                    "from": rel.from,
                    "to": rel.to,
                    "type": relTypeStr(rel.relation),
                    "markerAt": markerAtStr(rel.relation),
                    "points": rel.points.map { ["x": $0.x, "y": $0.y] },
                ]
                if let label = rel.title {
                    dict["label"] = label
                }
                if let lp = rel.labelPosition {
                    dict["labelPosition"] = ["x": lp.x, "y": lp.y]
                }
                return dict
            },
        ]
    }

    private func serializeErParsed(_ diagram: ErDiagram) -> [String: Any] {
        [
            "entities": diagram.entities.map { ["id": $0.id, "label": $0.label] },
            "relationships": diagram.relationships.map {
                [
                    "entity1": $0.entity1, "entity2": $0.entity2,
                    "cardinality1": $0.cardinality1, "cardinality2": $0.cardinality2,
                    "label": $0.label, "identifying": $0.identifying,
                ] as [String: Any]
            },
        ]
    }

    private func serializeErPositioned(_ diagram: PositionedErDiagram) -> [String: Any] {
        [
            "graphWidth": diagram.width,
            "graphHeight": diagram.height,
            "entities": diagram.entities.map {
                [
                    "id": $0.id, "x": $0.x, "y": $0.y, "width": $0.width, "height": $0.height,
                ] as [String: Any]
            },
            "relationships": diagram.relationships.map {
                [
                    "entity1": $0.entity1, "entity2": $0.entity2,
                    "points": $0.points.map { ["x": $0.x, "y": $0.y] },
                ] as [String: Any]
            },
        ]
    }

    private func serializeXYChartParsed(_ chart: XYChart) -> [String: Any] {
        var data: [String: Any] = [
            "horizontal": chart.horizontal,
            "series": chart.series.map {
                var s: [String: Any] = ["type": $0.type.rawValue, "data": $0.data]
                if !$0.title.text.isEmpty { s["title"] = $0.title.text }
                return s
            },
        ]
        if let title = chart.title { data["title"] = title }
        if let t = chart.titleText { data["titleKind"] = t.kind.rawValue }
        if let cats = chart.xAxis.categories { data["xCategories"] = cats }
        if let t = chart.xAxis.title { data["xTitle"] = t }
        if let t = chart.yAxis.title { data["yTitle"] = t }
        if let acc = chart.accTitle { data["accTitle"] = acc }
        if let acc = chart.accDescr { data["accDescr"] = acc }
        if let dt = chart.diagramTitle { data["diagramTitle"] = dt }
        data["xAxisKind"] = chart.xAxis.kind.rawValue
        data["yAxisKind"] = chart.yAxis.kind.rawValue
        return data
    }

    private func serializeXYChartPositioned(_ chart: PositionedXYChart) -> [String: Any] {
        var data: [String: Any] = [
            "graphWidth": chart.width,
            "graphHeight": chart.height,
            "bars": chart.bars.map {
                var b: [String: Any] = ["x": $0.x, "y": $0.y, "width": $0.width, "height": $0.height, "value": $0.value, "colorIndex": $0.colorIndex]
                if let dl = $0.dataLabel {
                    b["dataLabel"] = ["text": dl.text, "x": dl.x, "y": dl.y, "anchor": dl.textAnchor, "fontSize": dl.fontSize]
                }
                return b
            },
            "lines": chart.lines.map {
                ["points": $0.points.map { ["x": $0.x, "y": $0.y, "value": $0.value] as [String: Any] }, "colorIndex": $0.colorIndex] as [String: Any]
            },
        ]
        if let title = chart.title {
            data["title"] = ["text": title.text, "x": title.x, "y": title.y] as [String: Any]
        }
        if let acc = chart.accTitle { data["accTitle"] = acc }
        if let acc = chart.accDescr { data["accDescr"] = acc }
        if let dt = chart.diagramTitle { data["diagramTitle"] = dt }
        data["configWidth"] = chart.config.width
        data["configHeight"] = chart.config.height
        data["showDataLabel"] = chart.config.showDataLabel
        return data
    }

    private func defaultVerificationPath(component: String) -> String {
        let cwd = FileManager.default.currentDirectoryPath
        let root = (cwd as NSString).deletingLastPathComponent
        return (root as NSString).appendingPathComponent("verification/\(component)")
    }
}

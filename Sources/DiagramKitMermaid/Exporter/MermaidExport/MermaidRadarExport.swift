import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `radar-beta` source from a `RadarDiagram`.
///
/// Lossless: header → title → accessibility metadata → comma-joined
/// `axis` list → `curve <name>{<comma-joined entries>}` lines →
/// per-option lines (`showLegend`, `ticks`, `max`, `min`,
/// `graticule`) emitted only when they differ from defaults.
enum MermaidRadarExport {

    static func emit(_ model: RadarDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["radar-beta"]
        let diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("  title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("  accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("  accDescr: \(singleLine(accDescr))")
        }

        if !model.axes.isEmpty {
            let joined = model.axes.map { axis -> String in
                if axis.label.isEmpty || axis.label == axis.name {
                    return axis.name
                }
                return "\(axis.name)[\"\(escape(axis.label))\"]"
            }.joined(separator: ",")
            lines.append("  axis \(joined)")
        }

        for curve in model.curves {
            let entries = curve.entries.map { formatNumber($0) }.joined(separator: ",")
            let lhs: String
            if curve.label.isEmpty || curve.label == curve.name {
                lhs = curve.name
            } else {
                lhs = "\(curve.name)[\"\(escape(curve.label))\"]"
            }
            lines.append("  curve \(lhs){\(entries)}")
        }

        let defaults = RadarOptions()
        if model.options.showLegend != defaults.showLegend {
            lines.append("  showLegend \(model.options.showLegend)")
        }
        if model.options.ticks != defaults.ticks {
            lines.append("  ticks \(model.options.ticks)")
        }
        if model.options.min != defaults.min {
            lines.append("  min \(formatNumber(model.options.min))")
        }
        if let m = model.options.max, m != defaults.max {
            lines.append("  max \(formatNumber(m))")
        }
        if model.options.graticule != defaults.graticule {
            lines.append("  graticule \(model.options.graticule.rawValue)")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func formatNumber(_ value: Double) -> String {
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }
}

import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `xychart-beta` source from an `XYChart`.
///
/// Lossless: header (with optional `horizontal`) → title →
/// accessibility metadata → `x-axis` definition → `y-axis` range →
/// `bar`/`line` series data arrays.
enum MermaidXYChartExport {

    static func emit(_ model: XYChart) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        var header = "xychart-beta"
        if model.horizontal {
            header += " horizontal"
        }
        lines.append(header)

        if let title = model.diagramTitle ?? model.title, !title.isEmpty {
            lines.append("    title \"\(escape(singleLine(title)))\"")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        // x-axis: either a title + bracketed category list, or just a
        // title. Skip entirely if neither field is populated.
        let xTitle = model.xAxis.title
        let xCats = model.xAxis.categories ?? []
        if xTitle != nil || !xCats.isEmpty {
            var line = "    x-axis"
            if let t = xTitle, !t.isEmpty {
                line += " \"\(escape(singleLine(t)))\""
            }
            if !xCats.isEmpty {
                let joined = xCats.map { cat -> String in
                    let s = singleLine(cat)
                    // Quote when the category contains characters that
                    // would otherwise split the bracketed list (spaces,
                    // commas, brackets) so re-parse preserves the
                    // original token boundaries.
                    if s.contains(" ") || s.contains(",") || s.contains("[") || s.contains("]") || s.contains("\"") {
                        return "\"\(escape(s))\""
                    }
                    return escape(s)
                }.joined(separator: ", ")
                line += " [\(joined)]"
            }
            lines.append(line)
        }

        // y-axis: title + optional range.
        let yTitle = model.yAxis.title
        let yRange = model.yAxis.range
        if yTitle != nil || yRange != nil {
            var line = "    y-axis"
            if let t = yTitle, !t.isEmpty {
                line += " \"\(escape(singleLine(t)))\""
            }
            if let r = yRange {
                line += " \(formatNumber(r.min)) --> \(formatNumber(r.max))"
            }
            lines.append(line)
        }

        for series in model.series {
            let keyword: String
            switch series.type {
            case .bar: keyword = "bar"
            case .line: keyword = "line"
            }
            let joined = series.data.map { formatNumber($0) }.joined(separator: ", ")
            lines.append("    \(keyword) [\(joined)]")
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

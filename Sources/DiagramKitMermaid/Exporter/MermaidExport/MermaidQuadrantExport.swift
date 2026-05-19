import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `quadrantChart` source from a `QuadrantChart`.
///
/// Lossless: header → title → accessibility metadata → x-axis labels
/// (`Left --> Right`) → y-axis labels (`Bottom --> Top`) → quadrant
/// labels (`quadrant-1` … `quadrant-4`) → classDef lines → point
/// lines `Name[:className]: [x, y]`.
enum MermaidQuadrantExport {

    static func emit(_ model: QuadrantChart) throws -> DiagramExportResult {
        var lines: [String] = ["quadrantChart"]
        let diagnostics: [DiagramDiagnostic] = []

        let title = model.diagramTitle ?? model.titleText
        if let title, !title.isEmpty {
            lines.append("    title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("    accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("    accDescr: \(singleLine(accDescr))")
        }

        if model.xAxisLeftText != nil || model.xAxisRightText != nil {
            let left = singleLine(model.xAxisLeftText ?? "")
            if let right = model.xAxisRightText, !right.isEmpty {
                lines.append("    x-axis \(left) --> \(singleLine(right))")
            } else {
                lines.append("    x-axis \(left)")
            }
        }
        if model.yAxisBottomText != nil || model.yAxisTopText != nil {
            let bot = singleLine(model.yAxisBottomText ?? "")
            if let top = model.yAxisTopText, !top.isEmpty {
                lines.append("    y-axis \(bot) --> \(singleLine(top))")
            } else {
                lines.append("    y-axis \(bot)")
            }
        }

        let quads: [(String, String?)] = [
            ("quadrant-1", model.quadrant1Text),
            ("quadrant-2", model.quadrant2Text),
            ("quadrant-3", model.quadrant3Text),
            ("quadrant-4", model.quadrant4Text),
        ]
        for (keyword, text) in quads {
            if let text, !text.isEmpty {
                lines.append("    \(keyword) \(singleLine(text))")
            }
        }

        for name in model.classes.keys.sorted() {
            guard let styles = model.classes[name] else { continue }
            let parts = cssDeclarations(styles)
            if !parts.isEmpty {
                lines.append("    classDef \(name) \(parts.joined(separator: ", "))")
            }
        }

        for point in model.points {
            let xy = "[\(formatCoord(point.x)), \(formatCoord(point.y))]"
            if let cls = point.className, !cls.isEmpty {
                lines.append("    \(singleLine(point.text)):::\(cls): \(xy)")
            } else {
                lines.append("    \(singleLine(point.text)): \(xy)")
            }
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func cssDeclarations(_ styles: QuadrantPointStyles) -> [String] {
        var parts: [String] = []
        if let c = styles.color { parts.append("color: \(c)") }
        if let r = styles.radius { parts.append("radius: \(r)") }
        if let sc = styles.strokeColor { parts.append("stroke-color: \(sc)") }
        if let sw = styles.strokeWidth { parts.append("stroke-width: \(sw)") }
        return parts
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func formatCoord(_ value: Double) -> String {
        let s = String(format: "%.4f", value)
        var trimmed = s
        while trimmed.contains(".") && (trimmed.hasSuffix("0") || trimmed.hasSuffix(".")) {
            let last = trimmed.removeLast()
            if last == "." { break }
        }
        return trimmed
    }
}

import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `sankey-beta` source from a `SankeyDiagram`.
///
/// CSV body with RFC 4180 quoting for fields containing `,`, `"`, or
/// newlines. Lossless for nodes, links, and link values; the
/// document-level title rides the umbrella frontmatter path.
enum MermaidSankeyExport {

    static func emit(_ model: SankeyDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["sankey-beta", ""]
        let diagnostics: [DiagramDiagnostic] = []

        for link in model.links {
            let s = csvField(link.source.rawID)
            let t = csvField(link.target.rawID)
            let v = formatNumber(link.value)
            lines.append("\(s),\(t),\(v)")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    /// RFC 4180 quoting: wrap in `"..."` and double internal `"` if the
    /// field contains `,`, `"`, `\n`, `\r`, or leading/trailing whitespace.
    private static func csvField(_ raw: String) -> String {
        let needsQuoting = raw.contains(",")
            || raw.contains("\"")
            || raw.contains("\n")
            || raw.contains("\r")
            || raw.hasPrefix(" ")
            || raw.hasSuffix(" ")
        if !needsQuoting { return raw }
        let escaped = raw.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func formatNumber(_ value: Double) -> String {
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }
}

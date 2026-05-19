import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `packet-beta` source from a `PacketDiagram`.
///
/// Lossless: rows flatten to a single sorted sequence of
/// `start-end: "label"` lines. Single-bit blocks (`start == end`)
/// emit as the bare bit index.
enum MermaidPacketExport {

    static func emit(_ model: PacketDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["packet-beta"]
        var diagnostics: [DiagramDiagnostic] = []

        let blocks = model.rows
            .flatMap { $0 }
            .sorted { $0.start < $1.start }
        for block in blocks {
            let range = block.start == block.end
                ? "\(block.start)"
                : "\(block.start)-\(block.end)"
            let (quoted, qDiags) = MermaidExportHelpers.quote(block.label)
            diagnostics.append(contentsOf: qDiags)
            lines.append("\(range): \(quoted)")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }
}

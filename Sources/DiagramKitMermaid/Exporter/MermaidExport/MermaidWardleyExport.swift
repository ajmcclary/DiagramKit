import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits Mermaid `wardley-beta` source from a `WardleyMapDiagram`.
///
/// Lossless: `wardley-beta` header → optional title and accessibility
/// metadata → optional `size [w, h]` → optional `evolution <stage> ->
/// ...` → nodes (anchors first, then components, then pipeline parents
/// at top level) → notes → annotations → annotations box →
/// accelerators / deaccelerators → links → `evolve` trends → pipeline
/// blocks.
///
/// CRITICAL: the wardley parser stores `[visibility, evolution]` from
/// the DSL as `WardleyNode(x: evolution, y: visibility)` after a
/// 0-100 normalization. The exporter emits `[node.y/100,
/// node.x/100]` to restore the corpus-idiom decimal form.
enum MermaidWardleyExport {

    static func emit(_ model: WardleyMapDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["wardley-beta"]
        let diagnostics: [DiagramDiagnostic] = []

        if let title = model.diagramTitle, !title.isEmpty {
            lines.append("title \(singleLine(title))")
        }
        if let accTitle = model.accTitle, !accTitle.isEmpty {
            lines.append("accTitle: \(singleLine(accTitle))")
        }
        if let accDescr = model.accDescr, !accDescr.isEmpty {
            lines.append("accDescr: \(singleLine(accDescr))")
        }

        if let size = model.size {
            lines.append("size [\(formatPlain(size.width)), \(formatPlain(size.height))]")
        }

        if let stages = model.axes.stages, !stages.isEmpty {
            lines.append("evolution \(stages.joined(separator: " -> "))")
        }

        // Identify nodes participating in any pipeline so we can emit
        // them inside their pipeline block rather than at top level.
        let pipelineChildIds: Set<String> = Set(model.pipelines.flatMap { $0.componentIds })

        // Anchors first.
        for node in model.nodes where node.className == .anchor {
            lines.append(emitTopNode(node))
        }
        // Components (excluding pipeline children, which live inside
        // their pipeline block).
        for node in model.nodes where node.className != .anchor && !pipelineChildIds.contains(node.id) {
            lines.append(emitTopNode(node))
        }

        for note in model.notes {
            lines.append("note \"\(escapeQuoted(note.text))\" [\(coord(note.y)), \(coord(note.x))]")
        }

        if let box = model.annotationsBox {
            lines.append("annotations [\(coord(box.y)), \(coord(box.x))]")
        }
        for ann in model.annotations.sorted(by: { $0.number < $1.number }) {
            guard let first = ann.coordinates.first else { continue }
            let text = ann.text ?? ""
            lines.append("annotation \(ann.number),[\(coord(first.y)), \(coord(first.x))] \"\(escapeQuoted(text))\"")
        }

        for acc in model.accelerators {
            lines.append("accelerator \"\(escapeQuoted(acc.name))\" [\(coord(acc.y)), \(coord(acc.x))]")
        }
        for deacc in model.deaccelerators {
            lines.append("deaccelerator \"\(escapeQuoted(deacc.name))\" [\(coord(deacc.y)), \(coord(deacc.x))]")
        }

        for link in model.links {
            let arrow = arrowToken(dashed: link.dashed, flow: link.flow, label: link.label)
            lines.append("\(link.source) \(arrow) \(link.target)")
        }

        for trend in model.trends {
            lines.append("evolve \(trend.nodeId) \(coord(trend.targetX))")
        }

        for pipeline in model.pipelines {
            lines.append("pipeline \(pipeline.nodeId) {")
            for childId in pipeline.componentIds {
                if let child = model.nodes.first(where: { $0.id == childId }) {
                    // Inside pipeline: single coord (evolution only).
                    lines.append("  component \(child.label) [\(coord(child.x))]")
                }
            }
            lines.append("}")
        }

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }

    private static func emitTopNode(_ node: WardleyNode) -> String {
        let kind = (node.className == .anchor) ? "anchor" : "component"
        // CRITICAL coordinate swap: DSL is [visibility, evolution] =
        // [y/100, x/100] in stored model coordinates.
        var line = "\(kind) \(node.label) [\(coord(node.y)), \(coord(node.x))]"
        if let strategy = node.sourceStrategy {
            line += " (\(strategy.rawValue))"
        }
        if node.inertia {
            line += " (inertia)"
        }
        return line
    }

    private static func arrowToken(
        dashed: Bool,
        flow: WardleyFlowDirection?,
        label: String?
    ) -> String {
        if let label, !label.isEmpty {
            let marker: String
            switch flow {
            case .bidirectional: marker = "<>"
            case .backward: marker = "<"
            default: marker = ">"
            }
            return "+'\(escapeSingle(label))'\(marker)"
        }
        switch flow {
        case .forward: return "+>"
        case .backward: return "+<"
        case .bidirectional: return "+'<>"
        case .none:
            return dashed ? "-.->" : "->"
        }
    }

    private static func coord(_ value: Double) -> String {
        // Stored as 0-100; emit as 0-1 with up to 4 decimal places,
        // trimming trailing zeros. Anchors with stored x=63 emit `0.63`.
        let asUnit = value / 100.0
        var s = String(format: "%.4f", asUnit)
        while s.contains(".") && s.last == "0" {
            s.removeLast()
        }
        if s.last == "." {
            s.append("0")
        }
        return s
    }

    private static func formatPlain(_ value: Double) -> String {
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }

    private static func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func escapeQuoted(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private static func escapeSingle(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}

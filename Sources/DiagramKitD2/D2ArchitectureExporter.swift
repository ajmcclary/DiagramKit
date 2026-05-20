import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits an `ArchitectureDiagram` as D2 source.
///
/// Service kinds map to native D2 shapes where one exists
/// (`database` → `cylinder`, `cloud` → `cloud`, `queue` → `queue`,
/// `storage` → `page`, `interface` → `circle`, `component` → `hexagon`).
/// Kinds without a native shape (PlantUML deployment cohort: `node`,
/// `artifact`, `frame`, `folder`, `package`, `card`, `stack`, `agent`,
/// `actor`, `boundary`) emit a `# diagramkit:arch-icon=<id>,<rawValue>`
/// marker plus a `.lossyTransform(.shapeDowngrade, …)` diagnostic.
/// Same-format round-trip is lossless via marker recovery in
/// `D2ArchitectureMapper`.
enum D2ArchitectureExport {

    static func emit(_ arch: ArchitectureDiagram, title: String?) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        if let t = title, !t.isEmpty {
            lines.append("# title: \(singleLine(t))")
        }

        // Family marker is emitted only when the structural probe alone
        // would not detect architecture (fewer than two native arch shapes).
        let nativeArchShapeCount = arch.services.filter { d2ShapeAttr(for: $0.kind) != nil }.count
        if nativeArchShapeCount < 2 {
            lines.append(D2RecoveryMarker.emitFamily("architecture"))
        }

        for service in arch.services where service.parentGroupId == nil {
            emitService(service, indent: "", lines: &lines, diagnostics: &diagnostics)
        }

        for group in arch.groups where group.parentGroupId == nil {
            emitGroup(group, arch: arch, indent: "", lines: &lines, diagnostics: &diagnostics)
        }

        for edge in arch.edges {
            let arrow: String
            switch (edge.sourceArrow, edge.targetArrow) {
            case (true, true):   arrow = "<->"
            case (false, true):  arrow = "->"
            case (true, false):  arrow = "<-"
            case (false, false): arrow = "--"
            }
            if let label = edge.label, !label.isEmpty {
                lines.append("\(sanitize(edge.lhsId)) \(arrow) \(sanitize(edge.rhsId)): \"\(escape(label))\"")
            } else {
                lines.append("\(sanitize(edge.lhsId)) \(arrow) \(sanitize(edge.rhsId))")
            }
        }

        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }

    private static func emitGroup(
        _ group: ArchitectureGroup,
        arch: ArchitectureDiagram,
        indent: String,
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        if let title = group.title, !title.isEmpty {
            lines.append("\(indent)\(sanitize(group.id)): \"\(escape(title))\" {")
        } else {
            lines.append("\(indent)\(sanitize(group.id)): {")
        }
        let inner = indent + "  "
        for service in arch.services where service.parentGroupId == group.id {
            emitService(service, indent: inner, lines: &lines, diagnostics: &diagnostics)
        }
        for child in arch.groups where child.parentGroupId == group.id {
            emitGroup(child, arch: arch, indent: inner, lines: &lines, diagnostics: &diagnostics)
        }
        lines.append("\(indent)}")
    }

    private static func emitService(
        _ service: ArchitectureService,
        indent: String,
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        let id = sanitize(service.id)
        let shape = d2ShapeAttr(for: service.kind)
        let needsMarker = shape == nil && service.kind != .service
        let hasDistinctTitle = service.title.map { !$0.isEmpty && $0 != service.id } ?? false

        // Always emit at least one statement that establishes the id so
        // the D2 parser can re-parse our output. If we'd otherwise emit
        // no statement (default kind + no distinct title), emit the
        // explicit `id: "id"` form.
        if hasDistinctTitle {
            lines.append("\(indent)\(id): \"\(escape(service.title ?? service.id))\"")
        } else if shape == nil && !needsMarker {
            lines.append("\(indent)\(id): \"\(escape(service.id))\"")
        }
        if let shape {
            lines.append("\(indent)\(id).shape: \(shape)")
        } else if needsMarker {
            lines.append("\(indent)\(id): \"\(escape(service.id))\"")
            lines.append("\(indent)\(D2RecoveryMarker.emitArchIcon(serviceID: service.id, kindRawValue: service.kind.rawValue))")
            diagnostics.append(.lossyTransform(
                .shapeDowngrade,
                message: "Service '\(service.id)' kind '\(service.kind.rawValue)' has no native D2 shape; recovery marker carries kind for round-trip"
            ))
        }
    }

    /// Returns the D2 shape name for kinds D2 represents natively, or
    /// `nil` for kinds requiring marker recovery.
    private static func d2ShapeAttr(for kind: ArchitectureServiceKind) -> String? {
        switch kind {
        case .service:   return nil
        case .database:  return "cylinder"
        case .cloud:     return "cloud"
        case .queue:     return "queue"
        case .storage:   return "page"
        case .interface: return "circle"
        case .component: return "hexagon"
        case .node, .artifact, .frame, .folder, .package, .card,
             .stack, .agent, .actor, .boundary:
            return nil
        }
    }

    private static func sanitize(_ raw: String) -> String {
        var out = ""
        for (i, ch) in raw.enumerated() {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "_":
                if i == 0, ch.isNumber { out.append("_") }
                out.append(ch)
            case " ", "-", ".":
                out.append("_")
            default:
                break
            }
        }
        return out.isEmpty ? "node" : out
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\r", with: "")
    }

    private static func singleLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
         .replacingOccurrences(of: "\r", with: "\n")
         .split(separator: "\n", omittingEmptySubsequences: false)
         .joined(separator: " ")
    }
}

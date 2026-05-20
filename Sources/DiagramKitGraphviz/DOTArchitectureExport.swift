import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport

/// Emits an `ArchitectureDiagram` as DOT source.
///
/// Kinds with a native DOT shape (`database` → cylinder,
/// `interface` → circle, `component` → component) round-trip
/// losslessly. Kinds without a native shape (`cloud`, `queue`,
/// `storage`, plus the PlantUML deployment cohort) approximate to
/// DOT shapes and emit a `# diagramkit:arch-icon=<id>,<rawValue>`
/// marker plus a `.lossyTransform(.shapeDowngrade, …)` diagnostic;
/// same-format round-trip is lossless via marker recovery in
/// `DOTArchitectureMapper`.
enum DOTArchitectureExport {

    static func emit(_ arch: ArchitectureDiagram, title: String?) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        lines.append("digraph G {")
        if let t = title, !t.isEmpty {
            lines.append("  // title: \(singleLine(t))")
        }

        // Family marker emitted only when the structural probe alone
        // would not detect architecture (fewer than two native arch shapes).
        let nativeArchShapeCount = arch.services.filter { shapeAttr(for: $0.kind).native }.count
        if nativeArchShapeCount < 2 {
            lines.append("  \(DOTRecoveryMarker.emitFamily("architecture"))")
        }

        for service in arch.services where service.parentGroupId == nil {
            emitService(service, indent: "  ", lines: &lines, diagnostics: &diagnostics)
        }

        for group in arch.groups where group.parentGroupId == nil {
            emitGroup(group, arch: arch, indent: "  ", lines: &lines, diagnostics: &diagnostics)
        }

        for edge in arch.edges {
            let arrow = edge.targetArrow ? "->" : "--"
            if let label = edge.label, !label.isEmpty {
                lines.append("  \(sanitize(edge.lhsId)) \(arrow) \(sanitize(edge.rhsId)) [label=\"\(escape(label))\"];")
            } else {
                lines.append("  \(sanitize(edge.lhsId)) \(arrow) \(sanitize(edge.rhsId));")
            }
        }

        lines.append("}")
        return DiagramExportResult(source: lines.joined(separator: "\n") + "\n", diagnostics: diagnostics)
    }

    private static func emitGroup(
        _ group: ArchitectureGroup,
        arch: ArchitectureDiagram,
        indent: String,
        lines: inout [String],
        diagnostics: inout [DiagramDiagnostic]
    ) {
        lines.append("\(indent)subgraph cluster_\(sanitize(group.id)) {")
        let inner = indent + "  "
        if let title = group.title, !title.isEmpty {
            lines.append("\(inner)label = \"\(escape(title))\";")
        }
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
        // Cross-format hint: when kind=.service but icon is a known
        // architecture kind (Mermaid stores shape info in `icon`),
        // promote the icon to drive the DOT shape selection.
        let effectiveKind: ArchitectureServiceKind = {
            if service.kind != .service { return service.kind }
            return DOTArchitectureMapper.kindForIcon(service.icon) ?? .service
        }()
        let mapped = shapeAttr(for: effectiveKind)
        var attrs: [String] = []
        if let title = service.title, !title.isEmpty, title != service.id {
            attrs.append("label=\"\(escape(title))\"")
        }
        if let shape = mapped.shape {
            attrs.append("shape=\(shape)")
        }
        if let style = mapped.style {
            attrs.append("style=\(style)")
        }
        if attrs.isEmpty {
            lines.append("\(indent)\(id);")
        } else {
            lines.append("\(indent)\(id) [\(attrs.joined(separator: ", "))];")
        }

        if !mapped.native && effectiveKind != .service {
            lines.append("\(indent)\(DOTRecoveryMarker.emitArchIcon(serviceID: service.id, kindRawValue: effectiveKind.rawValue))")
            diagnostics.append(.lossyTransform(
                .shapeDowngrade,
                message: "Service '\(service.id)' kind '\(effectiveKind.rawValue)' approximated to DOT shape '\(mapped.shape ?? "box")'; recovery marker preserves kind"
            ))
        }
    }

    /// Returns the DOT shape (and optional `style`) for `kind`. `native`
    /// is true when DOT can represent the kind without approximation.
    private static func shapeAttr(for kind: ArchitectureServiceKind) -> (shape: String?, style: String?, native: Bool) {
        switch kind {
        case .service:   return (nil, nil, true)
        case .database:  return ("cylinder", nil, true)
        case .cloud:     return ("oval", "dashed", false)
        case .queue:     return ("box3d", nil, false)
        case .storage:   return ("folder", nil, false)
        case .interface: return ("circle", nil, true)
        case .component: return ("component", nil, true)
        case .node, .artifact, .frame, .folder, .package, .card,
             .stack, .agent, .actor, .boundary:
            return ("box", nil, false)
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

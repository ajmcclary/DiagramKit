import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Detects whether a `DOTDocument` should be mapped as an architecture
/// diagram. Returns true when the document contains ≥2 nodes with an
/// architecture-style `shape=` attribute (cylinder, component, note,
/// folder, box3d, circle, hexagon, oval). Biases toward false
/// negatives so unrelated flowcharts are not misclassified. A
/// `# diagramkit:family=architecture` marker bypasses the threshold;
/// that escape hatch is enforced by `GraphvizImporter`, not here.
public enum DOTArchitectureProbe {
    public static func detectsArchitecture(_ doc: DOTDocument) -> Bool {
        // Distinctive architecture-only shapes. `circle`, `hexagon`,
        // `oval` are intentionally excluded — they also appear as
        // flowchart shape downgrades and would misclassify generic
        // graphs (see Wave E spec, architecture probe risk).
        let archShapes: Set<String> = [
            "cylinder", "component", "note", "folder", "box3d"
        ]
        var hits = 0
        for stmt in doc.statements {
            guard case .nodeStatement(let n) = stmt else { continue }
            if let shape = n.attributes.first(where: { $0.key == "shape" })?.value,
               archShapes.contains(shape) {
                hits += 1
                if hits >= 2 { return true }
            }
        }
        return false
    }
}

/// Maps a `DOTDocument` to an `ArchitectureDiagram`. DOT clusters
/// (`subgraph cluster_<id>`) become `ArchitectureGroup`s; node shape
/// attributes map to `ArchitectureServiceKind`. Recovery markers
/// (`.archIcon`, `.archGroup`) restore canonical state for kinds
/// without a native DOT shape.
public struct DOTArchitectureMapper {
    public init() {}

    public func map(
        _ doc: DOTDocument,
        markers: [RecoveryMarker<DOTRecoveryMarker.Kind>]
    ) -> (ArchitectureDiagram, [DiagramDiagnostic]) {
        var services: [ArchitectureService] = []
        var groups: [ArchitectureGroup] = []
        var edges: [ArchitectureEdge] = []
        var diagnostics: [DiagramDiagnostic] = []

        walk(
            statements: doc.statements,
            parentGroup: nil,
            services: &services,
            groups: &groups,
            edges: &edges
        )

        applyArchMarkers(services: &services, groups: &groups, markers: markers)

        return (
            ArchitectureDiagram(groups: groups, services: services, edges: edges),
            diagnostics
        )
    }

    private func walk(
        statements: [DOTStatement],
        parentGroup: String?,
        services: inout [ArchitectureService],
        groups: inout [ArchitectureGroup],
        edges: inout [ArchitectureEdge]
    ) {
        for stmt in statements {
            switch stmt {
            case .nodeStatement(let n):
                let shape = n.attributes.first(where: { $0.key == "shape" })?.value
                let label = n.attributes.first(where: { $0.key == "label" })?.value
                let kind = Self.kind(for: shape)
                services.append(ArchitectureService(
                    id: n.id,
                    icon: Self.iconForKind(kind),
                    title: label ?? n.id,
                    parentGroupId: parentGroup,
                    kind: kind
                ))
            case .edgeStatement(let e):
                let label = e.attributes.first(where: { $0.key == "label" })?.value
                edges.append(ArchitectureEdge(
                    lhsId: e.source,
                    rhsId: e.target,
                    lhsDirection: .R,
                    rhsDirection: .L,
                    sourceArrow: false,
                    targetArrow: e.directed,
                    label: label
                ))
            case .subgraph(let sub):
                let groupID = Self.unprefixCluster(sub.id ?? "")
                // Pull label from a graphAttr child statement, if any.
                let attrs = sub.statements.compactMap { stmt -> DOTAttribute? in
                    if case .graphAttr(let key, let value) = stmt {
                        return DOTAttribute(key: key, value: value)
                    }
                    return nil
                }
                let title = sub.displayLabel(from: attrs)
                groups.append(ArchitectureGroup(
                    id: groupID,
                    title: title,
                    parentGroupId: parentGroup
                ))
                walk(
                    statements: sub.statements,
                    parentGroup: groupID,
                    services: &services,
                    groups: &groups,
                    edges: &edges
                )
            default:
                continue
            }
        }
    }

    private static func unprefixCluster(_ name: String) -> String {
        name.hasPrefix("cluster_") ? String(name.dropFirst("cluster_".count)) : name
    }

    private static func kind(for shape: String?) -> ArchitectureServiceKind {
        switch shape {
        case "cylinder":  return .database
        case "oval":      return .cloud
        case "box3d":     return .queue
        case "folder":    return .storage
        case "circle":    return .interface
        case "component": return .component
        case "hexagon":   return .component
        case "note":      return .artifact
        default:          return .service
        }
    }

    /// Returns a canonical Mermaid icon name for a kind. Used so that
    /// `mermaid → dot → mermaid` round-trip preserves shape identity
    /// (Mermaid stores arch shape info on `icon`; DOT stores it on
    /// `kind`).
    static func iconForKind(_ kind: ArchitectureServiceKind) -> String? {
        switch kind {
        case .service:   return nil
        case .database:  return "database"
        case .cloud:     return "cloud"
        case .queue:     return "queue"
        case .storage:   return "disk"
        case .interface: return "interface"
        case .component: return "component"
        case .node, .artifact, .frame, .folder, .package, .card,
             .stack, .agent, .actor, .boundary:
            return kind.rawValue
        }
    }

    /// Inverse of `iconForKind` for the exporter's cross-format hint.
    static func kindForIcon(_ icon: String?) -> ArchitectureServiceKind? {
        guard let icon else { return nil }
        switch icon {
        case "database", "cylinder":    return .database
        case "cloud":                    return .cloud
        case "queue", "message-queue":   return .queue
        case "disk", "storage":          return .storage
        case "interface":                return .interface
        case "component":                return .component
        default:
            return ArchitectureServiceKind(rawValue: icon)
        }
    }

    private func applyArchMarkers(
        services: inout [ArchitectureService],
        groups: inout [ArchitectureGroup],
        markers: [RecoveryMarker<DOTRecoveryMarker.Kind>]
    ) {
        for marker in markers {
            switch marker.kind {
            case .archIcon(let serviceID, let kindRawValue):
                guard let idx = services.firstIndex(where: { $0.id == serviceID }),
                      let restored = ArchitectureServiceKind(rawValue: kindRawValue) else { continue }
                services[idx].kind = restored
            case .archGroup(let groupID, let parentID):
                guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { continue }
                groups[idx].parentGroupId = parentID.isEmpty ? nil : parentID
            default:
                continue
            }
        }
    }
}

import Foundation
import DiagramKitCommon
import DiagramKitModel

/// Detects whether a `D2Document` should be mapped as an architecture
/// diagram. Returns true when the document contains ≥2 nodes with an
/// architecture-style shape attribute (cylinder, cloud, queue, page,
/// circle, hexagon), biasing toward false negatives so unrelated
/// flowcharts are not misclassified. A
/// `# diagramkit:family=architecture` marker bypasses the threshold;
/// that escape hatch is enforced by `D2Importer`, not this probe.
public enum D2ArchitectureProbe {
    public static func detectsArchitecture(_ doc: D2Document) -> Bool {
        // Distinctive architecture-only shapes. `circle` and `hexagon` are
        // intentionally excluded — they also appear as flowchart shape
        // downgrades from formats like Mermaid, and treating them as
        // architecture-defining would misclassify generic graphs.
        let archShapes: Set<String> = ["cylinder", "cloud", "queue", "page"]
        var hits = 0
        for stmt in doc.statements {
            guard case .nodeDefinition(let nodeDef) = stmt else { continue }
            if let shape = nodeDef.shape, archShapes.contains(shape) {
                hits += 1
                if hits >= 2 { return true }
            }
        }
        return false
    }
}

/// Maps a `D2Document` to an `ArchitectureDiagram`. D2 containers
/// become `ArchitectureGroup`s with nested `parentGroupId` chains;
/// shape attributes map to `ArchitectureServiceKind`. Recovery markers
/// (`.archIcon`, `.archGroup`) restore canonical state for kinds
/// without a native D2 shape and for ambiguous group nesting.
public struct D2ArchitectureMapper {
    public init() {}

    public func map(
        _ doc: D2Document,
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>]
    ) -> (ArchitectureDiagram, [DiagramDiagnostic]) {
        var services: [ArchitectureService] = []
        var groups: [ArchitectureGroup] = []
        var edges: [ArchitectureEdge] = []
        var diagnostics: [DiagramDiagnostic] = []
        var containerStack: [String] = []

        for stmt in doc.statements {
            switch stmt {
            case .containerOpen(let open):
                groups.append(ArchitectureGroup(
                    id: open.id,
                    title: open.label,
                    parentGroupId: containerStack.last
                ))
                containerStack.append(open.id)
            case .containerClose:
                if !containerStack.isEmpty { containerStack.removeLast() }
            case .nodeDefinition(let nodeDef):
                let kind = Self.kind(for: nodeDef.shape)
                services.append(ArchitectureService(
                    id: nodeDef.id,
                    icon: Self.iconForKind(kind),
                    title: nodeDef.label ?? nodeDef.id,
                    parentGroupId: containerStack.last,
                    kind: kind
                ))
            case .edgeDefinition(let edgeDef):
                edges.append(ArchitectureEdge(
                    lhsId: edgeDef.source,
                    rhsId: edgeDef.target,
                    lhsDirection: .R,
                    rhsDirection: .L,
                    sourceArrow: edgeDef.sourceArrow,
                    targetArrow: edgeDef.targetArrow,
                    label: edgeDef.label
                ))
            case .direction:
                continue
            }
        }

        applyArchMarkers(
            services: &services,
            groups: &groups,
            markers: markers,
            diagnostics: &diagnostics
        )

        return (
            ArchitectureDiagram(groups: groups, services: services, edges: edges),
            diagnostics
        )
    }

    private static func kind(for shape: String?) -> ArchitectureServiceKind {
        switch shape {
        case "cylinder": return .database
        case "cloud":    return .cloud
        case "queue":    return .queue
        case "page":     return .storage
        case "circle":   return .interface
        case "hexagon":  return .component
        default:         return .service
        }
    }

    /// Returns a canonical Mermaid icon name for a kind, so cross-format
    /// round-trip through Mermaid (which stores shape info in `icon`)
    /// preserves the service's visual identity. `nil` for kinds that
    /// have no canonical Mermaid icon (`.service` defaults to `server`).
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

    /// Inverse of `iconForKind` for foreign formats. Used by exporters
    /// that need to map a Mermaid-sourced icon string back to a kind
    /// before deciding the foreign shape.
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

    /// Apply architecture-family recovery markers. Marker consumption is
    /// silent (no diagnostics) matching the Wave-D pattern in
    /// `D2Importer.applyClassStereotypeMarkers` /
    /// `applyERCardinalityMarkers`.
    private func applyArchMarkers(
        services: inout [ArchitectureService],
        groups: inout [ArchitectureGroup],
        markers: [RecoveryMarker<D2RecoveryMarker.Kind>],
        diagnostics: inout [DiagramDiagnostic]
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

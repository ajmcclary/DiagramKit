import Foundation
import DiagramKitCommon
import DiagramKitImport
import DiagramKitModel

/// Parses c4-family DOT source into a `C4Diagram` payload.
///
/// Mirrors `D2C4Mapper`: walks source line-by-line, classifies declarations,
/// applies recovery markers post-parse. Decision to bypass `DOTParser` is the
/// same — boundary nesting and per-declaration line numbers are needed for
/// positional marker correlation.
enum DOTC4Mapper {

    static func map(source: String) -> DiagramImportResult {
        var diagnostics: [DiagramDiagnostic] = []
        let scan = DOTRecoveryMarker.scanner.scan(source: source)
        let markers = scan.markers

        var ctx = ParseContext()
        let lines = source.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })

        var i = 0
        while i < lines.count {
            let raw = String(lines[i])
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("//") {
                i += 1
                continue
            }

            if trimmed.hasPrefix("digraph") && trimmed.hasSuffix("{") {
                i += 1
                continue
            }
            if trimmed == "}" {
                if !ctx.boundaryStack.isEmpty {
                    ctx.boundaryStack.removeLast()
                }
                i += 1
                continue
            }
            // Subgraph cluster_<alias> { (or label = "..."; inside)
            if let clusterAlias = parseClusterOpen(trimmed) {
                let boundary = C4Boundary(
                    alias: clusterAlias,
                    label: clusterAlias,  // pending: replaced by upcoming label = "..." line
                    parentBoundary: ctx.currentParentBoundary
                )
                ctx.boundaries.append(boundary)
                ctx.boundaryDeclarationsByAlias[clusterAlias] = ctx.boundaries.count - 1
                ctx.boundaryStack.append(clusterAlias)
                i += 1
                continue
            }
            // label = "..."; (boundary label)
            if let label = parseClusterLabel(trimmed) {
                if let parent = ctx.boundaryStack.last,
                   let idx = ctx.boundaryDeclarationsByAlias[parent] {
                    ctx.boundaries[idx].label = label
                }
                i += 1
                continue
            }
            // Edge: <from> -> <to> [label="..."]
            if let edge = parseEdge(trimmed) {
                ctx.relationships.append(C4Relationship(
                    kind: .rel,
                    from: edge.from,
                    to: edge.to,
                    label: edge.label
                ))
                i += 1
                continue
            }
            // Shape: <alias> [shape=<native>, label="<label>"];
            if let decl = parseShapeDecl(trimmed) {
                let nominal = inferShapeType(native: decl.native, diagramKind: ctx.preliminaryDiagramKind(from: markers))
                let shape = C4Shape(
                    alias: decl.alias,
                    label: decl.label,
                    typeC4Shape: nominal,
                    parentBoundary: ctx.currentParentBoundary
                )
                ctx.shapes.append(shape)
                ctx.shapeDeclarationsByAlias[decl.alias] = ctx.shapes.count - 1
                if decl.native == "cylinder" {
                    let hasShapeKindMarker = markers.contains { m in
                        if case .c4ShapeKind(let target, _) = m.kind, target == decl.alias { return true }
                        return false
                    }
                    if !hasShapeKindMarker {
                        diagnostics.append(.lossyTransform(
                            .shapeDowngrade,
                            message: "DOT c4 shape '\(decl.alias)' defaulted to .\(nominal.rawValue) (cylinder is ambiguous; no c4-shape-kind marker)"
                        ))
                    }
                }
                i += 1
                continue
            }

            // Anything else: silently skip (unknown DOT attribute, etc.)
            i += 1
        }

        let diagramKind = decodeDiagramKind(from: markers, diagnostics: &diagnostics)
        ctx.applyMarkers(markers)

        let diagram = C4Diagram(
            kind: diagramKind,
            title: nil,
            shapes: ctx.shapes,
            boundaries: ctx.boundaries,
            relationships: ctx.relationships,
            config: C4DiagramConfig()
        )
        return DiagramImportResult(
            document: DiagramDocument(payload: .c4(diagram)),
            diagnostics: diagnostics
        )
    }

    // MARK: - ParseContext

    private struct ParseContext {
        var boundaryStack: [String] = []
        var shapes: [C4Shape] = []
        var boundaries: [C4Boundary] = []
        var relationships: [C4Relationship] = []
        var shapeDeclarationsByAlias: [String: Int] = [:]
        var boundaryDeclarationsByAlias: [String: Int] = [:]

        var currentParentBoundary: String { boundaryStack.last ?? "global" }

        func preliminaryDiagramKind(from markers: [RecoveryMarker<DOTRecoveryMarker.Kind>]) -> C4DiagramKind {
            for m in markers {
                if case .c4DiagramKind(let raw) = m.kind, let kind = C4DiagramKind(rawValue: raw) {
                    return kind
                }
            }
            return .context
        }

        mutating func applyMarkers(_ markers: [RecoveryMarker<DOTRecoveryMarker.Kind>]) {
            for marker in markers {
                switch marker.kind {
                case .c4ShapeKind(let targetID, let raw):
                    if let idx = shapeDeclarationsByAlias[targetID],
                       let type = C4ShapeType(rawValue: raw) {
                        shapes[idx].typeC4Shape = type
                    }
                case .c4External(let targetID):
                    if let idx = shapeDeclarationsByAlias[targetID] {
                        shapes[idx].typeC4Shape = shapes[idx].typeC4Shape.toExternal
                    }
                case .c4Technology(let targetID, let value):
                    applyToTarget(targetID, shapeUpdate: { $0.technology = value }, edgeUpdate: { $0.technology = value })
                case .c4Description(let targetID, let value):
                    applyToTarget(targetID,
                        shapeUpdate: { $0.description = value },
                        boundaryUpdate: { $0.description = value },
                        edgeUpdate: { $0.description = value })
                case .c4Sprite(let targetID, let value):
                    applyToTarget(targetID, shapeUpdate: { $0.sprite = value }, edgeUpdate: { $0.sprite = value })
                case .c4Tag(let targetID, let value):
                    applyToTarget(targetID,
                        shapeUpdate: { $0.tags = value },
                        boundaryUpdate: { $0.tags = value },
                        edgeUpdate: { $0.tags = value })
                case .c4Link(let targetID, let value):
                    applyToTarget(targetID,
                        shapeUpdate: { $0.link = value },
                        boundaryUpdate: { $0.link = value },
                        edgeUpdate: { $0.link = value })
                case .c4BoundaryKind(let targetID, let raw):
                    if let bidx = boundaryDeclarationsByAlias[targetID] {
                        boundaries[bidx].type = raw
                    }
                case .c4RelKind(let edgeIndex, let raw):
                    if edgeIndex < relationships.count,
                       let kind = C4RelationshipKind(rawValue: raw) {
                        relationships[edgeIndex].kind = kind
                    }
                case .c4Color(let targetID, let packed):
                    let parsed = parseColorPack(packed)
                    if let idx = shapeDeclarationsByAlias[targetID] {
                        if let v = parsed["bg"]     { shapes[idx].bgColor = v }
                        if let v = parsed["font"]   { shapes[idx].fontColor = v }
                        if let v = parsed["border"] { shapes[idx].borderColor = v }
                    } else if let bidx = boundaryDeclarationsByAlias[targetID] {
                        if let v = parsed["bg"]     { boundaries[bidx].bgColor = v }
                        if let v = parsed["font"]   { boundaries[bidx].fontColor = v }
                        if let v = parsed["border"] { boundaries[bidx].borderColor = v }
                    } else if let edgeIdx = Int(targetID), edgeIdx < relationships.count {
                        if let v = parsed["text"] { relationships[edgeIdx].textColor = v }
                        if let v = parsed["line"] { relationships[edgeIdx].lineColor = v }
                    }
                default:
                    continue
                }
            }
        }

        private mutating func applyToTarget(
            _ targetID: String,
            shapeUpdate: (inout C4Shape) -> Void,
            boundaryUpdate: ((inout C4Boundary) -> Void)? = nil,
            edgeUpdate: ((inout C4Relationship) -> Void)? = nil
        ) {
            if let idx = shapeDeclarationsByAlias[targetID] {
                shapeUpdate(&shapes[idx])
                return
            }
            if let boundaryUpdate, let bidx = boundaryDeclarationsByAlias[targetID] {
                boundaryUpdate(&boundaries[bidx])
                return
            }
            if let edgeUpdate, let edgeIdx = Int(targetID), edgeIdx < relationships.count {
                edgeUpdate(&relationships[edgeIdx])
            }
        }

        private func parseColorPack(_ packed: String) -> [String: String] {
            var out: [String: String] = [:]
            for part in packed.split(separator: ";") {
                let pieces = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard pieces.count == 2 else { continue }
                out[String(pieces[0])] = String(pieces[1])
            }
            return out
        }
    }

    // MARK: - Line patterns

    private static func parseClusterOpen(_ line: String) -> String? {
        guard line.hasPrefix("subgraph "), line.hasSuffix("{") else { return nil }
        let body = String(line.dropFirst("subgraph ".count).dropLast()).trimmingCharacters(in: .whitespaces)
        let alias: String
        if body.hasPrefix("cluster_") {
            alias = String(body.dropFirst("cluster_".count)).trimmingCharacters(in: .whitespaces)
        } else {
            alias = body
        }
        guard !alias.isEmpty, isIdentifier(alias) else { return nil }
        return alias
    }

    private static func parseClusterLabel(_ line: String) -> String? {
        guard line.hasPrefix("label") else { return nil }
        let body = String(line.dropFirst("label".count)).trimmingCharacters(in: .whitespaces)
        guard body.hasPrefix("=") else { return nil }
        let rhs = String(body.dropFirst()).trimmingCharacters(in: .whitespaces)
        let semi = rhs.hasSuffix(";") ? String(rhs.dropLast()).trimmingCharacters(in: .whitespaces) : rhs
        return extractFirstQuoted(semi)
    }

    private static func parseShapeDecl(_ line: String) -> (alias: String, native: String, label: String)? {
        // Matches: <alias> [shape=<native>, label="<label>"];
        guard let openBracket = line.firstIndex(of: "[") else { return nil }
        let alias = String(line[..<openBracket]).trimmingCharacters(in: .whitespaces)
        guard isIdentifier(alias) else { return nil }
        let rest = String(line[line.index(after: openBracket)...])
        guard let closeBracket = rest.firstIndex(of: "]") else { return nil }
        let attrs = String(rest[..<closeBracket])
        var native = ""
        var label = ""
        for part in attrs.split(separator: ",") {
            let kv = part.trimmingCharacters(in: .whitespaces)
            if let eq = kv.firstIndex(of: "=") {
                let key = String(kv[..<eq]).trimmingCharacters(in: .whitespaces)
                let value = String(kv[kv.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                switch key {
                case "shape": native = value
                case "label":
                    if let extracted = extractFirstQuoted(value) {
                        label = extracted
                    } else {
                        label = value
                    }
                default: continue
                }
            }
        }
        guard !native.isEmpty else { return nil }
        return (alias, native, label)
    }

    private static func parseEdge(_ line: String) -> (from: String, to: String, label: String)? {
        guard let arrowRange = line.range(of: "->") else { return nil }
        let lhs = String(line[..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard isIdentifier(lhs) else { return nil }
        let rhs = String(line[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        var to = rhs
        var label = ""
        if let openBracket = rhs.firstIndex(of: "[") {
            to = String(rhs[..<openBracket]).trimmingCharacters(in: .whitespaces)
            let attrs = String(rhs[rhs.index(after: openBracket)...])
            if let closeBracket = attrs.firstIndex(of: "]") {
                let attrBody = String(attrs[..<closeBracket])
                if let labelRange = attrBody.range(of: "label=") {
                    let after = String(attrBody[labelRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if let extracted = extractFirstQuoted(after) {
                        label = extracted
                    }
                }
            }
        } else if let semi = to.firstIndex(of: ";") {
            to = String(to[..<semi]).trimmingCharacters(in: .whitespaces)
        }
        guard isIdentifier(to) else { return nil }
        return (lhs, to, label)
    }

    private static func extractFirstQuoted(_ s: String) -> String? {
        guard s.hasPrefix("\"") else { return nil }
        let body = s.dropFirst()
        guard let endIdx = body.firstIndex(of: "\"") else { return nil }
        return String(body[..<endIdx])
    }

    private static func isIdentifier(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        for ch in s {
            if !(ch.isLetter || ch.isNumber || ch == "_") { return false }
        }
        return true
    }

    private static func inferShapeType(native: String, diagramKind: C4DiagramKind) -> C4ShapeType {
        switch native {
        case "oval":      return .person
        case "box":       return .system
        case "cylinder":
            switch diagramKind {
            case .component: return .component_db
            default:         return .system_db
            }
        case "component": return .component
        default:          return .system
        }
    }

    private static func decodeDiagramKind(
        from markers: [RecoveryMarker<DOTRecoveryMarker.Kind>],
        diagnostics: inout [DiagramDiagnostic]
    ) -> C4DiagramKind {
        for m in markers {
            if case .c4DiagramKind(let raw) = m.kind, let kind = C4DiagramKind(rawValue: raw) {
                return kind
            }
        }
        diagnostics.append(.lossyTransform(
            .shapeDowngrade,
            message: "C4 diagram kind defaulted to .context (no c4-diagram-kind marker)"
        ))
        return .context
    }
}

private extension C4ShapeType {
    var toExternal: C4ShapeType {
        switch self {
        case .person:                return .external_person
        case .system:                return .external_system
        case .system_db:             return .external_system_db
        case .system_queue:          return .external_system_queue
        case .container:             return .external_container
        case .container_db:          return .external_container_db
        case .container_queue:       return .external_container_queue
        case .component:             return .external_component
        case .component_db:          return .external_component_db
        case .component_queue:       return .external_component_queue
        default:                     return self
        }
    }
}

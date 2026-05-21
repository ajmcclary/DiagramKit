import Foundation
import DiagramKitCommon
import DiagramKitImport
import DiagramKitModel

/// Parses c4-family D2 source into a `C4Diagram` payload.
///
/// The mapper walks `source` line-by-line because D2's general-purpose
/// AST (`D2Document`) doesn't preserve the structural information
/// (boundary nesting, declaration line numbers) we need for positional
/// marker correlation. Recovery markers are applied via
/// `latestDeclaration(before:in:)` against the per-declaration line index.
enum D2C4Mapper {

    static func map(source: String) -> DiagramImportResult {
        var diagnostics: [DiagramDiagnostic] = []
        let scan = D2RecoveryMarker.scanner.scan(source: source)
        let markers = scan.markers

        var ctx = ParseContext()
        let lines = source.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })

        var i = 0
        while i < lines.count {
            let lineNumber = i + 1
            let raw = String(lines[i])
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                i += 1
                continue
            }

            // title: "..."
            if trimmed.hasPrefix("title:") {
                ctx.title = extractQuoted(after: "title:", in: trimmed)
                i += 1
                continue
            }

            // Arrow lines: "a -> b" or "a <-> b" with optional `: "label"`.
            if let arrow = parseArrow(trimmed) {
                ctx.relationships.append(C4Relationship(
                    kind: (arrow.bidirectional ? .birel : .rel),
                    from: arrow.from,
                    to: arrow.to,
                    label: arrow.label
                ))
                ctx.relationshipDeclarationLines.append(lineNumber)
                i += 1
                continue
            }

            // Block-open lines: "<id>: "<label>" {"
            if let block = parseBlockOpen(trimmed) {
                // Peek next non-blank, non-comment line to decide shape vs boundary.
                let nextContent = nextContentLine(from: i + 1, in: lines)
                if let nc = nextContent, let nativeShape = parseShapeAttr(nc.trimmed) {
                    // Shape
                    let nominal = inferShapeType(native: nativeShape, diagramKind: ctx.preliminaryDiagramKind(from: markers))
                    var shape = C4Shape(
                        alias: block.alias,
                        label: block.label,
                        typeC4Shape: nominal,
                        parentBoundary: ctx.currentParentBoundary
                    )
                    if nominal == .system_db || nominal == .container_db || nominal == .component_db {
                        // Cylinder is ambiguous across tiers — emit informational
                        // unless a c4-shape-kind marker overrides.
                        let hasShapeKindMarker = markers.contains { m in
                            if case .c4ShapeKind(let target, _) = m.kind, target == block.alias {
                                return true
                            }
                            return false
                        }
                        if !hasShapeKindMarker && nativeShape == "cylinder" {
                            diagnostics.append(.lossyTransform(
                                .shapeDowngrade,
                                message: "D2 c4 shape '\(block.alias)' defaulted to .\(nominal.rawValue) (cylinder is ambiguous; no c4-shape-kind marker)"
                            ))
                        }
                    }
                    ctx.shapes.append(shape)
                    ctx.shapeDeclarationLines.append(lineNumber)
                    ctx.shapeDeclarationsByAlias[block.alias] = ctx.shapes.count - 1
                    // Skip past `shape:` line and closing `}`.
                    i = nc.index + 1
                    while i < lines.count {
                        let look = String(lines[i]).trimmingCharacters(in: .whitespaces)
                        if look == "}" { i += 1; break }
                        i += 1
                    }
                    continue
                } else {
                    // Boundary (or empty block — treat as boundary)
                    let boundary = C4Boundary(
                        alias: block.alias,
                        label: block.label,
                        parentBoundary: ctx.currentParentBoundary
                    )
                    ctx.boundaries.append(boundary)
                    ctx.boundaryDeclarationLines.append(lineNumber)
                    ctx.boundaryDeclarationsByAlias[block.alias] = ctx.boundaries.count - 1
                    ctx.boundaryStack.append(block.alias)
                    i += 1
                    continue
                }
            }

            // Block close.
            if trimmed == "}" {
                if !ctx.boundaryStack.isEmpty {
                    ctx.boundaryStack.removeLast()
                }
                i += 1
                continue
            }

            // Anything else: silent skip.
            i += 1
        }

        // Decode diagram kind (or default with informational).
        let diagramKind = decodeDiagramKind(from: markers, diagnostics: &diagnostics)

        ctx.applyMarkers(markers)

        let diagram = C4Diagram(
            kind: diagramKind,
            title: ctx.title,
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
        var title: String?
        var boundaryStack: [String] = []
        var shapes: [C4Shape] = []
        var boundaries: [C4Boundary] = []
        var relationships: [C4Relationship] = []
        var shapeDeclarationLines: [Int] = []
        var boundaryDeclarationLines: [Int] = []
        var relationshipDeclarationLines: [Int] = []
        var shapeDeclarationsByAlias: [String: Int] = [:]
        var boundaryDeclarationsByAlias: [String: Int] = [:]

        var currentParentBoundary: String {
            boundaryStack.last ?? "global"
        }

        func preliminaryDiagramKind(from markers: [RecoveryMarker<D2RecoveryMarker.Kind>]) -> C4DiagramKind {
            for m in markers {
                if case .c4DiagramKind(let raw) = m.kind, let kind = C4DiagramKind(rawValue: raw) {
                    return kind
                }
            }
            return .context
        }

        mutating func applyMarkers(_ markers: [RecoveryMarker<D2RecoveryMarker.Kind>]) {
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
                    if let idx = shapeDeclarationsByAlias[targetID] {
                        shapes[idx].technology = value
                    } else if let edgeIdx = Int(targetID), edgeIdx < relationships.count {
                        relationships[edgeIdx].technology = value
                    }
                case .c4Description(let targetID, let value):
                    if let idx = shapeDeclarationsByAlias[targetID] {
                        shapes[idx].description = value
                    } else if let bidx = boundaryDeclarationsByAlias[targetID] {
                        boundaries[bidx].description = value
                    } else if let edgeIdx = Int(targetID), edgeIdx < relationships.count {
                        relationships[edgeIdx].description = value
                    }
                case .c4Sprite(let targetID, let value):
                    if let idx = shapeDeclarationsByAlias[targetID] {
                        shapes[idx].sprite = value
                    } else if let edgeIdx = Int(targetID), edgeIdx < relationships.count {
                        relationships[edgeIdx].sprite = value
                    }
                case .c4Tag(let targetID, let value):
                    if let idx = shapeDeclarationsByAlias[targetID] {
                        shapes[idx].tags = value
                    } else if let bidx = boundaryDeclarationsByAlias[targetID] {
                        boundaries[bidx].tags = value
                    } else if let edgeIdx = Int(targetID), edgeIdx < relationships.count {
                        relationships[edgeIdx].tags = value
                    }
                case .c4Link(let targetID, let value):
                    if let idx = shapeDeclarationsByAlias[targetID] {
                        shapes[idx].link = value
                    } else if let bidx = boundaryDeclarationsByAlias[targetID] {
                        boundaries[bidx].link = value
                    } else if let edgeIdx = Int(targetID), edgeIdx < relationships.count {
                        relationships[edgeIdx].link = value
                    }
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
                        if let v = parsed["bg"] { shapes[idx].bgColor = v }
                        if let v = parsed["font"] { shapes[idx].fontColor = v }
                        if let v = parsed["border"] { shapes[idx].borderColor = v }
                    } else if let bidx = boundaryDeclarationsByAlias[targetID] {
                        if let v = parsed["bg"] { boundaries[bidx].bgColor = v }
                        if let v = parsed["font"] { boundaries[bidx].fontColor = v }
                        if let v = parsed["border"] { boundaries[bidx].borderColor = v }
                    } else if let edgeIdx = Int(targetID), edgeIdx < relationships.count {
                        if let v = parsed["text"] { relationships[edgeIdx].textColor = v }
                        if let v = parsed["line"] { relationships[edgeIdx].lineColor = v }
                    }
                case .c4DiagramKind, .family:
                    continue
                default:
                    continue
                }
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

    private static func parseBlockOpen(_ line: String) -> (alias: String, label: String)? {
        // Matches: `<id>: "<label>" {` with optional whitespace.
        guard line.hasSuffix("{") else { return nil }
        let body = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
        guard let colon = body.firstIndex(of: ":") else { return nil }
        let alias = String(body[..<colon]).trimmingCharacters(in: .whitespaces)
        let rhs = String(body[body.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        guard !alias.isEmpty, isIdentifier(alias) else { return nil }
        if rhs.hasPrefix("\""), let label = extractFirstQuoted(rhs) {
            return (alias, label)
        }
        // Unlabeled block (e.g., `svc {`) — treat label as the alias.
        if rhs.isEmpty { return (alias, alias) }
        return nil
    }

    private static func parseShapeAttr(_ line: String) -> String? {
        guard line.hasPrefix("shape:") else { return nil }
        return String(line.dropFirst("shape:".count)).trimmingCharacters(in: .whitespaces)
    }

    private struct ArrowMatch {
        let from: String
        let to: String
        let bidirectional: Bool
        let label: String
    }

    private static func parseArrow(_ line: String) -> ArrowMatch? {
        let candidates: [(token: String, bi: Bool)] = [("<->", true), ("->", false)]
        for (token, bi) in candidates {
            if let range = line.range(of: token) {
                let lhs = line[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                let rhs = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                guard isIdentifier(lhs) else { continue }
                var label = ""
                var to = rhs
                if let colonRange = rhs.range(of: ":") {
                    to = String(rhs[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let afterColon = String(rhs[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if let extracted = extractFirstQuoted(afterColon) {
                        label = extracted
                    }
                }
                guard isIdentifier(to) else { continue }
                return ArrowMatch(from: lhs, to: to, bidirectional: bi, label: label)
            }
        }
        return nil
    }

    private static func nextContentLine(
        from index: Int,
        in lines: [Substring]
    ) -> (index: Int, trimmed: String)? {
        var i = index
        while i < lines.count {
            let trimmed = String(lines[i]).trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                return (i, trimmed)
            }
            i += 1
        }
        return nil
    }

    private static func extractQuoted(after prefix: String, in line: String) -> String? {
        let rhs = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        return extractFirstQuoted(rhs) ?? (rhs.isEmpty ? nil : rhs)
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
        case "person":     return .person
        case "rectangle":  return .system
        case "cylinder":
            switch diagramKind {
            case .component: return .component_db
            default:         return .system_db
            }
        case "queue":      return .system_queue
        case "hexagon":    return .component
        default:           return .system
        }
    }

    // MARK: - Diagram kind decoding

    private static func decodeDiagramKind(
        from markers: [RecoveryMarker<D2RecoveryMarker.Kind>],
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
    /// Promote a shape type to its `external_` variant. Idempotent.
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

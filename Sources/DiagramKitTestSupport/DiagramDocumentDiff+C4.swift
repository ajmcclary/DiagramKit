import DiagramKitModel

func diffC4Diagram(_ a: C4Diagram, _ b: C4Diagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.kind != b.kind {
        deltas.append(.unexpected(
            path: "c4.kind",
            detail: "lhs=\(a.kind) rhs=\(b.kind)"
        ))
    }

    // 1) Shapes — alias-based with sanitization pairing.
    let aShapes = Dictionary(uniqueKeysWithValues: a.shapes.map { ($0.alias, $0) })
    let bShapes = Dictionary(uniqueKeysWithValues: b.shapes.map { ($0.alias, $0) })
    let sanitizationMap = diffShapeAliases(a: aShapes, b: bShapes, deltas: &deltas)

    for (alias, aShape) in aShapes {
        let mappedAlias = sanitizationMap[alias] ?? alias
        guard let bShape = bShapes[mappedAlias] else { continue }
        if aShape.label != bShape.label {
            deltas.append(.unexpected(
                path: "shapes[\(alias)].label",
                detail: "lhs=\(aShape.label) rhs=\(bShape.label)"
            ))
        }
        if aShape.typeC4Shape != bShape.typeC4Shape {
            deltas.append(.unexpected(
                path: "shapes[\(alias)].typeC4Shape",
                detail: "lhs=\(aShape.typeC4Shape) rhs=\(bShape.typeC4Shape)"
            ))
        }
        // Technology / description slot drop — surfaces when one side has a
        // populated slot and the other doesn't.
        if aShape.technology != bShape.technology {
            if aShape.technology != nil && bShape.technology == nil {
                deltas.append(.loss(.c4SlotDrop(shapeID: alias, slot: .technology)))
            } else {
                deltas.append(.unexpected(
                    path: "shapes[\(alias)].technology",
                    detail: "lhs=\(aShape.technology ?? "nil") rhs=\(bShape.technology ?? "nil")"
                ))
            }
        }
        if aShape.description != bShape.description {
            if aShape.description != nil && bShape.description == nil {
                deltas.append(.loss(.c4SlotDrop(shapeID: alias, slot: .description)))
            } else {
                deltas.append(.unexpected(
                    path: "shapes[\(alias)].description",
                    detail: "lhs=\(aShape.description ?? "nil") rhs=\(bShape.description ?? "nil")"
                ))
            }
        }
        let aMappedParent = sanitizationMap[aShape.parentBoundary] ?? aShape.parentBoundary
        if aMappedParent != bShape.parentBoundary {
            deltas.append(.unexpected(
                path: "shapes[\(alias)].parentBoundary",
                detail: "lhs=\(aShape.parentBoundary) rhs=\(bShape.parentBoundary)"
            ))
        }
    }

    // 2) Boundaries — only authored boundaries should appear in both sides
    // (viewScopeSynthesized boundaries are re-derived at parse time).
    let aBoundaries = a.boundaries.filter { $0.origin == .authored }
    let bBoundaries = b.boundaries.filter { $0.origin == .authored }
    if aBoundaries.count != bBoundaries.count {
        deltas.append(.unexpected(
            path: "boundaries.count(authored)",
            detail: "lhs=\(aBoundaries.count) rhs=\(bBoundaries.count)"
        ))
    }

    // 3) Relationships — positional after canonical sort.
    let aRels = a.relationships.sorted(by: c4RelOrder)
    let bRels = b.relationships.sorted(by: c4RelOrder)
    if aRels.count != bRels.count {
        deltas.append(.unexpected(
            path: "relationships.count",
            detail: "lhs=\(aRels.count) rhs=\(bRels.count)"
        ))
    }

    return deltas
}

private func c4RelOrder(_ lhs: C4Relationship, _ rhs: C4Relationship) -> Bool {
    let lk = "\(lhs.from)|\(lhs.to)|\(lhs.label)"
    let rk = "\(rhs.from)|\(rhs.to)|\(rhs.label)"
    return lk < rk
}

private func diffShapeAliases(
    a: [String: C4Shape],
    b: [String: C4Shape],
    deltas: inout [RoundTripDelta]
) -> [String: String] {
    var sanitizationMap: [String: String] = [:]
    let onlyA = Set(a.keys).subtracting(b.keys)
    let onlyB = Set(b.keys).subtracting(a.keys)
    var pairedRhs: Set<String> = []
    for aID in onlyA {
        guard let aShape = a[aID] else { continue }
        let match = onlyB.first { bID in
            !pairedRhs.contains(bID) && b[bID]?.label == aShape.label
        }
        if let bID = match {
            deltas.append(.loss(.idSanitization(original: aID, sanitized: bID)))
            sanitizationMap[aID] = bID
            pairedRhs.insert(bID)
        } else {
            deltas.append(.unexpected(path: "shapes", detail: "lhs-only alias=\(aID)"))
        }
    }
    for bID in onlyB where !pairedRhs.contains(bID) {
        deltas.append(.unexpected(path: "shapes", detail: "rhs-only alias=\(bID)"))
    }
    return sanitizationMap
}

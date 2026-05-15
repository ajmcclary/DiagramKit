import DiagramKitModel

func diffClassDiagram(_ a: ClassDiagram, _ b: ClassDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    // 1) Direction
    if a.direction != b.direction {
        deltas.append(.unexpected(
            path: "direction",
            detail: "lhs=\(a.direction) rhs=\(b.direction)"
        ))
    }

    // 2) Classes — id-based comparison with sanitization pairing on label match.
    let aClasses = Dictionary(uniqueKeysWithValues: a.classes.map { ($0.id, $0) })
    let bClasses = Dictionary(uniqueKeysWithValues: b.classes.map { ($0.id, $0) })
    let sanitizationMap = diffClassIDs(a: aClasses, b: bClasses, deltas: &deltas)

    for (id, aClass) in aClasses {
        let mappedID = sanitizationMap[id] ?? id
        guard let bClass = bClasses[mappedID] else { continue }
        if aClass.label != bClass.label {
            deltas.append(.unexpected(
                path: "classes[\(id)].label",
                detail: "lhs=\(aClass.label) rhs=\(bClass.label)"
            ))
        }
    }

    // 3) Relationships — positional comparison after canonical sort.
    let aRels = a.relationships.sorted(by: relOrder)
    let bRels = b.relationships.sorted(by: relOrder)
    if aRels.count != bRels.count {
        deltas.append(.unexpected(
            path: "relationships.count",
            detail: "lhs=\(aRels.count) rhs=\(bRels.count)"
        ))
    } else {
        for (i, (ar, br)) in zip(aRels, bRels).enumerated() {
            let aMappedFirst = sanitizationMap[ar.id1] ?? ar.id1
            let aMappedSecond = sanitizationMap[ar.id2] ?? ar.id2
            if aMappedFirst != br.id1 || aMappedSecond != br.id2 {
                deltas.append(.unexpected(
                    path: "relationships[\(i)].endpoints",
                    detail: "lhs=(\(ar.id1)→\(ar.id2)) rhs=(\(br.id1)→\(br.id2))"
                ))
            }
        }
    }

    return deltas
}

private func relOrder(_ lhs: ClassRelationship, _ rhs: ClassRelationship) -> Bool {
    let lk = "\(lhs.id1)|\(lhs.id2)"
    let rk = "\(rhs.id1)|\(rhs.id2)"
    return lk < rk
}

private func diffClassIDs(
    a: [String: ClassNode],
    b: [String: ClassNode],
    deltas: inout [RoundTripDelta]
) -> [String: String] {
    var sanitizationMap: [String: String] = [:]
    let onlyA = Set(a.keys).subtracting(b.keys)
    let onlyB = Set(b.keys).subtracting(a.keys)
    var pairedRhs: Set<String> = []
    for aID in onlyA {
        guard let aClass = a[aID] else { continue }
        let match = onlyB.first { bID in
            !pairedRhs.contains(bID) && b[bID]?.label == aClass.label
        }
        if let bID = match {
            deltas.append(.loss(.idSanitization(original: aID, sanitized: bID)))
            sanitizationMap[aID] = bID
            pairedRhs.insert(bID)
        } else {
            deltas.append(.unexpected(path: "classes", detail: "lhs-only id=\(aID)"))
        }
    }
    for bID in onlyB where !pairedRhs.contains(bID) {
        deltas.append(.unexpected(path: "classes", detail: "rhs-only id=\(bID)"))
    }
    return sanitizationMap
}

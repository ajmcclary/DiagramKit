import DiagramKitModel

func diffErDiagram(_ a: ErDiagram, _ b: ErDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    // 1) Entities by id (key).
    let aEntities = Dictionary(uniqueKeysWithValues: a.entities.map { ($0.id, $0) })
    let bEntities = Dictionary(uniqueKeysWithValues: b.entities.map { ($0.id, $0) })
    let sanitizationMap = diffEntityIDs(a: aEntities, b: bEntities, deltas: &deltas)

    for (id, aEntity) in aEntities {
        let mappedID = sanitizationMap[id] ?? id
        guard let bEntity = bEntities[mappedID] else { continue }
        if aEntity.attributes.count != bEntity.attributes.count {
            deltas.append(.unexpected(
                path: "entities[\(id)].attributes.count",
                detail: "lhs=\(aEntity.attributes.count) rhs=\(bEntity.attributes.count)"
            ))
            continue
        }
        for (i, (aa, bb)) in zip(aEntity.attributes, bEntity.attributes).enumerated() {
            if aa.name != bb.name || aa.type != bb.type {
                deltas.append(.unexpected(
                    path: "entities[\(id)].attributes[\(i)]",
                    detail: "lhs=\(aa.type) \(aa.name) rhs=\(bb.type) \(bb.name)"
                ))
            }
        }
    }

    // 2) Relationships — positional after canonical sort, with sanitization map.
    let aRels = a.relationships.sorted(by: erRelOrder)
    let bRels = b.relationships.sorted(by: erRelOrder)
    if aRels.count != bRels.count {
        deltas.append(.unexpected(
            path: "relationships.count",
            detail: "lhs=\(aRels.count) rhs=\(bRels.count)"
        ))
    } else {
        for (i, (ar, br)) in zip(aRels, bRels).enumerated() {
            let aMappedFirst = sanitizationMap[ar.entity1] ?? ar.entity1
            let aMappedSecond = sanitizationMap[ar.entity2] ?? ar.entity2
            if aMappedFirst != br.entity1 || aMappedSecond != br.entity2 {
                deltas.append(.unexpected(
                    path: "relationships[\(i)].endpoints",
                    detail: "lhs=(\(ar.entity1)→\(ar.entity2)) rhs=(\(br.entity1)→\(br.entity2))"
                ))
            }
            if ar.label != br.label {
                deltas.append(.unexpected(
                    path: "relationships[\(i)].label",
                    detail: "lhs=\(ar.label) rhs=\(br.label)"
                ))
            }
            if ar.cardinality1 != br.cardinality1 || ar.cardinality2 != br.cardinality2 {
                deltas.append(.unexpected(
                    path: "relationships[\(i)].cardinality",
                    detail: "lhs=\(ar.cardinality1)/\(ar.cardinality2) rhs=\(br.cardinality1)/\(br.cardinality2)"
                ))
            }
        }
    }

    return deltas
}

private func erRelOrder(_ lhs: ErRelationship, _ rhs: ErRelationship) -> Bool {
    let lk = "\(lhs.entity1)|\(lhs.entity2)|\(lhs.label)"
    let rk = "\(rhs.entity1)|\(rhs.entity2)|\(rhs.label)"
    return lk < rk
}

private func diffEntityIDs(
    a: [String: ErEntity],
    b: [String: ErEntity],
    deltas: inout [RoundTripDelta]
) -> [String: String] {
    var sanitizationMap: [String: String] = [:]
    let onlyA = Set(a.keys).subtracting(b.keys)
    let onlyB = Set(b.keys).subtracting(a.keys)
    var pairedRhs: Set<String> = []
    for aID in onlyA {
        guard let aEntity = a[aID] else { continue }
        let match = onlyB.first { bID in
            !pairedRhs.contains(bID) && b[bID]?.label == aEntity.label
        }
        if let bID = match {
            deltas.append(.loss(.idSanitization(original: aID, sanitized: bID)))
            sanitizationMap[aID] = bID
            pairedRhs.insert(bID)
        } else {
            deltas.append(.unexpected(path: "entities", detail: "lhs-only id=\(aID)"))
        }
    }
    for bID in onlyB where !pairedRhs.contains(bID) {
        deltas.append(.unexpected(path: "entities", detail: "rhs-only id=\(bID)"))
    }
    return sanitizationMap
}

import DiagramKitModel

func diffSequenceDiagram(_ a: SequenceDiagram, _ b: SequenceDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    // Compare derived actor lists. Sequence diagrams identify actors by id.
    // Mermaid round-trip preserves actor declarations + implicit-from-message
    // creation; comparison is by id with sanitization pairing on label match.
    let aActors = Dictionary(uniqueKeysWithValues: a.actors.map { ($0.id, $0) })
    let bActors = Dictionary(uniqueKeysWithValues: b.actors.map { ($0.id, $0) })
    let sanitizationMap = diffActorIDs(a: aActors, b: bActors, deltas: &deltas)

    // 2) Per-actor label comparison (with sanitization map).
    for (id, aActor) in aActors {
        let mappedID = sanitizationMap[id] ?? id
        guard let bActor = bActors[mappedID] else { continue }
        if aActor.label != bActor.label {
            deltas.append(.unexpected(
                path: "actors[\(id)].label",
                detail: "lhs=\(aActor.label) rhs=\(bActor.label)"
            ))
        }
    }

    // 3) Messages — sequence order is semantically significant, so compare
    // positionally without sorting. Length mismatch is unexpected.
    if a.messages.count != b.messages.count {
        deltas.append(.unexpected(
            path: "messages.count",
            detail: "lhs=\(a.messages.count) rhs=\(b.messages.count)"
        ))
    } else {
        for (i, (am, bm)) in zip(a.messages, b.messages).enumerated() {
            let aMappedFrom = sanitizationMap[am.from] ?? am.from
            let aMappedTo = sanitizationMap[am.to] ?? am.to
            if aMappedFrom != bm.from || aMappedTo != bm.to {
                deltas.append(.unexpected(
                    path: "messages[\(i)].endpoints",
                    detail: "lhs=(\(am.from)→\(am.to)) rhs=(\(bm.from)→\(bm.to))"
                ))
            }
            if am.label != bm.label {
                deltas.append(.unexpected(
                    path: "messages[\(i)].label",
                    detail: "lhs=\(am.label) rhs=\(bm.label)"
                ))
            }
            if am.arrowType != bm.arrowType {
                deltas.append(.unexpected(
                    path: "messages[\(i)].arrowType",
                    detail: "lhs=\(am.arrowType) rhs=\(bm.arrowType)"
                ))
            }
        }
    }

    return deltas
}

private func diffActorIDs(
    a: [String: SequenceActor],
    b: [String: SequenceActor],
    deltas: inout [RoundTripDelta]
) -> [String: String] {
    var sanitizationMap: [String: String] = [:]
    let onlyA = Set(a.keys).subtracting(b.keys)
    let onlyB = Set(b.keys).subtracting(a.keys)
    var pairedRhs: Set<String> = []
    for aID in onlyA {
        guard let aActor = a[aID] else { continue }
        let match = onlyB.first { bID in
            !pairedRhs.contains(bID) && b[bID]?.label == aActor.label
        }
        if let bID = match {
            deltas.append(.loss(.idSanitization(original: aID, sanitized: bID)))
            sanitizationMap[aID] = bID
            pairedRhs.insert(bID)
        } else {
            deltas.append(.unexpected(path: "actors", detail: "lhs-only id=\(aID)"))
        }
    }
    for bID in onlyB where !pairedRhs.contains(bID) {
        deltas.append(.unexpected(path: "actors", detail: "rhs-only id=\(bID)"))
    }
    return sanitizationMap
}

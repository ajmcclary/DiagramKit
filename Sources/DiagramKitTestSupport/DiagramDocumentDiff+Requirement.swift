import DiagramKitModel

func diffRequirementDiagram(_ a: RequirementDiagram, _ b: RequirementDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "requirement.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }
    if a.direction != b.direction {
        deltas.append(.unexpected(
            path: "requirement.direction",
            detail: "lhs=\(a.direction) rhs=\(b.direction)"
        ))
    }

    let aReqs = a.requirements.sorted { $0.name < $1.name }
    let bReqs = b.requirements.sorted { $0.name < $1.name }
    if aReqs.count != bReqs.count {
        deltas.append(.unexpected(
            path: "requirement.requirements.count",
            detail: "lhs=\(aReqs.count) rhs=\(bReqs.count)"
        ))
    } else {
        for (i, (l, r)) in zip(aReqs, bReqs).enumerated() {
            if l.name != r.name
                || l.type != r.type
                || l.requirementId != r.requirementId
                || l.text != r.text
                || l.risk != r.risk
                || l.verifyMethod != r.verifyMethod {
                deltas.append(.unexpected(
                    path: "requirement.requirements[\(i)]",
                    detail: "lhs=\(l.name):\(l.type) id=\(l.requirementId) text=\(l.text) risk=\(String(describing: l.risk)) vm=\(String(describing: l.verifyMethod)) rhs=\(r.name):\(r.type) id=\(r.requirementId) text=\(r.text) risk=\(String(describing: r.risk)) vm=\(String(describing: r.verifyMethod))"
                ))
            }
        }
    }

    let aElems = a.elements.sorted { $0.name < $1.name }
    let bElems = b.elements.sorted { $0.name < $1.name }
    if aElems.count != bElems.count {
        deltas.append(.unexpected(
            path: "requirement.elements.count",
            detail: "lhs=\(aElems.count) rhs=\(bElems.count)"
        ))
    } else {
        for (i, (l, r)) in zip(aElems, bElems).enumerated() {
            if l.name != r.name || l.type != r.type || l.docRef != r.docRef {
                deltas.append(.unexpected(
                    path: "requirement.elements[\(i)]",
                    detail: "lhs=\(l.name):\(l.type):\(l.docRef) rhs=\(r.name):\(r.type):\(r.docRef)"
                ))
            }
        }
    }

    func relKey(_ r: RequirementRelationship) -> String {
        let (s, t) = r.isReversed
            ? (r.destinationName, r.sourceName)
            : (r.sourceName, r.destinationName)
        return "\(s)|\(t)|\(r.type.rawValue)"
    }
    let lhs = Set(a.relationships.map(relKey))
    let rhs = Set(b.relationships.map(relKey))
    if lhs != rhs {
        deltas.append(.unexpected(
            path: "requirement.relationships",
            detail: "onlyLhs=\(lhs.subtracting(rhs).sorted()) onlyRhs=\(rhs.subtracting(lhs).sorted())"
        ))
    }
    return deltas
}

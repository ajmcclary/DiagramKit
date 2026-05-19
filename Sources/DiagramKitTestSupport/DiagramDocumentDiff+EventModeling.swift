import DiagramKitModel

func diffEventModelingDiagram(_ a: EventModelingDiagram, _ b: EventModelingDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "eventmodeling.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }

    func frameKey(_ f: EventModelingFrame) -> String {
        let srcs = f.sourceFrameNames.joined(separator: ",")
        return "\(f.name)|\(f.modelEntityType.rawValue)|\(f.entityIdentifier)|reset=\(f.isResetFrame)|src=\(srcs)|dref=\(f.dataReferenceName ?? "")|dtyp=\(f.dataInlineType?.rawValue ?? "")|dval=\(f.dataInlineValue ?? "")"
    }
    let aFrames = Set(a.frames.map(frameKey))
    let bFrames = Set(b.frames.map(frameKey))
    if aFrames != bFrames {
        deltas.append(.unexpected(
            path: "eventmodeling.frames",
            detail: "onlyLhs=\(aFrames.subtracting(bFrames).sorted()) onlyRhs=\(bFrames.subtracting(aFrames).sorted())"
        ))
    }

    let aEntities = Set(a.modelEntities.map { $0.name })
    let bEntities = Set(b.modelEntities.map { $0.name })
    if aEntities != bEntities {
        deltas.append(.unexpected(
            path: "eventmodeling.modelEntities",
            detail: "onlyLhs=\(aEntities.subtracting(bEntities).sorted()) onlyRhs=\(bEntities.subtracting(aEntities).sorted())"
        ))
    }

    func dataKey(_ d: EventModelingDataEntity) -> String {
        "\(d.name)|\(d.dataType?.rawValue ?? "")|\(d.dataBlockValue)"
    }
    let aData = Set(a.dataEntities.map(dataKey))
    let bData = Set(b.dataEntities.map(dataKey))
    if aData != bData {
        deltas.append(.unexpected(
            path: "eventmodeling.dataEntities",
            detail: "onlyLhs=\(aData.subtracting(bData).sorted()) onlyRhs=\(bData.subtracting(aData).sorted())"
        ))
    }

    func gwtKey(_ g: EventModelingGwtEntity) -> String {
        func stmts(_ ss: [EventModelingGwtStatement]) -> String {
            ss.map { "\($0.entityType.rawValue):\($0.modelEntityName)" }.joined(separator: ",")
        }
        return "\(g.sourceFrameName)|G=\(stmts(g.givenStatements))|W=\(stmts(g.whenStatements))|T=\(stmts(g.thenStatements))"
    }
    let aGwt = Set(a.gwtEntities.map(gwtKey))
    let bGwt = Set(b.gwtEntities.map(gwtKey))
    if aGwt != bGwt {
        deltas.append(.unexpected(
            path: "eventmodeling.gwtEntities",
            detail: "onlyLhs=\(aGwt.subtracting(bGwt).sorted()) onlyRhs=\(bGwt.subtracting(aGwt).sorted())"
        ))
    }
    return deltas
}

import DiagramKitModel

func diffZenUMLDiagram(_ a: ZenUMLDiagram, _ b: ZenUMLDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.title != b.title {
        deltas.append(.unexpected(
            path: "zenuml.title",
            detail: "lhs=\(a.title ?? "nil") rhs=\(b.title ?? "nil")"
        ))
    }

    let aPart = Set(a.participants.filter { $0.explicit }.map { $0.name })
    let bPart = Set(b.participants.filter { $0.explicit }.map { $0.name })
    if aPart != bPart {
        deltas.append(.unexpected(
            path: "zenuml.participants",
            detail: "onlyLhs=\(aPart.subtracting(bPart).sorted()) onlyRhs=\(bPart.subtracting(aPart).sorted())"
        ))
    }

    if a.statements.count != b.statements.count {
        deltas.append(.unexpected(
            path: "zenuml.statements.count",
            detail: "lhs=\(a.statements.count) rhs=\(b.statements.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(a.statements, b.statements).enumerated() {
        diffZenUMLStatement(l, r, path: "zenuml.statements[\(i)]", deltas: &deltas)
    }
    return deltas
}

private func diffZenUMLStatement(
    _ a: ZenUMLStatement,
    _ b: ZenUMLStatement,
    path: String,
    deltas: inout [RoundTripDelta]
) {
    switch (a, b) {
    case let (.message(af, at, asig, atyp, ablk, _),
              .message(bf, bt, bsig, btyp, bblk, _)):
        if af != bf || at != bt || asig != bsig || atyp != btyp {
            deltas.append(.unexpected(
                path: "\(path).message",
                detail: "lhs=\(af)->\(at):\(asig)[\(atyp)] rhs=\(bf)->\(bt):\(bsig)[\(btyp)]"
            ))
        }
        let aBlock = ablk ?? []
        let bBlock = bblk ?? []
        if aBlock.count != bBlock.count {
            deltas.append(.unexpected(
                path: "\(path).message.block.count",
                detail: "lhs=\(aBlock.count) rhs=\(bBlock.count)"
            ))
        } else {
            for (i, (l, r)) in zip(aBlock, bBlock).enumerated() {
                diffZenUMLStatement(l, r, path: "\(path).message.block[\(i)]", deltas: &deltas)
            }
        }
    case let (.asyncMessage(af, at, ac, _), .asyncMessage(bf, bt, bc, _)):
        if af != bf || at != bt || ac != bc {
            deltas.append(.unexpected(
                path: "\(path).async",
                detail: "lhs=\(af)->\(at):\(ac ?? "nil") rhs=\(bf)->\(bt):\(bc ?? "nil")"
            ))
        }
    case let (.return(af, at, av, _), .return(bf, bt, bv, _)):
        if af != bf || at != bt || av != bv {
            deltas.append(.unexpected(
                path: "\(path).return",
                detail: "lhs=\(af)->\(at):\(av ?? "nil") rhs=\(bf)->\(bt):\(bv ?? "nil")"
            ))
        }
    case let (.fragment(akind, acond, asecs), .fragment(bkind, bcond, bsecs)):
        if akind != bkind || acond != bcond || asecs.count != bsecs.count {
            deltas.append(.unexpected(
                path: "\(path).fragment.shape",
                detail: "lhs=\(akind):\(acond ?? "nil") secs=\(asecs.count) rhs=\(bkind):\(bcond ?? "nil") secs=\(bsecs.count)"
            ))
            return
        }
        for (s, (asec, bsec)) in zip(asecs, bsecs).enumerated() {
            if asec.label != bsec.label || asec.statements.count != bsec.statements.count {
                deltas.append(.unexpected(
                    path: "\(path).fragment.section[\(s)]",
                    detail: "lhs=\(asec.label) stmts=\(asec.statements.count) rhs=\(bsec.label) stmts=\(bsec.statements.count)"
                ))
                continue
            }
            for (i, (l, r)) in zip(asec.statements, bsec.statements).enumerated() {
                diffZenUMLStatement(l, r, path: "\(path).fragment.section[\(s)].stmt[\(i)]", deltas: &deltas)
            }
        }
    case let (.divider(al), .divider(bl)):
        if al != bl {
            deltas.append(.unexpected(path: "\(path).divider", detail: "lhs=\(al) rhs=\(bl)"))
        }
    case let (.comment(at), .comment(bt)):
        if at != bt {
            deltas.append(.unexpected(path: "\(path).comment", detail: "lhs=\(at) rhs=\(bt)"))
        }
    case let (.creation(aas, atyp, ac, at, ap, _, _),
              .creation(bas, btyp, bc, bt, bp, _, _)):
        if aas != bas || atyp != btyp || ac != bc || at != bt || (ap ?? []) != (bp ?? []) {
            deltas.append(.unexpected(
                path: "\(path).creation",
                detail: "lhs=\(aas ?? "nil")=\(atyp ?? "nil"):\(ac)->\(at) rhs=\(bas ?? "nil")=\(btyp ?? "nil"):\(bc)->\(bt)"
            ))
        }
    default:
        deltas.append(.unexpected(
            path: "\(path).kind",
            detail: "lhs=\(String(describing: a)) rhs=\(String(describing: b))"
        ))
    }
}

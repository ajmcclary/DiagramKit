import DiagramKitModel

func diffPacketDiagram(_ a: PacketDiagram, _ b: PacketDiagram) -> [RoundTripDelta] {
    var deltas: [RoundTripDelta] = []

    if a.diagramTitle != b.diagramTitle {
        deltas.append(.unexpected(
            path: "packet.title",
            detail: "lhs=\(a.diagramTitle ?? "nil") rhs=\(b.diagramTitle ?? "nil")"
        ))
    }

    // Flatten rows: the parser may re-pack into rows differently
    // depending on `config.bitsPerRow`, but the block sequence must
    // match.
    let lhs = a.rows.flatMap { $0 }
    let rhs = b.rows.flatMap { $0 }
    if lhs.count != rhs.count {
        deltas.append(.unexpected(
            path: "packet.blocks.count",
            detail: "lhs=\(lhs.count) rhs=\(rhs.count)"
        ))
        return deltas
    }
    for (i, (l, r)) in zip(lhs, rhs).enumerated() {
        if l.start != r.start || l.end != r.end || l.label != r.label {
            deltas.append(.unexpected(
                path: "packet.blocks[\(i)]",
                detail: "lhs=\(l.start)-\(l.end):'\(l.label)' rhs=\(r.start)-\(r.end):'\(r.label)'"
            ))
        }
    }
    return deltas
}

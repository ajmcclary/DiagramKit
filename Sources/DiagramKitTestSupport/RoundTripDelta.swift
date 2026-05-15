/// One categorised divergence between two `DiagramDocument`s in a round-trip
/// comparison. `.loss(_)` is an explainable, kind-tagged divergence;
/// `.unexpected(_, _)` is always a test failure (either a real regression or
/// a taxonomy gap surfaced through CI).
public enum RoundTripDelta: Hashable, Sendable, CustomStringConvertible {
    case loss(RoundTripLoss)
    case unexpected(path: String, detail: String)

    public var description: String {
        switch self {
        case .loss(let loss):
            return ".loss(\(loss))"
        case .unexpected(let path, let detail):
            return ".unexpected(path: \(path), detail: \(detail))"
        }
    }
}

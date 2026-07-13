import DesignKitThemes

struct RoundTripSummary: Equatable {
    let lossCount: Int
    let categories: [String]
    let status: DSStatusKind
    let label: String
}

struct SaveFeedback: Equatable {
    let label: String
    let status: DSStatusKind

    static func success(_ message: String) -> SaveFeedback {
        SaveFeedback(label: message, status: .success)
    }

    static func failure(_ message: String) -> SaveFeedback {
        SaveFeedback(label: message, status: .error)
    }
}

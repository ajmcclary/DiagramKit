import Foundation
import DiagramKitCommon

public enum PlantUMLRecoveryMarker {

    public enum Kind: Sendable, Equatable {
        case activityPartition(originalId: String, partition: String)
        case activityOriginalId(syntheticId: String, originalId: String)
        case sequenceParticipantLink(participantId: String, url: String)
        case sequenceParticipantProperty(participantId: String, key: String, value: String)
        case sequenceParticipantDetails(participantId: String, base64: String)
    }

    /// PlantUML uses `'` for line comments, not `#`. Markers are line-form
    /// only; block-comment-wrapped (`/' ... '/`) markers are intentionally
    /// ignored — the scanner only inspects leading whitespace + first
    /// non-whitespace token per line.
    public static let scanner = RecoveryMarkerScanner<Kind>(commentPrefix: "'") { rest in
        parseKind(rest)
    }

    // MARK: - Parsing

    private static func parseKind(_ rest: String) -> Kind? {
        if let args = stripPrefix("activity-partition=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .activityPartition(originalId: String(fields[0]), partition: String(fields[1]))
        }
        if let args = stripPrefix("activity-original-id=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .activityOriginalId(syntheticId: String(fields[0]), originalId: String(fields[1]))
        }
        if let args = stripPrefix("sequence-participant-link=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .sequenceParticipantLink(participantId: String(fields[0]), url: String(fields[1]))
        }
        if let args = stripPrefix("sequence-participant-property=", rest) {
            let fields = args.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3 else { return nil }
            return .sequenceParticipantProperty(participantId: String(fields[0]), key: String(fields[1]), value: String(fields[2]))
        }
        if let args = stripPrefix("sequence-participant-details=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, fields[1].hasPrefix("b64:") else { return nil }
            return .sequenceParticipantDetails(participantId: String(fields[0]), base64: String(fields[1].dropFirst(4)))
        }
        return nil
    }

    private static func stripPrefix(_ prefix: String, _ s: String) -> String? {
        guard s.hasPrefix(prefix) else { return nil }
        return String(s.dropFirst(prefix.count))
    }

    // MARK: - Emission

    public static func emitActivityPartition(originalId: String, partition: String) -> String {
        "' diagramkit:activity-partition=\(sanitize(originalId)),\(sanitize(partition))"
    }

    public static func emitActivityOriginalId(syntheticId: String, originalId: String) -> String {
        "' diagramkit:activity-original-id=\(sanitize(syntheticId)),\(sanitize(originalId))"
    }

    public static func emitSequenceParticipantLink(participantId: String, url: String) -> String {
        "' diagramkit:sequence-participant-link=\(sanitize(participantId)),\(sanitize(url))"
    }

    public static func emitSequenceParticipantProperty(participantId: String, key: String, value: String) -> String {
        "' diagramkit:sequence-participant-property=\(sanitize(participantId)),\(sanitize(key)),\(sanitize(value))"
    }

    public static func emitSequenceParticipantDetails(participantId: String, details: String) -> String {
        let base64 = Data(details.utf8).base64EncodedString()
        return "' diagramkit:sequence-participant-details=\(sanitize(participantId)),b64:\(base64)"
    }

    private static func sanitize(_ value: String) -> String {
        var out = ""
        for ch in value {
            switch ch {
            case "\n", "\r", "\"":
                out.append(" ")
            default:
                out.append(ch)
            }
        }
        return out
    }
}

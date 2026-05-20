import Foundation
import DiagramKitCommon

public enum PlantUMLRecoveryMarker {

    public enum Kind: Sendable, Equatable {
        case activityPartition(originalId: String, partition: String)
        case activityOriginalId(syntheticId: String, originalId: String)
        case sequenceParticipantLink(participantId: String, label: String, url: String)
        case sequenceParticipantLinks(participantId: String, base64Json: String)
        case sequenceParticipantProperties(participantId: String, base64Json: String)
        case sequenceParticipantDetails(participantId: String, elementId: String)
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
            let fields = args.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3 else { return nil }
            return .sequenceParticipantLink(
                participantId: String(fields[0]),
                label: String(fields[1]),
                url: String(fields[2])
            )
        }
        if let args = stripPrefix("sequence-participant-links=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, fields[1].hasPrefix("b64:") else { return nil }
            return .sequenceParticipantLinks(participantId: String(fields[0]), base64Json: String(fields[1].dropFirst(4)))
        }
        if let args = stripPrefix("sequence-participant-properties=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, fields[1].hasPrefix("b64:") else { return nil }
            return .sequenceParticipantProperties(participantId: String(fields[0]), base64Json: String(fields[1].dropFirst(4)))
        }
        if let args = stripPrefix("sequence-participant-details=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .sequenceParticipantDetails(participantId: String(fields[0]), elementId: String(fields[1]))
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

    public static func emitSequenceParticipantLink(participantId: String, label: String, url: String) -> String {
        "' diagramkit:sequence-participant-link=\(sanitize(participantId)),\(sanitize(label)),\(sanitize(url))"
    }

    public static func emitSequenceParticipantLinks(participantId: String, json: String) -> String {
        let base64 = Data(json.utf8).base64EncodedString()
        return "' diagramkit:sequence-participant-links=\(sanitize(participantId)),b64:\(base64)"
    }

    public static func emitSequenceParticipantProperties(participantId: String, json: String) -> String {
        let base64 = Data(json.utf8).base64EncodedString()
        return "' diagramkit:sequence-participant-properties=\(sanitize(participantId)),b64:\(base64)"
    }

    public static func emitSequenceParticipantDetails(participantId: String, elementId: String) -> String {
        "' diagramkit:sequence-participant-details=\(sanitize(participantId)),\(sanitize(elementId))"
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

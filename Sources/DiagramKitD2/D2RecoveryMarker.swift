import Foundation
import DiagramKitCommon

public enum D2RecoveryMarker {

    public enum StateActionPhase: String, Sendable, Equatable {
        case entry, exit
    }

    public enum Kind: Sendable, Equatable {
        case classStereotype(className: String, stereotype: String)
        case stateAction(ownerStateId: String, phase: StateActionPhase, label: String)
        case erCardinality(relationshipId: String, source: String, target: String)
        case archIcon(serviceID: String, kindRawValue: String)
        case archGroup(groupID: String, parentGroupID: String)
        case family(name: String)
    }

    public static let scanner = RecoveryMarkerScanner<Kind>(commentPrefix: "#") { rest in
        parseKind(rest)
    }

    // MARK: - Parsing

    private static func parseKind(_ rest: String) -> Kind? {
        if let args = stripPrefix("class-stereotype=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .classStereotype(className: String(fields[0]), stereotype: String(fields[1]))
        }
        if let args = stripPrefix("state-action=", rest) {
            let fields = args.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3, let phase = StateActionPhase(rawValue: String(fields[1])) else { return nil }
            return .stateAction(ownerStateId: String(fields[0]), phase: phase, label: String(fields[2]))
        }
        if let args = stripPrefix("er-cardinality=", rest) {
            let fields = args.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3 else { return nil }
            return .erCardinality(relationshipId: String(fields[0]), source: String(fields[1]), target: String(fields[2]))
        }
        return nil
    }

    private static func stripPrefix(_ prefix: String, _ s: String) -> String? {
        guard s.hasPrefix(prefix) else { return nil }
        return String(s.dropFirst(prefix.count))
    }

    // MARK: - Emission

    public static func emitClassStereotype(className: String, stereotype: String) -> String {
        "# diagramkit:class-stereotype=\(sanitize(className)),\(sanitize(stereotype))"
    }

    public static func emitStateAction(ownerStateId: String, phase: StateActionPhase, label: String) -> String {
        "# diagramkit:state-action=\(sanitize(ownerStateId)),\(phase.rawValue),\(sanitize(label))"
    }

    public static func emitERCardinality(relationshipId: String, source: String, target: String) -> String {
        "# diagramkit:er-cardinality=\(sanitize(relationshipId)),\(sanitize(source)),\(sanitize(target))"
    }

    public static func emitArchIcon(serviceID: String, kindRawValue: String) -> String {
        "# diagramkit:arch-icon=\(sanitize(serviceID)),\(sanitize(kindRawValue))"
    }

    public static func emitArchGroup(groupID: String, parentGroupID: String) -> String {
        "# diagramkit:arch-group=\(sanitize(groupID)),\(sanitize(parentGroupID))"
    }

    public static func emitFamily(_ name: String) -> String {
        "# diagramkit:family=\(name)"
    }

    /// Replace newline/quote/CR with space-replacements to keep the
    /// comma-separated arg grammar parseable. Mirrors Wave 3 Structurizr.
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

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
        case treeRoot(rootID: String)
        case mindmapIcon(nodeID: String, iconKey: String)
        case seqActorKind(actorID: String, participantType: String)
        case seqArrowType(messageIndex: Int, rawValue: Int)
        case seqMessageAttr(messageIndex: Int, attr: String)
        case seqBlockType(containerLabel: String, blockType: String)
        case seqBlockDivider(containerLabel: String, dividerIndex: Int, label: String)
        case seqNote(afterMessageIndex: Int, position: String, actorIDsCsv: String, text: String)
        case seqBox(containerLabel: String, fill: String, wrap: Bool, name: String)
        case seqAutonumber(start: Double, step: Double, visible: Bool)
        case seqTitle(text: String)
        case seqAccTitle(text: String)
        case seqAccDescr(text: String)
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
        if let args = stripPrefix("arch-icon=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .archIcon(serviceID: String(fields[0]), kindRawValue: String(fields[1]))
        }
        if let args = stripPrefix("arch-group=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .archGroup(groupID: String(fields[0]), parentGroupID: String(fields[1]))
        }
        if let args = stripPrefix("family=", rest) {
            return .family(name: args)
        }
        if let args = stripPrefix("tree-root=", rest) {
            return .treeRoot(rootID: args)
        }
        if let args = stripPrefix("mindmap-icon=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .mindmapIcon(nodeID: String(fields[0]), iconKey: String(fields[1]))
        }
        if let args = stripPrefix("seq-actor-kind=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .seqActorKind(actorID: String(fields[0]), participantType: String(fields[1]))
        }
        if let args = stripPrefix("seq-arrow-type=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, let idx = Int(fields[0]), let raw = Int(fields[1]) else { return nil }
            return .seqArrowType(messageIndex: idx, rawValue: raw)
        }
        if let args = stripPrefix("seq-message-attr=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, let idx = Int(fields[0]) else { return nil }
            return .seqMessageAttr(messageIndex: idx, attr: String(fields[1]))
        }
        if let args = stripPrefix("seq-block-type=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .seqBlockType(containerLabel: String(fields[0]), blockType: String(fields[1]))
        }
        if let args = stripPrefix("seq-block-divider=", rest) {
            let fields = args.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3, let idx = Int(fields[1]) else { return nil }
            return .seqBlockDivider(containerLabel: String(fields[0]), dividerIndex: idx, label: String(fields[2]))
        }
        if let args = stripPrefix("seq-note=", rest) {
            let fields = args.split(separator: ",", maxSplits: 3, omittingEmptySubsequences: false)
            guard fields.count == 4, let after = Int(fields[0]) else { return nil }
            return .seqNote(
                afterMessageIndex: after,
                position: String(fields[1]),
                actorIDsCsv: String(fields[2]),
                text: String(fields[3])
            )
        }
        if let args = stripPrefix("seq-box=", rest) {
            let fields = args.split(separator: ",", maxSplits: 3, omittingEmptySubsequences: false)
            guard fields.count == 4 else { return nil }
            let wrap = (String(fields[2]).lowercased() == "true")
            return .seqBox(containerLabel: String(fields[0]), fill: String(fields[1]), wrap: wrap, name: String(fields[3]))
        }
        if let args = stripPrefix("seq-autonumber=", rest) {
            let fields = args.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false)
            guard fields.count == 3, let start = Double(fields[0]), let step = Double(fields[1]) else { return nil }
            let visible = (String(fields[2]).lowercased() == "true")
            return .seqAutonumber(start: start, step: step, visible: visible)
        }
        if let args = stripPrefix("seq-title=", rest) {
            return .seqTitle(text: args)
        }
        if let args = stripPrefix("seq-acc-title=", rest) {
            return .seqAccTitle(text: args)
        }
        if let args = stripPrefix("seq-acc-descr=", rest) {
            return .seqAccDescr(text: args)
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

    public static func emitTreeRoot(_ id: String) -> String {
        "# diagramkit:tree-root=\(sanitize(id))"
    }

    public static func emitMindmapIcon(nodeID: String, iconKey: String) -> String {
        "# diagramkit:mindmap-icon=\(sanitize(nodeID)),\(sanitize(iconKey))"
    }

    public static func emitSeqActorKind(actorID: String, participantType: String) -> String {
        "# diagramkit:seq-actor-kind=\(sanitize(actorID)),\(sanitize(participantType))"
    }

    public static func emitSeqArrowType(messageIndex: Int, rawValue: Int) -> String {
        "# diagramkit:seq-arrow-type=\(messageIndex),\(rawValue)"
    }

    public static func emitSeqMessageAttr(messageIndex: Int, attr: String) -> String {
        "# diagramkit:seq-message-attr=\(messageIndex),\(sanitize(attr))"
    }

    public static func emitSeqBlockType(containerLabel: String, blockType: String) -> String {
        "# diagramkit:seq-block-type=\(sanitize(containerLabel)),\(sanitize(blockType))"
    }

    public static func emitSeqBlockDivider(containerLabel: String, dividerIndex: Int, label: String) -> String {
        "# diagramkit:seq-block-divider=\(sanitize(containerLabel)),\(dividerIndex),\(sanitize(label))"
    }

    public static func emitSeqNote(afterMessageIndex: Int, position: String, actorIDsCsv: String, text: String) -> String {
        "# diagramkit:seq-note=\(afterMessageIndex),\(sanitize(position)),\(sanitize(actorIDsCsv)),\(sanitize(text))"
    }

    public static func emitSeqBox(containerLabel: String, fill: String, wrap: Bool, name: String) -> String {
        "# diagramkit:seq-box=\(sanitize(containerLabel)),\(sanitize(fill)),\(wrap),\(sanitize(name))"
    }

    public static func emitSeqAutonumber(start: Double, step: Double, visible: Bool) -> String {
        "# diagramkit:seq-autonumber=\(start),\(step),\(visible)"
    }

    public static func emitSeqTitle(_ text: String) -> String {
        "# diagramkit:seq-title=\(sanitize(text))"
    }

    public static func emitSeqAccTitle(_ text: String) -> String {
        "# diagramkit:seq-acc-title=\(sanitize(text))"
    }

    public static func emitSeqAccDescr(_ text: String) -> String {
        "# diagramkit:seq-acc-descr=\(sanitize(text))"
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

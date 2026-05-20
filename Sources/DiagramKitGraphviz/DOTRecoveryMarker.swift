import Foundation
import DiagramKitCommon

public enum DOTRecoveryMarker {

    public enum Kind: Sendable, Equatable {
        case classStereotype(className: String, stereotype: String)
        case erCardinality(relationshipId: String, source: String, target: String)
        case archIcon(serviceID: String, kindRawValue: String)
        case archGroup(groupID: String, parentGroupID: String)
        case family(name: String)
        case treeRoot(rootID: String)
        case mindmapIcon(nodeID: String, iconKey: String)
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

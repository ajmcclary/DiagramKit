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
        case c4DiagramKind(rawValue: String)
        case c4ShapeKind(targetID: String, rawValue: String)
        case c4External(targetID: String)
        case c4Technology(targetID: String, value: String)
        case c4Description(targetID: String, value: String)
        case c4Sprite(targetID: String, value: String)
        case c4Tag(targetID: String, value: String)
        case c4Link(targetID: String, value: String)
        case c4BoundaryKind(targetID: String, rawValue: String)
        case c4RelKind(edgeIndex: Int, rawValue: String)
        case c4Color(targetID: String, packed: String)
        case blockCols(containerID: String, columns: Int)
        case blockWidth(nodeID: String, widthInColumns: Int)
        case blockShapeFallback(nodeID: String, rawValue: String)
        case blockArrowDir(nodeID: String, directionsCsv: String)
        case blockSpace(parentID: String, columnIndex: Int)
        case blockEdgeAttrs(
            edgeIndex: Int,
            thickness: String,
            pattern: String,
            arrowStart: String,
            arrowEnd: String
        )
        case blockClassDef(className: String, stylesCsv: String)
        case blockClassApply(nodeID: String, className: String)
        case blockStyle(nodeID: String, stylesCsv: String)
        case blockAccTitle(text: String)
        case blockAccDescr(text: String)
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
        if let args = stripPrefix("c4-diagram-kind=", rest) {
            return .c4DiagramKind(rawValue: args)
        }
        if let args = stripPrefix("c4-shape-kind=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .c4ShapeKind(targetID: String(fields[0]), rawValue: String(fields[1]))
        }
        if let args = stripPrefix("c4-external=", rest) {
            return .c4External(targetID: args)
        }
        if let args = stripPrefix("c4-technology=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .c4Technology(targetID: String(fields[0]), value: String(fields[1]))
        }
        if let args = stripPrefix("c4-description=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .c4Description(targetID: String(fields[0]), value: String(fields[1]))
        }
        if let args = stripPrefix("c4-sprite=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .c4Sprite(targetID: String(fields[0]), value: String(fields[1]))
        }
        if let args = stripPrefix("c4-tag=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .c4Tag(targetID: String(fields[0]), value: String(fields[1]))
        }
        if let args = stripPrefix("c4-link=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .c4Link(targetID: String(fields[0]), value: String(fields[1]))
        }
        if let args = stripPrefix("c4-boundary-kind=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .c4BoundaryKind(targetID: String(fields[0]), rawValue: String(fields[1]))
        }
        if let args = stripPrefix("c4-rel-kind=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, let idx = Int(fields[0]) else { return nil }
            return .c4RelKind(edgeIndex: idx, rawValue: String(fields[1]))
        }
        if let args = stripPrefix("c4-color=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .c4Color(targetID: String(fields[0]), packed: String(fields[1]))
        }
        if let args = stripPrefix("block-cols=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, let n = Int(fields[1]) else { return nil }
            return .blockCols(containerID: String(fields[0]), columns: n)
        }
        if let args = stripPrefix("block-width=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, let span = Int(fields[1]) else { return nil }
            return .blockWidth(nodeID: String(fields[0]), widthInColumns: span)
        }
        if let args = stripPrefix("block-shape-fallback=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .blockShapeFallback(nodeID: String(fields[0]), rawValue: String(fields[1]))
        }
        if let args = stripPrefix("block-arrow-dir=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .blockArrowDir(nodeID: String(fields[0]), directionsCsv: String(fields[1]))
        }
        if let args = stripPrefix("block-space=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2, let idx = Int(fields[1]) else { return nil }
            return .blockSpace(parentID: String(fields[0]), columnIndex: idx)
        }
        if let args = stripPrefix("block-edge-attrs=", rest) {
            let fields = args.split(separator: ",", maxSplits: 4, omittingEmptySubsequences: false)
            guard fields.count == 5, let idx = Int(fields[0]) else { return nil }
            return .blockEdgeAttrs(
                edgeIndex: idx,
                thickness: String(fields[1]),
                pattern: String(fields[2]),
                arrowStart: String(fields[3]),
                arrowEnd: String(fields[4])
            )
        }
        if let args = stripPrefix("block-classdef=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .blockClassDef(className: String(fields[0]), stylesCsv: String(fields[1]))
        }
        if let args = stripPrefix("block-class-apply=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .blockClassApply(nodeID: String(fields[0]), className: String(fields[1]))
        }
        if let args = stripPrefix("block-style=", rest) {
            let fields = args.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard fields.count == 2 else { return nil }
            return .blockStyle(nodeID: String(fields[0]), stylesCsv: String(fields[1]))
        }
        if let args = stripPrefix("block-acc-title=", rest) {
            return .blockAccTitle(text: args)
        }
        if let args = stripPrefix("block-acc-descr=", rest) {
            return .blockAccDescr(text: args)
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

    public static func emitC4DiagramKind(_ rawValue: String) -> String {
        "# diagramkit:c4-diagram-kind=\(sanitize(rawValue))"
    }

    public static func emitC4ShapeKind(targetID: String, rawValue: String) -> String {
        "# diagramkit:c4-shape-kind=\(sanitize(targetID)),\(sanitize(rawValue))"
    }

    public static func emitC4External(targetID: String) -> String {
        "# diagramkit:c4-external=\(sanitize(targetID))"
    }

    public static func emitC4Technology(targetID: String, value: String) -> String {
        "# diagramkit:c4-technology=\(sanitize(targetID)),\(sanitize(value))"
    }

    public static func emitC4Description(targetID: String, value: String) -> String {
        "# diagramkit:c4-description=\(sanitize(targetID)),\(sanitize(value))"
    }

    public static func emitC4Sprite(targetID: String, value: String) -> String {
        "# diagramkit:c4-sprite=\(sanitize(targetID)),\(sanitize(value))"
    }

    public static func emitC4Tag(targetID: String, value: String) -> String {
        "# diagramkit:c4-tag=\(sanitize(targetID)),\(sanitize(value))"
    }

    public static func emitC4Link(targetID: String, value: String) -> String {
        "# diagramkit:c4-link=\(sanitize(targetID)),\(sanitize(value))"
    }

    public static func emitC4BoundaryKind(targetID: String, rawValue: String) -> String {
        "# diagramkit:c4-boundary-kind=\(sanitize(targetID)),\(sanitize(rawValue))"
    }

    public static func emitC4RelKind(edgeIndex: Int, rawValue: String) -> String {
        "# diagramkit:c4-rel-kind=\(edgeIndex),\(sanitize(rawValue))"
    }

    public static func emitC4Color(targetID: String, packed: String) -> String {
        "# diagramkit:c4-color=\(sanitize(targetID)),\(sanitize(packed))"
    }

    public static func emitBlockCols(containerID: String, columns: Int) -> String {
        "# diagramkit:block-cols=\(sanitize(containerID)),\(columns)"
    }

    public static func emitBlockWidth(nodeID: String, widthInColumns: Int) -> String {
        "# diagramkit:block-width=\(sanitize(nodeID)),\(widthInColumns)"
    }

    public static func emitBlockShapeFallback(nodeID: String, rawValue: String) -> String {
        "# diagramkit:block-shape-fallback=\(sanitize(nodeID)),\(sanitize(rawValue))"
    }

    public static func emitBlockArrowDir(nodeID: String, directionsCsv: String) -> String {
        "# diagramkit:block-arrow-dir=\(sanitize(nodeID)),\(directionsCsv)"
    }

    public static func emitBlockSpace(parentID: String, columnIndex: Int) -> String {
        "# diagramkit:block-space=\(sanitize(parentID)),\(columnIndex)"
    }

    public static func emitBlockEdgeAttrs(
        edgeIndex: Int,
        thickness: String,
        pattern: String,
        arrowStart: String,
        arrowEnd: String
    ) -> String {
        "# diagramkit:block-edge-attrs=\(edgeIndex),\(sanitize(thickness)),\(sanitize(pattern)),\(sanitize(arrowStart)),\(sanitize(arrowEnd))"
    }

    public static func emitBlockClassDef(className: String, stylesCsv: String) -> String {
        "# diagramkit:block-classdef=\(sanitize(className)),\(stylesCsv)"
    }

    public static func emitBlockClassApply(nodeID: String, className: String) -> String {
        "# diagramkit:block-class-apply=\(sanitize(nodeID)),\(sanitize(className))"
    }

    public static func emitBlockStyle(nodeID: String, stylesCsv: String) -> String {
        "# diagramkit:block-style=\(sanitize(nodeID)),\(stylesCsv)"
    }

    public static func emitBlockAccTitle(_ text: String) -> String {
        "# diagramkit:block-acc-title=\(sanitize(text))"
    }

    public static func emitBlockAccDescr(_ text: String) -> String {
        "# diagramkit:block-acc-descr=\(sanitize(text))"
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

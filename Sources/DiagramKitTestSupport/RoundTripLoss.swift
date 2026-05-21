import DiagramKitModel

/// Typed, closed-set categorization of an allowed-by-design divergence between
/// two `DiagramDocument`s produced by a round-trip (parse → export → parse).
///
/// The enum is intentionally *closed* — new lossy round-trip paths must add a
/// case here rather than slipping through a `case other(String)` escape hatch.
public enum RoundTripLoss: Hashable, Sendable, CustomStringConvertible {
    case idSanitization(original: String, sanitized: String)
    case shapeDowngrade(nodeID: String, from: original_src_types.NodeShape, to: original_src_types.NodeShape)
    case subgraphFlatten(subgraphID: String, depth: Int)
    case boundaryFlatten(boundaryID: String, depth: Int)
    case c4SlotDrop(shapeID: String, slot: C4Slot)
    case titleDrop
    case configDrop(key: String)
    case styleDrop(target: String, attribute: String)
    case accessibilityDrop(field: AccessibilityField)
    case anonymousSubgraphRename(old: String, new: String)
    case d2DuplicateOverride(nodeID: String, attribute: String)
    case classStereotypeDrop(classID: String, stereotype: String)
    case stateActionDrop(stateID: String, phase: StateActionPhase)
    case cardinalityDrop(relationshipID: String, side: CardinalitySide)
    case deploymentShapeFlattened(serviceID: String, kindRawValue: String)
    case deploymentDecorationDropped(serviceID: String, decoration: String)
    case deploymentLegendDropped
    /// Mermaid multi-root treeView input (synthetic `/` container with 2+
    /// children) was flattened on export to a format that cannot represent
    /// multi-root payloads (currently only PlantUML WBS), dropping all but
    /// the first sibling.
    case syntheticRootFlattened

    public var kind: RoundTripLossKind {
        switch self {
        case .idSanitization: return .idSanitization
        case .shapeDowngrade: return .shapeDowngrade
        case .subgraphFlatten: return .subgraphFlatten
        case .boundaryFlatten: return .boundaryFlatten
        case .c4SlotDrop: return .c4SlotDrop
        case .titleDrop: return .titleDrop
        case .configDrop: return .configDrop
        case .styleDrop: return .styleDrop
        case .accessibilityDrop: return .accessibilityDrop
        case .anonymousSubgraphRename: return .anonymousSubgraphRename
        case .d2DuplicateOverride: return .d2DuplicateOverride
        case .classStereotypeDrop: return .classStereotypeDrop
        case .stateActionDrop: return .stateActionDrop
        case .cardinalityDrop: return .cardinalityDrop
        case .deploymentShapeFlattened: return .deploymentShapeFlattened
        case .deploymentDecorationDropped: return .deploymentDecorationDropped
        case .deploymentLegendDropped: return .deploymentLegendDropped
        case .syntheticRootFlattened: return .syntheticRootFlattened
        }
    }

    public var description: String {
        switch self {
        case .idSanitization(let original, let sanitized):
            return "idSanitization(original: \(original), sanitized: \(sanitized))"
        case .shapeDowngrade(let nodeID, let from, let to):
            return "shapeDowngrade(nodeID: \(nodeID), from: \(from), to: \(to))"
        case .subgraphFlatten(let subgraphID, let depth):
            return "subgraphFlatten(subgraphID: \(subgraphID), depth: \(depth))"
        case .boundaryFlatten(let boundaryID, let depth):
            return "boundaryFlatten(boundaryID: \(boundaryID), depth: \(depth))"
        case .c4SlotDrop(let shapeID, let slot):
            return "c4SlotDrop(shapeID: \(shapeID), slot: \(slot))"
        case .titleDrop:
            return "titleDrop"
        case .configDrop(let key):
            return "configDrop(key: \(key))"
        case .styleDrop(let target, let attribute):
            return "styleDrop(target: \(target), attribute: \(attribute))"
        case .accessibilityDrop(let field):
            return "accessibilityDrop(field: \(field))"
        case .anonymousSubgraphRename(let old, let new):
            return "anonymousSubgraphRename(old: \(old), new: \(new))"
        case .d2DuplicateOverride(let nodeID, let attribute):
            return "d2DuplicateOverride(nodeID: \(nodeID), attribute: \(attribute))"
        case .classStereotypeDrop(let classID, let stereotype):
            return "classStereotypeDrop(classID: \(classID), stereotype: \(stereotype))"
        case .stateActionDrop(let stateID, let phase):
            return "stateActionDrop(stateID: \(stateID), phase: \(phase.rawValue))"
        case .cardinalityDrop(let relationshipID, let side):
            return "cardinalityDrop(relationshipID: \(relationshipID), side: \(side.rawValue))"
        case .deploymentShapeFlattened(let serviceID, let raw):
            return "deploymentShapeFlattened(serviceID: \(serviceID), kind: \(raw))"
        case .deploymentDecorationDropped(let serviceID, let decoration):
            return "deploymentDecorationDropped(serviceID: \(serviceID), decoration: \(decoration))"
        case .deploymentLegendDropped:
            return "deploymentLegendDropped"
        case .syntheticRootFlattened:
            return "syntheticRootFlattened"
        }
    }
}

/// Case-tag-only companion to `RoundTripLoss` used for per-cell allow-lists.
/// String-raw so `Codable` works for sidecar JSON declaration; `CaseIterable`
/// so coverage assertions can iterate over every kind.
public enum RoundTripLossKind: String, Hashable, Sendable, CaseIterable, Codable {
    case idSanitization, shapeDowngrade, subgraphFlatten, boundaryFlatten
    case c4SlotDrop, titleDrop, configDrop, styleDrop
    case accessibilityDrop, anonymousSubgraphRename, d2DuplicateOverride
    case classStereotypeDrop, stateActionDrop, cardinalityDrop
    case deploymentShapeFlattened, deploymentDecorationDropped, deploymentLegendDropped
    case syntheticRootFlattened
}

/// State entry/exit action phase identifier — used by
/// `RoundTripLoss.stateActionDrop`.
public enum StateActionPhase: String, Hashable, Sendable, Codable {
    case entry, exit
}

/// ER relationship side identifier — used by
/// `RoundTripLoss.cardinalityDrop`.
public enum CardinalitySide: String, Hashable, Sendable, Codable {
    case source, target
}

/// C4 shape slot identifier — used by `RoundTripLoss.c4SlotDrop`. The
/// availability of each slot varies by `C4ShapeType.hasTechnologySlot`.
public enum C4Slot: String, Hashable, Sendable, Codable {
    case technology, description
}

/// Accessibility metadata field — used by `RoundTripLoss.accessibilityDrop`.
public enum AccessibilityField: String, Hashable, Sendable, Codable {
    case title, description
}

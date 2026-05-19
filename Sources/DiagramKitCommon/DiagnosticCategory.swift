import Foundation

/// Typed category that pins which severity an emission site MUST use.
///
/// Use with `DiagramDiagnostic.lossyTransform(_:message:)`,
/// `.featureDropped(_:message:)`, or `.informational(_:message:)`. See
/// `docs/diagnostic-severity-discipline.md` for the decision tree.
///
/// Each case statically maps to one `DiagramDiagnostic.Severity`. Wrong
/// helper for category is caught by `precondition` in the factory.
public enum DiagnosticCategory: String, Sendable, Hashable, CaseIterable {
    // MARK: - .warning — lossy structural transforms
    case idSanitization
    case shapeDowngrade
    case subgraphFlatten
    case boundaryFlatten
    case c4SlotDrop
    case titleDrop
    case configDrop
    case styleDrop
    case accessibilityDrop
    case anonymousSubgraphRename
    case d2DuplicateOverride
    case labelNewlineEscape           // promoted from .info per spec §1
    case d2InlineCommentStripped      // was silent per spec §1
    case classStereotypeDrop
    case stateActionDrop
    case cardinalityDrop

    // MARK: - .unsupported — feature not available in target format
    case diagramFamilyUnsupported
    case slotUnsupported
    case boundaryTypeUnsupported
    case c4ShapeUnsupported

    // MARK: - .info — encoding-level transforms; round-trip stable
    case identifierEscape
    case commentPreserved

    /// The severity this category implies. Factories `precondition` on this.
    public var severity: DiagramDiagnostic.Severity {
        switch self {
        case .idSanitization, .shapeDowngrade, .subgraphFlatten, .boundaryFlatten,
             .c4SlotDrop, .titleDrop, .configDrop, .styleDrop, .accessibilityDrop,
             .anonymousSubgraphRename, .d2DuplicateOverride,
             .labelNewlineEscape, .d2InlineCommentStripped,
             .classStereotypeDrop, .stateActionDrop, .cardinalityDrop:
            return .warning
        case .diagramFamilyUnsupported, .slotUnsupported,
             .boundaryTypeUnsupported, .c4ShapeUnsupported:
            return .unsupported
        case .identifierEscape, .commentPreserved:
            return .info
        }
    }
}

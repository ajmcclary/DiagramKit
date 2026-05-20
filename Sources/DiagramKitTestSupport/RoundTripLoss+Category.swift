import DiagramKitCommon

extension RoundTripLossKind {
    /// The `DiagnosticCategory` an exporter MUST emit when producing this
    /// round-trip loss. Exhaustive switch — adding a new loss kind forces
    /// a category choice at compile time.
    ///
    /// `anonymousSubgraphRename` returns its own category for completeness,
    /// but `RoundTripHarness.diagnosticsCover` short-circuits on this kind
    /// (anonymous renames are positional parser artifacts, not exporter
    /// emissions).
    internal var expectedCategory: DiagnosticCategory {
        switch self {
        case .idSanitization:          return .idSanitization
        case .shapeDowngrade:          return .shapeDowngrade
        case .subgraphFlatten:         return .subgraphFlatten
        case .boundaryFlatten:         return .boundaryFlatten
        case .c4SlotDrop:              return .c4SlotDrop
        case .titleDrop:               return .titleDrop
        case .configDrop:              return .configDrop
        case .styleDrop:               return .styleDrop
        case .accessibilityDrop:       return .accessibilityDrop
        case .anonymousSubgraphRename: return .anonymousSubgraphRename
        case .d2DuplicateOverride:     return .d2DuplicateOverride
        case .classStereotypeDrop:     return .classStereotypeDrop
        case .stateActionDrop:         return .stateActionDrop
        case .cardinalityDrop:         return .cardinalityDrop
        case .deploymentShapeFlattened:    return .shapeDowngrade
        case .deploymentDecorationDropped: return .slotUnsupported
        case .deploymentLegendDropped:     return .slotUnsupported
        }
    }
}

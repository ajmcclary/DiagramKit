import DiagramKitTestSupport

/// Cross-format additional-allowed-loss sets per ordered direction. Each entry
/// names the foreign format's narrower vocabulary losses that surface only
/// when that format is the intermediate leg of an A→B→A round-trip. The
/// cells themselves come from `RoundTripCellRegistry` directly at the @Test
/// call sites — keeping this registry payload-free avoids generic-shape
/// gymnastics around RoundTripCell<I, E>.
enum RoundTripCrossRegistry {
    // Flowchart pairs
    static let mermaidD2Flowchart: Set<RoundTripLossKind> = [.subgraphFlatten, .styleDrop, .shapeDowngrade]
    static let d2MermaidFlowchart: Set<RoundTripLossKind> = [.idSanitization, .shapeDowngrade]
    static let mermaidDotFlowchart: Set<RoundTripLossKind> = [.subgraphFlatten, .styleDrop, .shapeDowngrade]
    static let dotMermaidFlowchart: Set<RoundTripLossKind> = [.idSanitization, .shapeDowngrade]
    static let d2DotFlowchart: Set<RoundTripLossKind> = [.subgraphFlatten, .styleDrop, .shapeDowngrade]
    static let dotD2Flowchart: Set<RoundTripLossKind> = [.subgraphFlatten, .styleDrop, .shapeDowngrade]

    // C4 pairs
    static let mermaidStructurizrC4: Set<RoundTripLossKind> = [.idSanitization, .boundaryFlatten, .c4SlotDrop, .configDrop]
    static let structurizrMermaidC4: Set<RoundTripLossKind> = [.idSanitization, .boundaryFlatten, .c4SlotDrop, .configDrop]
    static let mermaidPlantumlC4: Set<RoundTripLossKind> = [.idSanitization, .c4SlotDrop, .configDrop]
    static let plantumlMermaidC4: Set<RoundTripLossKind> = [.idSanitization, .c4SlotDrop, .configDrop]
    static let plantumlStructurizrC4: Set<RoundTripLossKind> = [.idSanitization, .boundaryFlatten, .c4SlotDrop]
    static let structurizrPlantumlC4: Set<RoundTripLossKind> = [.idSanitization, .boundaryFlatten, .c4SlotDrop]

    // Sequence pair
    static let mermaidPlantumlSequence: Set<RoundTripLossKind> = [.idSanitization, .configDrop]
    static let plantumlMermaidSequence: Set<RoundTripLossKind> = [.idSanitization, .configDrop]

    // Class pair
    static let mermaidPlantumlClass: Set<RoundTripLossKind> = [.idSanitization]
    static let plantumlMermaidClass: Set<RoundTripLossKind> = [.idSanitization]

    // ER pair (Wave 1 — PlantUML expansion)
    static let mermaidPlantumlEr: Set<RoundTripLossKind> = [.idSanitization, .accessibilityDrop]
    static let plantumlMermaidEr: Set<RoundTripLossKind> = [.idSanitization, .accessibilityDrop]

    // Flowchart pair via PlantUML activity default (Wave 1)
    static let mermaidPlantumlFlowchart: Set<RoundTripLossKind> = [.idSanitization, .subgraphFlatten, .styleDrop, .shapeDowngrade]
    static let plantumlMermaidFlowchart: Set<RoundTripLossKind> = [.idSanitization, .subgraphFlatten, .styleDrop, .shapeDowngrade]

    // Wave 2 — classDiagram cross-format pairs
    static let mermaidD2Class: Set<RoundTripLossKind> = [.idSanitization, .classStereotypeDrop, .styleDrop, .titleDrop]
    static let d2MermaidClass: Set<RoundTripLossKind> = [.idSanitization, .classStereotypeDrop, .styleDrop, .titleDrop]
    static let mermaidDotClass: Set<RoundTripLossKind> = [.idSanitization, .classStereotypeDrop, .styleDrop, .titleDrop]
    static let dotMermaidClass: Set<RoundTripLossKind> = [.idSanitization, .classStereotypeDrop, .styleDrop, .titleDrop]
    static let d2DotClass: Set<RoundTripLossKind> = [.idSanitization, .classStereotypeDrop, .styleDrop, .titleDrop]
    static let dotD2Class: Set<RoundTripLossKind> = [.idSanitization, .classStereotypeDrop, .styleDrop, .titleDrop]

    // Wave 2 — stateDiagram cross-format pairs
    static let mermaidD2State: Set<RoundTripLossKind> = [.idSanitization, .stateActionDrop, .titleDrop, .shapeDowngrade]
    static let d2MermaidState: Set<RoundTripLossKind> = [.idSanitization, .stateActionDrop, .titleDrop, .shapeDowngrade]
    static let mermaidDotState: Set<RoundTripLossKind> = [.idSanitization, .stateActionDrop, .titleDrop, .shapeDowngrade]
    static let dotMermaidState: Set<RoundTripLossKind> = [.idSanitization, .stateActionDrop, .titleDrop, .shapeDowngrade]
    static let d2DotState: Set<RoundTripLossKind> = [.idSanitization, .stateActionDrop, .titleDrop, .shapeDowngrade]
    static let dotD2State: Set<RoundTripLossKind> = [.idSanitization, .stateActionDrop, .titleDrop, .shapeDowngrade]

    // Wave 2 — erDiagram cross-format pairs
    static let mermaidD2Er: Set<RoundTripLossKind> = [.idSanitization, .cardinalityDrop, .titleDrop, .accessibilityDrop]
    static let d2MermaidEr: Set<RoundTripLossKind> = [.idSanitization, .cardinalityDrop, .titleDrop, .accessibilityDrop]
    static let mermaidDotEr: Set<RoundTripLossKind> = [.idSanitization, .cardinalityDrop, .titleDrop, .accessibilityDrop]
    static let dotMermaidEr: Set<RoundTripLossKind> = [.idSanitization, .cardinalityDrop, .titleDrop, .accessibilityDrop]
    static let d2DotEr: Set<RoundTripLossKind> = [.idSanitization, .cardinalityDrop, .titleDrop, .accessibilityDrop]
    static let dotD2Er: Set<RoundTripLossKind> = [.idSanitization, .cardinalityDrop, .titleDrop, .accessibilityDrop]
}

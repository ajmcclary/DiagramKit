import Foundation

/// Default fallback colors for the Journey family.
///
/// Both `Sources/DiagramKitRenderingCG/DiagramRenderer+Journey.swift`
/// and `Sources/DiagramKitModel/src_journey_renderer.swift` reach for
/// the same actor-color fallback when the diagram source / config did
/// not specify an explicit palette. Lives here so the CG and SVG paths
/// can never drift on the default.
public enum JourneyRenderConstants {
    /// Default per-actor color when no palette is configured.
    /// Mermaid-js reference output uses dark sea green (`#8FBC8F`).
    public static let defaultActorColor: String = "#8FBC8F"
}

import Foundation

/// Default fallback colors for the C4 family.
///
/// These are the Microsoft / Simon Brown C4-Model brand defaults the
/// renderer reaches for when the diagram source did not specify an
/// explicit `$bgColor`, `$borderColor`, or `$fontColor`. Pulled out of
/// `DiagramRenderer+C4.swift` so the renderer body doesn't carry
/// raw hex literals.
public enum C4RenderConstants {
    /// Default fill for a C4 shape (system / container / component /
    /// person). Microsoft Azure-blue family.
    public static let defaultShapeFill: String = "#1168BD"

    /// Default border for a C4 shape, a few shades lighter than the
    /// fill so the rectangle silhouettes against its own fill.
    public static let defaultShapeBorder: String = "#3C7FC0"

    /// Default text color drawn on top of a C4 shape — white for
    /// contrast against the dark-blue fill.
    public static let defaultShapeTextColor: String = "#FFFFFF"

    /// Default color for boundary borders, boundary text, relationship
    /// strokes, and relationship labels. A neutral dark gray.
    public static let defaultBoundaryAndRelColor: String = "#444444"
}

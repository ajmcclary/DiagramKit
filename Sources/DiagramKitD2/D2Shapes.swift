import DiagramKitModel

/// Maps d2 shape names to DiagramKit NodeShape values.
/// Returns nil for unsupported shapes (caller emits diagnostic).
public func mapD2Shape(_ shape: String) -> original_src_types.NodeShape? {
    switch shape.lowercased() {
    case "rectangle", "square": return .rectangle
    case "cylinder", "cyl": return .cylinder
    case "stored_data": return .cylinder
    case "diamond": return .diamond
    case "circle": return .circle
    case "hexagon": return .hexagon
    case "cloud": return .cloud
    case "oval": return .ellipse
    case "document": return .document
    case "page": return .document
    case "text": return .text
    case "parallelogram": return .parallelogram
    case "step": return .parallelogramAlt
    case "queue": return .stadium
    case "package": return .roundedWithTitle
    // Deferred shapes (emit diagnostic):
    case "sql_table", "class", "image", "icon", "person",
         "code", "sequence_diagram", "callout":
        return nil
    default:
        return .rectangle  // fallback: default shape
    }
}

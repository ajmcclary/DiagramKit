import Foundation
import DiagramKitCommon

// MARK: - Flow Node Sizer

/// Compute the bounding-box dimensions for a flowchart/state node.
/// Extracted from `src_layout.swift` to isolate the layout sizing logic.
public func _nodeSize(
    _ node: original_src_types.MermaidNode,
    hideEmptyDescription: Bool = false
) -> (width: Double, height: Double) {
    let labelForMetrics: String
    if node.shape == .rectWithTitle, node.descriptions.count > 1 {
        labelForMetrics = node.descriptions.joined(separator: "\n")
    } else {
        labelForMetrics = node.label
    }
    let metrics = original_src_text_metrics.measureMultilineText(
        labelForMetrics,
        fontSize: original_src_styles.FONT_SIZES.nodeLabel,
        fontWeight: original_src_styles.FONT_WEIGHTS.nodeLabel
    )
    // Match TS NODE_PADDING: horizontal=20 (*2=40), vertical=10 (*2=20)
    var width = metrics.width + 40
    var height = metrics.height + 20

    switch node.shape {
    case .diamond:
        let side = max(width, height) + 24
        width = side; height = side
    case .circle, .ellipse, .smallCircle, .filledCircle, .framedCircle, .crossedCircle, .bang:
        let d = ceil(sqrt(width * width + height * height)) + 8
        width = d; height = d
    case .doublecircle:
        let d = ceil(sqrt(width * width + height * height)) + 8 + 12
        width = d; height = d
    case .hexagon, .notchedPentagon:
        width += 20
    case .trapezoid, .trapezoidAlt, .parallelogram, .parallelogramAlt, .curvedTrapezoid, .slopedRectangle:
        width += 20
    case .asymmetric, .flippedTriangle:
        width += 12
    case .cylinder, .horizontalCylinder, .linedCylinder:
        height += 14
    case .dataStore:
        height += 14; width += 10
    case .hourglass, .lightningBolt:
        width += 8; height += 8
    case .bowTieRectangle:
        width += 12
    case .stateStart, .stateEnd:
        return (28, 28)
    case .fork, .join:
        return (70, 7)
    case .choice:
        let side = max(width, height) + 16
        width = side; height = side
    case .stateDivider:
        width = max(width, 60); height = 12
    case .stateNote:
        width = max(width, 80); height = max(height, 40)
    case .rectWithTitle:
        if node.descriptions.count > 1 {
            let title = original_src_text_metrics.measureMultilineText(
                node.descriptions[0],
                fontSize: original_src_styles.FONT_SIZES.nodeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.nodeLabel
            )
            let body = original_src_text_metrics.measureMultilineText(
                node.descriptions.dropFirst().joined(separator: "\n"),
                fontSize: original_src_styles.FONT_SIZES.nodeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.nodeLabel
            )
            width = max(title.width, body.width) + 40
            height = title.height + body.height + 44
        } else if !hideEmptyDescription {
            height += 26
        }
    case .roundedWithTitle:
        height += 37
    case .document, .linedDocument, .taggedDocument, .stackedDocument:
        height += 10
    case .triangle:
        width += 10; height += 10
    case .text:
        width += 4; height += 4
    case .imageSquare:
        // Image nodes honor the declared display size (default 120×90)
        // + 16pt padding; labels don't drive the box, but keep the
        // node label-wide so titles don't clip.
        height = (node.properties?.h ?? 90) + 16
        width = max((node.properties?.w ?? 120) + 16, metrics.width + 16)
    case .icon, .iconCircle, .iconRounded, .iconSquare:
        // Icon nodes are an h-driven box (default 48pt glyph area +
        // 16pt padding). The label renders inside or at pos t/b; keep
        // the node at least label-wide so offset labels don't clip,
        // but the height is the icon box, not the text extent.
        let box = (node.properties?.h ?? 48) + 16
        height = box
        width = max(box, metrics.width + 16)
    default: break
    }

    width = max(width, 60)
    height = max(height, 36)
    return (width, height)
}

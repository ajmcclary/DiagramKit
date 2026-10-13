// Ported from original/src/ascii/shapes/index.ts
import DiagramKitCommon
import Foundation

private func _basicBoxDimensions(_ label: String, _ options: ShapeRenderOptions) -> ShapeDimensions {
    let lines = splitLines(label)
    let maxLineWidth = max(lines.map { terminalDisplayWidth($0) }.max() ?? 0, 0)
    let lineCount = max(lines.count, 1)

    let innerWidth = 2 * options.padding + maxLineWidth
    let width = innerWidth + 2
    let innerHeight = lineCount + 2 * options.padding
    let height = innerHeight + 2

    return ShapeDimensions(
        width: width,
        height: height,
        labelArea: ShapeLabelArea(
            x: 1 + options.padding,
            y: 1 + options.padding,
            width: maxLineWidth,
            height: lineCount
        ),
        gridColumns: [1, innerWidth, 1],
        gridRows: [1, innerHeight, 1]
    )
}

public func getShapeDimensions(
    _ shape: AsciiNodeShape,
    _ label: String,
    _ options: ShapeRenderOptions
) -> ShapeDimensions {
    switch shape {
    case "subroutine": subroutineRenderer.getDimensions(label, options)
    case "doublecircle": doublecircleRenderer.getDimensions(label, options)
    case "cylinder": cylinderRenderer.getDimensions(label, options)
    case "asymmetric": asymmetricRenderer.getDimensions(label, options)
    case "trapezoid": trapezoidRenderer.getDimensions(label, options)
    case "trapezoid-alt": trapezoidAltRenderer.getDimensions(label, options)
    case "state-start": stateStartRenderer.getDimensions(label, options)
    case "state-end": stateEndRenderer.getDimensions(label, options)
    default: _basicBoxDimensions(label, options)
    }
}


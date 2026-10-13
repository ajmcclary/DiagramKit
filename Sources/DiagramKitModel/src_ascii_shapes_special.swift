// Ported from original/src/ascii/shapes/special.ts
import DiagramKitCommon
import Foundation

private func _shapeBaseBoxDimensions(_ label: String, _ options: ShapeRenderOptions) -> ShapeDimensions {
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

public let subroutineRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: { label, options in
        let lines = splitLines(label)
        let maxLineWidth = max(lines.map { terminalDisplayWidth($0) }.max() ?? 0, 0)
        let lineCount = max(lines.count, 1)

        let innerWidth = 2 * options.padding + maxLineWidth
        let width = innerWidth + 4
        let innerHeight = lineCount + 2 * options.padding
        let height = innerHeight + 2

        return ShapeDimensions(
            width: width,
            height: height,
            labelArea: ShapeLabelArea(
                x: 2 + options.padding,
                y: 1 + options.padding,
                width: maxLineWidth,
                height: lineCount
            ),
            gridColumns: [2, innerWidth, 2],
            gridRows: [1, innerHeight, 1]
        )
    }
)

public let doublecircleRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: _shapeBaseBoxDimensions
)

public let cylinderRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: { label, options in
        let lines = splitLines(label)
        let maxLineWidth = max(lines.map { terminalDisplayWidth($0) }.max() ?? 0, 0)
        let lineCount = max(lines.count, 1)

        let innerWidth = 2 * options.padding + maxLineWidth
        let width = innerWidth + 2
        let innerHeight = lineCount + 2 * options.padding + 2
        let height = innerHeight + 2

        return ShapeDimensions(
            width: width,
            height: height,
            labelArea: ShapeLabelArea(
                x: 1 + options.padding,
                y: 2 + options.padding,
                width: maxLineWidth,
                height: lineCount
            ),
            gridColumns: [1, innerWidth, 1],
            gridRows: [2, innerHeight - 2, 2]
        )
    }
)

public let asymmetricRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: _shapeBaseBoxDimensions
)

public let trapezoidRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: _shapeBaseBoxDimensions
)

public let trapezoidAltRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: _shapeBaseBoxDimensions
)


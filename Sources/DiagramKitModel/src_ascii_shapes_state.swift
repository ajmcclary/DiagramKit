// Ported from original/src/ascii/shapes/state.ts
import Foundation

private func _stateDimensions() -> ShapeDimensions {
    ShapeDimensions(
        width: 5,
        height: 3,
        labelArea: ShapeLabelArea(x: 2, y: 1, width: 1, height: 1),
        gridColumns: [1, 3, 1],
        gridRows: [1, 1, 1]
    )
}

public let stateStartRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: { _, _ in _stateDimensions() }
)

public let stateEndRenderer: any ShapeRenderer = ClosureShapeRenderer(
    getDimensionsFn: { _, _ in _stateDimensions() }
)

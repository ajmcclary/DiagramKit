// Ported from original/src/ascii/shapes/types.ts
import Foundation

public struct ShapeLabelArea: Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct ShapeDimensions: Sendable {
    public var width: Int
    public var height: Int
    public var labelArea: ShapeLabelArea
    public var gridColumns: [Int]
    public var gridRows: [Int]

    public init(
        width: Int,
        height: Int,
        labelArea: ShapeLabelArea,
        gridColumns: [Int],
        gridRows: [Int]
    ) {
        self.width = width
        self.height = height
        self.labelArea = labelArea
        self.gridColumns = gridColumns
        self.gridRows = gridRows
    }
}

public struct ShapeRenderOptions: Sendable {
    public var useAscii: Bool
    public var padding: Int

    public init(useAscii: Bool, padding: Int) {
        self.useAscii = useAscii
        self.padding = padding
    }
}

/// The ASCII node pipeline (`drawNode`) sizes boxes from grid dimensions;
/// box visuals are drawn by the grid/corner machinery, so only dimension
/// computation is dispatched per shape.
public protocol ShapeRenderer: Sendable {
    func getDimensions(_ label: String, _ options: ShapeRenderOptions) -> ShapeDimensions
}

public struct ClosureShapeRenderer: ShapeRenderer {
    public let getDimensionsFn: @Sendable (String, ShapeRenderOptions) -> ShapeDimensions

    public init(
        getDimensionsFn: @escaping @Sendable (String, ShapeRenderOptions) -> ShapeDimensions
    ) {
        self.getDimensionsFn = getDimensionsFn
    }

    public func getDimensions(_ label: String, _ options: ShapeRenderOptions) -> ShapeDimensions {
        getDimensionsFn(label, options)
    }
}


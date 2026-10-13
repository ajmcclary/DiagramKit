import Foundation
import DiagramKitCommon

public struct C4FrontmatterBinding: FrontmatterBinding {
    public static let prefixes = ["config.c4."]

    private var section = SingleSectionBinding<C4DiagramConfig>(config: C4DiagramConfig())

    public init() {}

    public mutating func apply(path: String, value: FrontmatterValue) -> Bool {
        section.apply(path: path, value: value, prefixes: Self.prefixes) { key, value, config in
            switch key {
            case "diagramMarginX":   guard let v = value.double else { return false }; config.diagramMarginX = v
            case "diagramMarginY":   guard let v = value.double else { return false }; config.diagramMarginY = v
            case "c4ShapeMargin":    guard let v = value.double else { return false }; config.c4ShapeMargin = v
            case "c4ShapePadding":   guard let v = value.double else { return false }; config.c4ShapePadding = v
            case "width":            guard let v = value.double else { return false }; config.width = v
            case "height":           guard let v = value.double else { return false }; config.height = v
            case "boxMargin":        guard let v = value.double else { return false }; config.boxMargin = v
            case "c4ShapeInRow":
                let raw = value.double ?? Double(value.int ?? 0)
                config.c4ShapeInRow = _clampedInt(raw, min: 1, max: 1000, default: 4)
                return true
            case "nextLinePaddingX": guard let v = value.double else { return false }; config.nextLinePaddingX = v
            case "c4BoundaryInRow":
                let raw = value.double ?? Double(value.int ?? 0)
                config.c4BoundaryInRow = _clampedInt(raw, min: 1, max: 1000, default: 4)
                return true
            case "useMaxWidth":      guard let v = value.bool else { return false }; config.useMaxWidth = v
            case "wrap":             guard let v = value.bool else { return false }; config.wrap = v
            case "wrapPadding":      guard let v = value.double else { return false }; config.wrapPadding = v
            default: return false
            }
            return true
        }
    }

    public func commit(into frontmatter: inout DiagramFrontmatter) {
        if section.hasSection { frontmatter.perDiagram.c4.config = section.config }
    }
}

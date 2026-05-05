import Foundation
import CoreGraphics

// MARK: - Edge Style Parsing

enum EdgeStyleParser {
    static func parse(from styleString: String, arrowHeadStart: ArrowHead, arrowHeadEnd: ArrowHead) -> EdgeStyle {
        var lineStyle: LineStyle
        let sourceArrow: ArrowHead = arrowHeadStart
        let targetArrow: ArrowHead = arrowHeadEnd

        switch styleString.lowercased() {
        case "dotted":
            lineStyle = .dotted
        case "dashed":
            lineStyle = .dashed
        case "thick":
            lineStyle = .thick
        case "invisible":
            lineStyle = .invisible
        default:
            lineStyle = .solid
        }

        return EdgeStyle(lineStyle: lineStyle, sourceArrow: sourceArrow, targetArrow: targetArrow)
    }
}

// MARK: - Render Relationship Type Constants

enum RenderRelType: String {
    case inheritance
    case composition
    case aggregation
    case association
    case dependency
    case realization
}

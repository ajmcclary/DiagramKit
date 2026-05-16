// CG-side draw routine for the renderer-neutral SequenceArrowheadGeometry
// enum defined in DiagramKitCommon. Apple-gated; on Linux this file is empty.
#if canImport(CoreGraphics)
import CoreGraphics
import DiagramKitCommon

extension SequenceArrowheadGeometry {
    /// Draws the arrowhead at the current context origin, oriented along +x.
    ///
    /// Callers are responsible for translating/rotating the context so the
    /// arrow tip lands at (0, 0) and the shaft extends along the negative-x
    /// axis. The drawing operations mirror the legacy `_drawSequenceArrowHead`
    /// / `_drawHalfArrowHead` body exactly, so corpus image snapshots remain
    /// within the existing 0.99 / 0.98 precision envelope.
    func draw(in context: CGContext, arrowWidth: CGFloat, arrowHeight: CGFloat) {
        switch self {
        case .filledTriangle:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            path.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()

        case .openV:
            context.move(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            context.addLine(to: CGPoint(x: 0, y: 0))
            context.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
            context.strokePath()

        case .cross:
            let cs: CGFloat = arrowHeight * 0.7
            context.move(to: CGPoint(x: -cs, y: -cs))
            context.addLine(to: CGPoint(x: 0, y: cs))
            context.move(to: CGPoint(x: -cs, y: cs))
            context.addLine(to: CGPoint(x: 0, y: -cs))
            context.strokePath()

        case .asyncArc:
            context.move(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
            context.addQuadCurve(
                to: CGPoint(x: -arrowWidth * 0.2, y: arrowHeight / 2),
                control: CGPoint(x: -arrowWidth * 1.5, y: 0)
            )
            context.strokePath()

        case let .halfTriangle(direction, reversed):
            let isTop = direction == .top
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            if reversed {
                if isTop {
                    path.addLine(to: CGPoint(x: arrowWidth, y: -arrowHeight / 2))
                    path.addLine(to: CGPoint(x: arrowWidth, y: 0))
                } else {
                    path.addLine(to: CGPoint(x: arrowWidth, y: 0))
                    path.addLine(to: CGPoint(x: arrowWidth, y: arrowHeight / 2))
                }
            } else {
                if isTop {
                    path.addLine(to: CGPoint(x: -arrowWidth, y: -arrowHeight / 2))
                    path.addLine(to: CGPoint(x: -arrowWidth, y: 0))
                } else {
                    path.addLine(to: CGPoint(x: -arrowWidth, y: 0))
                    path.addLine(to: CGPoint(x: -arrowWidth, y: arrowHeight / 2))
                }
            }
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()

        case let .stick(direction, reversed):
            let isTop = direction == .top
            let half = arrowHeight / 2
            let top: CGFloat = isTop ? -half : 0
            let bottom: CGFloat = isTop ? 0 : half
            context.move(to: CGPoint(x: 0, y: top))
            context.addLine(to: CGPoint(x: 0, y: bottom))
            let tickX = reversed ? arrowWidth * 0.7 : -arrowWidth * 0.7
            let tickY = isTop ? top : bottom
            let tickDelta: CGFloat = isTop ? -2 : 2
            context.move(to: CGPoint(x: 0, y: tickY))
            context.addLine(to: CGPoint(x: tickX, y: tickY + tickDelta))
            context.strokePath()
        }
    }
}
#endif

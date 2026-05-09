// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import CoreGraphics

// MARK: - C4 Core Graphics Renderer

extension DiagramRenderer {
    func _drawC4(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .c4(diagram) = positioned.content else { return }

        _withFittedContext(context, bounds: bounds, contentWidth: diagram.width, contentHeight: diagram.height) { ctx in
            // Draw boundaries
            for boundary in diagram.boundaries where boundary.alias != "global" {
                _drawC4Boundary(boundary, in: ctx)
            }

            // Draw shapes
            for shape in diagram.shapes {
                _drawC4Shape(shape, in: ctx)
            }

            // Draw relationships
            _drawC4Relationships(diagram.relationships, in: ctx)

            // Draw title
            if let title = diagram.title {
                _drawTextInFlipped(title, at: CGPoint(x: diagram.width / 2, y: diagram.height + 40), context: ctx, contentHeight: diagram.height, color: theme.foreground, font: _monoFont(size: 16))
            }
        }
    }

    private func _drawC4Shape(_ shape: PositionedC4Shape, in context: CGContext) {
        let fillColor = _c4CGColor(from: shape.bgColor ?? "#1168BD")
        let strokeColor = _c4CGColor(from: shape.borderColor ?? "#3C7FC0")
        let fontColor = _c4CGColor(from: shape.fontColor ?? "#FFFFFF")

        let rect = CGRect(x: shape.x, y: shape.y, width: shape.width, height: shape.height)

        context.saveGState()

        switch shape.typeC4Shape {
        case .system_db, .external_system_db, .container_db, .external_container_db,
             .component_db, .external_component_db:
            // Cylinder
            let topEllipse = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 20)
            context.setFillColor(fillColor)
            context.setStrokeColor(strokeColor)
            context.setLineWidth(0.5)

            // Body
            context.fill(CGRect(x: rect.minX, y: rect.minY + 10, width: rect.width, height: rect.height - 20))
            context.stroke(CGRect(x: rect.minX, y: rect.minY + 10, width: rect.width, height: rect.height - 20))

            // Top ellipse
            context.fillEllipse(in: topEllipse)
            context.strokeEllipse(in: topEllipse)

            // Bottom ellipse
            let bottomEllipse = CGRect(x: rect.minX, y: rect.maxY - 20, width: rect.width, height: 20)
            context.fillEllipse(in: bottomEllipse)
            context.strokeEllipse(in: bottomEllipse)

        case .system_queue, .external_system_queue, .container_queue, .external_container_queue,
             .component_queue, .external_component_queue:
            // Queue shape (rectangle with curved right edge)
            context.setFillColor(fillColor)
            context.setStrokeColor(strokeColor)
            context.setLineWidth(0.5)

            let path = CGMutablePath()
            path.move(to: CGPoint(x: rect.minX + 5, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - 5, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - 5, y: rect.midY), control: CGPoint(x: rect.maxX + 5, y: rect.midY - 5))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - 5, y: rect.maxY), control: CGPoint(x: rect.maxX + 5, y: rect.midY + 5))
            path.addLine(to: CGPoint(x: rect.minX + 5, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 5, y: rect.midY), control: CGPoint(x: rect.minX - 5, y: rect.midY + 5))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 5, y: rect.minY), control: CGPoint(x: rect.minX - 5, y: rect.midY - 5))
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
            context.addPath(path)
            context.strokePath()

        default:
            // Rectangle
            let roundedRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
            let bezierPath = CGPath(roundedRect: roundedRect, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
            context.setFillColor(fillColor)
            context.setStrokeColor(strokeColor)
            context.setLineWidth(0.5)
            context.addPath(bezierPath)
            context.fillPath()
            context.addPath(bezierPath)
            context.strokePath()
        }

        // Stereotype text
        let stereotype = "\u{00AB}\(shape.typeC4Shape.rawValue)\u{00BB}"
        _drawTextInFlipped(stereotype, at: CGPoint(x: rect.midX, y: rect.minY + shape.stereotypeY + 10), context: context, contentHeight: rect.height, color: BMColor(cgColor: fontColor) ?? theme.background, font: _monoFont(size: 12))

        // Label
        _drawTextInFlipped(shape.label, at: CGPoint(x: rect.midX, y: rect.minY + shape.labelY + shape.labelHeight / 2 + 5), context: context, contentHeight: rect.height, color: BMColor(cgColor: fontColor) ?? theme.background, font: _monoFont(size: 16))

        // Technology
        if let techn = shape.technology, !techn.isEmpty, shape.technHeight > 0 {
            _drawTextInFlipped("[\(techn)]", at: CGPoint(x: rect.midX, y: rect.minY + shape.technY + shape.technHeight / 2 + 5), context: context, contentHeight: rect.height, color: BMColor(cgColor: fontColor) ?? theme.background, font: _monoFont(size: 14))
        }

        // Description
        if let descr = shape.description, !descr.isEmpty, shape.descrHeight > 0 {
            _drawTextInFlipped(descr, at: CGPoint(x: rect.midX, y: rect.minY + shape.descrY + shape.descrHeight / 2 + 5), context: context, contentHeight: rect.height, color: BMColor(cgColor: fontColor) ?? theme.background, font: _monoFont(size: 14))
        }

        context.restoreGState()
    }

    private func _drawC4Boundary(_ boundary: PositionedC4Boundary, in context: CGContext) {
        let fillColor = _c4CGColor(from: boundary.bgColor ?? "none", allowClear: true)
        let strokeColor = _c4CGColor(from: boundary.borderColor ?? "#444444")
        let fontColor = _c4CGColor(from: boundary.fontColor ?? "#444444")

        let rect = CGRect(x: boundary.x, y: boundary.y, width: boundary.width, height: boundary.height)
        let bezierPath = CGPath(roundedRect: rect, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)

        context.saveGState()
        context.setStrokeColor(strokeColor)
        context.setLineWidth(1.0)

        if boundary.nodeType != nil {
            // Solid stroke for deployment nodes
            context.setLineDash(phase: 0, lengths: [])
        } else {
            // Dashed stroke for normal boundaries
            context.setLineDash(phase: 0, lengths: [7, 7])
        }

        if fillColor.alpha > 0 || fillColor != CGColor.clear {
            context.setFillColor(fillColor)
            context.addPath(bezierPath)
            context.fillPath()
        } else {
            context.setFillColor(CGColor.clear)
        }

        context.addPath(bezierPath)
        context.strokePath()

        // Label
        _drawTextInFlipped(boundary.label, at: CGPoint(x: rect.midX, y: rect.minY + boundary.labelHeight / 2 + 5), context: context, contentHeight: rect.height, color: BMColor(cgColor: fontColor) ?? theme.foreground, font: _monoFont(size: 16))

        // Type
        if let type = boundary.type, !type.isEmpty, boundary.typeHeight > 0 {
            let typeY = rect.minY + boundary.labelHeight + boundary.typeHeight / 2 + 10
            _drawTextInFlipped("[\(type)]", at: CGPoint(x: rect.midX, y: typeY), context: context, contentHeight: rect.height, color: BMColor(cgColor: fontColor) ?? theme.foreground, font: _monoFont(size: 14))
        }

        // Description
        if let descr = boundary.description, !descr.isEmpty, boundary.descrHeight > 0 {
            let descrY = rect.minY + boundary.labelHeight + boundary.typeHeight + boundary.descrHeight / 2 + 15
            _drawTextInFlipped(descr, at: CGPoint(x: rect.midX, y: descrY), context: context, contentHeight: rect.height, color: BMColor(cgColor: fontColor) ?? theme.foreground, font: _monoFont(size: 12))
        }

        context.restoreGState()
    }

    private func _drawC4Relationships(_ rels: [PositionedC4Relationship], in context: CGContext) {
        context.saveGState()

        for (i, rel) in rels.enumerated() {
            let strokeColor = _c4CGColor(from: rel.lineColor ?? "#444444")
            let textColor = BMColor(cgColor: _c4CGColor(from: rel.textColor ?? "#444444")) ?? theme.foreground
            let ox = CGFloat(rel.offsetX ?? 0)
            let oy = CGFloat(rel.offsetY ?? 0)

            context.setStrokeColor(strokeColor)
            context.setLineWidth(1.0)

            if i == 0 {
                // Straight line
                context.move(to: rel.startPoint)
                context.addLine(to: rel.endPoint)
            } else {
                // Quadratic bezier
                let controlX = rel.startPoint.x + (rel.endPoint.x - rel.startPoint.x) / 2
                let controlY = rel.startPoint.y + (rel.endPoint.y - rel.startPoint.y) / 2
                context.move(to: rel.startPoint)
                context.addQuadCurve(to: rel.endPoint, control: CGPoint(x: controlX, y: controlY))
            }
            context.strokePath()

            // Label
            let lblX = (rel.startPoint.x + rel.endPoint.x) / 2 + ox
            let lblY = (rel.startPoint.y + rel.endPoint.y) / 2 + oy
            _drawTextInFlipped(rel.label, at: CGPoint(x: lblX, y: lblY), context: context, contentHeight: 1000, color: textColor, font: _monoFont(size: 12))

            // Technology
            if let techn = rel.technology, !techn.isEmpty {
                let technY = lblY + 17
                _drawTextInFlipped("[\(techn)]", at: CGPoint(x: lblX, y: technY), context: context, contentHeight: 1000, color: textColor, font: _monoFont(size: 12))
            }
        }

        context.restoreGState()
    }

    private func _c4CGColor(from hex: String, allowClear: Bool = false) -> CGColor {
        if allowClear && (hex == "none" || hex.isEmpty) {
            return CGColor.clear
        }
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        return CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif

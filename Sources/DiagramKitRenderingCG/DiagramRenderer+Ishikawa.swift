// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import CoreGraphics
import CoreText
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DiagramRenderer {
    func _drawIshikawa(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .ishikawa(data) = positioned.content else { return }

        if !theme.transparent {
            context.setFillColor(theme.background.cgColor)
            context.fill(bounds)
        }

        let vbx = data.viewBox.origin.x
        let vby = data.viewBox.origin.y
        let vbw = data.viewBox.size.width
        let vbh = data.viewBox.size.height
        let scale = min(bounds.width / vbw, bounds.height / vbh)
        let offsetX = (bounds.width - vbw * scale) / 2 - vbx * scale
        let offsetY = (bounds.height - vbh * scale) / 2 - vby * scale

        context.saveGState()
        context.translateBy(x: offsetX, y: offsetY)
        context.scaleBy(x: scale, y: scale)

        let lineColor = theme.line ?? theme.foreground
        let mainBkg = theme.surface ?? theme.background
        let textColor = theme.foreground
        let fontSize: CGFloat = 14
        let font = _ishikawaMonoFont(size: fontSize)
        let headFont = _ishikawaBoldFont(size: fontSize)

        if let head = data.head {
            _drawIshikawaHead(head, in: context, mainBkg: mainBkg, lineColor: lineColor, textColor: textColor, headFont: headFont, fontSize: fontSize)
        }

        for bone in data.bones.sorted(by: { $0.id < $1.id }) {
            _drawIshikawaBone(bone, in: context, color: lineColor, markerId: "ishikawa-arrow")
        }

        for label in data.labels {
            if label.labelClass == .cause {
                _drawIshikawaCauseLabel(label, in: context, textColor: textColor, mainBkg: mainBkg, font: font, fontSize: fontSize)
            } else {
                _drawIshikawaSubLabel(label, in: context, textColor: textColor, font: font, fontSize: fontSize)
            }
        }

        context.restoreGState()
    }

    private func _drawIshikawaHead(
        _ head: PositionedIshikawaHead,
        in context: CGContext,
        mainBkg: BMColor,
        lineColor: BMColor,
        textColor: BMColor,
        headFont: BMFont,
        fontSize: CGFloat
    ) {
        context.saveGState()
        context.translateBy(x: CGFloat(head.x), y: CGFloat(head.y))

        let path = _ishikawaMakeCGPath(from: head.path)
        context.setFillColor(mainBkg.cgColor)
        context.addPath(path)
        context.fillPath()

        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1)
        context.addPath(path)
        context.strokePath()

        let lh = fontSize * 1.05
        for (i, line) in head.lines.enumerated() {
            let y = lh * CGFloat(i)
            labelRenderer.drawText(line, at: CGPoint(x: CGFloat(head.labelX), y: CGFloat(head.labelY) + y), context: context, color: textColor, font: headFont, alignment: .center)
        }

        context.restoreGState()
    }

    private func _drawIshikawaBone(
        _ bone: PositionedIshikawaBone,
        in context: CGContext,
        color: BMColor,
        markerId: String
    ) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: CGFloat(bone.x1), y: CGFloat(bone.y1)))
        context.addLine(to: CGPoint(x: CGFloat(bone.x2), y: CGFloat(bone.y2)))
        context.strokePath()

        if bone.marker == .normalArrowAtStart {
            _drawIshikawaArrowMarker(
                at: CGPoint(x: CGFloat(bone.x1), y: CGFloat(bone.y1)),
                toward: CGPoint(x: CGFloat(bone.x2), y: CGFloat(bone.y2)),
                in: context,
                color: color
            )
        }

        context.restoreGState()
    }

    private func _drawIshikawaArrowMarker(
        at start: CGPoint,
        toward end: CGPoint,
        in context: CGContext,
        color: BMColor
    ) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let len = hypot(dx, dy)
        guard len > 0 else { return }
        let ux = dx / len
        let uy = dy / len
        let s: CGFloat = 6
        let tipX = start.x
        let tipY = start.y

        context.saveGState()
        context.setFillColor(color.cgColor)
        context.move(to: CGPoint(x: tipX, y: tipY))
        context.addLine(to: CGPoint(x: tipX - ux * s * 2 + uy * s, y: tipY - uy * s * 2 - ux * s))
        context.addLine(to: CGPoint(x: tipX - ux * s * 2 - uy * s, y: tipY - uy * s * 2 + ux * s))
        context.closePath()
        context.fillPath()
        context.restoreGState()
    }

    private func _drawIshikawaCauseLabel(
        _ label: PositionedIshikawaLabel,
        in context: CGContext,
        textColor: BMColor,
        mainBkg: BMColor,
        font: BMFont,
        fontSize: CGFloat
    ) {
        context.saveGState()

        if let box = label.box {
            let rect = CGRect(x: CGFloat(box.x), y: CGFloat(box.y), width: CGFloat(box.width), height: CGFloat(box.height))
            context.setFillColor(mainBkg.cgColor)
            context.fill(rect)
        }

        let lh = fontSize * 1.05
        let totalH = lh * CGFloat(label.lines.count)
        let startY = label.y - totalH / 2

        for (i, line) in label.lines.enumerated() {
            let y = startY + lh * CGFloat(i)
            labelRenderer.drawText(line, at: CGPoint(x: label.x, y: y), context: context, color: textColor, font: font, alignment: .center)
        }

        context.restoreGState()
    }

    private func _drawIshikawaSubLabel(
        _ label: PositionedIshikawaLabel,
        in context: CGContext,
        textColor: BMColor,
        font: BMFont,
        fontSize: CGFloat
    ) {
        context.saveGState()

        let alignment: TextAlignment = label.anchor == .start ? .left : (label.anchor == .end ? .right : .center)
        let lh = fontSize * 1.05
        let totalH = lh * CGFloat(label.lines.count)
        let startY = label.y - totalH / 2

        for (i, line) in label.lines.enumerated() {
            let y = startY + lh * CGFloat(i)
            labelRenderer.drawText(line, at: CGPoint(x: label.x, y: y), context: context, color: textColor, font: font, alignment: alignment)
        }

        context.restoreGState()
    }

    private func _ishikawaMakeCGPath(from pathString: String) -> CGPath {
        let path = CGMutablePath()
        let tokens = pathString.split(separator: " ")
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero
        var command: Character = "M"
        var args: [CGFloat] = []

        for token in tokens {
            let t = String(token)
            if t == "M" || t == "L" || t == "Q" || t == "Z" {
                if !args.isEmpty {
                    _applyIshikawaPathCmd(command, args: args, currentPoint: &currentPoint, subpathStart: &subpathStart, path: path)
                    args = []
                }
                if t == "Z" {
                    path.closeSubpath()
                    currentPoint = subpathStart
                    continue
                }
                command = Character(t)
            } else if let value = Double(t) {
                args.append(CGFloat(value))
            }
        }

        if !args.isEmpty {
            _applyIshikawaPathCmd(command, args: args, currentPoint: &currentPoint, subpathStart: &subpathStart, path: path)
        }

        return path
    }

    private func _applyIshikawaPathCmd(
        _ cmd: Character,
        args: [CGFloat],
        currentPoint: inout CGPoint,
        subpathStart: inout CGPoint,
        path: CGMutablePath
    ) {
        switch cmd {
        case "M":
            guard args.count >= 2 else { return }
            let pt = CGPoint(x: args[0], y: args[1])
            path.move(to: pt)
            currentPoint = pt
            subpathStart = pt
        case "L":
            guard args.count >= 2 else { return }
            let pt = CGPoint(x: args[0], y: args[1])
            path.addLine(to: pt)
            currentPoint = pt
        case "Q":
            guard args.count >= 4 else { return }
            let cp = CGPoint(x: args[0], y: args[1])
            let ep = CGPoint(x: args[2], y: args[3])
            path.addQuadCurve(to: ep, control: cp)
            currentPoint = ep
        default:
            break
        }
    }

    private func _ishikawaMonoFont(size: CGFloat) -> BMFont {
        fontResolver.monoFont(size: size)
    }

    private func _ishikawaBoldFont(size: CGFloat) -> BMFont {
        fontResolver.boldMonoFont(size: size)
    }
}
#endif

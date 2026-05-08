import Foundation
import CoreGraphics
import CoreText
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DiagramRenderer {
    func _drawEventModeling(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .eventModeling(data) = positioned.content else { return }

        if !theme.transparent {
            context.setFillColor(theme.background.cgColor)
            context.fill(bounds)
        }

        let vbw = data.width
        let vbh = data.height
        guard vbw > 0, vbh > 0 else { return }

        let scale = min(bounds.width / vbw, bounds.height / vbh)
        let offsetX = (bounds.width - vbw * scale) / 2
        let offsetY = (bounds.height - vbh * scale) / 2

        context.saveGState()
        context.translateBy(x: offsetX, y: offsetY)
        context.scaleBy(x: scale, y: scale)

        let textColor = theme.foreground
        let fontSize: CGFloat = 16
        let font = _emFont(size: fontSize)
        let boldFont = _emBoldFont(size: fontSize)
        let monoFont = _emMonoFont(size: fontSize - 2)

        // Draw swimlanes
        let swimlaneFill = _emParseColor(data.themeVariables.swimlaneBackgroundOdd)
        let swimlaneStroke = _emParseColor(data.themeVariables.swimlaneBackgroundStroke)
        for sl in data.swimlanes {
            _drawEMSwimlane(
                sl,
                in: context,
                maxR: data.swimlanes.map(\.r).max() ?? 250,
                textColor: textColor,
                font: boldFont,
                fillColor: swimlaneFill,
                strokeColor: swimlaneStroke
            )
        }

        // Draw boxes
        for box in data.boxes {
            _drawEMBox(box, in: context, textColor: textColor, font: font, boldFont: boldFont, monoFont: monoFont)
        }

        // Draw relations
        let arrowheadColor = _emParseColor(data.themeVariables.arrowhead)
        for rel in data.relations {
            _drawEMRelation(rel, in: context, arrowheadColor: arrowheadColor)
        }

        context.restoreGState()
    }

    private func _drawEMSwimlane(
        _ sl: PositionedEventModelingSwimlane,
        in context: CGContext,
        maxR: Double,
        textColor: BMColor,
        font: BMFont,
        fillColor: BMColor,
        strokeColor: BMColor
    ) {
        let swimWidth = maxR + 15
        let rect = CGRect(x: 0, y: sl.y, width: swimWidth, height: sl.height)

        context.setFillColor(fillColor.cgColor)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(1)

        let path = CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        context.addPath(path)
        context.fillPath()
        context.addPath(path)
        context.strokePath()

        labelRenderer.drawText(
            sl.label,
            at: CGPoint(x: 30, y: sl.y + 30),
            context: context,
            color: textColor,
            font: font,
            alignment: .left
        )
    }

    private func _drawEMBox(
        _ box: PositionedEventModelingBox,
        in context: CGContext,
        textColor: BMColor,
        font: BMFont,
        boldFont: BMFont,
        monoFont: BMFont
    ) {
        let rect = CGRect(x: box.x, y: box.y, width: box.width, height: box.height)

        // Fill
        let fillColor = _emParseColor(box.fill)
        context.setFillColor(fillColor.cgColor)
        let path = CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil)
        context.addPath(path)
        context.fillPath()

        // Stroke
        let strokeColor = _emParseColor(box.stroke)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(1)
        context.addPath(path)
        context.strokePath()

        // Parse HTML text content: extract entity name and optional code data
        var entityName = box.textContent
        var codeData: String?

        // Extract <b>...</b> entity name
        if let boldStart = entityName.range(of: "<b>"),
           let boldEnd = entityName.range(of: "</b>") {
            let nameRange = boldStart.upperBound..<boldEnd.lowerBound
            entityName = String(entityName[nameRange])
        } else if entityName.hasPrefix("<b>") {
            entityName = String(entityName.dropFirst(3))
        }

        // Extract <code ...>...</code> data
        if let codeStart = box.textContent.range(of: "<code"),
           let codeClose = box.textContent.range(of: "</code>") {
            let afterCodeTag = box.textContent[codeStart.upperBound...]
            if let bracketEnd = afterCodeTag.firstIndex(of: ">") {
                let codeRange = afterCodeTag.index(after: bracketEnd)..<codeClose.lowerBound
                codeData = String(box.textContent[codeRange])
            }
        }

        // Decode HTML entities
        entityName = _decodeHTMLEntities(entityName)
        if let cd = codeData {
            codeData = _decodeHTMLEntities(cd)
        }

        let lineHeight = boldFont.pointSize * 1.3
        let monoLineHeight = monoFont.pointSize * 1.3

        // Count lines for centering: entity name lines + separator gap + code lines
        let nameLines = entityName.split(separator: "\n", omittingEmptySubsequences: true)
        let codeLines = codeData?.split(separator: "\n", omittingEmptySubsequences: true) ?? []
        let hasCode = !codeLines.isEmpty

        let nameBlockHeight = CGFloat(nameLines.count) * lineHeight
        let codeBlockHeight = hasCode ? CGFloat(codeLines.count) * monoLineHeight + lineHeight * 0.5 : 0
        let totalHeight = nameBlockHeight + codeBlockHeight
        let startY = rect.midY - totalHeight / 2

        // Draw entity name (bold)
        for (i, line) in nameLines.enumerated() {
            let y = startY + CGFloat(i) * lineHeight
            labelRenderer.drawText(
                String(line),
                at: CGPoint(x: rect.midX, y: y),
                context: context,
                color: textColor,
                font: boldFont,
                alignment: .center
            )
        }

        // Draw code data (monospace)
        if hasCode {
            let codeStartY = startY + nameBlockHeight + lineHeight * 0.5
            for (i, line) in codeLines.enumerated() {
                let y = codeStartY + CGFloat(i) * monoLineHeight
                labelRenderer.drawText(
                    String(line),
                    at: CGPoint(x: rect.midX, y: y),
                    context: context,
                    color: textColor,
                    font: monoFont,
                    alignment: .center
                )
            }
        }
    }

    private func _decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n")
    }

    private func _drawEMRelation(
        _ rel: PositionedEventModelingRelation,
        in context: CGContext,
        arrowheadColor: BMColor
    ) {
        let strokeColor = _emParseColor(rel.stroke)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: rel.sourceX, y: rel.sourceY))
        context.addLine(to: CGPoint(x: rel.targetX, y: rel.targetY))
        context.strokePath()

        // Draw arrowhead
        let dx = rel.targetX - rel.sourceX
        let dy = rel.targetY - rel.sourceY
        let len = hypot(dx, dy)
        guard len > 0 else { return }

        let ux = dx / len
        let uy = dy / len
        let arrowSize: CGFloat = 7
        let tipX = CGFloat(rel.targetX)
        let tipY = CGFloat(rel.targetY)

        context.setFillColor(arrowheadColor.cgColor)
        context.move(to: CGPoint(x: tipX, y: tipY))
        context.addLine(to: CGPoint(x: tipX - ux * arrowSize * 2 + uy * arrowSize * 0.7, y: tipY - uy * arrowSize * 2 - ux * arrowSize * 0.7))
        context.addLine(to: CGPoint(x: tipX - ux * arrowSize * 2 - uy * arrowSize * 0.7, y: tipY - uy * arrowSize * 2 + ux * arrowSize * 0.7))
        context.closePath()
        context.fillPath()
    }

    private func _emParseColor(_ colorStr: String) -> BMColor {
        if colorStr == "none" || colorStr == "transparent" {
            return BMColor(white: 0, alpha: 0)
        }
        if colorStr == "white" { return BMColor.white }
        if colorStr.hasPrefix("#") {
            let hex = String(colorStr.dropFirst())
            if hex.count == 6 {
                let r = CGFloat(Int(hex.prefix(2), radix: 16) ?? 0) / 255
                let g = CGFloat(Int(hex[hex.index(hex.startIndex, offsetBy: 2)..<hex.index(hex.startIndex, offsetBy: 4)], radix: 16) ?? 0) / 255
                let b = CGFloat(Int(hex.suffix(2), radix: 16) ?? 0) / 255
                return BMColor(red: r, green: g, blue: b, alpha: 1)
            }
        }
        if colorStr.hasPrefix("rgb(") {
            let inner = colorStr
                .replacingOccurrences(of: "rgb(", with: "")
                .replacingOccurrences(of: ")", with: "")
            let parts = inner.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 3 {
                return BMColor(red: CGFloat(parts[0]) / 255, green: CGFloat(parts[1]) / 255, blue: CGFloat(parts[2]) / 255, alpha: 1)
            }
        }
        return BMColor.black
    }

    private func _emFont(size: CGFloat) -> BMFont {
        BMFont(name: "TrebuchetMS", size: size)
            ?? BMFont(name: "Trebuchet MS", size: size)
            ?? BMFont.systemFont(ofSize: size)
    }

    private func _emBoldFont(size: CGFloat) -> BMFont {
        BMFont(name: "TrebuchetMS-Bold", size: size)
            ?? BMFont(name: "Trebuchet-BoldMS", size: size)
            ?? BMFont.boldSystemFont(ofSize: size)
    }

    private func _emMonoFont(size: CGFloat) -> BMFont {
        BMFont(name: "Menlo", size: size)
            ?? BMFont(name: "Courier", size: size)
            ?? BMFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

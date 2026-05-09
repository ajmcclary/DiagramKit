// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import CoreGraphics
#if targetEnvironment(macCatalyst) || canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DiagramRenderer {

    func _drawPacket(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case .packet(let packet) = positioned.content else { return }

        _withFittedContext(context, bounds: bounds,
                           contentWidth: packet.width, contentHeight: packet.height) { ctx in

            // Background
            if !theme.transparent {
                ctx.setFillColor(theme.background.cgColor)
                ctx.fill(CGRect(x: 0, y: 0, width: packet.width, height: packet.height))
            }

            let effectivePaddingY = packetEffectivePaddingY(packet.config)
            let rowHeightTotal = packet.config.rowHeight + effectivePaddingY
            let packetTheme = packet.theme
            let blockFill = _packetColor(packetTheme.blockFillColor, fallback: BMColor(hex: "#efefef"))
            let blockStroke = _packetColor(packetTheme.blockStrokeColor, fallback: BMColor.black)
            let blockStrokeWidth = _packetStrokeWidth(packetTheme.blockStrokeWidth)
            let labelColor = _packetColor(packetTheme.labelColor, fallback: BMColor.black)
            let labelFont = _monoFont(size: _packetFontSize(packetTheme.labelFontSize, fallback: 12))
            let startByteColor = _packetColor(packetTheme.startByteColor, fallback: BMColor.black)
            let endByteColor = _packetColor(packetTheme.endByteColor, fallback: BMColor.black)
            let byteFont = _monoFont(size: _packetFontSize(packetTheme.byteFontSize, fallback: 10))
            let titleColor = _packetColor(packetTheme.titleColor, fallback: BMColor.black)
            let titleFont = _monoFont(size: _packetFontSize(packetTheme.titleFontSize, fallback: 14))

            func drawBitLabels(start: Int, end: Int, x: Double, y: Double, width: Double) {
                guard packet.config.showBits else { return }

                let bitBottomY = CGFloat(packetBitLabelY(forBlockY: y))
                let bitLabelHeight = byteFont.pointSize * 1.4
                let bitRect = CGRect(
                    x: x,
                    y: bitBottomY - bitLabelHeight,
                    width: width,
                    height: bitLabelHeight
                )

                if start == end {
                    labelRenderer.drawText(
                        "\(start)",
                        in: bitRect,
                        context: ctx,
                        color: startByteColor,
                        font: byteFont,
                        alignment: .center,
                        verticalAlignment: .bottom
                    )
                } else {
                    labelRenderer.drawText(
                        "\(start)",
                        in: bitRect,
                        context: ctx,
                        color: startByteColor,
                        font: byteFont,
                        alignment: .left,
                        verticalAlignment: .bottom
                    )
                    labelRenderer.drawText(
                        "\(end)",
                        in: bitRect,
                        context: ctx,
                        color: endByteColor,
                        font: byteFont,
                        alignment: .right,
                        verticalAlignment: .bottom
                    )
                }
            }

            func drawBlock(start: Int, end: Int, label: String, x: Double, y: Double, width: Double, height: Double) {
                let rect = CGRect(x: x, y: y, width: width, height: height)
                ctx.setFillColor(blockFill.cgColor)
                ctx.setStrokeColor(blockStroke.cgColor)
                ctx.setLineWidth(blockStrokeWidth)
                ctx.fill(rect)
                ctx.stroke(rect)

                if !label.isEmpty {
                    _drawTextInFlipped(label,
                        at: CGPoint(x: x + width / 2, y: y + height / 2),
                        context: ctx, contentHeight: packet.height,
                        color: labelColor,
                        font: labelFont,
                        alignment: .center)
                }

                drawBitLabels(start: start, end: end, x: x, y: y, width: width)
            }

            if packet.rows.isEmpty {
                drawBlock(
                    start: 0,
                    end: packet.config.bitsPerRow - 1,
                    label: "",
                    x: 1,
                    y: effectivePaddingY,
                    width: packet.config.bitWidth * Double(packet.config.bitsPerRow) - packet.config.paddingX,
                    height: packet.config.rowHeight
                )
            }

            // Draw each row and block
            for row in packet.rows {
                for block in row {
                    drawBlock(
                        start: block.start,
                        end: block.end,
                        label: block.label,
                        x: block.x,
                        y: block.y,
                        width: block.width,
                        height: block.height
                    )
                }
            }

            // Draw title
            if let title = packet.diagramTitle, !title.isEmpty {
                let titleX = packet.width / 2
                let titleY = packet.height - rowHeightTotal / 2
                _drawTextInFlipped(title,
                    at: CGPoint(x: titleX, y: titleY),
                    context: ctx, contentHeight: packet.height,
                    color: titleColor,
                    font: titleFont,
                    alignment: .center)
            }
        }
    }

    private func _packetColor(_ value: String, fallback: BMColor) -> BMColor {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        switch lower {
        case "black": return BMColor.black
        case "white": return BMColor.white
        case "red": return BMColor(red: 1, green: 0, blue: 0, alpha: 1)
        case "green": return BMColor(red: 0, green: 0.5, blue: 0, alpha: 1)
        case "blue": return BMColor(red: 0, green: 0, blue: 1, alpha: 1)
        case "orange": return BMColor(red: 1, green: 0.647, blue: 0, alpha: 1)
        case "purple": return BMColor(red: 0.5, green: 0, blue: 0.5, alpha: 1)
        case "gray", "grey": return BMColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        case "transparent": return BMColor(red: 0, green: 0, blue: 0, alpha: 0)
        default:
            let cleaned = lower.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            guard (cleaned.count == 6 || cleaned.count == 8),
                  cleaned.allSatisfy({ $0.isHexDigit })
            else { return fallback }
            return BMColor(hex: trimmed)
        }
    }

    private func _packetFontSize(_ value: String, fallback: CGFloat) -> CGFloat {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "px", with: "")
        return CGFloat(Double(cleaned) ?? Double(fallback))
    }

    private func _packetStrokeWidth(_ value: String) -> CGFloat {
        max(0, _packetFontSize(value, fallback: 1))
    }
}
#endif

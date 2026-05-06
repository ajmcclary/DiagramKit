import Foundation
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

            let effectivePaddingY = packet.config.paddingY + (packet.config.showBits ? 10 : 0)
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

            // Draw each row and block
            for row in packet.rows {
                for block in row {
                    // Draw rectangle
                    let rect = CGRect(x: block.x, y: block.y,
                                      width: block.width, height: block.height)
                    ctx.setFillColor(blockFill.cgColor)
                    ctx.setStrokeColor(blockStroke.cgColor)
                    ctx.setLineWidth(blockStrokeWidth)
                    ctx.fill(rect)
                    ctx.stroke(rect)

                    // Draw label centered
                    _drawTextInFlipped(block.label,
                        at: CGPoint(x: block.x + block.width / 2, y: block.y + block.height / 2),
                        context: ctx, contentHeight: packet.height,
                        color: labelColor,
                        font: labelFont,
                        alignment: .center)

                    // Draw bit numbers if showBits
                    if packet.config.showBits {
                        let bitY = block.y - 2
                        if block.start == block.end {
                            // Single-bit: center
                            let bitX = block.x + block.width / 2
                            _drawTextInFlipped("\(block.start)",
                                at: CGPoint(x: bitX, y: bitY),
                                context: ctx, contentHeight: packet.height,
                                color: startByteColor,
                                font: byteFont,
                                alignment: .center)
                        } else {
                            // Start bit label
                            _drawTextInFlipped("\(block.start)",
                                at: CGPoint(x: block.x, y: bitY),
                                context: ctx, contentHeight: packet.height,
                                color: startByteColor,
                                font: byteFont,
                                alignment: .left)
                            // End bit label
                            _drawTextInFlipped("\(block.end)",
                                at: CGPoint(x: block.x + block.width, y: bitY),
                                context: ctx, contentHeight: packet.height,
                                color: endByteColor,
                                font: byteFont,
                                alignment: .right)
                        }
                    }
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

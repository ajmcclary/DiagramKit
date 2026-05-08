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
    func _drawTreemap(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case let .treemap(data) = positioned.content else { return }
        let theme = self.theme

        if !theme.transparent {
            context.setFillColor(theme.background.cgColor)
            context.fill(bounds)
        }

        let scaleX = bounds.width / CGFloat(data.svgWidth)
        let scaleY = bounds.height / CGFloat(data.svgHeight)
        let scale = data.config.useMaxWidth ? scaleX : min(scaleX, scaleY)
        let offsetX = (bounds.width - CGFloat(data.svgWidth) * scale) / 2
        let offsetY = data.config.useMaxWidth
            ? (max(0, bounds.height - CGFloat(data.svgHeight) * scale)) / 2
            : (bounds.height - CGFloat(data.svgHeight) * scale) / 2

        context.saveGState()
        context.translateBy(x: offsetX, y: offsetY)
        context.scaleBy(x: scale, y: scale)

        if let title = data.title {
            _drawTreemapTitle(title, in: context, theme: theme)
        }

        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(data.titleHeight))

        for section in data.sections {
            _drawTreemapSection(section, in: context)
        }

        for leaf in data.leaves {
            _drawTreemapLeaf(leaf, in: context)
        }

        context.restoreGState()

        context.restoreGState()
    }

    private func _drawTreemapTitle(_ title: PositionedTreemapTitle, in context: CGContext, theme: DiagramTheme) {
        let font = _systemFont(size: 14)
        let color = theme.foreground
        let point = CGPoint(x: CGFloat(title.x), y: CGFloat(title.y))
        _drawTextInFlipped(title.text, at: point, context: context, contentHeight: 1000, color: color, font: font, alignment: .center)
    }

    private func _drawTreemapSection(_ section: PositionedTreemapSection, in context: CGContext) {
        guard section.depth > 0 else { return }

        let x = CGFloat(section.x0)
        let y = CGFloat(section.y0)
        let w = CGFloat(section.x1 - section.x0)
        let h = CGFloat(section.y1 - section.y0)

        context.saveGState()

        let fillColor = _treemapStyledColor(section.cssCompiledStyles, keys: ["fill"], fallback: section.fillColor)
        context.setFillColor(fillColor.withAlphaComponent(0.6).cgColor)
        let bodyRect = CGRect(x: x, y: y + 25, width: w, height: h - 25)
        context.fill(bodyRect)

        let strokeColor = _treemapStyledColor(section.cssCompiledStyles, keys: ["stroke"], fallback: section.strokeColor)
        context.setStrokeColor(strokeColor.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(_treemapStyledLineWidth(section.cssCompiledStyles, fallback: 2.0))
        context.stroke(bodyRect)

        if let label = section.label, !label.hidden {
            let font = _boldSystemFont(size: 12)
            let labelColor = _treemapStyledColor(section.cssCompiledStyles, keys: ["color", "fill"], fallback: label.fillColor)
            let point = CGPoint(x: x + 6, y: y + 12.5)
            _drawTextInFlipped(label.text, at: point, context: context, contentHeight: 1000, color: labelColor, font: font, alignment: .left)
        }

        if let value = section.value, !value.hidden {
            let font = _italicSystemFont(size: 10, weight: 0)
            let valueColor = _treemapStyledColor(section.cssCompiledStyles, keys: ["color", "fill"], fallback: value.fillColor)
            let point = CGPoint(x: x + w - 10, y: y + 12.5)
            _drawTextInFlipped(value.text, at: point, context: context, contentHeight: 1000, color: valueColor, font: font, alignment: .right)
        }

        context.restoreGState()
    }

    private func _drawTreemapLeaf(_ leaf: PositionedTreemapLeaf, in context: CGContext) {
        let x = CGFloat(leaf.x0)
        let y = CGFloat(leaf.y0)
        let w = CGFloat(leaf.x1 - leaf.x0)
        let h = CGFloat(leaf.y1 - leaf.y0)

        context.saveGState()

        let fillColor = _treemapStyledColor(leaf.cssCompiledStyles, keys: ["fill"], fallback: leaf.fillColor)
        context.setFillColor(fillColor.withAlphaComponent(0.3).cgColor)
        context.fill(CGRect(x: x, y: y, width: w, height: h))

        let strokeColor = _treemapStyledColor(leaf.cssCompiledStyles, keys: ["stroke"], fallback: leaf.strokeColor)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(_treemapStyledLineWidth(leaf.cssCompiledStyles, fallback: 3.0))
        context.stroke(CGRect(x: x, y: y, width: w, height: h))

        if let label = leaf.label, !label.hidden {
            let font = _systemFont(size: CGFloat(label.fontSize))
            let labelColor = _treemapStyledColor(leaf.cssCompiledStyles, keys: ["color", "fill"], fallback: label.fillColor)
            let point = CGPoint(x: x + w / 2, y: y + CGFloat(label.y))
            _drawTextInFlipped(label.text, at: point, context: context, contentHeight: 1000, color: labelColor, font: font, alignment: .center)
        }

        if let valueText = leaf.valueText, !valueText.hidden {
            let font = _systemFont(size: CGFloat(valueText.fontSize))
            let valueColor = _treemapStyledColor(leaf.cssCompiledStyles, keys: ["color", "fill"], fallback: valueText.fillColor)
            let point = CGPoint(x: x + w / 2, y: y + CGFloat(valueText.y))
            _drawTextInFlipped(valueText.text, at: point, context: context, contentHeight: 1000, color: valueColor, font: font, alignment: .center)
        }

        context.restoreGState()
    }

    private func _systemFont(size: CGFloat) -> BMFont {
        if let family = config.defaultProportionalFontFamily,
           let bundled = BMFont(name: family, size: size) {
            return bundled
        }
        return BMFont.systemFont(ofSize: size)
    }

    private func _boldSystemFont(size: CGFloat) -> BMFont {
        if let family = config.defaultProportionalFontFamily {
            let candidates = ["\(family)-Bold", "\(family) Bold"]
            for name in candidates {
                if let f = BMFont(name: name, size: size) { return f }
            }
        }
        return BMFont.boldSystemFont(ofSize: size)
    }

    private func _treemapStyledColor(_ styles: [String]?, keys: [String], fallback: String) -> BMColor {
        let map = _treemapStyleMap(styles)
        for key in keys {
            if let value = map[key] {
                return BMColor(hex: value)
            }
        }
        return BMColor(hex: fallback)
    }

    private func _treemapStyledLineWidth(_ styles: [String]?, fallback: CGFloat) -> CGFloat {
        guard let value = _treemapStyleMap(styles)["stroke-width"] else { return fallback }
        return _parseCSSLength(value) ?? fallback
    }
}

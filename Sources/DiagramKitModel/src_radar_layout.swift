import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public func layoutRadarDiagram(_ diagram: RadarDiagram) -> PositionedRadarDiagram {
    let config = diagram.config
    let theme = diagram.theme
    let axes = diagram.axes
    let curves = diagram.curves
    let options = diagram.options

    let totalWidth = config.width + config.marginLeft + config.marginRight
    let totalHeight = config.height + config.marginTop + config.marginBottom
    let centerX = config.marginLeft + config.width / 2
    let centerY = config.marginTop + config.height / 2
    let radius = min(config.width, config.height) / 2

    // Empty curves + no explicit `options.max` would otherwise leave
    // `maxValue` as -.infinity. `relativeRadius(...)` guards against
    // non-finite maxValue but the implicit -.infinity is confusing on
    // its own; fall back to a sane unit-range so the empty radar
    // still renders cleanly.
    let entryMax = curves.flatMap(\.entries).max()
    let maxValue: Double
    if let supplied = options.max {
        maxValue = supplied
    } else if let computed = entryMax {
        maxValue = computed
    } else {
        maxValue = 1.0
    }
    let minValue = options.min
    let numAxes = axes.count

    var positioned = PositionedRadarDiagram(
        width: totalWidth,
        height: totalHeight,
        centerX: centerX,
        centerY: centerY,
        radius: radius,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        diagramTitle: diagram.diagramTitle,
        config: config,
        theme: theme,
        showLegend: options.showLegend
    )

    let titleText = diagram.diagramTitle ?? diagram.accTitle
    if let t = titleText, !t.isEmpty {
        positioned.title = PositionedRadarTitle(
            text: t,
            x: 0,
            y: -config.height / 2 - config.marginTop,
            fontSize: theme.fontSize
        )
    }

    var graticules: [PositionedRadarGraticule] = []
    if options.graticule == .circle {
        for i in 0..<options.ticks {
            let r = radius * Double(i + 1) / Double(options.ticks)
            graticules.append(PositionedRadarGraticule(type: .circle, radius: r))
        }
    } else {
        for i in 0..<options.ticks {
            let r = radius * Double(i + 1) / Double(options.ticks)
            var pts: [CGPoint] = []
            for j in 0..<numAxes {
                let angle = (2.0 * Double(j) * Double.pi) / Double(numAxes) - Double.pi / 2
                pts.append(CGPoint(x: r * cos(angle), y: r * sin(angle)))
            }
            graticules.append(PositionedRadarGraticule(type: .polygon, points: pts))
        }
    }
    positioned.graticules = graticules

    var axisLines: [PositionedRadarAxisLine] = []
    var axisLabels: [PositionedRadarText] = []
    for i in 0..<numAxes {
        let angle = (2.0 * Double(i) * Double.pi) / Double(numAxes) - Double.pi / 2
        let endX = radius * config.axisScaleFactor * cos(angle)
        let endY = radius * config.axisScaleFactor * sin(angle)
        axisLines.append(PositionedRadarAxisLine(x1: 0, y1: 0, x2: endX, y2: endY))

        let labelX = radius * config.axisLabelFactor * cos(angle)
        let labelY = radius * config.axisLabelFactor * sin(angle)
        axisLabels.append(PositionedRadarText(
            text: axes[i].label,
            x: labelX,
            y: labelY,
            classAttr: "radarAxisLabel",
            fontSize: theme.axisLabelFontSize
        ))
    }
    positioned.axisLines = axisLines
    positioned.axisLabels = axisLabels

    var positionedCurves: [PositionedRadarCurve] = []
    for (index, curve) in curves.enumerated() {
        if curve.entries.count != numAxes {
            continue
        }
        let points: [CGPoint] = curve.entries.enumerated().map { (i, entry) in
            let angle = (2.0 * Double(i) * Double.pi) / Double(numAxes) - Double.pi / 2
            let r = relativeRadius(entry, minValue: minValue, maxValue: maxValue, radius: radius)
            return CGPoint(x: r * cos(angle), y: r * sin(angle))
        }

        if options.graticule == .circle {
            let segments = closedRoundCurveSegments(points, tension: config.curveTension)
            positionedCurves.append(PositionedRadarCurve(
                index: index,
                label: curve.label,
                points: points,
                cubicSegments: segments,
                type: .circle
            ))
        } else {
            positionedCurves.append(PositionedRadarCurve(
                index: index,
                label: curve.label,
                points: points,
                polygonPoints: points,
                type: .polygon
            ))
        }
    }
    positioned.curves = positionedCurves

    var legendItems: [PositionedRadarLegendItem] = []
    if options.showLegend {
        let legendX = ((config.width / 2 + config.marginRight) * 3) / 4
        let legendY = (-(config.height / 2 + config.marginTop) * 3) / 4
        for (index, curve) in positioned.curves.enumerated() {
            legendItems.append(PositionedRadarLegendItem(
                index: index,
                label: curve.label,
                x: legendX,
                y: legendY + Double(index) * 20,
                boxSize: theme.legendBoxSize
            ))
        }
    }
    positioned.legendItems = legendItems

    return positioned
}

// MARK: - Helper functions

public func relativeRadius(
    _ value: Double,
    minValue: Double,
    maxValue: Double,
    radius: Double
) -> Double {
    guard value.isFinite, minValue.isFinite, maxValue.isFinite, radius.isFinite, maxValue > minValue else {
        return 0
    }
    let clipped = min(max(value, minValue), maxValue)
    return (radius * (clipped - minValue)) / (maxValue - minValue)
}

public func closedRoundCurveSegments(
    _ points: [CGPoint],
    tension: Double
) -> [RadarCubicSegment] {
    let numPoints = points.count
    var segments: [RadarCubicSegment] = []
    for i in 0..<numPoints {
        let p0 = points[(i - 1 + numPoints) % numPoints]
        let p1 = points[i]
        let p2 = points[(i + 1) % numPoints]
        let p3 = points[(i + 2) % numPoints]
        let cp1 = CGPoint(
            x: p1.x + (p2.x - p0.x) * tension,
            y: p1.y + (p2.y - p0.y) * tension
        )
        let cp2 = CGPoint(
            x: p2.x - (p3.x - p1.x) * tension,
            y: p2.y - (p3.y - p1.y) * tension
        )
        segments.append(RadarCubicSegment(cp1: cp1, cp2: cp2, end: p2))
    }
    return segments
}

public func closedRoundCurveSVGPath(
    _ points: [CGPoint],
    tension: Double
) -> String {
    let numPoints = points.count
    var d = "M\(_svgNum(points[0].x)),\(_svgNum(points[0].y))"
    for i in 0..<numPoints {
        let p0 = points[(i - 1 + numPoints) % numPoints]
        let p1 = points[i]
        let p2 = points[(i + 1) % numPoints]
        let p3 = points[(i + 2) % numPoints]
        let cp1 = CGPoint(
            x: p1.x + (p2.x - p0.x) * tension,
            y: p1.y + (p2.y - p0.y) * tension
        )
        let cp2 = CGPoint(
            x: p2.x - (p3.x - p1.x) * tension,
            y: p2.y - (p3.y - p1.y) * tension
        )
        d += " C\(_svgNum(cp1.x)),\(_svgNum(cp1.y)) \(_svgNum(cp2.x)),\(_svgNum(cp2.y)) \(_svgNum(p2.x)),\(_svgNum(p2.y))"
    }
    return d + " Z"
}

private func _svgNum(_ n: Double) -> String {
    guard n.isFinite else { return "0" }
    let nearestInt = n.rounded()
    if abs(n - nearestInt) < 1e-9 {
        return String(Int(nearestInt))
    }
    var s = String(format: "%.6f", n)
    while s.hasSuffix("0") { s = String(s.dropLast()) }
    if s.hasSuffix(".") { s = String(s.dropLast()) }
    return s
}

import Testing
import Foundation
import CoreGraphics
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG

@Suite("Radar Layout")
struct RadarLayoutTests {

    @Test("Empty diagram layout")
    func emptyLayout() {
        let diagram = RadarDiagram()
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.width == 700)
        #expect(positioned.height == 700)
        #expect(positioned.centerX == 350)
        #expect(positioned.centerY == 350)
        #expect(positioned.radius == 300)
        #expect(positioned.graticules.count == 5)
        #expect(positioned.curves.isEmpty)
        #expect(positioned.legendItems.isEmpty)
    }

    @Test("Single axis single curve layout")
    func singleAxisSingleCurve() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A")]
        diagram.curves = [RadarCurve(name: "c1", entries: [5])]
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.axisLines.count == 1)
        #expect(positioned.axisLabels.count == 1)
        #expect(positioned.curves.count == 1)
        #expect(positioned.legendItems.count == 1)
    }

    @Test("Multi-axis multi-curve layout")
    func multiAxisMultiCurve() {
        var diagram = RadarDiagram()
        diagram.axes = [
            RadarAxis(name: "A"), RadarAxis(name: "B"), RadarAxis(name: "C")
        ]
        diagram.curves = [
            RadarCurve(name: "c1", entries: [1, 2, 3]),
            RadarCurve(name: "c2", entries: [3, 2, 1])
        ]
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.axisLines.count == 3)
        #expect(positioned.axisLabels.count == 3)
        #expect(positioned.curves.count == 2)
        #expect(positioned.legendItems.count == 2)
    }

    @Test("Curve skip when entry count does not match axis count")
    func curveSkipMismatchedEntries() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A"), RadarAxis(name: "B")]
        diagram.curves = [
            RadarCurve(name: "c1", entries: [1]), // only 1 entry for 2 axes
            RadarCurve(name: "c2", entries: [1, 2]) // correct
        ]
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.curves.count == 1)
        #expect(positioned.curves[0].label == "c2")
    }

    @Test("relativeRadius basic calculation")
    func relativeRadiusBasic() {
        #expect(relativeRadius(5, minValue: 0, maxValue: 10, radius: 100) == 50)
        #expect(relativeRadius(0, minValue: 0, maxValue: 10, radius: 100) == 0)
        #expect(relativeRadius(10, minValue: 0, maxValue: 10, radius: 100) == 100)
    }

    @Test("relativeRadius clipping")
    func relativeRadiusClipping() {
        #expect(relativeRadius(-5, minValue: 0, maxValue: 10, radius: 100) == 0)
        #expect(relativeRadius(15, minValue: 0, maxValue: 10, radius: 100) == 100)
        #expect(relativeRadius(5, minValue: -10, maxValue: 10, radius: 100) == 75)
    }

    @Test("relativeRadius returns finite zero when min and max are equal")
    func relativeRadiusZeroRange() {
        let radius = relativeRadius(0, minValue: 0, maxValue: 0, radius: 100)
        #expect(radius == 0)
        #expect(radius.isFinite)
    }

    @Test("relativeRadius with non-zero min value produces correct scaling")
    func relativeRadiusNonZeroMin() {
        #expect(relativeRadius(5, minValue: 5, maxValue: 10, radius: 100) == 0)
        #expect(relativeRadius(7.5, minValue: 5, maxValue: 10, radius: 100) == 50)
        #expect(relativeRadius(10, minValue: 5, maxValue: 10, radius: 100) == 100)
        #expect(relativeRadius(3, minValue: 5, maxValue: 10, radius: 100) == 0)
    }

    @Test("empty diagram layout produces finite graticule radii")
    func emptyDiagramFiniteGraticules() throws {
        let diagram = RadarDiagram()
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.graticules.count == 5)
        for g in positioned.graticules {
            if case .circle = g.type {
                let r = try #require(g.radius)
                #expect(r.isFinite)
                #expect(r >= 0)
            }
        }
    }

    @Test("circle graticule ticks")
    func circleGraticuleTicks() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A"), RadarAxis(name: "B")]
        diagram.options.ticks = 3
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.graticules.count == 3)
        for g in positioned.graticules {
            #expect(g.type == .circle)
            #expect(g.radius != nil)
        }
    }

    @Test("polygon graticule points")
    func polygonGraticulePoints() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A"), RadarAxis(name: "B"), RadarAxis(name: "C")]
        diagram.options.graticule = .polygon
        diagram.options.ticks = 2
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.graticules.count == 2)
        for g in positioned.graticules {
            #expect(g.type == .polygon)
            #expect(g.points?.count == 3)
        }
    }

    @Test("axis angles spread evenly starting from top")
    func axisAngles() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A"), RadarAxis(name: "B"), RadarAxis(name: "C"), RadarAxis(name: "D")]
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.axisLines.count == 4)
        // First axis (A) should point upward (angle = -pi/2)
        let firstEndX = positioned.axisLines[0].x2
        let firstEndY = positioned.axisLines[0].y2
        // cos(-pi/2) ≈ 0, sin(-pi/2) ≈ -1 → x2 ≈ 0, y2 < 0
        #expect(abs(firstEndX) < 1.0)
        #expect(firstEndY < 0)
    }

    @Test("legend positions")
    func legendPositions() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A")]
        diagram.curves = [RadarCurve(name: "c1", entries: [5])]
        diagram.options.showLegend = true
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.legendItems.count == 1)
        #expect(positioned.legendItems[0].label == "c1")
        #expect(positioned.legendItems[0].boxSize == 12)
    }

    @Test("legend suppressed when showLegend false")
    func legendSuppressed() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A")]
        diagram.curves = [RadarCurve(name: "c1", entries: [5])]
        diagram.options.showLegend = false
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.legendItems.isEmpty)
    }

    @Test("title position")
    func titlePosition() {
        var diagram = RadarDiagram()
        diagram.diagramTitle = "My Radar Chart"
        diagram.axes = [RadarAxis(name: "A")]
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.title != nil)
        #expect(positioned.title?.text == "My Radar Chart")
        #expect(positioned.title?.x == 0)
        #expect(positioned.title?.y == -(diagram.config.height / 2 + diagram.config.marginTop))
    }

    @Test("config overrides affect layout dimensions")
    func configOverrides() {
        var config = RadarDiagramConfig.default
        config.width = 800
        config.height = 400
        config.marginTop = 20
        config.marginLeft = 30
        config.marginRight = 40
        config.marginBottom = 10
        var diagram = RadarDiagram(config: config)
        diagram.axes = [RadarAxis(name: "A")]
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.width == 870)
        #expect(positioned.height == 430)
        #expect(positioned.radius == 200)
    }

    @Test("axisScaleFactor affects axis line length")
    func axisScaleFactor() {
        var config = RadarDiagramConfig.default
        config.axisScaleFactor = 0.5
        var diagram = RadarDiagram(config: config)
        diagram.axes = [RadarAxis(name: "A")]
        let positioned = layoutRadarDiagram(diagram)
        let defaultDiagram = RadarDiagram(axes: [RadarAxis(name: "A")])
        let defaultPositioned = layoutRadarDiagram(defaultDiagram)
        #expect(abs(positioned.axisLines[0].x2) < abs(defaultPositioned.axisLines[0].x2))
    }

    @Test("closedRoundCurve SVG path for 4-point square tension 0")
    func closedRoundCurveSquareTension0() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let path = closedRoundCurveSVGPath(points, tension: 0)
        #expect(path == "M0,0 C0,0 100,0 100,0 C100,0 100,100 100,100 C100,100 0,100 0,100 C0,100 0,0 0,0 Z")
    }

    @Test("closedRoundCurve SVG path for 2-point line tension 0.5")
    func closedRoundCurveLineTension05() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 100)
        ]
        let path = closedRoundCurveSVGPath(points, tension: 0.5)
        #expect(path == "M0,0 C0,0 100,100 100,100 C100,100 0,0 0,0 Z")
    }

    @Test("closedRoundCurve SVG path for 4-point square tension 0.5")
    func closedRoundCurveSquareTension05() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let path = closedRoundCurveSVGPath(points, tension: 0.5)
        #expect(path == "M0,0 C50,-50 50,-50 100,0 C150,50 150,50 100,100 C50,150 50,150 0,100 C-50,50 -50,50 0,0 Z")
    }

    @Test("curveTension affects curve path")
    func curveTensionAffectsPath() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let path0 = closedRoundCurveSVGPath(points, tension: 0)
        let path05 = closedRoundCurveSVGPath(points, tension: 0.5)
        #expect(path0 != path05)
    }

    @Test("SVG path fractional values preserve precision up to 6 decimals")
    func svgPathFractionalValuesPreservePrecision() {
        let points = [
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 100.5, y: 0.5),
            CGPoint(x: 100.5, y: 100.5),
            CGPoint(x: 0.5, y: 100.5)
        ]
        let path = closedRoundCurveSVGPath(points, tension: 0)
        #expect(path.hasPrefix("M0.5,0.5"))
        #expect(!path.contains(".0,"))
        #expect(!path.contains(".0 "))
        #expect(!path.contains(".0C"))
    }

    @Test("SVG path integral values have no trailing .0")
    func svgPathIntegralValuesNoDotZero() {
        let points = [
            CGPoint(x: 100, y: 0),
            CGPoint(x: 0, y: 100)
        ]
        let path = closedRoundCurveSVGPath(points, tension: 0.5)
        #expect(!path.contains(".0"))
        #expect(path.contains("M100,0"))
    }

    @Test("SVG path negative fractional values formatted correctly")
    func svgPathNegativeFractionalValues() {
        let points = [
            CGPoint(x: -0.5, y: -0.5),
            CGPoint(x: 0.5, y: -0.5)
        ]
        let path = closedRoundCurveSVGPath(points, tension: 0)
        #expect(path.hasPrefix("M-0.5,-0.5"))
        #expect(path.contains("0.5,-0.5"))
    }

    @Test("SVG path very small fractional values produce non-integer output")
    func svgPathVerySmallFractionalValues() {
        let points = [
            CGPoint(x: 0.05, y: 0.15),
            CGPoint(x: 0.15, y: 0.05)
        ]
        let path = closedRoundCurveSVGPath(points, tension: 0)
        #expect(path.hasPrefix("M0.05,0.15"))
        #expect(path.contains("C0.05,0.15"))
        #expect(!path.hasSuffix(".0 Z"))
    }

    @Test("effective max from options")
    func effectiveMaxFromOptions() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A")]
        diagram.curves = [RadarCurve(name: "c1", entries: [5])]
        diagram.options.max = 10
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.curves.count == 1)
    }

    @Test("effective max from curve entries")
    func effectiveMaxFromCurveEntries() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A")]
        diagram.curves = [RadarCurve(name: "c1", entries: [5])]
        diagram.options.max = nil
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.curves.count == 1)
    }

    @Test("all-zero curve produces finite positioned points")
    func allZeroCurveProducesFinitePoints() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A"), RadarAxis(name: "B")]
        diagram.curves = [RadarCurve(name: "c1", entries: [0, 0])]
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.curves.count == 1)
        for point in positioned.curves[0].points {
            #expect(point.x.isFinite)
            #expect(point.y.isFinite)
        }
    }

    @Test("circle graticule curves have cubic segments")
    func circleCurveCubicSegments() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A"), RadarAxis(name: "B"), RadarAxis(name: "C")]
        diagram.curves = [RadarCurve(name: "c1", entries: [1, 2, 3])]
        diagram.options.graticule = .circle
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.curves.count == 1)
        #expect(!positioned.curves[0].cubicSegments.isEmpty)
        #expect(positioned.curves[0].type == .circle)
    }

    @Test("polygon graticule curves have polygon points")
    func polygonCurvePolygonPoints() {
        var diagram = RadarDiagram()
        diagram.axes = [RadarAxis(name: "A"), RadarAxis(name: "B"), RadarAxis(name: "C")]
        diagram.curves = [RadarCurve(name: "c1", entries: [1, 2, 3])]
        diagram.options.graticule = .polygon
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.curves.count == 1)
        #expect(positioned.curves[0].type == .polygon)
        #expect(positioned.curves[0].polygonPoints?.count == 3)
    }

    @Test("accessibility metadata preserved in positioned output")
    func accessibilityMetadataPreserved() {
        var diagram = RadarDiagram()
        diagram.accTitle = "AT"
        diagram.accDescr = "AD"
        let positioned = layoutRadarDiagram(diagram)
        #expect(positioned.accTitle == "AT")
        #expect(positioned.accDescr == "AD")
    }
}

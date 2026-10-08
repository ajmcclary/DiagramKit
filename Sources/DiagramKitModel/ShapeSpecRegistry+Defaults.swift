// Linux-portable: SVG/geometry code shared by every platform (see PortableRenderSupport.swift).
import Foundation
#if canImport(CoreGraphics)
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#endif

// MARK: - Shape Spec Defaults

extension ShapeSpecRegistry {

    // MARK: - Individual specs

    static func _makeRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["rect", "proc", "process", "rectangle", "entity", "state-fork"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) }
        )
    }

    static func _makeRoundedSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["rounded", "fr-rect", "rounded-rectangle"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 6) }
        )
    }

    static func _makeDiamondSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["diamond", "diam", "decision", "rhombus"],
            sizeAdjustment: { textSize, config in
                let side = Swift.max(Swift.max(textSize.width + config.nodePaddingHorizontal * 2, textSize.height + config.nodePaddingVertical * 2), config.minimumNodeWidth) + config.nodePaddingDiamondExtra
                return CGSize(width: side, height: side)
            },
            path: { _, _ in .diamond }
        )
    }

    static func _makeStadiumSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["stadium"], sizeAdjustment: _rectSizing, path: { _, _ in .stadium })
    }

    static func _makeCircleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["circle", "circ"],
            sizeAdjustment: { textSize, config in
                let w = textSize.width + config.nodePaddingHorizontal * 2
                let h = textSize.height + config.nodePaddingVertical * 2
                let d = ceil(sqrt(w * w + h * h)) + 8
                return CGSize(width: Swift.max(d, config.minimumNodeWidth), height: Swift.max(d, config.minimumNodeHeight))
            },
            path: { _, _ in .ellipse }
        )
    }

    static func _makeSubroutineSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["subroutine", "subproc", "sub-routine"],
            sizeAdjustment: _rectSizing,
            path: { _, config in .subroutine(inset: config.subroutineInset) },
            decorations: [
                ShapeDecoration(
                    path: { rect, config in .polyline(points: [
                        CGPoint(x: rect.minX + config.subroutineInset, y: rect.minY),
                        CGPoint(x: rect.minX + config.subroutineInset, y: rect.maxY),
                    ]) },
                    stroke: .mainStroke
                ),
                ShapeDecoration(
                    path: { rect, config in .polyline(points: [
                        CGPoint(x: rect.maxX - config.subroutineInset, y: rect.minY),
                        CGPoint(x: rect.maxX - config.subroutineInset, y: rect.maxY),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }

    static func _makeDoubleCircleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["double-circle", "dbl-circ", "doublecircle"],
            sizeAdjustment: { textSize, config in
                let w = textSize.width + config.nodePaddingHorizontal * 2
                let h = textSize.height + config.nodePaddingVertical * 2
                let d = ceil(sqrt(w * w + h * h)) + 8 + 12
                return CGSize(width: Swift.max(d, config.minimumNodeWidth), height: Swift.max(d, config.minimumNodeHeight))
            },
            path: { _, config in .doubleCircle(gap: config.doubleCircleGap) },
            decorations: [
                ShapeDecoration(
                    path: { _, _ in .ellipse },
                    stroke: .mainStroke,
                    fill: .inherit
                ),
            ]
        )
    }

    static func _makeHexagonSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["hexagon", "hex"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 20, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .hexagon }
        )
    }

    static func _makeCylinderSpec() -> ShapeSpec {
        let sideLines: [ShapeDecoration] = [
            ShapeDecoration(
                path: { rect, config in .polyline(points: [
                    CGPoint(x: rect.minX, y: rect.minY + config.cylinderEllipseRadius),
                    CGPoint(x: rect.minX, y: rect.maxY - config.cylinderEllipseRadius),
                ]) },
                stroke: .mainStroke
            ),
            ShapeDecoration(
                path: { rect, config in .polyline(points: [
                    CGPoint(x: rect.maxX, y: rect.minY + config.cylinderEllipseRadius),
                    CGPoint(x: rect.maxX, y: rect.maxY - config.cylinderEllipseRadius),
                ]) },
                stroke: .mainStroke
            ),
        ]
        let capDecorations: [ShapeDecoration] = [
            ShapeDecoration(
                path: { _, _ in .ellipse },
                bounds: { full, config in
                    let h = config.cylinderEllipseRadius * 2
                    return CGRect(x: full.minX, y: full.minY, width: full.width, height: h)
                },
                stroke: .mainStroke,
                fill: .inherit
            ),
            ShapeDecoration(
                path: { _, _ in .ellipse },
                bounds: { full, config in
                    let h = config.cylinderEllipseRadius * 2
                    return CGRect(x: full.minX, y: full.maxY - h, width: full.width, height: h)
                },
                stroke: .mainStroke,
                fill: .inherit
            ),
        ]
        return ShapeSpec(
            aliases: ["cylinder", "cyl"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 14, config.minimumNodeHeight)
                )
            },
            path: { _, config in .cylinder(topCapInset: config.cylinderEllipseRadius) },
            decorations: sideLines + capDecorations
        )
    }

    static func _makeAsymmetricSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["odd", "rect-left-inv-arrow", "asymmetric"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 12, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, config in .asymmetric(indent: config.asymmetricIndent) }
        )
    }

    static func _makeTrapezoidSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["trapezoid", "trap-b"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 20, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .trapezoid(skew: 0.3) }
        )
    }

    static func _makeParallelogramSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["lean-right", "lean_right", "parallelogram"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 20, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .parallelogram(skew: 0.3) }
        )
    }

    static func _makeTrapezoidAltSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["trapezoid-alt", "inv_trapezoid", "trap-t"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 20, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .trapezoidAlt(skew: 0.15) }
        )
    }

    static func _makeParallelogramAltSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["lean-left", "lean_left", "parallelogram-alt"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 20, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .parallelogramAlt(skew: 0.2) }
        )
    }

    // MARK: Phase 1 — specs migrated from _defaultSpec to explicit paths + decorations.

    static func _makeBangSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["bang"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .ellipse },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.midX, y: rect.minY),
                        CGPoint(x: rect.midX, y: rect.maxY),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    static func _makeCloudSpec() -> ShapeSpec { ShapeSpec(aliases: ["cloud"], sizeAdjustment: _rectSizing, path: { _, _ in .cloud }) }
    static func _makeDataStoreSpec() -> ShapeSpec {
        let sideLines: [ShapeDecoration] = [
            ShapeDecoration(
                path: { rect, config in .polyline(points: [
                    CGPoint(x: rect.minX, y: rect.minY + config.cylinderEllipseRadius),
                    CGPoint(x: rect.minX, y: rect.maxY - config.cylinderEllipseRadius),
                ]) },
                stroke: .mainStroke
            ),
            ShapeDecoration(
                path: { rect, config in .polyline(points: [
                    CGPoint(x: rect.maxX, y: rect.minY + config.cylinderEllipseRadius),
                    CGPoint(x: rect.maxX, y: rect.maxY - config.cylinderEllipseRadius),
                ]) },
                stroke: .mainStroke
            ),
        ]
        let capDecorations: [ShapeDecoration] = [
            ShapeDecoration(
                path: { _, _ in .ellipse },
                bounds: { full, config in
                    let h = config.cylinderEllipseRadius * 2
                    return CGRect(x: full.minX, y: full.minY, width: full.width, height: h)
                },
                stroke: .mainStroke,
                fill: .inherit
            ),
            ShapeDecoration(
                path: { _, _ in .ellipse },
                bounds: { full, config in
                    let h = config.cylinderEllipseRadius * 2
                    return CGRect(x: full.minX, y: full.maxY - h, width: full.width, height: h)
                },
                stroke: .mainStroke,
                fill: .inherit
            ),
        ]
        return ShapeSpec(
            aliases: ["data-store", "datastore"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 14, config.minimumNodeHeight)
                )
            },
            path: { _, config in .cylinder(topCapInset: config.cylinderEllipseRadius) },
            decorations: sideLines + capDecorations
        )
    }
    static func _makeTextSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["text"], sizeAdjustment: { textSize, _ in CGSize(width: textSize.width + 4, height: textSize.height + 4) }, path: { _, _ in .rect(cornerRadius: 0) })
    }
    static func _makeNotchedRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["card", "notched-rectangle", "notch-rect"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .notchedRectangle(notchSize: 10) }
        )
    }
    static func _makeLinedRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["lined-process", "lined-rectangle", "lin-rect", "lin-proc", "shaded-process"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX + 4, y: rect.minY),
                        CGPoint(x: rect.minX + 4, y: rect.maxY),
                    ]) },
                    stroke: .thinStroke
                ),
            ]
        )
    }
    static func _makeSmallCircleSpec() -> ShapeSpec { ShapeSpec(aliases: ["start", "small-circle", "sm-circ"], sizeAdjustment: { _, _ in CGSize(width: 28, height: 28) }, path: { _, _ in .ellipse }) }
    static func _makeFramedCircleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["stop", "framed-circle", "fr-circ"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .ellipse },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .ellipse },
                    stroke: .thinStroke
                ),
            ]
        )
    }
    static func _makeForkSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["fork"], sizeAdjustment: { _, _ in CGSize(width: 70, height: 7) }, path: { _, _ in .rect(cornerRadius: 0) }, fillOverride: .foreground, strokeOverride: ShapeDecoration.Stroke.none)
    }
    static func _makeJoinSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["join"], sizeAdjustment: { _, _ in CGSize(width: 70, height: 7) }, path: { _, _ in .rect(cornerRadius: 0) }, fillOverride: .foreground, strokeOverride: ShapeDecoration.Stroke.none)
    }
    static func _makeHourglassSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["collate", "hourglass"], sizeAdjustment: _rectSizing, path: { _, _ in .hourglass })
    }
    static func _makeBraceLSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["brace-l", "comment", "brace"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX + rect.width * 0.4, y: rect.minY + 2),
                        CGPoint(x: rect.minX + 2, y: rect.minY + rect.height * 0.1),
                        CGPoint(x: rect.minX + rect.width * 0.3, y: rect.midY),
                        CGPoint(x: rect.minX + 2, y: rect.maxY - rect.height * 0.1),
                        CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY - 2),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    static func _makeBraceRSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["brace-r"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX + rect.width * 0.6, y: rect.minY + 2),
                        CGPoint(x: rect.maxX - 2, y: rect.minY + rect.height * 0.1),
                        CGPoint(x: rect.minX + rect.width * 0.7, y: rect.midY),
                        CGPoint(x: rect.maxX - 2, y: rect.maxY - rect.height * 0.1),
                        CGPoint(x: rect.minX + rect.width * 0.6, y: rect.maxY - 2),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    static func _makeBracesSpec() -> ShapeSpec {
        let leftDecoration = ShapeDecoration(
            path: { rect, _ in .polyline(points: [
                CGPoint(x: rect.minX + rect.width * 0.4, y: rect.minY + 2),
                CGPoint(x: rect.minX + 2, y: rect.minY + rect.height * 0.1),
                CGPoint(x: rect.minX + rect.width * 0.3, y: rect.midY),
                CGPoint(x: rect.minX + 2, y: rect.maxY - rect.height * 0.1),
                CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY - 2),
            ]) },
            stroke: ShapeDecoration.Stroke.mainStroke
        )
        let rightDecoration = ShapeDecoration(
            path: { rect, _ in .polyline(points: [
                CGPoint(x: rect.minX + rect.width * 0.6, y: rect.minY + 2),
                CGPoint(x: rect.maxX - 2, y: rect.minY + rect.height * 0.1),
                CGPoint(x: rect.minX + rect.width * 0.7, y: rect.midY),
                CGPoint(x: rect.maxX - 2, y: rect.maxY - rect.height * 0.1),
                CGPoint(x: rect.minX + rect.width * 0.6, y: rect.maxY - 2),
            ]) },
            stroke: ShapeDecoration.Stroke.mainStroke
        )
        return ShapeSpec(
            aliases: ["braces"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [leftDecoration, rightDecoration]
        )
    }
    // Specs from `_makeLightningBoltSpec` through `_makeEllipseSpec` live
    // in `ShapeSpecRegistry+DefaultsSpecial.swift` to keep both files
    // below the file-size warning threshold (REVIEW.md L1).
}

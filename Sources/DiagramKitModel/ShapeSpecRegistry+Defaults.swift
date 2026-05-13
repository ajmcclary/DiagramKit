// Apple-only — depends on RenderConfig (BMColor/BMFont). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
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
    static func _makeLightningBoltSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["com-link", "bolt", "lightning-bolt"], sizeAdjustment: { textSize, config in
            CGSize(width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 8, config.minimumNodeWidth), height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 8, config.minimumNodeHeight))
        }, path: { _, _ in .lightningBolt })
    }
    static func _makeDocumentSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["doc", "document"], sizeAdjustment: _rectSizing, path: { _, _ in .document })
    }
    static func _makeDelaySpec() -> ShapeSpec {
        ShapeSpec(aliases: ["delay", "half-rounded-rectangle"], sizeAdjustment: _rectSizing, path: { _, _ in .stadium })
    }
    static func _makeHorizontalCylinderSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["horizontal-cylinder", "h-cyl", "das"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 14, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, config in .horizontalCylinder(leftCapInset: config.cylinderEllipseRadius) },
            decorations: [
                ShapeDecoration(
                    path: { _, _ in .ellipse },
                    bounds: { full, config in
                        let w = config.cylinderEllipseRadius * 2
                        return CGRect(x: full.minX, y: full.minY, width: w, height: full.height)
                    },
                    stroke: .mainStroke,
                    fill: .inherit
                ),
                ShapeDecoration(
                    path: { _, _ in .ellipse },
                    bounds: { full, config in
                        let w = config.cylinderEllipseRadius * 2
                        return CGRect(x: full.maxX - w, y: full.minY, width: w, height: full.height)
                    },
                    stroke: .mainStroke,
                    fill: .inherit
                ),
                ShapeDecoration(
                    path: { rect, config in .polyline(points: [
                        CGPoint(x: rect.minX + config.cylinderEllipseRadius, y: rect.minY),
                        CGPoint(x: rect.maxX - config.cylinderEllipseRadius, y: rect.minY),
                    ]) },
                    stroke: .mainStroke
                ),
                ShapeDecoration(
                    path: { rect, config in .polyline(points: [
                        CGPoint(x: rect.minX + config.cylinderEllipseRadius, y: rect.maxY),
                        CGPoint(x: rect.maxX - config.cylinderEllipseRadius, y: rect.maxY),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    static func _makeLinedCylinderSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["lined-cylinder", "lin-cyl", "disk"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 14, config.minimumNodeHeight)
                )
            },
            path: { _, config in .cylinder(topCapInset: config.cylinderEllipseRadius) },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX, y: rect.midY),
                        CGPoint(x: rect.maxX, y: rect.midY),
                    ]) },
                    stroke: .dashed(lengths: [3, 3])
                ),
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
        )
    }
    static func _makeCurvedTrapezoidSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["curbed-trapezoid", "curv-trap", "display"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 20, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .curvedTrapezoid(skew: 0.15) }
        )
    }
    static func _makeDividedRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["divided-rectangle", "div-rect", "div-proc", "divided-process"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX, y: rect.midY),
                        CGPoint(x: rect.maxX, y: rect.midY),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    static func _makeTriangleSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["triangle", "tri", "extract"], sizeAdjustment: { textSize, config in
            CGSize(width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 10, config.minimumNodeWidth), height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 10, config.minimumNodeHeight))
        }, path: { _, _ in .triangle })
    }
    static func _makeWindowPaneSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["internal-storage", "win-pane", "window-pane"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { _, _ in .rect(cornerRadius: 0) },
                    bounds: { full, _ in
                        let inset = full.width * 0.2
                        return CGRect(x: full.maxX - inset - 4, y: full.minY + 4,
                                      width: inset, height: full.height - 8)
                    },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    static func _makeFilledCircleSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["filled-circle", "f-circ", "junction"], sizeAdjustment: { _, _ in CGSize(width: 28, height: 28) }, path: { _, _ in .ellipse }, fillOverride: .foreground, strokeOverride: ShapeDecoration.Stroke.none)
    }
    static func _makeLinedDocumentSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["lined-document", "lin-doc"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .document },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX + 8, y: rect.minY + rect.height * 0.3),
                        CGPoint(x: rect.maxX - 8, y: rect.minY + rect.height * 0.3),
                    ]) },
                    stroke: .thinStroke
                ),
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.minX + 8, y: rect.minY + rect.height * 0.3 + 6),
                        CGPoint(x: rect.maxX - 16, y: rect.minY + rect.height * 0.3 + 6),
                    ]) },
                    stroke: .thinStroke
                ),
            ]
        )
    }
    static func _makeNotchedPentagonSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["loop-limit", "notch-pent", "notched-pentagon"],
            sizeAdjustment: { textSize, config in
                CGSize(width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 10, config.minimumNodeWidth), height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 10, config.minimumNodeHeight))
            },
            path: { _, _ in .triangle }
        )
    }
    static func _makeFlippedTriangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["manual-file", "flip-tri", "flipped-triangle"],
            sizeAdjustment: { textSize, config in
                CGSize(
                    width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 10, config.minimumNodeWidth),
                    height: Swift.max(textSize.height + config.nodePaddingVertical * 2 + 10, config.minimumNodeHeight)
                )
            },
            path: { _, _ in .triangleDown }
        )
    }

    static func _makeSlopedRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["manual-input", "sl-rect", "sloped-rectangle"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .slopedRectangle(slope: 0.2) }
        )
    }
    static func _makeStackedDocumentSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["stacked-document", "docs", "documents", "st-doc"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .document },
            decorations: [
                ShapeDecoration(
                    path: { _, _ in .document },
                    bounds: { full, _ in full.offsetBy(dx: -4, dy: -4) },
                    stroke: .thinStroke
                ),
            ]
        )
    }
    static func _makeStackedRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["stacked-rectangle", "st-rect", "procs", "processes"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { _, _ in .rect(cornerRadius: 0) },
                    bounds: { full, _ in full.offsetBy(dx: -4, dy: -4) },
                    stroke: .thinStroke
                ),
            ]
        )
    }
    static func _makeFlagSpec() -> ShapeSpec { ShapeSpec(aliases: ["paper-tape", "flag"], sizeAdjustment: _rectSizing, path: { _, _ in .flag }) }
    static func _makeBowTieRectangleSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["bow-tie-rectangle", "bow-rect", "stored-data"], sizeAdjustment: { textSize, config in
            CGSize(width: Swift.max(textSize.width + config.nodePaddingHorizontal * 2 + 12, config.minimumNodeWidth), height: Swift.max(textSize.height + config.nodePaddingVertical * 2, config.minimumNodeHeight))
        }, path: { _, _ in .bowTie(indent: 12) })
    }
    static func _makeCrossedCircleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["crossed-circle", "cross-circ", "summary"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .crossedCircle },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.midX - rect.width * 0.25, y: rect.midY - rect.height * 0.25),
                        CGPoint(x: rect.midX + rect.width * 0.25, y: rect.midY + rect.height * 0.25),
                    ]) },
                    stroke: .mainStroke
                ),
                ShapeDecoration(
                    path: { rect, _ in .polyline(points: [
                        CGPoint(x: rect.midX + rect.width * 0.25, y: rect.midY - rect.height * 0.25),
                        CGPoint(x: rect.midX - rect.width * 0.25, y: rect.midY + rect.height * 0.25),
                    ]) },
                    stroke: .mainStroke
                ),
            ]
        )
    }
    static func _makeTaggedDocumentSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["tagged-document", "tag-doc"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .document },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polygon(vertices: [
                        CGPoint(x: rect.maxX - 10, y: rect.minY),
                        CGPoint(x: rect.maxX - 10, y: rect.minY + 10),
                        CGPoint(x: rect.maxX, y: rect.minY + 10),
                    ]) },
                    stroke: .mainStroke,
                    fill: .inherit
                ),
            ]
        )
    }
    static func _makeTaggedRectangleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["tagged-rectangle", "tag-rect", "tag-proc", "tagged-process"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 0) },
            decorations: [
                ShapeDecoration(
                    path: { rect, _ in .polygon(vertices: [
                        CGPoint(x: rect.maxX - 10, y: rect.minY),
                        CGPoint(x: rect.maxX - 10, y: rect.minY + 10),
                        CGPoint(x: rect.maxX, y: rect.minY + 10),
                    ]) },
                    stroke: .mainStroke,
                    fill: .inherit
                ),
            ]
        )
    }
    static func _makeIconSquareSpec() -> ShapeSpec { ShapeSpec(aliases: ["icon-square"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    static func _makeIconCircleSpec() -> ShapeSpec { ShapeSpec(aliases: ["icon-circle"], sizeAdjustment: _rectSizing, path: { _, _ in .ellipse }) }
    static func _makeIconSpec() -> ShapeSpec { ShapeSpec(aliases: ["icon"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    static func _makeIconRoundedSpec() -> ShapeSpec { ShapeSpec(aliases: ["icon-rounded"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 6) }) }
    static func _makeImageSquareSpec() -> ShapeSpec { ShapeSpec(aliases: ["image-square"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    static func _makeStateSpec() -> ShapeSpec { ShapeSpec(aliases: ["state"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    static func _makeChoiceSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["choice", "state-choice"], sizeAdjustment: { textSize, config in
            let side = Swift.max(Swift.max(textSize.width + config.nodePaddingHorizontal * 2, textSize.height + config.nodePaddingVertical * 2), config.minimumNodeWidth) + 16
            return CGSize(width: side, height: side)
        }, path: { _, _ in .diamond })
    }
    static func _makeNoteSpec() -> ShapeSpec { ShapeSpec(aliases: ["note"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    static func _makeRectWithTitleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["rect-with-title"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 4) },
            decorations: [
                ShapeDecoration(
                    path: { sub, _ in .rect(cornerRadius: 4) },
                    bounds: { full, _ in CGRect(x: full.minX, y: full.minY, width: full.width, height: 24) },
                    stroke: .none,
                    fill: .surface
                ),
                ShapeDecoration(
                    path: { _, _ in .polyline(points: [
                        CGPoint(x: 0, y: 24),
                        CGPoint(x: 100, y: 24),  // width overridden by bounds scaling
                    ]) },
                    stroke: .mainStroke,
                    fill: .none
                ),
            ]
        )
    }
    static func _makeLabelRectSpec() -> ShapeSpec { ShapeSpec(aliases: ["label-rect"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    static func _makeAnchorSpec() -> ShapeSpec { ShapeSpec(aliases: ["anchor"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 0) }) }
    static func _makeClassBoxSpec() -> ShapeSpec { ShapeSpec(aliases: ["class-box"], sizeAdjustment: _rectSizing, path: { _, _ in .rect(cornerRadius: 4) }) }
    static func _makeInvisibleSpec() -> ShapeSpec { ShapeSpec(aliases: ["invisible"], sizeAdjustment: { _, _ in .zero }, path: { _, _ in .rect(cornerRadius: 0) }) }
    static func _makeStateStartSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["state-start"],
            sizeAdjustment: { _, _ in CGSize(width: 28, height: 28) },
            path: { _, _ in .ellipse },
            fillOverride: .foreground,
            strokeOverride: ShapeDecoration.Stroke.none
        )
    }
    static func _makeStateEndSpec() -> ShapeSpec { ShapeSpec(aliases: ["state-end"], sizeAdjustment: { _, _ in CGSize(width: 28, height: 28) }, path: { _, _ in .doubleCircle(gap: 5) }) }
    static func _makeStateDividerSpec() -> ShapeSpec { ShapeSpec(aliases: ["state-divider"], sizeAdjustment: { textSize, _ in CGSize(width: Swift.max(textSize.width, 60), height: 12) }, path: { _, _ in .rect(cornerRadius: 0) }) }
    static func _makeStateNoteSpec() -> ShapeSpec { ShapeSpec(aliases: ["state-note"], sizeAdjustment: { textSize, _ in CGSize(width: Swift.max(textSize.width, 80), height: Swift.max(textSize.height, 40)) }, path: { _, _ in .rect(cornerRadius: 6) }) }
    static func _makeRoundedWithTitleSpec() -> ShapeSpec {
        ShapeSpec(
            aliases: ["rounded-with-title"],
            sizeAdjustment: _rectSizing,
            path: { _, _ in .rect(cornerRadius: 8) },
            decorations: [
                ShapeDecoration(
                    path: { sub, _ in .rect(cornerRadius: 8) },
                    bounds: { full, _ in CGRect(x: full.minX, y: full.minY, width: full.width, height: 35) },
                    stroke: .none,
                    fill: .surface
                ),
                ShapeDecoration(
                    path: { _, _ in .polyline(points: [
                        CGPoint(x: 0, y: 35),
                        CGPoint(x: 100, y: 35),
                    ]) },
                    stroke: .mainStroke,
                    fill: .none
                ),
            ]
        )
    }
    static func _makeEllipseSpec() -> ShapeSpec {
        ShapeSpec(aliases: ["ellipse"], sizeAdjustment: { textSize, config in
            let w = textSize.width + config.nodePaddingHorizontal * 2
            let h = textSize.height + config.nodePaddingVertical * 2
            let d = ceil(sqrt(w * w + h * h)) + 8
            return CGSize(width: Swift.max(d, config.minimumNodeWidth), height: Swift.max(d, config.minimumNodeHeight))
        }, path: { _, _ in .ellipse })
    }
}
#endif
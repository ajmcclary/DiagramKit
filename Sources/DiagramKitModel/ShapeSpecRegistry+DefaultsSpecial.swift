// Linux-portable: shape geometry shared by every platform (see PortableRenderSupport.swift).
//
// Second half of `ShapeSpecRegistry+Defaults.swift`, split per REVIEW.md L1
// to keep both files below the file-size warning threshold. Holds the
// document / cylinder / specialized / state / icon spec factories.
// `ShapeSpec._buildSpecs()` ties both halves into a single registry.
import Foundation
#if canImport(CoreGraphics)
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#endif

extension ShapeSpecRegistry {

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

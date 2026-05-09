import Foundation
import DiagramKitModel
import CoreGraphics

extension DiagramRenderer {

    func _drawClass(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard
            let classes = positioned.classNodes,
            let relationships = positioned.classRelationships,
            !classes.isEmpty
        else { return }

        _withFittedContext(context, bounds: bounds, contentWidth: max(1, positioned.width), contentHeight: max(1, positioned.height)) { ctx in
            let ch = max(1, positioned.height)
            let config = self.config

            // Namespace boxes (behind everything)
            if let namespaces = positioned.classNamespaces {
                for ns in namespaces {
                    self._drawClassNamespace(ns, in: ctx, contentHeight: ch)
                }
            }

            // Notes
            if let notes = positioned.classNotes {
                for note in notes {
                    self._drawClassNote(note, in: ctx, contentHeight: ch)
                }
            }

            // Relationships (lines)
            for rel in relationships {
                let pts = rel.points.map { CGPoint(x: $0.x, y: $0.y) }
                guard pts.count >= 2 else { continue }
                ctx.saveGState()
                ctx.setStrokeColor(self.theme.effectiveLine().cgColor)
                ctx.setLineWidth(config.strokeWidthConnector)
                let isDashed = rel.relation.lineType == ClassLineType.dotted.rawValue
                if isDashed { ctx.setLineDash(phase: 0, lengths: [6, 4]) }
                ctx.move(to: pts[0])
                for i in 1..<pts.count { ctx.addLine(to: pts[i]) }
                ctx.strokePath()
                ctx.restoreGState()

                // Two-ended markers
                self._drawClassMarkerTwoEnded(rel, pts: pts, in: ctx)
            }

            // Class boxes
            for cls in classes {
                let box = CGRect(x: cls.x, y: cls.y, width: cls.width, height: cls.height)
                ctx.setFillColor(self.theme.effectiveSurface().cgColor)
                ctx.fill(box)
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.setLineWidth(config.strokeWidthOuterBox)
                ctx.stroke(box)

                // Header
                let headerRect = CGRect(x: cls.x, y: cls.y, width: cls.width, height: cls.headerHeight)
                ctx.setFillColor(self.theme.subgraphHeaderColor().cgColor)
                ctx.fill(headerRect)
                ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                ctx.stroke(headerRect)

                // Annotations
                var nameY = cls.y + cls.headerHeight / 2
                if !cls.annotations.isEmpty {
                    var annotY = cls.y + 12
                    for annotation in cls.annotations {
                        let annotFont = self._italicSystemFont(size: 10, weight: 0.23)
                        self._drawTextInFlipped(
                            "<<\(annotation)>>",
                            at: CGPoint(x: cls.x + cls.width / 2, y: annotY),
                            context: ctx, contentHeight: ch,
                            color: self.theme.effectiveMuted(),
                            font: annotFont,
                            alignment: .center
                        )
                        annotY += 12
                    }
                    nameY = cls.y + cls.headerHeight / 2 + 4 + CGFloat(cls.annotations.count) * 6
                }

                // Class name
                let nameFont = BMFont.systemFont(ofSize: config.fontSizeNodeLabel, weight: .bold)
                let labelText = cls.text.isEmpty ? cls.label : cls.text
                self._drawTextInFlipped(
                    labelText,
                    at: CGPoint(x: cls.x + cls.width / 2, y: nameY),
                    context: ctx, contentHeight: ch,
                    color: self.theme.foreground,
                    font: nameFont,
                    alignment: .center
                )

                // If hideEmptyMembersBox and no members, skip dividers
                let hasAttrs = !cls.attributes.isEmpty
                let hasMethods = !cls.methods.isEmpty

                if hasAttrs {
                    let attrTop = cls.y + cls.headerHeight
                    ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                    ctx.setLineWidth(config.strokeWidthInnerBox)
                    ctx.move(to: CGPoint(x: cls.x, y: attrTop))
                    ctx.addLine(to: CGPoint(x: cls.x + cls.width, y: attrTop))
                    ctx.strokePath()

                    for i in 0..<cls.attributes.count {
                        let member = cls.attributes[i]
                        let memberY = attrTop + 4 + CGFloat(i) * config.classMemberRowHeight + config.classMemberRowHeight / 2
                        self._drawClassMemberHighlighted(member, at: CGPoint(x: cls.x + config.classBoxPadX, y: memberY), context: ctx, contentHeight: ch, config: config)
                    }
                }

                if hasMethods {
                    let methodTop = cls.y + cls.headerHeight + cls.attrHeight
                    ctx.setStrokeColor(self.theme.effectiveBorder().cgColor)
                    ctx.setLineWidth(config.strokeWidthInnerBox)
                    ctx.move(to: CGPoint(x: cls.x, y: methodTop))
                    ctx.addLine(to: CGPoint(x: cls.x + cls.width, y: methodTop))
                    ctx.strokePath()

                    for i in 0..<cls.methods.count {
                        let method = cls.methods[i]
                        let memberY = methodTop + 4 + CGFloat(i) * config.classMemberRowHeight + config.classMemberRowHeight / 2
                        self._drawClassMemberHighlighted(method, at: CGPoint(x: cls.x + config.classBoxPadX, y: memberY), context: ctx, contentHeight: ch, config: config)
                    }
                }
            }

            // Relationship labels + cardinality
            for rel in relationships {
                let hasLabel = rel.title.map { !$0.isEmpty } ?? false
                let hasTitle1 = rel.relationTitle1.map { !$0.isEmpty } ?? false
                let hasTitle2 = rel.relationTitle2.map { !$0.isEmpty } ?? false
                guard hasLabel || hasTitle1 || hasTitle2 else { continue }
                let pts = rel.points.map { CGPoint(x: $0.x, y: $0.y) }
                guard pts.count >= 2 else { continue }
                let labelFont = config.edgeLabelFont()

                if let label = rel.title, !label.isEmpty {
                    let pos = rel.labelPosition.map { CGPoint(x: $0.x, y: $0.y) } ?? pts[pts.count / 2]
                    self._drawTextInFlipped(label, at: CGPoint(x: pos.x, y: pos.y - 8), context: ctx, contentHeight: ch, color: self.theme.effectiveMuted(), font: labelFont, alignment: .center)
                }

                if let title1 = rel.relationTitle1, !title1.isEmpty {
                    let p = pts[0], next = pts[1]
                    let offset = self._cardinalityOffset(from: p, to: next)
                    self._drawTextInFlipped(title1, at: CGPoint(x: p.x + offset.x, y: p.y + offset.y), context: ctx, contentHeight: ch, color: self.theme.effectiveMuted(), font: labelFont, alignment: .center)
                }

                if let title2 = rel.relationTitle2, !title2.isEmpty {
                    let p = pts[pts.count - 1], prev = pts[pts.count - 2]
                    let offset = self._cardinalityOffset(from: p, to: prev)
                    self._drawTextInFlipped(title2, at: CGPoint(x: p.x + offset.x, y: p.y + offset.y), context: ctx, contentHeight: ch, color: self.theme.effectiveMuted(), font: labelFont, alignment: .center)
                }
            }
        }
    }

    // MARK: - Two-ended marker drawing

    private func _drawClassMarkerTwoEnded(_ rel: PositionedClassRelationship, pts: [CGPoint], in context: CGContext) {
        guard pts.count >= 2 else { return }

        // Draw marker at start if type1 != none
        if rel.relation.type1 != ClassRelationType.none.rawValue {
            let endpoint = pts[0]
            let prevPoint = pts[1]
            _drawSingleMarker(rel.relation.type1, endpoint: endpoint, prevPoint: prevPoint, in: context)
        }

        // Draw marker at end if type2 != none
        if rel.relation.type2 != ClassRelationType.none.rawValue {
            let endpoint = pts[pts.count - 1]
            let prevPoint = pts[pts.count - 2]
            _drawSingleMarker(rel.relation.type2, endpoint: endpoint, prevPoint: prevPoint, in: context)
        }
    }

    private func _drawSingleMarker(_ relType: Int, endpoint: CGPoint, prevPoint: CGPoint, in context: CGContext) {
        let angle = atan2(endpoint.y - prevPoint.y, endpoint.x - prevPoint.x)

        context.saveGState()
        context.translateBy(x: endpoint.x, y: endpoint.y)
        context.rotate(by: angle)

        switch relType {
        case ClassRelationType.inheritance.rawValue:
            let path = CGMutablePath()
            path.move(to: .zero); path.addLine(to: CGPoint(x: -12, y: -5)); path.addLine(to: CGPoint(x: -12, y: 5)); path.closeSubpath()
            context.addPath(path)
            context.setFillColor(theme.background.cgColor)
            context.setStrokeColor(theme.effectiveArrow().cgColor)
            context.setLineWidth(1.5)
            context.drawPath(using: .fillStroke)

        case ClassRelationType.composition.rawValue:
            let path = CGMutablePath()
            path.move(to: .zero); path.addLine(to: CGPoint(x: -6, y: -5)); path.addLine(to: CGPoint(x: -12, y: 0)); path.addLine(to: CGPoint(x: -6, y: 5)); path.closeSubpath()
            context.addPath(path)
            context.setFillColor(theme.effectiveArrow().cgColor)
            context.drawPath(using: .fillStroke)

        case ClassRelationType.aggregation.rawValue:
            let path = CGMutablePath()
            path.move(to: .zero); path.addLine(to: CGPoint(x: -6, y: -5)); path.addLine(to: CGPoint(x: -12, y: 0)); path.addLine(to: CGPoint(x: -6, y: 5)); path.closeSubpath()
            context.addPath(path)
            context.setFillColor(theme.background.cgColor)
            context.setStrokeColor(theme.effectiveArrow().cgColor)
            context.setLineWidth(1.5)
            context.drawPath(using: .fillStroke)

        case ClassRelationType.dependency.rawValue:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -8, y: -3)); path.addLine(to: .zero); path.addLine(to: CGPoint(x: -8, y: 3))
            context.addPath(path)
            context.setStrokeColor(theme.effectiveArrow().cgColor)
            context.setLineWidth(1.5)
            context.strokePath()

        case ClassRelationType.lollipop.rawValue:
            let circleRect = CGRect(x: -8, y: -8, width: 16, height: 16)
            context.setStrokeColor(theme.effectiveLine().cgColor)
            context.setLineWidth(1.5)
            context.strokeEllipse(in: circleRect)

        default: break
        }
        context.restoreGState()
    }

    // MARK: - Member drawing

    private func _drawClassMemberHighlighted(
        _ member: ClassMember,
        at point: CGPoint,
        context ctx: CGContext,
        contentHeight ch: CGFloat,
        config: RenderConfig
    ) {
        let memberFont = member.cssStyle.contains("italic")
            ? _italicMonoFont(size: config.classMemberFontSize)
            : _monoFont(size: config.classMemberFontSize)
        var currentX = point.x

        // Visibility symbol
        if !member.visibility.isEmpty {
            let visText = member.visibility + " "
            _drawTextInFlipped(visText, at: CGPoint(x: currentX, y: point.y), context: ctx, contentHeight: ch, color: theme.effectiveTextFaint(), font: memberFont, alignment: .left)
            currentX += config.estimateMonoTextWidth(visText, fontSize: config.classMemberFontSize)
        }

        // Member name (include params if method)
        let genName = parseGenericTypes(member.id)
        let displayName: String
        if member.memberType == .method {
            let genParams = parseGenericTypes(member.parameters)
            displayName = "\(genName)(\(genParams))"
        } else {
            displayName = genName
        }
        _drawTextInFlipped(displayName, at: CGPoint(x: currentX, y: point.y), context: ctx, contentHeight: ch, color: theme.effectiveTextSecondary(), font: memberFont, alignment: .left)

        // Underline for static
        if member.cssStyle.contains("underline") {
            let nameWidth = config.estimateMonoTextWidth(displayName, fontSize: config.classMemberFontSize)
            let underlineY = point.y + 6
            ctx.saveGState()
            ctx.setStrokeColor(theme.effectiveTextSecondary().cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: currentX, y: underlineY))
            ctx.addLine(to: CGPoint(x: currentX + nameWidth, y: underlineY))
            ctx.strokePath()
            ctx.restoreGState()
        }

        currentX += config.estimateMonoTextWidth(displayName, fontSize: config.classMemberFontSize)

        // Return type
        if !member.returnType.isEmpty {
            let genReturn = parseGenericTypes(member.returnType)
            let colonText = " : "
            _drawTextInFlipped(colonText, at: CGPoint(x: currentX, y: point.y), context: ctx, contentHeight: ch, color: theme.effectiveTextFaint(), font: memberFont, alignment: .left)
            currentX += config.estimateMonoTextWidth(colonText, fontSize: config.classMemberFontSize)
            _drawTextInFlipped(genReturn, at: CGPoint(x: currentX, y: point.y), context: ctx, contentHeight: ch, color: theme.effectiveMuted(), font: memberFont, alignment: .left)
        }
    }

    // MARK: - Namespace drawing

    private func _drawClassNamespace(_ ns: PositionedClassNamespace, in context: CGContext, contentHeight ch: CGFloat) {
        context.saveGState()
        let rect = CGRect(x: ns.x, y: ns.y, width: ns.width, height: ns.height)
        context.setStrokeColor(theme.effectiveLine().cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [6, 4])
        let roundedPath = CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil)
        context.addPath(roundedPath)
        context.strokePath()
        context.restoreGState()

        // Label
        if ns.height > 20 {
            let labelFont = config.edgeLabelFont()
            let labelW = config.estimateTextWidth(ns.label, fontSize: config.fontSizeEdgeLabel, fontWeight: 400) + 16
            let labelH = config.fontSizeEdgeLabel + 8
            let labelRect = CGRect(x: ns.x + config.classBoxPadX, y: ns.y - labelH / 2, width: labelW, height: labelH)
            context.saveGState()
            context.setFillColor(theme.subgraphHeaderColor().cgColor)
            context.fill(labelRect)
            context.setStrokeColor(theme.effectiveBorder().cgColor)
            context.setLineWidth(1)
            context.stroke(labelRect)
            context.restoreGState()

            _drawTextInFlipped(ns.label, at: CGPoint(x: ns.x + config.classBoxPadX + 8, y: ns.y), context: context, contentHeight: ch, color: theme.foreground, font: labelFont, alignment: .left)
        }
    }

    // MARK: - Note drawing

    private func _drawClassNote(_ note: PositionedClassNote, in context: CGContext, contentHeight ch: CGFloat) {
        let x = note.x, y = note.y, w = note.width, h = note.height
        let foldSize: CGFloat = 12
        let r: CGFloat = 4

        // Draw UML note shape with folded corner
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x + r, y: y))
        path.addLine(to: CGPoint(x: x + w - foldSize, y: y))
        path.addLine(to: CGPoint(x: x + w - foldSize, y: y + foldSize))
        path.addLine(to: CGPoint(x: x + w, y: y + foldSize))
        path.addLine(to: CGPoint(x: x + w, y: y + h - r))
        path.addQuadCurve(to: CGPoint(x: x + w - r, y: y + h), control: CGPoint(x: x + w, y: y + h))
        path.addLine(to: CGPoint(x: x + r, y: y + h))
        path.addQuadCurve(to: CGPoint(x: x, y: y + h - r), control: CGPoint(x: x, y: y + h))
        path.addLine(to: CGPoint(x: x, y: y + r))
        path.addQuadCurve(to: CGPoint(x: x + r, y: y), control: CGPoint(x: x, y: y))
        path.closeSubpath()

        context.saveGState()
        context.addPath(path)
        // Note color: light yellow
        let noteColor = theme.noteBackgroundColor().cgColor
        context.setFillColor(noteColor)
        context.setStrokeColor(theme.noteBorderColor().cgColor)
        context.setLineWidth(1.5)
        context.drawPath(using: .fillStroke)

        // Fold lines
        context.move(to: CGPoint(x: x + w - foldSize, y: y))
        context.addLine(to: CGPoint(x: x + w - foldSize, y: y + foldSize))
        context.addLine(to: CGPoint(x: x + w, y: y + foldSize))
        context.setStrokeColor(theme.effectiveLine().cgColor)
        context.setLineWidth(1)
        context.strokePath()
        context.restoreGState()

        // Text centered
        let labelFont = config.edgeLabelFont()
        _drawTextInFlipped(note.text, at: CGPoint(x: x + w / 2, y: y + h / 2), context: context, contentHeight: ch, color: theme.foreground, font: labelFont, alignment: .center)

        // Dotted edge to class
        if let edgePts = note.edgePoints, edgePts.count >= 2 {
            context.saveGState()
            context.setStrokeColor(theme.effectiveLine().cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [4, 4])
            context.move(to: CGPoint(x: edgePts[0].x, y: edgePts[0].y))
            for i in 1..<edgePts.count {
                context.addLine(to: CGPoint(x: edgePts[i].x, y: edgePts[i].y))
            }
            context.strokePath()
            context.restoreGState()
        }
    }

    // MARK: - Helpers

    func _cardinalityOffset(from: CGPoint, to: CGPoint) -> CGPoint {
        let dx = to.x - from.x
        let dy = to.y - from.y
        if abs(dx) > abs(dy) {
            return CGPoint(x: dx > 0 ? 14 : -14, y: -10)
        }
        return CGPoint(x: -14, y: dy > 0 ? 14 : -14)
    }
}

import Foundation
import DiagramKitCommon
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(CoreText)
import CoreText
#endif

// MARK: - Layout Constants

private let FONT_SIZE_DEFAULT: Double = 14

/// Mutable accumulator for Ishikawa layout-time diagnostics. Mirrors
/// `_LayoutDiagnostics` from `src_layout.swift`; `@unchecked Sendable` is
/// safe because each layout call runs on a single 8 MB worker thread.
final class _IshikawaDiagnostics: @unchecked Sendable {
    var items: [DiagramDiagnostic] = []
    func warn(_ message: String) {
        items.append(DiagramDiagnostic(severity: .warning, message: message, location: nil))
    }
}
private let SPINE_BASE_LENGTH: Double = 250
private let BONE_STUB: Double = 30
private let BONE_BASE: Double = 60
private let BONE_PER_CHILD: Double = 5
private let ANGLE_RAD: Double = (82 * .pi) / 180
private let COS_A: Double = cos(ANGLE_RAD)
private let SIN_A: Double = sin(ANGLE_RAD)

// MARK: - Text measurement (CoreText-based, mirrors browser getBBox)

private struct _IshikawaTextBounds {
    let width: Double
    let height: Double
    let x: Double
    let y: Double
}

private func _measureIshikawaText(_ lines: [String], fontSize: Double) -> _IshikawaTextBounds {
    guard !lines.isEmpty else {
        return _IshikawaTextBounds(width: 0, height: 0, x: 0, y: 0)
    }
#if canImport(CoreText)
    let font = DiagramFontResolver.shared.monospaceCTFont(size: CGFloat(fontSize))
    let attr: [NSAttributedString.Key: Any] = [
        .font: font,
        .kern: 0
    ]
    var maxWidth: Double = 0
    for line in lines {
        let attrStr = NSAttributedString(string: line, attributes: attr)
        let ctLine = CTLineCreateWithAttributedString(attrStr)
        let bounds = CTLineGetBoundsWithOptions(ctLine, .useOpticalBounds)
        maxWidth = max(maxWidth, Double(bounds.width))
    }
    let lineHeight = fontSize * 1.05
    let totalHeight = lineHeight * Double(lines.count)
    return _IshikawaTextBounds(width: maxWidth, height: totalHeight, x: 0, y: -totalHeight)
#else
    let (maxWidth, totalHeight) = TextMetrics.shared.measureMonospaceMultiline(lines, fontSize: CGFloat(fontSize))
    return _IshikawaTextBounds(width: Double(maxWidth), height: Double(totalHeight), x: 0, y: -Double(totalHeight))
#endif
}

private func _ishikawaWrapText(_ text: String, maxChars: Int) -> [String] {
    if text.count <= maxChars {
        return [text]
    }
    var lines: [String] = []
    for word in text.split(separator: " ") {
        let w = String(word)
        if let last = lines.last, last.count + 1 + w.count <= maxChars {
            lines[lines.count - 1] = last + " " + w
        } else {
            lines.append(w)
        }
    }
    return lines.isEmpty ? [text] : lines
}

private func _ishikawaSplitLines(_ text: String) -> [String] {
    let parts = text.components(separatedBy: "\n")
    return parts.flatMap { line in
        line.components(separatedBy: "<br>").flatMap { br in
            br.components(separatedBy: "<br/>").flatMap { bri in
                bri.components(separatedBy: "<br />")
            }
        }
    }.filter { !$0.isEmpty }
}

// MARK: - Side statistics

private struct _IshikawaSideStats {
    var total: Double
    var max: Double
}
private func _countIshikawaDescendants(_ node: IshikawaNode) -> Double {
    node.children.reduce(0) { sum, child in
        sum + 1 + _countIshikawaDescendants(child)
    }
}

private func _ishikawaSideStats(_ nodes: [IshikawaNode]) -> _IshikawaSideStats {
    nodes.reduce(into: _IshikawaSideStats(total: 0, max: 0)) { stats, node in
        let d = _countIshikawaDescendants(node)
        stats.total += d
        stats.max = max(stats.max, d)
    }
}

// MARK: - Flatten tree

private struct _IshikawaLabelEntry {
    let text: [String]
    let depth: Int
    let parentIndex: Int
    let childCount: Int
}

private struct _IshikawaBoneInfo {
    let x0: Double
    let y0: Double
    let x1: Double
    let y1: Double
    let childCount: Int
    var childrenDrawn: Int
}

/// Soft cap on Ishikawa-tree recursion. Pathological input would otherwise
/// keep recursing until the worker stack is exhausted; truncating here
/// reports a diagnostic and stops the walk gracefully.
private let _MAX_ISHIKAWA_RECURSION_DEPTH = 1024

private func _flattenIshikawaTree(_ children: [IshikawaNode], direction: Int, diagnostics: _IshikawaDiagnostics? = nil) -> (entries: [_IshikawaLabelEntry], yOrder: [Int]) {
    var entries: [_IshikawaLabelEntry] = []
    var yOrder: [Int] = []

    func walk(_ nodes: [IshikawaNode], pid: Int, depth: Int) {
        if depth >= _MAX_ISHIKAWA_RECURSION_DEPTH {
            diagnostics?.warn("Ishikawa recursion depth exceeded \(_MAX_ISHIKAWA_RECURSION_DEPTH); truncating tree walk.")
            return
        }
        let ordered = direction == -1 ? Array(nodes.reversed()) : nodes
        for child in ordered {
            let idx = entries.count
            let gc = child.children
            entries.append(_IshikawaLabelEntry(
                text: _ishikawaWrapText(child.text, maxChars: 15),
                depth: depth,
                parentIndex: pid,
                childCount: gc.count
            ))
            if depth % 2 == 0 {
                yOrder.append(idx)
                if !gc.isEmpty {
                    walk(gc, pid: idx, depth: depth + 1)
                }
            } else {
                if !gc.isEmpty {
                    walk(gc, pid: idx, depth: depth + 1)
                }
                yOrder.append(idx)
            }
        }
    }

    walk(children, pid: -1, depth: 2)
    return (entries, yOrder)
}

private func _lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

private func _ishikawaLabelTextLeftEdge(_ label: PositionedIshikawaLabel) -> Double {
    switch label.anchor {
    case .start:
        return label.x
    case .middle:
        return label.x - label.width / 2
    case .end:
        return label.x - label.width
    }
}

private func _ishikawaLabelTextRightEdge(_ label: PositionedIshikawaLabel) -> Double {
    switch label.anchor {
    case .start:
        return label.x + label.width
    case .middle:
        return label.x + label.width / 2
    case .end:
        return label.x
    }
}

private func _ishikawaLabelLeftEdge(_ label: PositionedIshikawaLabel) -> Double {
    if let box = label.box {
        return min(box.x, _ishikawaLabelTextLeftEdge(label))
    }
    return _ishikawaLabelTextLeftEdge(label)
}

private func _ishikawaLabelRightEdge(_ label: PositionedIshikawaLabel) -> Double {
    if let box = label.box {
        return max(box.x + box.width, _ishikawaLabelTextRightEdge(label))
    }
    return _ishikawaLabelTextRightEdge(label)
}

private func _ishikawaLabelTopEdge(_ label: PositionedIshikawaLabel) -> Double {
    let textTop = label.y - label.height / 2
    if let box = label.box {
        return min(box.y, textTop)
    }
    return textTop
}

private func _ishikawaLabelBottomEdge(_ label: PositionedIshikawaLabel) -> Double {
    let textBottom = label.y + label.height / 2
    if let box = label.box {
        return max(box.y + box.height, textBottom)
    }
    return textBottom
}

// MARK: - Public layout

public func layoutIshikawaDiagram(_ diagram: IshikawaDiagram) -> (PositionedIshikawaDiagram, [DiagramDiagnostic]) {
    let bag = _IshikawaDiagnostics()
    let positioned = _layoutIshikawaInternal(diagram, fontSize: FONT_SIZE_DEFAULT, diagnostics: bag)
    return (positioned, bag.items)
}

public func _layoutIshikawa(_ diagram: IshikawaDiagram, fontSize: Double) -> PositionedIshikawaDiagram {
    _layoutIshikawaInternal(diagram, fontSize: fontSize, diagnostics: nil)
}

func _layoutIshikawaInternal(_ diagram: IshikawaDiagram, fontSize: Double, diagnostics: _IshikawaDiagnostics? = nil) -> PositionedIshikawaDiagram {
    var result = PositionedIshikawaDiagram(config: diagram.config)
    result.diagramTitle = diagram.diagramTitle
    result.accTitle = diagram.accTitle
    result.accDescr = diagram.accDescr

    guard let root = diagram.root else {
        return result
    }

    let causes = root.children
    let padding = diagram.config.diagramPadding

    var spineX: Double = 0
    var spineY: Double = SPINE_BASE_LENGTH

    let headMaxChars = max(6, Int(floor(110 / (fontSize * 0.6))))
    let headLines = _ishikawaWrapText(root.text, maxChars: headMaxChars)
    let headBounds = _measureIshikawaText(headLines, fontSize: fontSize)
    let headW = max(60, headBounds.width + 6)
    let headH = max(40, headBounds.height * 2 + 40)
    let headPath = "M 0 \(-headH / 2) L 0 \(headH / 2) Q \(headW * 2.4) 0 0 \(-headH / 2) Z"
    let headLabelX = headW / 2 + 3
    let headLabelY = 0.0

    let head = PositionedIshikawaHead(
        path: headPath,
        x: spineX,
        y: spineY,
        width: headW,
        height: headH,
        labelX: headLabelX,
        labelY: headLabelY,
        lines: headLines
    )
    result.head = head

    var bones: [PositionedIshikawaBone] = []
    var labels: [PositionedIshikawaLabel] = []
    var boneId = 0

    if causes.isEmpty {
        let spineBone = PositionedIshikawaBone(
            id: boneId, x1: spineX, y1: spineY, x2: spineX, y2: spineY,
            kind: .spine, depth: 0, marker: .normalArrowAtStart
        )
        boneId += 1
        bones.append(spineBone)
        result.bones = bones
        result.labels = labels
        result.usesMarkerDefinition = true
        let minX = spineX
        let maxX = headW
        let minY = spineY - headH / 2
        let maxY = spineY + headH / 2
        result.viewBox = CGRect(x: minX - padding, y: minY - padding, width: (maxX - minX) + padding * 2, height: (maxY - minY) + padding * 2)
        result.width = Double(result.viewBox.width)
        result.height = Double(result.viewBox.height)
        return result
    }

    spineX -= 20

    let upperCauses = causes.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
    let lowerCauses = causes.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)

    let upperStats = _ishikawaSideStats(upperCauses)
    let lowerStats = _ishikawaSideStats(lowerCauses)
    let descendantTotal = upperStats.total + lowerStats.total

    var upperLen = SPINE_BASE_LENGTH
    var lowerLen = SPINE_BASE_LENGTH
    if descendantTotal > 0 {
        let pool = SPINE_BASE_LENGTH * 2
        let minLen = SPINE_BASE_LENGTH * 0.3
        upperLen = max(minLen, pool * (upperStats.total / descendantTotal))
        lowerLen = max(minLen, pool * (lowerStats.total / descendantTotal))
    }

    let minSpacing = fontSize * 2
    upperLen = max(upperLen, upperStats.max * minSpacing)
    lowerLen = max(lowerLen, lowerStats.max * minSpacing)

    spineY = max(upperLen, SPINE_BASE_LENGTH)
    var mutableHead = head
    mutableHead = PositionedIshikawaHead(path: headPath, x: mutableHead.x, y: spineY,
                                          width: mutableHead.width, height: mutableHead.height,
                                          labelX: mutableHead.labelX, labelY: mutableHead.labelY,
                                          lines: mutableHead.lines)
    result.head = mutableHead

    let pairCount = (causes.count + 1) / 2
    for p in 0..<pairCount {
        let upperCause = p * 2 < causes.count ? causes[p * 2] : nil as IshikawaNode?
        let lowerCause = p * 2 + 1 < causes.count ? causes[p * 2 + 1] : nil as IshikawaNode?

        let pairLabelStart = labels.count
        var pairMinX = Double.infinity

        if let cause = upperCause {
            _drawBranch(&bones, &labels, &boneId, node: cause, startX: spineX, startY: spineY,
                        direction: -1, length: upperLen, fontSize: fontSize, diagnostics: diagnostics)
        }

        if let cause = lowerCause {
            _drawBranch(&bones, &labels, &boneId, node: cause, startX: spineX, startY: spineY,
                        direction: 1, length: lowerLen, fontSize: fontSize, diagnostics: diagnostics)
        }

        for label in labels[pairLabelStart..<labels.count] {
            pairMinX = min(pairMinX, _ishikawaLabelTextLeftEdge(label))
        }

        if pairMinX < Double.infinity {
            spineX = pairMinX
        }
    }

    let spineBone = PositionedIshikawaBone(
        id: boneId, x1: spineX, y1: spineY, x2: 0, y2: spineY,
        kind: .spine, depth: 0, marker: .normalArrowAtStart
    )
    boneId += 1
    bones.append(spineBone)

    result.bones = bones
    result.labels = labels
    result.usesMarkerDefinition = true

    var minX = spineX
    var maxX = headW
    var minY = spineY - upperLen
    var maxY = spineY + lowerLen

    for label in labels {
        minX = min(minX, _ishikawaLabelLeftEdge(label))
        maxX = max(maxX, _ishikawaLabelRightEdge(label))
        minY = min(minY, _ishikawaLabelTopEdge(label))
        maxY = max(maxY, _ishikawaLabelBottomEdge(label))
    }

    let pad = padding
    result.viewBox = CGRect(x: minX - pad, y: minY - pad, width: (maxX - minX) + pad * 2, height: (maxY - minY) + pad * 2)
    result.width = Double(result.viewBox.width)
    result.height = Double(result.viewBox.height)

    return result
}

// MARK: - Branch drawing

@discardableResult
private func _drawBranch(
    _ bones: inout [PositionedIshikawaBone],
    _ labels: inout [PositionedIshikawaLabel],
    _ boneId: inout Int,
    node: IshikawaNode,
    startX: Double,
    startY: Double,
    direction: Int,
    length: Double,
    fontSize: Double,
    diagnostics: _IshikawaDiagnostics? = nil
) -> [PositionedIshikawaBone] {
    let children = node.children
    let lineLen = length * (children.isEmpty ? 0.2 : 1.0)
    let dx = -COS_A * lineLen
    let dy = SIN_A * lineLen * Double(direction)
    let endX = startX + dx
    let endY = startY + dy

    let branchBone = PositionedIshikawaBone(
        id: boneId, x1: startX, y1: startY, x2: endX, y2: endY,
        kind: .branch, direction: direction < 0 ? .upper : .lower,
        depth: 1, marker: .normalArrowAtStart
    )
    boneId += 1
    bones.append(branchBone)

    let causeLines = _ishikawaWrapText(node.text, maxChars: 15)
    let causeBounds = _measureIshikawaText(causeLines, fontSize: fontSize)
    let lh = fontSize * 1.05
    let causeY = endY + 11 * Double(direction) - (Double(causeLines.count - 1) * lh) / 2
    let causeTextLeft = endX - causeBounds.width / 2
    let causeLabel = PositionedIshikawaLabel(
        text: node.text,
        lines: causeLines,
        x: endX,
        y: causeY,
        width: causeBounds.width,
        height: causeBounds.height,
        anchor: .middle,
        labelClass: .cause,
        direction: direction < 0 ? .upper : .lower,
        depth: 0,
        parentBoneId: branchBone.id,
        box: PositionedIshikawaLabelBox(
            x: causeTextLeft - 20,
            y: causeY - lh - 2,
            width: causeBounds.width + 40,
            height: causeBounds.height + 4
        )
    )
    labels.append(causeLabel)

    if children.isEmpty {
        return [branchBone]
    }

    let (entries, yOrder) = _flattenIshikawaTree(children, direction: direction, diagnostics: diagnostics)
    let entryCount = entries.count
    var ys = Array(repeating: 0.0, count: entryCount)
    for (slot, entryIdx) in yOrder.enumerated() {
        ys[entryIdx] = startY + dy * (Double(slot + 1) / Double(entryCount + 1))
    }

    var boneMap = [Int: _IshikawaBoneInfo]()
    boneMap[-1] = _IshikawaBoneInfo(
        x0: startX, y0: startY, x1: endX, y1: endY,
        childCount: children.count, childrenDrawn: 0
    )

    let diagonalX = -COS_A
    let diagonalY = SIN_A * Double(direction)
    let oddLabelClass: IshikawaLabelClass = direction < 0 ? .up : .down

    for (i, e) in entries.enumerated() {
        let y = ys[i]
        let par = boneMap[e.parentIndex]!

        if e.depth % 2 == 0 {
            let dyP = par.y1 - par.y0
            let t = dyP != 0 ? (y - par.y0) / dyP : 0.5
            let bx0 = _lerp(par.x0, par.x1, t)
            let by0 = y
            let subLen = e.childCount > 0 ? BONE_BASE + Double(e.childCount) * BONE_PER_CHILD : BONE_STUB
            let bx1 = bx0 - subLen

            let subBone = PositionedIshikawaBone(
                id: boneId, x1: bx0, y1: y, x2: bx1, y2: y,
                kind: .subBranch, depth: e.depth,
                parentBoneId: e.parentIndex >= 0 ? e.parentIndex : nil,
                marker: .normalArrowAtStart
            )
            boneId += 1
            bones.append(subBone)

            let subLines = e.text
            let subBounds = _measureIshikawaText(subLines, fontSize: fontSize)
            let subLabelY = y - (Double(subLines.count - 1) * lh) / 2
            let subLabel = PositionedIshikawaLabel(
                text: subLines.joined(separator: "\n"),
                lines: subLines,
                x: bx1,
                y: subLabelY,
                width: subBounds.width,
                height: subBounds.height,
                anchor: .end,
                labelClass: .align,
                direction: direction < 0 ? .upper : .lower,
                depth: e.depth,
                parentBoneId: subBone.id
            )
            labels.append(subLabel)

            if e.childCount > 0 {
                boneMap[i] = _IshikawaBoneInfo(
                    x0: bx0, y0: by0, x1: bx1, y1: y,
                    childCount: e.childCount, childrenDrawn: 0
                )
            }
        } else {
            let k = par.childrenDrawn
            var mutablePar = par
            mutablePar.childrenDrawn += 1
            boneMap[e.parentIndex] = mutablePar

            let t = Double(par.childCount - k) / Double(par.childCount + 1)
            let bx0 = _lerp(par.x0, par.x1, t)
            let by0 = par.y0
            let bx1 = bx0 + diagonalX * ((y - by0) / diagonalY)

            let subBone = PositionedIshikawaBone(
                id: boneId, x1: bx0, y1: by0, x2: bx1, y2: y,
                kind: .subBranch, depth: e.depth,
                parentBoneId: e.parentIndex >= 0 ? e.parentIndex : nil,
                marker: .normalArrowAtStart
            )
            boneId += 1
            bones.append(subBone)

            let subLines = e.text
            let subBounds = _measureIshikawaText(subLines, fontSize: fontSize)
            let subLabelY = y - (Double(subLines.count - 1) * lh) / 2
            let subLabel = PositionedIshikawaLabel(
                text: subLines.joined(separator: "\n"),
                lines: subLines,
                x: bx1,
                y: subLabelY,
                width: subBounds.width,
                height: subBounds.height,
                anchor: .end,
                labelClass: oddLabelClass,
                direction: direction < 0 ? .upper : .lower,
                depth: e.depth,
                parentBoneId: subBone.id
            )
            labels.append(subLabel)

            if e.childCount > 0 {
                boneMap[i] = _IshikawaBoneInfo(
                    x0: bx0, y0: by0, x1: bx1, y1: y,
                    childCount: e.childCount, childrenDrawn: 0
                )
            }
        }
    }

    return bones.filter { $0.kind == .branch && $0.id == branchBone.id }
}

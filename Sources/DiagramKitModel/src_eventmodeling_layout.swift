import Foundation
import DiagramKitCommon
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(CoreText)
import CoreText
#endif

// MARK: - Layout Constants

private struct EMPDefaults {
    static let swimlaneMinHeight: Double = 70
    static let swimlanePadding: Double = 15
    static let swimlaneGap: Double = 10
    static let boxPadding: Double = 10
    static let boxOverlap: Double = 90
    static let boxMinWidth: Double = 80
    static let boxMaxWidth: Double = 450
    static let boxMinHeight: Double = 80
    static let boxMaxHeight: Double = 750
    static let contentStartX: Double = 250
    static let textMaxWidth: Double = 430
    static let boxTextPadding: Double = 10
    static let fontSize: Double = 16
    static let fontWeight: Double = 700
#if canImport(CoreText)
    static var fontFamily: String { DiagramFontResolver().svgProportionalFamilyChain }
#else
    static var fontFamily: String { "Inter, Verdana, sans-serif" }
#endif
}

// MARK: - Public layout entry point

public func layoutEventModeling(_ diagram: EventModelingDiagram) -> PositionedEventModelingDiagram {
    guard !diagram.frames.isEmpty else {
        return PositionedEventModelingDiagram(
            diagramTitle: diagram.diagramTitle,
            accTitle: diagram.accTitle,
            accDescr: diagram.accDescr,
            config: diagram.config,
            themeVariables: diagram.themeVariables
        )
    }

    let theme = diagram.themeVariables

    // Phase 1: Assign swimlanes
    var swimlanes: [Int: PositionedEventModelingSwimlane] = [:]
    var frameSwimlaneIndices: [Int] = [] // maps frame source-order index -> swimlane index

    for frame in diagram.frames {
        let sl = getOrCreateSwimlane(
            for: frame,
            swimlanes: &swimlanes
        )
        frameSwimlaneIndices.append(sl.index)
    }

    // Phase 2: Position boxes
    var boxes: [PositionedEventModelingBox] = []

    for (i, frame) in diagram.frames.enumerated() {
        let swimlaneIndex = frameSwimlaneIndices[i]
        guard var swimlane = swimlanes[swimlaneIndex] else { continue }

        // Compute text content and extract raw data text for measurement
        let entityName = extractEntityName(frame.entityIdentifier)
        let textContent = formatBoxText(
            entityName: entityName,
            frame: frame,
            dataEntities: diagram.dataEntities
        )

        let dataText: String?
        let hasRenderedData: Bool
        if let inlineValue = frame.dataInlineValue {
            dataText = stripBraces(inlineValue)
            hasRenderedData = !(dataText?.isEmpty ?? true)
        } else if let refName = frame.dataReferenceName,
                  let dataEntity = diagram.dataEntities.first(where: { $0.name == refName }) {
            dataText = stripBraces(dataEntity.dataBlockValue)
            hasRenderedData = !(dataText?.isEmpty ?? true)
        } else {
            dataText = nil
            hasRenderedData = false
        }

        let (textWidth, textHeight) = _measureTextDimensions(
            entityName: entityName,
            hasRenderedData: hasRenderedData,
            dataText: dataText,
            maxWidth: EMPDefaults.textMaxWidth,
            fontSize: EMPDefaults.fontSize
        )

        // Clamp box dimensions
        let boxWidth = max(EMPDefaults.boxMinWidth,
                           min(EMPDefaults.boxMaxWidth,
                               textWidth + 2 * EMPDefaults.boxTextPadding)) + 2 * EMPDefaults.boxPadding
        let boxHeight = max(EMPDefaults.boxMinHeight,
                            min(EMPDefaults.boxMaxHeight,
                                textHeight + 2 * EMPDefaults.boxTextPadding)) + 2 * EMPDefaults.boxPadding

        // Compute x position
        let x: Double
        if i == 0 {
            x = EMPDefaults.contentStartX
        } else {
            let prevBox = boxes[i - 1]
            let prevSwimlaneIndex = frameSwimlaneIndices[i - 1]
            if prevSwimlaneIndex == swimlaneIndex && swimlane.r != 0 {
                x = swimlane.r + EMPDefaults.boxPadding
            } else {
                x = prevBox.r - EMPDefaults.boxOverlap + EMPDefaults.boxPadding
            }
        }

        let r = x + boxWidth + EMPDefaults.boxPadding
        let initialY = swimlane.y + EMPDefaults.swimlanePadding

        let fill = theme.fill(for: frame.modelEntityType)
        let stroke = theme.stroke(for: frame.modelEntityType)

        let box = PositionedEventModelingBox(
            x: x,
            y: initialY,
            r: r,
            width: boxWidth,
            height: boxHeight,
            swimlaneIndex: swimlaneIndex,
            fill: fill,
            stroke: stroke,
            textContent: textContent,
            frameIndex: i,
            frameName: frame.name
        )
        boxes.append(box)

        // Update swimlane
        swimlane.r = max(swimlane.r, x + boxWidth)
        swimlane.maxHeight = max(swimlane.maxHeight, boxHeight)
        swimlanes[swimlaneIndex] = swimlane
    }

    // Phase 3: Create relations
    var pendingRelations: [(sourceBoxIndex: Int, targetBoxIndex: Int, stroke: String)] = []

    for (i, frame) in diagram.frames.enumerated() {
        if i == 0 || frame.isResetFrame { continue }
        let swimlaneIndex = frameSwimlaneIndices[i]

        if !frame.sourceFrameNames.isEmpty {
            // Explicit source references - create one relation per source
            for srcName in frame.sourceFrameNames {
                if let srcIdx = boxes.firstIndex(where: { $0.frameName == srcName }) {
                    let srcSwimlane = frameSwimlaneIndices[boxes[srcIdx].frameIndex]
                    if srcSwimlane != swimlaneIndex {
                        let relStroke = theme.emRelationStroke ?? theme.stroke(for: frame.modelEntityType)
                        pendingRelations.append((sourceBoxIndex: srcIdx, targetBoxIndex: i, stroke: relStroke))
                    }
                }
            }
        } else {
            // Implicit relation: scan backward for most recent box in different swimlane
            var foundSrcIdx: Int?
            for j in stride(from: i - 1, through: 0, by: -1) {
                let prevSwimlane = frameSwimlaneIndices[boxes[j].frameIndex]
                if prevSwimlane != swimlaneIndex {
                    foundSrcIdx = j
                    break
                }
            }
            if let srcIdx = foundSrcIdx {
                let relStroke = theme.emRelationStroke ?? theme.stroke(for: frame.modelEntityType)
                pendingRelations.append((sourceBoxIndex: srcIdx, targetBoxIndex: i, stroke: relStroke))
            }
        }
    }

    // Phase 4: Recalculate swimlane y-coordinates
    let sortedSl = swimlanes.values.sorted(by: { $0.index < $1.index })
    var recalcSwimlanes: [PositionedEventModelingSwimlane] = []
    var cumulativeY: Double = 0

    for sl in sortedSl {
        let height = max(EMPDefaults.swimlaneMinHeight, sl.maxHeight) + 2 * EMPDefaults.swimlanePadding
        var updated = sl
        updated.y = cumulativeY
        updated.height = height
        recalcSwimlanes.append(updated)
        cumulativeY += height + EMPDefaults.swimlaneGap
    }

    // Recalculate box y-coordinates
    for idx in boxes.indices {
        let slIndex = boxes[idx].swimlaneIndex
        if let sl = recalcSwimlanes.first(where: { $0.index == slIndex }) {
            boxes[idx].y = sl.y + EMPDefaults.swimlanePadding
            // Also recalculate r for consistent box bounds
            boxes[idx].r = boxes[idx].x + boxes[idx].width + EMPDefaults.boxPadding
        }
    }

    // Phase 5: Compute relation endpoints
    let maxR = recalcSwimlanes.map(\.r).max() ?? EMPDefaults.contentStartX
    var diagramHeight = recalcSwimlanes.last.map { $0.y + $0.height } ?? 0

    // Ensure minimum height
    if diagramHeight < 100 { diagramHeight = 100 }

    var relations: [PositionedEventModelingRelation] = []

    for (srcIdx, tgtIdx, stroke) in pendingRelations {
        guard srcIdx < boxes.count, tgtIdx < boxes.count else { continue }
        let sourceBox = boxes[srcIdx]
        let targetBox = boxes[tgtIdx]

        let sourceSwimlaneIndex = sourceBox.swimlaneIndex
        let targetSwimlaneIndex = targetBox.swimlaneIndex

        let sourceX: Double
        let sourceY: Double
        let targetX: Double
        let targetY: Double

        // Upwards: source swimlane index > target swimlane index (source is below target)
        if sourceSwimlaneIndex > targetSwimlaneIndex {
            // Source is lower, target is higher - arrow goes UP
            sourceX = sourceBox.x + (2.0 / 3.0) * sourceBox.width
            sourceY = sourceBox.y
            targetX = targetBox.x + (1.0 / 3.0) * targetBox.width
            targetY = targetBox.y + targetBox.height
        } else {
            // Source is higher, target is lower - arrow goes DOWN
            sourceX = sourceBox.x + (2.0 / 3.0) * sourceBox.width
            sourceY = sourceBox.y + sourceBox.height
            targetX = targetBox.x + (1.0 / 3.0) * targetBox.width
            targetY = targetBox.y
        }

        relations.append(PositionedEventModelingRelation(
            sourceX: sourceX,
            sourceY: sourceY,
            targetX: targetX,
            targetY: targetY,
            sourceBoxIndex: srcIdx,
            targetBoxIndex: tgtIdx,
            fill: "none",
            stroke: stroke
        ))
    }

    let diagramWidth = maxR + EMPDefaults.swimlanePadding

    return PositionedEventModelingDiagram(
        width: diagramWidth,
        height: diagramHeight,
        swimlanes: recalcSwimlanes,
        boxes: boxes,
        relations: relations,
        diagramTitle: diagram.diagramTitle,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        config: diagram.config,
        themeVariables: diagram.themeVariables
    )
}

// MARK: - Swimlane assignment

private func getOrCreateSwimlane(
    for frame: EventModelingFrame,
    swimlanes: inout [Int: PositionedEventModelingSwimlane]
) -> PositionedEventModelingSwimlane {
    let namespace = extractNamespace(frame.entityIdentifier)
    let defaultIndex: Int
    let defaultLabel: String
    let prefix: String

    switch frame.modelEntityType {
    case .ui, .pcr:
        defaultIndex = 0
        defaultLabel = "UI/Automation"
        prefix = "UI/A: "
    case .cmd, .rmo:
        defaultIndex = 100
        defaultLabel = "Command/Read Model"
        prefix = "C/RM: "
    case .evt:
        defaultIndex = 200
        defaultLabel = "Events"
        prefix = "Stream: "
    }

    if let ns = namespace {
        // Find existing swimlane by namespace within the range
        let rangeStart = defaultIndex
        let rangeEnd = defaultIndex + 100
        if let existing = swimlanes.first(where: { $0.value.namespace == ns && $0.key >= rangeStart && $0.key < rangeEnd }) {
            return existing.value
        }
        // Assign next available index (Mermaid's max+1 approach)
        let existingIndices = swimlanes.keys.filter { $0 > defaultIndex && $0 < rangeEnd }
        let nextIdx: Int
        if existingIndices.isEmpty {
            nextIdx = defaultIndex
        } else {
            nextIdx = existingIndices.max()! + 1
        }

        let sl = PositionedEventModelingSwimlane(
            index: nextIdx,
            label: prefix + ns,
            namespace: ns
        )
        swimlanes[nextIdx] = sl
        return sl
    } else {
        // Default swimlane
        if let existing = swimlanes[defaultIndex] {
            return existing
        }
        let sl = PositionedEventModelingSwimlane(
            index: defaultIndex,
            label: defaultLabel
        )
        swimlanes[defaultIndex] = sl
        return sl
    }
}

// MARK: - Text helpers

private func extractEntityName(_ identifier: String) -> String {
    let parts = identifier.split(separator: ".")
    if parts.count >= 2 { return String(parts.last!) }
    return identifier
}

private func extractNamespace(_ identifier: String) -> String? {
    let parts = identifier.split(separator: ".")
    if parts.count == 2 { return String(parts[0]) }
    return nil
}

private func formatBoxText(
    entityName: String,
    frame: EventModelingFrame,
    dataEntities: [EventModelingDataEntity]
) -> String {
    var html = "<b>\(sanitizeEntityText(entityName))</b>"

    // Get data content
    var dataContent: String?

    if let inlineValue = frame.dataInlineValue {
        // Strip outer { and }
        let stripped = stripBraces(inlineValue)
        dataContent = sanitizeDataText(stripped)
    } else if let refName = frame.dataReferenceName,
              let dataEntity = dataEntities.first(where: { $0.name == refName }) {
        let stripped = stripBraces(dataEntity.dataBlockValue)
        dataContent = sanitizeDataText(stripped)
    }

    if let data = dataContent, !data.isEmpty {
        html += "<br/><br/><code style=\"text-align: left; display: block; max-width:\(Int(EMPDefaults.textMaxWidth))px\">\(data)</code>"
    }

    return html
}

private func stripBraces(_ text: String) -> String {
    var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.hasPrefix("{") { t = String(t.dropFirst()) }
    if t.hasSuffix("}") { t = String(t.dropLast()) }
    return t.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func sanitizeEntityText(_ text: String) -> String {
    SVG.escapeAttribute(text)
}

private func sanitizeDataText(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: " ", with: "&nbsp;")
}

private func _measureTextDimensions(
    entityName: String,
    hasRenderedData: Bool,
    dataText: String?,
    maxWidth: Double,
    fontSize: Double
) -> (width: Double, height: Double) {
    let plainText: String
    if hasRenderedData, let data = dataText, !data.isEmpty {
        plainText = entityName + "\n\n" + data
    } else {
        plainText = entityName
    }

#if canImport(CoreText)
    let font = DiagramFontResolver().proportionalCTFont(size: CGFloat(fontSize))
    let attr: [NSAttributedString.Key: Any] = [.font: font]
    let attrStr = NSAttributedString(string: plainText, attributes: attr)

    let framesetter = CTFramesetterCreateWithAttributedString(attrStr)
    let constraintSize = CGSize(width: CGFloat(maxWidth), height: .greatestFiniteMagnitude)
    let frameSize = CTFramesetterSuggestFrameSizeWithConstraints(
        framesetter,
        CFRange(location: 0, length: 0),
        nil,
        constraintSize,
        nil
    )

    var width = Double(frameSize.width)
    if hasRenderedData {
        width = width / 3.0
    }
    let height = Double(frameSize.height)

    return (width, height)
#else
    // Linux fallback: per-line char-count estimation, clamped to maxWidth.
    // Approximates the CoreText framesetter's wrap+measure behavior without
    // glyph metrics. Geometric validity only.
    let lines = plainText.components(separatedBy: "\n")
    var maxLineWidth: Double = 0
    var lineCount = 0
    for line in lines {
        if line.isEmpty {
            lineCount += 1
            continue
        }
        let raw = Double(TextMetrics.shared.estimateTextWidth(
            line, fontSize: CGFloat(fontSize), fontWeight: 400))
        if raw <= maxWidth {
            maxLineWidth = max(maxLineWidth, raw)
            lineCount += 1
        } else {
            // Wrap into ceil(raw / maxWidth) visual lines.
            maxLineWidth = max(maxLineWidth, maxWidth)
            lineCount += Int((raw / maxWidth).rounded(.up))
        }
    }
    var width = maxLineWidth
    if hasRenderedData {
        width = width / 3.0
    }
    let height = Double(lineCount) * fontSize * 1.2
    return (width, height)
#endif
}

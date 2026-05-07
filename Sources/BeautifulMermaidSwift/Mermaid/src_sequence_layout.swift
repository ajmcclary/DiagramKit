// Ported from original/src/sequence/layout.ts
import Foundation

// MARK: - Internal Config Adapter

private enum _C {
    static var `default`: SequenceDiagramConfig { .default }
}

public func layoutSequenceDiagram(
    _ diagram: SequenceDiagram,
    _ options: RenderOptions = RenderOptions(),
    config: SequenceDiagramConfig = .default
) throws -> PositionedSequenceDiagram {
    try _layoutSequenceDiagramEntry(diagram, config)
}

private func _layoutSequenceDiagramEntry(
    _ diagram: SequenceDiagram,
    _ cfg: SequenceDiagramConfig
) throws -> PositionedSequenceDiagram {
    let actors = diagram.actors
    let messages = diagram.messages
    let blocks = diagram.blocks
    let notes = diagram.notes
    let boxes = diagram.boxes

    // Filter unused participants if configured
    let visibleActors: [SequenceActor]
    if cfg.hideUnusedParticipants {
        let usedIds = Set(messages.flatMap { [$0.from, $0.to] })
        visibleActors = actors.filter { !$0.isExplicit || usedIds.contains($0.id) }
    } else {
        visibleActors = actors
    }

    if visibleActors.isEmpty {
        return PositionedSequenceDiagram(width: 0, height: 0)
    }

    let actorCount = visibleActors.count

    // Compute actor widths
    let actorWidths: [Double] = visibleActors.map { actor in
        let textW = original_src_styles.estimateTextWidth(
            actor.label,
            original_src_styles.FONT_SIZES.nodeLabel,
            original_src_styles.FONT_WEIGHTS.nodeLabel
        )
        return max(textW + 32, cfg.width * 0.5)
    }

    // Position actor centers
    var actorCenterX: [Double] = []
    var currentX = cfg.diagramMarginX + actorWidths[0] / 2
    for i in 0..<actorCount {
        if i > 0 {
            let minGap = max(cfg.actorMargin, (actorWidths[i - 1] + actorWidths[i]) / 2 + 40)
            currentX += minGap
        }
        actorCenterX.append(currentX)
    }

    // Adjust for boxes (expand gap for boxed actors)
    if !boxes.isEmpty {
        var boxActors: [String: [Int]] = [:]
        for (boxIdx, box) in boxes.enumerated() {
            for actorId in box.actorIds {
                boxActors[actorId, default: []].append(boxIdx)
            }
        }
        // Actors in the same box stay close; boxes get margin
        // Simplified: add boxMargin between boxes
        var lastBoxRight: Double? = nil
        for box in boxes {
            if box.actorIds.isEmpty { continue }
            let indices: [Int] = box.actorIds.compactMap { id in visibleActors.firstIndex(where: { $0.id == id }) }
            guard let first = indices.min(), let last = indices.max() else { continue }

            let boxLeft = actorCenterX[first] - actorWidths[first] / 2 - cfg.boxMargin
            let boxRight = actorCenterX[last] + actorWidths[last] / 2 + cfg.boxMargin

            if let prevRight = lastBoxRight, boxLeft < prevRight + cfg.boxMargin {
                // Shift subsequent actors right
                let shift = prevRight + cfg.boxMargin - boxLeft
                for i in first..<actorCount {
                    actorCenterX[i] += shift
                }
            }
            lastBoxRight = boxRight
        }
    }

    var actorIndex: [String: Int] = [:]
    for i in 0..<actorCount {
        actorIndex[visibleActors[i].id] = i
    }

    let actorY = cfg.diagramMarginY
    var positionedActors: [PositionedSequenceActor] = visibleActors.map { actor in
        let idx = actorIndex[actor.id] ?? 0
        let actorH = _estimateActorHeight(actor.label, cfg: cfg)
        return PositionedSequenceActor(
            id: actor.id,
            label: actor.label,
            type: actor.type.rawValue,
            participantType: actor.type,
            x: actorCenterX[idx],
            y: actorY,
            width: actorWidths[idx],
            height: actorH,
            links: actor.links,
            properties: actor.properties,
            detailsElementId: actor.detailsElementId
        )
    }

    // ---- Layout messages ----
    let maxActorHeight = positionedActors.map(\.height).max() ?? cfg.height
    var messageY = actorY + maxActorHeight + cfg.diagramMarginY
    var positionedMessages: [PositionedSequenceMessage] = []

    // Extra space for block headers/dividers
    var extraSpaceBefore: [Int: Double] = [:]
    for block in blocks {
        // Block header before first message
        extraSpaceBefore[block.startItemIndex] = max(extraSpaceBefore[block.startItemIndex] ?? 0, 40)
        for div in block.dividers {
            extraSpaceBefore[div.itemIndex] = max(extraSpaceBefore[div.itemIndex] ?? 0, 24)
        }
    }

    // Autonumber tracking — config.showSequenceNumbers can force it on
    // In-diagram autonumber events (including "autonumber off") take precedence
    var seenAutonumberEvent = false
    var seqNum: Double = diagram.autonumberEnabled ? diagram.autonumberStart : 1.0
    var seqStep: Double = diagram.autonumberEnabled ? diagram.autonumberStep : 1.0
    var seqEnabled: Bool = diagram.autonumberEnabled || cfg.showSequenceNumbers
    var messageIdx = 0

    // Activation stacks
    var activationStacks: [String: [(startY: Double, depth: Int)]] = [:]
    var positionedActivations: [SequenceActivation] = []
    let nestingOffset = 4.0
    let lifecycle = _sequenceLifecycleMessageIndices(diagram)

    for (itemIndex, item) in diagram.items.enumerated() {
        let extra = extraSpaceBefore[itemIndex] ?? 0
        if extra > 0 { messageY += extra }

        switch item {
        case .autonumberEvent(let start, let step, let visible):
            seenAutonumberEvent = true
            seqEnabled = visible
            if visible {
                seqNum = start
                seqStep = step
            }

        case .activationStart(let actorId):
            guard actorIndex[actorId] != nil else { break }
            var stack = activationStacks[actorId] ?? []
            stack.append((startY: messageY, depth: stack.count))
            activationStacks[actorId] = stack

        case .activationEnd(let actorId):
            guard let actorIdx = actorIndex[actorId] else { break }
            var stack = activationStacks[actorId] ?? []
            guard !stack.isEmpty else { break }
            let top = stack.removeLast()
            activationStacks[actorId] = stack
            let xOffset = Double(top.depth) * nestingOffset
            positionedActivations.append(
                SequenceActivation(
                    actorId: actorId,
                    x: actorCenterX[actorIdx] - cfg.activationWidth / 2 + xOffset,
                    topY: top.startY,
                    bottomY: max(messageY, top.startY + cfg.messageMargin),
                    width: cfg.activationWidth
                )
            )

        case .message(let msg):
        let fromIdx = actorIndex[msg.from] ?? 0
        let toIdx = actorIndex[msg.to] ?? 0
        let isSelfMsg = msg.from == msg.to

        // Push messageY for notes placed after the previous message
        for note in notes {
            let noteMsgIdx = _msgIdxBeforeItem(note.afterItemIndex, diagram: diagram)
            if noteMsgIdx == messageIdx - 1 {
                let noteH = _estimateNoteHeight(note)
                let noteBottom = messageY + 4 + noteH
                let requiredY = noteBottom + cfg.noteMargin
                messageY = max(messageY, requiredY)
            }
        }

        let x1 = actorCenterX[fromIdx]
        let x2 = actorCenterX[toIdx]
        let style = SequenceArrowStyle(type: msg.arrowType)

        // Central connection circle offset
        _ = msg.centralConnection != nil ? 16.5 : 0.0

        let pm = PositionedSequenceMessage(
            from: msg.from,
            to: msg.to,
            label: msg.label,
            lineStyle: style.isDotted ? "dashed" : "solid",
            arrowHead: msg.arrowHead,
            arrowType: msg.arrowType,
            centralConnection: msg.centralConnection,
            x1: x1,
            x2: x2,
            y: messageY,
            isSelf: isSelfMsg,
            sequenceNumber: seqEnabled ? seqNum : nil,
            sequenceVisible: seqEnabled
        )
        positionedMessages.append(pm)

        if seqEnabled { seqNum += seqStep }

        // Activation
        if msg.activate {
            var stack = activationStacks[msg.to] ?? []
            stack.append((startY: messageY, depth: stack.count))
            activationStacks[msg.to] = stack
        }
        if msg.deactivate {
            var stack = activationStacks[msg.from] ?? []
            if !stack.isEmpty {
                let top = stack.removeLast()
                activationStacks[msg.from] = stack
                let xOffset = Double(top.depth) * nestingOffset
                positionedActivations.append(
                    SequenceActivation(
                        actorId: msg.from,
                        x: actorCenterX[fromIdx] - cfg.activationWidth / 2 + xOffset,
                        topY: top.startY,
                        bottomY: messageY,
                        width: cfg.activationWidth
                    )
                )
            }
        }

        messageY += _estimateMessageRowHeight(msg.label, cfg: cfg, isSelf: isSelfMsg)
        messageIdx += 1

        default:
            break
        }
    }

    for i in positionedActors.indices {
        let actorId = positionedActors[i].id
        guard let createMessageIndex = lifecycle.created[actorId],
              createMessageIndex < positionedMessages.count
        else { continue }
        positionedActors[i].y = max(actorY, positionedMessages[createMessageIndex].y - positionedActors[i].height / 2)
    }

    // Close remaining activation stacks
    for (actorId, stack) in activationStacks {
        for item in stack {
            let idx = actorIndex[actorId] ?? 0
            let xOffset = Double(item.depth) * nestingOffset
            positionedActivations.append(
                SequenceActivation(
                    actorId: actorId,
                    x: actorCenterX[idx] - cfg.activationWidth / 2 + xOffset,
                    topY: item.startY,
                    bottomY: messageY - cfg.messageMargin / 2,
                    width: cfg.activationWidth
                )
            )
        }
    }

    // ---- Blocks ----
    let positionedBlocks: [PositionedSequenceBlock] = blocks.map { block in
        // Convert item indices to positioned message indices
        let msgStartIdx = _itemIdxToMsgIdx(block.startItemIndex, diagram: diagram)
        let msgEndIdx = _itemIdxToMsgIdx(block.endItemIndex, diagram: diagram)

        let startMsg = msgStartIdx < positionedMessages.count ? positionedMessages[msgStartIdx] : nil
        let endMsg = msgEndIdx < positionedMessages.count ? positionedMessages[msgEndIdx] : nil
        let blockTop = (startMsg?.y ?? messageY) - cfg.boxMargin - 28
        let blockBottom = (endMsg?.y ?? messageY) + cfg.boxMargin + 12

        let minActorIdx: Int
        let maxActorIdx: Int
        if msgStartIdx <= msgEndIdx {
            let involvedActors = Set(
                (msgStartIdx...msgEndIdx).compactMap { mi -> [String]? in
                    guard mi < messages.count else { return nil }
                    return [messages[mi].from, messages[mi].to]
                }.flatMap { $0 }
            )
            let indices = involvedActors.compactMap { actorIndex[$0] }
            minActorIdx = indices.min() ?? 0
            maxActorIdx = indices.max() ?? max(0, actorCount - 1)
        } else {
            minActorIdx = 0
            maxActorIdx = max(0, actorCount - 1)
        }

        let blockLeft = actorCenterX[minActorIdx] - actorWidths[minActorIdx] / 2 - cfg.boxMargin
        let blockRight = actorCenterX[maxActorIdx] + actorWidths[maxActorIdx] / 2 + cfg.boxMargin

        // Nesting depth
        let nestingDepth = _countNestingDepth(blocks, block)
        let nestMargin = cfg.boxMargin * Double(nestingDepth)
        let adjustedLeft = blockLeft - nestMargin
        let adjustedRight = blockRight + nestMargin

        let positionedDividers: [PositionedSequenceBlockDivider] = block.dividers.map { div in
            let divMsgIdx = _itemIdxToMsgIdx(div.itemIndex, diagram: diagram)
            let divMsg = divMsgIdx < positionedMessages.count ? positionedMessages[divMsgIdx] : nil
            let divY = (divMsg?.y ?? messageY) - 18
            return PositionedSequenceBlockDivider(y: divY, label: div.label)
        }

        return PositionedSequenceBlock(
            type: block.type,
            label: block.label,
            x: adjustedLeft,
            y: blockTop,
            width: adjustedRight - adjustedLeft,
            height: blockBottom - blockTop,
            dividers: positionedDividers,
            isHighlight: block.isHighlight,
            highlightFill: block.highlightFill
        )
    }

    // ---- Notes ----
    let positionedNotes: [PositionedSequenceNote] = notes.map { note in
        let noteH = _estimateNoteHeight(note)
        let noteW = max(120, _estimateNoteWidth(note))

        // Position note relative to the message it's "after"
        let msgIdx = _msgIdxBeforeItem(note.afterItemIndex, diagram: diagram)
        let refY: Double
        if msgIdx >= 0 && msgIdx < positionedMessages.count {
            refY = positionedMessages[msgIdx].y + 4
        } else {
            refY = actorY + maxActorHeight + 4
        }

        let firstActorIdx = actorIndex[note.actorIds.first ?? ""] ?? 0
        let noteX: Double
        if note.position == "left" {
            noteX = actorCenterX[firstActorIdx] - actorWidths[firstActorIdx] / 2 - noteW - cfg.noteMargin
        } else if note.position == "right" {
            noteX = actorCenterX[firstActorIdx] + actorWidths[firstActorIdx] / 2 + cfg.noteMargin
        } else {
            if note.actorIds.count > 1 {
                let lastActorIdx = actorIndex[note.actorIds.last ?? ""] ?? firstActorIdx
                noteX = (actorCenterX[firstActorIdx] + actorCenterX[lastActorIdx]) / 2 - noteW / 2
            } else {
                noteX = actorCenterX[firstActorIdx] - noteW / 2
            }
        }

        return PositionedSequenceNote(
            text: note.text,
            x: noteX,
            y: refY,
            width: noteW,
            height: noteH,
            position: note.position,
            actors: note.actorIds
        )
    }

    // ---- Boxes ----
    let positionedBoxes: [PositionedSequenceBox] = boxes.map { box in
        let indices: [Int] = box.actorIds.compactMap { id in actorIndex[id] }
        guard let first = indices.min(), let last = indices.max() else {
            return PositionedSequenceBox(id: box.id, name: box.name, fill: box.fill, x: 0, y: 0, width: 0, height: 0, actorIds: box.actorIds)
        }
        let boxLeft = actorCenterX[first] - actorWidths[first] / 2 - cfg.boxMargin
        let boxRight = actorCenterX[last] + actorWidths[last] / 2 + cfg.boxMargin
        let boxTop = actorY - cfg.boxMargin
        let boxHeight = messageY - actorY + cfg.boxMargin * 2

        return PositionedSequenceBox(
            id: box.id,
            name: box.name,
            fill: box.fill,
            x: boxLeft,
            y: boxTop,
            width: boxRight - boxLeft,
            height: boxHeight,
            actorIds: box.actorIds
        )
    }

    // ---- Rect highlights ----
    let rectHighlights: [PositionedRectHighlight] = blocks.filter { $0.isHighlight }.map { block in
        let msgStartIdx = _itemIdxToMsgIdx(block.startItemIndex, diagram: diagram)
        let msgEndIdx = _itemIdxToMsgIdx(block.endItemIndex, diagram: diagram)
        let topY = (msgStartIdx < positionedMessages.count ? positionedMessages[msgStartIdx].y : messageY) - 4
        let bottomY = (msgEndIdx < positionedMessages.count ? positionedMessages[msgEndIdx].y : messageY) + cfg.messageMargin + 4
        let rightX = actorCenterX.last ?? 300
        return PositionedRectHighlight(
            x: cfg.diagramMarginX,
            y: topY,
            width: rightX + cfg.diagramMarginX,
            height: bottomY - topY,
            fill: block.highlightFill ?? "transparent"
        )
    }

    // ---- Mirror actors ----
    let bottomActors: [PositionedSequenceActor]
    if cfg.mirrorActors {
        bottomActors = positionedActors.map { actor in
            var a = actor
            a.y = messageY + cfg.diagramMarginY
            return a
        }
    } else {
        bottomActors = []
    }

    let diagramBottom = messageY + cfg.diagramMarginY + (cfg.mirrorActors ? maxActorHeight + cfg.diagramMarginY : 0)

    // ---- Lifelines ----
    let lifelines: [SequenceLifeline] = visibleActors.map { actor in
        let idx = actorIndex[actor.id] ?? 0
        let topY: Double
        if lifecycle.created[actor.id] != nil {
            topY = positionedActors[idx].y + positionedActors[idx].height
        } else {
            topY = actorY + positionedActors[idx].height
        }

        let bottomY: Double
        if let destroyedMessageIndex = lifecycle.destroyed[actor.id],
           destroyedMessageIndex < positionedMessages.count {
            bottomY = positionedMessages[destroyedMessageIndex].y
        } else {
            bottomY = diagramBottom - cfg.diagramMarginY
        }

        return SequenceLifeline(
            actorId: actor.id,
            x: actorCenterX[idx],
            topY: topY,
            bottomY: bottomY
        )
    }

    // ---- Global bounds ----
    var globalMinX = cfg.diagramMarginX
    var globalMaxX = 0.0

    for actor in positionedActors {
        globalMinX = min(globalMinX, actor.x - actor.width / 2)
        globalMaxX = max(globalMaxX, actor.x + actor.width / 2)
    }
    for block in positionedBlocks {
        globalMinX = min(globalMinX, block.x)
        globalMaxX = max(globalMaxX, block.x + block.width)
    }
    for note in positionedNotes {
        globalMinX = min(globalMinX, note.x)
        globalMaxX = max(globalMaxX, note.x + note.width)
    }

    let shiftX = globalMinX < cfg.diagramMarginX ? cfg.diagramMarginX - globalMinX : 0

    func shift(_ arr: inout [some Any], _ keyPaths: [WritableKeyPath<(some Any), Double>]) {} // Not used

    var shiftedActors = positionedActors
    var shiftedMessages = positionedMessages
    var shiftedActivations = positionedActivations
    var shiftedBlocks = positionedBlocks
    var shiftedNotes = positionedNotes
    var shiftedBoxes = positionedBoxes
    var shiftedHighlights = rectHighlights
    var shiftedLifelines = lifelines
    var shiftedBottomActors = bottomActors

    if shiftX > 0 {
        for i in shiftedActors.indices { shiftedActors[i].x += shiftX }
        for i in shiftedMessages.indices {
            shiftedMessages[i].x1 += shiftX
            shiftedMessages[i].x2 += shiftX
        }
        for i in shiftedActivations.indices { shiftedActivations[i].x += shiftX }
        for i in shiftedBlocks.indices { shiftedBlocks[i].x += shiftX }
        for i in shiftedNotes.indices { shiftedNotes[i].x += shiftX }
        for i in shiftedBoxes.indices { shiftedBoxes[i].x += shiftX }
        for i in shiftedHighlights.indices { shiftedHighlights[i].x += shiftX }
        for i in shiftedLifelines.indices { shiftedLifelines[i].x += shiftX }
        for i in shiftedBottomActors.indices { shiftedBottomActors[i].x += shiftX }
        for i in actorCenterX.indices { actorCenterX[i] += shiftX }
    }

    let diagramWidth = globalMaxX + shiftX + cfg.diagramMarginX
    let diagramHeight = diagramBottom

    return PositionedSequenceDiagram(
        width: max(diagramWidth, 200),
        height: max(diagramHeight, 100),
        actors: shiftedActors,
        lifelines: shiftedLifelines,
        messages: shiftedMessages,
        activations: shiftedActivations,
        blocks: shiftedBlocks,
        notes: shiftedNotes,
        boxes: shiftedBoxes,
        bottomActors: shiftedBottomActors,
        rectHighlights: shiftedHighlights,
        title: diagram.title,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr
    )
}

// MARK: - Helpers

private func _estimateNoteHeight(_ note: SequenceNote) -> Double {
    let lines = note.text.components(separatedBy: "\n")
    let count = Double(max(1, lines.count))
    let lineHeight = ceil(original_src_styles.FONT_SIZES.edgeLabel)
    let spacing: Double = 4
    return count * lineHeight + max(0, count - 1) * spacing + 16
}

private func _estimateMessageRowHeight(_ label: String, cfg: SequenceDiagramConfig, isSelf: Bool) -> Double {
    let lines = label.components(separatedBy: "\n")
    let count = max(1, lines.count)
    let lineHeight = ceil(original_src_styles.FONT_SIZES.edgeLabel)
    let textHeight = Double(count) * lineHeight + max(0, Double(count - 1)) * 2
    let base = isSelf ? (30.0 + cfg.messageMargin) : cfg.messageMargin
    return max(base, textHeight + 8)
}

private func _estimateActorHeight(_ label: String, cfg: SequenceDiagramConfig) -> Double {
    let lines = label.components(separatedBy: "\n")
    let count = max(1, lines.count)
    let lineHeight = ceil(original_src_styles.FONT_SIZES.nodeLabel)
    let textHeight = Double(count) * lineHeight + max(0, Double(count - 1)) * 2
    return max(cfg.height, textHeight + 20)
}

private func _estimateNoteWidth(_ note: SequenceNote) -> Double {
    let lines = note.text.components(separatedBy: "\n")
    let maxW = lines.map {
        original_src_styles.estimateTextWidth($0, original_src_styles.FONT_SIZES.edgeLabel, original_src_styles.FONT_WEIGHTS.edgeLabel)
    }.max() ?? 0
    return maxW + 16
}

private func _itemIdxToMsgIdx(_ itemIdx: Int, diagram: SequenceDiagram) -> Int {
    var msgCount = 0
    for (idx, item) in diagram.items.enumerated() {
        if idx >= itemIdx { return msgCount }
        if case .message = item { msgCount += 1 }
    }
    return msgCount
}

private func _msgIdxBeforeItem(_ itemIdx: Int, diagram: SequenceDiagram) -> Int {
    // Returns the index of the last message before or at the given item index
    var msgCount = -1
    for (idx, item) in diagram.items.enumerated() {
        if idx > itemIdx { return msgCount }
        if case .message = item { msgCount += 1 }
    }
    return msgCount
}

private func _countNestingDepth(_ allBlocks: [SequenceBlock], _ target: SequenceBlock) -> Int {
    var depth = 0
    for other in allBlocks {
        if other.startItemIndex == target.startItemIndex && other.endItemIndex == target.endItemIndex && other.type == target.type {
            continue
        }
        if other.startItemIndex <= target.startItemIndex && other.endItemIndex >= target.endItemIndex {
            depth += 1
        }
    }
    return depth
}

private func _sequenceLifecycleMessageIndices(_ diagram: SequenceDiagram) -> (created: [String: Int], destroyed: [String: Int]) {
    var created: [String: Int] = [:]
    var destroyed: [String: Int] = [:]
    var pendingCreate: String?
    var pendingDestroy: String?
    var messageIndex = 0

    for item in diagram.items {
        switch item {
        case .createParticipant(let actor):
            pendingCreate = actor.id
        case .destroyParticipant(let actorId):
            pendingDestroy = actorId
        case .message(let message):
            if let actorId = pendingCreate, message.to == actorId {
                created[actorId] = messageIndex
                pendingCreate = nil
            }
            if let actorId = pendingDestroy, message.from == actorId || message.to == actorId {
                destroyed[actorId] = messageIndex
                pendingDestroy = nil
            }
            messageIndex += 1
        default:
            break
        }
    }

    return (created, destroyed)
}

// MARK: - Legacy class

open class original_src_sequence_layout {
    public init() {}

    public static func layoutSequenceDiagram(
        _ diagram: SequenceDiagram,
        _ options: RenderOptions = RenderOptions()
    ) throws -> PositionedSequenceDiagram {
        try _layoutSequenceDiagramEntry(diagram, .default)
    }
}

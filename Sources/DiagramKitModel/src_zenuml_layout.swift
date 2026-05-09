import Foundation

// MARK: - ZenUML Layout Engine

/// Layout a parsed ZenUML diagram into positioned geometry.
/// Recursive layout that handles nested sync blocks, creation, fragments, returns, and dividers.
public func layoutZenUMLDiagram(_ diagram: ZenUMLDiagram) -> PositionedZenUMLDiagram {
    let participantWidth: Double = 100
    let participantHeight: Double = 70
    let horizontalSpacing: Double = 60
    let verticalSpacing: Double = 30
    let messageHeight: Double = 16
    let fragmentHeaderHeight: Double = 25
    let diagramPadding: Double = 20

    var positionedParticipants: [PositionedZenUMLParticipant] = []
    var positionedLifelines: [PositionedZenUMLLifeline] = []
    var positionedMessages: [PositionedZenUMLMessage] = []
    var positionedSelfCalls: [PositionedZenUMLSelfCall] = []
    var positionedOccurrences: [PositionedZenUMLOccurrence] = []
    var positionedCreations: [PositionedZenUMLCreation] = []
    var positionedFragments: [PositionedZenUMLFragment] = []
    var positionedReturns: [PositionedZenUMLReturn] = []
    var positionedDividers: [PositionedZenUMLDivider] = []
    var positionedComments: [PositionedZenUMLComment] = []
    var positionedGroups: [PositionedZenUMLGroup] = []

    let participantCount = max(1, diagram.participants.count)
    let totalWidth = Double(participantCount) * (participantWidth + horizontalSpacing) + diagramPadding * 2
    let diagramWidth = max(400, totalWidth)
    let maxContentWidth = diagramWidth - diagramPadding * 2

    // Position participants
    for (index, p) in diagram.participants.enumerated() {
        let x = diagramPadding + Double(index) * (participantWidth + horizontalSpacing) + participantWidth / 2
        let pp = PositionedZenUMLParticipant(
            name: p.name, label: p.label ?? p.name,
            x: x, y: diagramPadding,
            width: participantWidth, height: participantHeight,
            isStarter: p.isStarter, showBottom: false,
            type: p.type, stereotype: p.stereotype, color: p.color, emoji: p.emoji, groupId: p.groupId
        )
        positionedParticipants.append(pp)
        positionedLifelines.append(PositionedZenUMLLifeline(participantName: p.name, x: x, topY: diagramPadding + participantHeight, bottomY: 0, dashed: false))
    }

    func participantX(for name: String) -> Double {
        if let p = positionedParticipants.first(where: { $0.name == name }) { return p.x }
        // Find or create a placeholder position
        let idx = positionedParticipants.count
        let x = diagramPadding + Double(idx) * (participantWidth + horizontalSpacing) + participantWidth / 2
        let pp = PositionedZenUMLParticipant(name: name, label: name, x: x, y: diagramPadding, width: participantWidth, height: participantHeight)
        positionedParticipants.append(pp)
        positionedLifelines.append(PositionedZenUMLLifeline(participantName: name, x: x, topY: diagramPadding + participantHeight, bottomY: 0))
        return x
    }

    // Recursive layout state
    var currentY: Double = diagramPadding + participantHeight + verticalSpacing

    func layoutStatements(_ statements: [ZenUMLStatement], indentX: Double, indentWidth: Double) -> Double {
        var y = currentY
        for stmt in statements {
            switch stmt {
            case .message(let from, let to, let signature, let type, let block, _):
                let fromX = participantX(for: from)
                let toX = participantX(for: to)
                let isSelf = from == to
                let arrowStyle: ZenUMLArrowStyle = type == .async ? .open : .solid

                if isSelf {
                    let ux = max(0, fromX) - 20
                    positionedSelfCalls.append(PositionedZenUMLSelfCall(x: ux, y: y, width: 40, height: 25, label: signature, arrowStyle: arrowStyle))
                    positionedOccurrences.append(PositionedZenUMLOccurrence(x: fromX - 7, y: y, width: 15, height: 25, participantName: from))
                    y += 25 + verticalSpacing
                } else {
                    positionedMessages.append(PositionedZenUMLMessage(fromX: fromX, toX: toX, y: y, label: signature, arrowStyle: arrowStyle, isSelf: false, isReverse: fromX > toX))
                    positionedOccurrences.append(PositionedZenUMLOccurrence(x: fromX - 7, y: y, width: 15, height: messageHeight, participantName: from))
                    if from != to {
                        positionedOccurrences.append(PositionedZenUMLOccurrence(x: toX - 7, y: y, width: 15, height: messageHeight, participantName: to))
                    }
                    y += messageHeight + verticalSpacing
                }

                // Recursive inner block
                if let inner = block {
                    currentY = y
                    let blockBottom = layoutStatements(inner, indentX: fromX - 15, indentWidth: maxContentWidth)
                    y = max(y, blockBottom)
                    currentY = y
                }

            case .asyncMessage(let from, let to, let content, _):
                let fromX = participantX(for: from)
                let toX = participantX(for: to)
                positionedMessages.append(PositionedZenUMLMessage(fromX: fromX, toX: toX, y: y, label: content ?? "", arrowStyle: .open, isSelf: from == to, isReverse: fromX > toX))
                y += messageHeight + verticalSpacing

            case .creation(_, _, let construct, let to, _, let block, _):
                let fromX = participantX(for: "_STARTER_")
                let createX = participantX(for: to)
                let msg = PositionedZenUMLMessage(fromX: fromX, toX: createX, y: y, label: "new \(construct)()", arrowStyle: .dashed, isSelf: false, isReverse: false)
                let pp = positionedParticipants.first(where: { $0.name == to }) ?? PositionedZenUMLParticipant(name: to, label: to, x: createX, y: diagramPadding, width: participantWidth, height: participantHeight)
                positionedCreations.append(PositionedZenUMLCreation(participant: pp, message: msg))
                y += messageHeight + verticalSpacing

                if let inner = block {
                    currentY = y
                    let blockBottom = layoutStatements(inner, indentX: createX - 15, indentWidth: maxContentWidth)
                    y = max(y, blockBottom)
                    currentY = y
                }

            case .return(let from, let to, let value, _):
                let fromX = participantX(for: from)
                let toX = participantX(for: to)
                positionedReturns.append(PositionedZenUMLReturn(fromX: fromX, toX: toX, y: y, label: value ?? "", isReverse: fromX > toX, isSelf: from == to))
                y += messageHeight + verticalSpacing

            case .fragment(let kind, let condition, let sections):
                let headerH = fragmentHeaderHeight
                let fragStartY = y
                var sectionGeometries: [PositionedZenUMLFragmentSection] = []
                var maxY = y + headerH

                for section in sections {
                    let secY = maxY
                    currentY = secY
                    let secBottom = layoutStatements(section.statements, indentX: indentX + 10, indentWidth: indentWidth - 20)
                    maxY = max(secBottom, secY + verticalSpacing)
                    sectionGeometries.append(PositionedZenUMLFragmentSection(label: section.label, y: secY, height: max(verticalSpacing, secBottom - secY)))
                    currentY = maxY
                }

                let fragHeight = max(50, maxY - fragStartY)
                positionedFragments.append(PositionedZenUMLFragment(
                    kind: kind, label: condition ?? kind.rawValue,
                    x: indentX, y: fragStartY, width: indentWidth, height: fragHeight,
                    headerY: fragStartY, sections: sectionGeometries, depth: 0
                ))
                y = fragStartY + fragHeight + verticalSpacing

            case .divider(let label):
                positionedDividers.append(PositionedZenUMLDivider(y: y, width: maxContentWidth, label: label))
                y += 24 + verticalSpacing

            case .comment(let text):
                positionedComments.append(PositionedZenUMLComment(x: indentX + 8, y: y, text: text))
                y += 20 + verticalSpacing
            }
        }
        currentY = y
        return y
    }

    let bottomY = layoutStatements(diagram.statements, indentX: diagramPadding, indentWidth: maxContentWidth)

    let diagramHeight = max(bottomY + diagramPadding, 200)

    // Update lifeline bottoms
    positionedLifelines = positionedLifelines.map { l in
        var updated = l
        updated.bottomY = diagramHeight + participantHeight - 28
        return updated
    }

    positionedGroups = diagram.groups.compactMap { group in
        let members = group.participants.compactMap { name in
            positionedParticipants.first(where: { $0.name == name })
        }
        guard !members.isEmpty else { return nil }
        let minX = members.map { $0.x - $0.width / 2 }.min() ?? diagramPadding
        let maxX = members.map { $0.x + $0.width / 2 }.max() ?? minX
        let groupX = max(0, minX - 16)
        let groupY = max(0, diagramPadding - 12)
        let groupWidth = max(0, maxX - minX + 32)
        let groupHeight = max(participantHeight + 24, diagramHeight - groupY - diagramPadding)
        return PositionedZenUMLGroup(
            name: group.id ?? members.map(\.name).joined(separator: ", "),
            x: groupX,
            y: groupY,
            width: groupWidth,
            height: groupHeight
        )
    }

    return PositionedZenUMLDiagram(
        width: diagramWidth, height: diagramHeight,
        frameBorderLeft: 0, frameBorderRight: 0,
        title: diagram.title,
        participants: positionedParticipants,
        lifelines: positionedLifelines,
        messages: positionedMessages,
        selfCalls: positionedSelfCalls,
        occurrences: positionedOccurrences,
        creations: positionedCreations,
        fragments: positionedFragments,
        dividers: positionedDividers,
        returns: positionedReturns,
        comments: positionedComments,
        groups: positionedGroups
    )
}

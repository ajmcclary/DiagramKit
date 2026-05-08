import Foundation
import CoreGraphics

// MARK: - ZenUML Layout Engine

/// Layout a parsed ZenUML diagram into positioned geometry.
/// Skeleton implementation that returns a basic positioned diagram with placeholder geometry.
public func layoutZenUMLDiagram(_ diagram: ZenUMLDiagram) -> PositionedZenUMLDiagram {
    let participantCount = max(1, diagram.participants.count)
    let statementCount = diagram.statements.count

    // Basic layout constants
    let participantWidth: Double = 100
    let participantHeight: Double = 70
    let horizontalSpacing: Double = 60
    let verticalSpacing: Double = 40
    let messageHeight: Double = 30
    let diagramPadding: Double = 20

    var positionedParticipants: [PositionedZenUMLParticipant] = []
    var positionedLifelines: [PositionedZenUMLLifeline] = []
    var positionedMessages: [PositionedZenUMLMessage] = []
    var positionedFragments: [PositionedZenUMLFragment] = []
    var positionedReturns: [PositionedZenUMLReturn] = []
    var positionedDividers: [PositionedZenUMLDivider] = []
    var positionedGroups: [PositionedZenUMLGroup] = []

    // Calculate total width based on participants
    let totalWidth = Double(participantCount) * (participantWidth + horizontalSpacing) + diagramPadding * 2
    let diagramWidth = max(400, totalWidth)

    var currentY: Double = diagramPadding + participantHeight

    // Position participants
    for (index, p) in diagram.participants.enumerated() {
        let x = diagramPadding + Double(index) * (participantWidth + horizontalSpacing) + participantWidth / 2

        let posParticipant = PositionedZenUMLParticipant(
            name: p.name,
            label: p.label ?? p.name,
            x: x,
            y: diagramPadding,
            width: participantWidth,
            height: participantHeight,
            isStarter: p.isStarter,
            showBottom: false,
            type: p.type,
            stereotype: p.stereotype,
            color: p.color,
            emoji: p.emoji,
            groupId: p.groupId
        )
        positionedParticipants.append(posParticipant)

        // Lifeline
        positionedLifelines.append(PositionedZenUMLLifeline(
            participantName: p.name,
            x: x,
            topY: diagramPadding + participantHeight,
            bottomY: 0,
            dashed: false
        ))
    }

    // Position statements
    let maxWidth = diagramWidth - diagramPadding * 2

    for (index, stmt) in diagram.statements.enumerated() {
        let y = currentY + Double(index) * (messageHeight + verticalSpacing)

        switch stmt {
        case .message(let from, let to, let signature, let type, _, _):
            let fromX = participantX(for: from, participants: positionedParticipants, defaultX: diagramPadding)
            let toX = participantX(for: to, participants: positionedParticipants, defaultX: diagramWidth - diagramPadding)
            let arrowStyle: ZenUMLArrowStyle = type == .async ? .open : .solid
            let label = signature

            positionedMessages.append(PositionedZenUMLMessage(
                fromX: fromX,
                toX: toX,
                y: y,
                label: label,
                arrowStyle: arrowStyle,
                isSelf: from == to,
                isReverse: fromX > toX
            ))

        case .asyncMessage(let from, let to, let content, _):
            let fromX = participantX(for: from, participants: positionedParticipants, defaultX: diagramPadding)
            let toX = participantX(for: to, participants: positionedParticipants, defaultX: diagramWidth - diagramPadding)

            positionedMessages.append(PositionedZenUMLMessage(
                fromX: fromX,
                toX: toX,
                y: y,
                label: content ?? "",
                arrowStyle: .open,
                isSelf: from == to,
                isReverse: fromX > toX
            ))

        case .creation(_, _, let construct, let to, _, _, _):
            let fromX = participantX(for: "_STARTER_", participants: positionedParticipants, defaultX: diagramPadding)
            let createX = fromX + 100

            // Add the created participant if not already present
            if !positionedParticipants.contains(where: { $0.name == to }) {
                positionedParticipants.append(PositionedZenUMLParticipant(
                    name: to,
                    label: to,
                    x: createX,
                    y: diagramPadding,
                    width: participantWidth,
                    height: participantHeight,
                    isStarter: false,
                    showBottom: false
                ))
                positionedLifelines.append(PositionedZenUMLLifeline(
                    participantName: to,
                    x: createX,
                    topY: diagramPadding + participantHeight,
                    bottomY: 0,
                    dashed: true
                ))
            }

            positionedMessages.append(PositionedZenUMLMessage(
                fromX: fromX,
                toX: createX,
                y: y,
                label: "new \(construct)()",
                arrowStyle: .dashed,
                isSelf: false,
                isReverse: false
            ))

        case .return(let from, let to, let value, _):
            let fromX = participantX(for: from, participants: positionedParticipants, defaultX: diagramPadding)
            let toX = participantX(for: to, participants: positionedParticipants, defaultX: diagramWidth - diagramPadding)

            positionedReturns.append(PositionedZenUMLReturn(
                fromX: fromX,
                toX: toX,
                y: y,
                label: value ?? "",
                isReverse: fromX > toX,
                isSelf: from == to
            ))

        case .fragment(let kind, let condition, let sections):
            let fragmentX = diagramPadding
            let sectionCount = sections.count
            let fragmentHeight = Double(sectionCount) * messageHeight * 2 + 30

            positionedFragments.append(PositionedZenUMLFragment(
                kind: kind,
                label: condition ?? kind.rawValue,
                x: fragmentX,
                y: y,
                width: maxWidth,
                height: max(50, fragmentHeight),
                headerY: y,
                sections: sections.enumerated().map { (i, section) in
                    PositionedZenUMLFragmentSection(
                        label: section.label,
                        y: y + Double(i + 1) * messageHeight,
                        height: messageHeight
                    )
                },
                depth: 0
            ))

        case .divider(let label):
            positionedDividers.append(PositionedZenUMLDivider(
                y: y,
                width: maxWidth,
                label: label
            ))
        }
    }

    // Calculate diagram height
    let lastY = currentY + Double(statementCount) * (messageHeight + verticalSpacing) + diagramPadding
    let diagramHeight = max(lastY, 200)

    // Update lifeline bottoms
    positionedLifelines = positionedLifelines.map { l in
        var updated = l
        updated.bottomY = diagramHeight + participantHeight - 28
        return updated
    }

    return PositionedZenUMLDiagram(
        width: diagramWidth,
        height: diagramHeight,
        frameBorderLeft: 0,
        frameBorderRight: 0,
        title: diagram.title,
        participants: positionedParticipants,
        lifelines: positionedLifelines,
        messages: positionedMessages,
        selfCalls: [],
        occurrences: [],
        creations: [],
        fragments: positionedFragments,
        dividers: positionedDividers,
        returns: positionedReturns,
        comments: [],
        groups: positionedGroups
    )
}

private func participantX(for name: String, participants: [PositionedZenUMLParticipant], defaultX: Double) -> Double {
    if let p = participants.first(where: { $0.name == name }) {
        return p.x
    }
    return defaultX
}

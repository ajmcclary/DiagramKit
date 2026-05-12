// Phase 8: Interactivity Primitives — Slice 8C
// DiagramStableElement conformances and lookup builder for sequence diagrams.

import DiagramKitCommon
import Foundation

// MARK: - PositionedSequenceActor conformance

extension PositionedSequenceActor: DiagramStableElement {
    public var stableElementID: String { "actor:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label }
}

// MARK: - SequenceLifeline conformance

extension SequenceLifeline: DiagramStableElement {
    public var stableElementID: String { "lifeline:\(actorId)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x - 1, y: topY, width: 2, height: max(1, bottomY - topY))
    }
    public var stableElementLabel: String? { actorId }
}

// MARK: - PositionedSequenceMessage conformance

extension PositionedSequenceMessage {
    /// Synthetic stable ID from from+to+label+sequenceNumber (source-model
    /// fields only; no layout geometry). Duplicates are disambiguated by
    /// the lookup builder via source-order ordinal.
    public var guaranteedMessageID: String {
        let parts: [String] = [from, to, label]
            + (sequenceNumber.map { [String($0)] } ?? [])
        let seed = (parts as [String]).joined(separator: "→")
        return "message:\(StableID.derive(from: seed))"
    }
}

extension PositionedSequenceMessage: DiagramStableElement {
    public var stableElementID: String { guaranteedMessageID }
    public var stableElementBounds: DiagramRect {
        let halfHeight: Double = 6
        return DiagramRect(
            x: min(x1, x2),
            y: y - halfHeight,
            width: abs(x2 - x1),
            height: halfHeight * 2
        )
    }
    public var stableElementLabel: String? { label.isEmpty ? nil : label }
}

// MARK: - SequenceActivation conformance

extension SequenceActivation: DiagramStableElement {
    /// Stable ID from actorId only. Multiple activations on the same actor
    /// are disambiguated by the builder via source-order ordinal.
    public var stableElementID: String { "activation:\(actorId)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: topY, width: width, height: max(1, bottomY - topY))
    }
    public var stableElementLabel: String? { nil }
}

// MARK: - PositionedSequenceBlock conformance

extension PositionedSequenceBlock: DiagramStableElement {
    /// Stable ID from type+label only. Duplicates disambiguated by builder.
    public var stableElementID: String {
        let seed = "\(type):\(label)"
        return "block:\(StableID.derive(from: seed))"
    }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { label.isEmpty ? type : "\(type): \(label)" }
}

// MARK: - PositionedSequenceNote conformance

extension PositionedSequenceNote: DiagramStableElement {
    /// Stable ID from text only. Duplicates disambiguated by builder.
    public var stableElementID: String {
        let seed = text
        return "note:\(StableID.derive(from: seed))"
    }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { text }
}

// MARK: - PositionedSequenceBox conformance

extension PositionedSequenceBox: DiagramStableElement {
    public var stableElementID: String { "box:\(id)" }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { name ?? id }
}

// MARK: - PositionedRectHighlight conformance

extension PositionedRectHighlight: DiagramStableElement {
    /// Stable ID from fill color. Duplicates disambiguated by builder.
    public var stableElementID: String {
        "highlight:\(fill)"
    }
    public var stableElementBounds: DiagramRect {
        DiagramRect(x: x, y: y, width: width, height: height)
    }
    public var stableElementLabel: String? { nil }
}

// MARK: - Bottom actor wrapper

private struct _BottomActorWrapper: DiagramStableElement {
    let actor: PositionedSequenceActor
    var stableElementID: String { "bottom-actor:\(actor.id)" }
    var stableElementBounds: DiagramRect {
        DiagramRect(x: actor.x, y: actor.y, width: actor.width, height: actor.height)
    }
    var stableElementLabel: String? { actor.label }
}

// MARK: - Sequence lookup builder

func _sequenceLookup(
    actors: [PositionedSequenceActor],
    messages: [PositionedSequenceMessage],
    blocks: [PositionedSequenceBlock],
    lifelines: [SequenceLifeline],
    activations: [SequenceActivation],
    notes: [PositionedSequenceNote],
    boxes: [PositionedSequenceBox],
    bottomActors: [PositionedSequenceActor],
    rectHighlights: [PositionedRectHighlight]
) -> DiagramBoundsLookup {
    typealias E = DiagramBoundsLookup.ElementKind
    var elements: [(any DiagramStableElement, kind: E)] = []

    _disambiguateIDs(actors, kind: .actor, into: &elements)
    _disambiguateIDs(messages, kind: .edge, into: &elements)
    _disambiguateIDs(blocks, kind: .block, into: &elements)
    _disambiguateIDs(lifelines, kind: .lifeline, into: &elements)
    _disambiguateIDs(activations, kind: .activation, into: &elements)
    _disambiguateIDs(notes, kind: .note, into: &elements)
    _disambiguateIDs(boxes, kind: .box, into: &elements)

    // Bottom actors get a distinct prefix to avoid ID collision with top actors.
    for actor in bottomActors {
        elements.append((_BottomActorWrapper(actor: actor), .actor))
    }

    _disambiguateIDs(rectHighlights, kind: .highlight, into: &elements)

    return DiagramBoundsLookup.build(diagramType: .sequenceDiagram, elements: elements)
}

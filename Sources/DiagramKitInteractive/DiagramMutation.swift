// Phase 9: Interactive Model — Slice 9A
// Core mutation value types.

import DiagramKitModel

// MARK: - DiagramMutation

/// A typed mutation on a DiagramDocument.
///
/// Mutations use `DiagramSelection` for existing elements (consistent
/// with Phase 8's opaque stable IDs) and raw `id: String` for insertions
/// where no selection yet exists.
///
/// All cases are `Sendable` — they carry only value-type payloads.
public enum DiagramMutation: Sendable {
    /// Delete the element identified by `selection` and any incident edges.
    case deleteElement(DiagramSelection)

    /// Change the label of the element identified by `selection`.
    case setLabel(of: DiagramSelection, to: String)

    /// Change the diagram's title.
    case setTitle(String?)

    /// A no-op mutation used as a sentinel for undo grouping boundaries.
    case noop
}

// MARK: - Undo action names

extension DiagramMutation {
    /// Human-readable name for the undo/redo menu.
    public var undoActionName: String {
        switch self {
        case .deleteElement:
            return "Delete Element"
        case .setLabel:
            return "Set Label"
        case .setTitle:
            return "Set Title"
        case .noop:
            return ""
        }
    }
}

// MARK: - Equatable & Hashable

extension DiagramMutation: Equatable, Hashable {
    public static func == (lhs: DiagramMutation, rhs: DiagramMutation) -> Bool {
        switch (lhs, rhs) {
        case (.deleteElement(let a), .deleteElement(let b)):
            return a == b
        case (.setLabel(let aSel, let aLabel), .setLabel(let bSel, let bLabel)):
            return aSel == bSel && aLabel == bLabel
        case (.setTitle(let a), .setTitle(let b)):
            return a == b
        case (.noop, .noop):
            return true
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .deleteElement(let sel):
            hasher.combine(0)
            hasher.combine(sel)
        case .setLabel(let sel, let label):
            hasher.combine(1)
            hasher.combine(sel)
            hasher.combine(label)
        case .setTitle(let title):
            hasher.combine(2)
            hasher.combine(title)
        case .noop:
            hasher.combine(3)
        }
    }
}

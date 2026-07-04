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

    /// Set (or clear, with nil) the frontmatter theme. Names are
    /// validated against DiagramTheme.theme(named:).
    case setTheme(String?)

    /// Choose the layout preset. `.hierarchical` is the default and
    /// clears the frontmatter layout key; `.adaptive` persists it.
    case setLayoutPreset(LayoutPreset)
}

/// Flowchart layout presets (visual editor plan 6). Hierarchical is
/// the ELK layered default; adaptive relaxes model order, routes
/// edges as splines, and widens spacing for connection-dense flows.
public enum LayoutPreset: String, Sendable, CaseIterable, Hashable {
    case hierarchical
    case adaptive
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
        case .setTheme:
            return "Set Theme"
        case .setLayoutPreset:
            return "Set Layout"
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
        case (.setTheme(let a), .setTheme(let b)):
            return a == b
        case (.setLayoutPreset(let a), .setLayoutPreset(let b)):
            return a == b
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
        case .setTheme(let name):
            hasher.combine(4)
            hasher.combine(name)
        case .setLayoutPreset(let preset):
            hasher.combine(5)
            hasher.combine(preset)
        }
    }
}

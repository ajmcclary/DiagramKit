//
//  VisualEditorState.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.1 — Visual-mode-only sub-state of LiveEditorState.
//  Tracks the active tool, the seven-stage canvas state machine, and
//  the optional demo state-stepper visibility.
//

import Foundation

public enum VisualEditorState {

    /// Seven-stage state machine driven by the FlowchartEditCanvas.
    /// Mirrors the JSX `STATE_*` constants in `visual.jsx`.
    public enum Stage: String, Codable, CaseIterable, Sendable, Hashable {
        /// Nothing selected.
        case idle
        /// One node selected, four corner handles visible.
        case nodeSelected
        /// NodeEditPopover is open with the label field focused.
        case labelEdited
        /// User is dragging from a node handle to create an edge.
        case edgeDrag
        /// User is drag-rectangle-selecting nodes.
        case marquee
        /// An undo just executed; canvas dims briefly to confirm.
        case undone
        /// A subgraph commit just executed; banner toast briefly visible.
        case subgraphCommitted

        public var label: String {
            switch self {
            case .idle:              return "Idle"
            case .nodeSelected:      return "Node selected"
            case .labelEdited:       return "Label edited"
            case .edgeDrag:          return "Edge drag"
            case .marquee:           return "Marquee"
            case .undone:            return "Undone"
            case .subgraphCommitted: return "Subgraph committed"
            }
        }
    }

    /// Tool palette selection in the VisualPane.
    public enum Tool: String, Codable, CaseIterable, Sendable, Hashable {
        case select
        case pan
        case marquee
        case connector

        public var label: String {
            switch self {
            case .select:    return "Select"
            case .pan:       return "Pan"
            case .marquee:   return "Marquee"
            case .connector: return "Connector"
            }
        }

        public var sfSymbol: String {
            switch self {
            case .select:    return "arrow.up.left"
            case .pan:       return "hand.draw"
            case .marquee:   return "rectangle.dashed"
            case .connector: return "arrow.left.and.right"
            }
        }
    }
}

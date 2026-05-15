//
//  LiveEditorStore+Visual.swift
//  DiagramPlayground
//
//  Visual-mode (Phase 3) + subgraph commit (Phase 5) + the undo
//  timeline that powers VisualPane's UndoTimelineView. Extracted from
//  LiveEditorStore.swift to keep that file under the file-size gate.
//

import SwiftUI
import DiagramKit
import DiagramKitInteractive

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
extension LiveEditorStore {

    // MARK: - Visual mode (Phase 3 / Task 3.1)

    /// Alias for the persistent `editor` so call sites in VisualPane /
    /// FlowchartEditCanvas read with the JSX's vocabulary. Same
    /// instance, same lifecycle.
    public var visualEditor: DiagramEditor? { editor }

    /// Update the visual stage. Wraps direct field assignment so call
    /// sites and tests use one entry point.
    public func setVisualStage(_ stage: VisualEditorState.Stage) {
        state.visualStage = stage
    }

    /// Switch the active VisualPane tool.
    public func setVisualTool(_ tool: VisualEditorState.Tool) {
        state.visualTool = tool
    }

    /// Replace the marquee selection set. Pass `[]` to clear.
    public func setMarqueeSelection(_ ids: Set<String>) {
        state.marqueeSelection = ids
    }

    /// Toggle the StateStepper demo widget. Off in production UI;
    /// flipped on by UITests that walk the seven stages.
    public func setDemoStepperVisible(_ flag: Bool) {
        state.demoStepperVisible = flag
    }

    // MARK: - Subgraph commit (Phase 5 / Task 5.2)

    public func openSubgraphPrompt() {
        guard !state.marqueeSelection.isEmpty else { return }
        isSubgraphPromptOpen = true
    }

    public func cancelSubgraphPrompt() {
        isSubgraphPromptOpen = false
    }

    /// Commit the marquee selection as a subgraph titled `title`.
    /// On success: clears the marquee, drops the prompt, records a
    /// SubgraphCommit so the toast appears, and bounces visualStage
    /// to .subgraphCommitted.
    public func commitSubgraph(title: String) async {
        let ids = state.marqueeSelection
        guard !ids.isEmpty else { return }
        let selections = ids.map { id in
            DiagramSelection(diagramType: .flowchart, elementID: "node:\(id)")
        }
        do {
            try await performFlowchartMutation(
                .groupIntoSubgraph(selections: selections, title: title)
            )
            isSubgraphPromptOpen = false
            lastSubgraphCommit = SubgraphCommit(title: title, memberIDs: ids)
            setMarqueeSelection([])
            setVisualStage(.subgraphCommitted)
        } catch {
            // performFlowchartMutation already records the error on
            // store.lastMutationError; drop the prompt either way so
            // the user can re-marquee.
            isSubgraphPromptOpen = false
        }
    }

    public func dismissSubgraphToast() {
        lastSubgraphCommit = nil
    }
}

// MARK: - SubgraphCommit

/// Snapshot of the most-recent groupIntoSubgraph commit. Drives the
/// transient SubgraphCommitToast.
public struct SubgraphCommit: Hashable, Sendable {
    public let title: String
    public let memberIDs: Set<String>
    public let timestamp: Date

    public init(title: String, memberIDs: Set<String>, timestamp: Date = Date()) {
        self.title = title
        self.memberIDs = memberIDs
        self.timestamp = timestamp
    }
}

// MARK: - UndoEntry

public struct UndoEntry: Hashable, Sendable {
    public enum Kind: String, Sendable {
        case noop
        case setLabel
        case setTitle
        case insertNode
        case insertEdge
        case deleteElement
        case groupIntoSubgraph
    }

    public let displayLabel: String
    public let kind: Kind
    public let isCurrent: Bool
    public let isFuture: Bool

    public init(
        displayLabel: String,
        kind: Kind = .noop,
        isCurrent: Bool = false,
        isFuture: Bool = false
    ) {
        self.displayLabel = displayLabel
        self.kind = kind
        self.isCurrent = isCurrent
        self.isFuture = isFuture
    }
}

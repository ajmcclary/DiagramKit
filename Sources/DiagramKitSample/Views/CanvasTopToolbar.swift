//
//  CanvasTopToolbar.swift
//  DiagramPlayground
//
//  Three floating pills anchored to the canvas top — family + mode,
//  scene-graph counts, and render-health perf. Mirrors the v2.1
//  mockup's canvas chrome.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

struct CanvasTopToolbar: View {
    @Bindable var store: LiveEditorStore

    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack(spacing: PlaygroundSpacing.xs) {
            familyPill
            sceneGraphPill
            renderHealthPill
        }
    }

    private var familyPill: some View {
        ToolbarPill(
            label: "\(store.state.sourceFormat.shortName.lowercased()) · \(workspaceLabel)",
            dotColor: tokens.palette.statusInfo
        )
    }

    private var sceneGraphPill: some View {
        // Phase 4 fills in real counts from PreparedDiagram.
        ToolbarPill(
            label: "scene graph",
            dotColor: tokens.palette.fg3,
            trailing: sceneGraphMetric
        )
    }

    @ViewBuilder
    private var renderHealthPill: some View {
        switch store.renderStatus {
        case .rendered:
            RenderHealthPill(state: .ok(layoutMs: 0, paintMs: 0))
        case .failed:
            RenderHealthPill(state: .failed(error: failureMessage))
                .help(failureMessage)
        case .pending, .rendering:
            RenderHealthPill(state: .slow(layoutMs: 0, paintMs: 0))
                .help("Render in flight on the worker · 8 MB stack")
        case .idle:
            EmptyView()
        }
    }

    private var workspaceLabel: String {
        switch store.state.workspaceMode {
        case .code:   return "code"
        case .visual: return "visual"
        case .split:  return "split"
        }
    }

    private var sceneGraphMetric: String {
        // Phase 4: derive from PreparedDiagram.{nodeCount,edgeCount}.
        "—n · —e"
    }

    private var failureMessage: String {
        if let error = store.parseError {
            return error.localizedDescription
        }
        return "Render failed"
    }
}

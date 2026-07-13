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
import DesignKitThemes

struct CanvasTopToolbar: View {
    @Bindable var store: LiveEditorStore

    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        HStack(spacing: DSTokens.Spacing.xs) {
            familyPill
            sceneGraphPill
            renderHealthPill
        }
    }

    private var familyPill: some View {
        toolbarPill(
            label: "\(store.state.sourceFormat.shortName.lowercased()) · \(workspaceLabel)",
            dotColor: environment.theme.colors.info.color
        )
    }

    private var sceneGraphPill: some View {
        // Phase 4 fills in real counts from PreparedDiagram.
        toolbarPill(
            label: "scene graph",
            dotColor: environment.theme.colors.iconMuted.color,
            trailing: sceneGraphMetric
        )
    }

    private func toolbarPill(label: String, dotColor: Color, trailing: String? = nil) -> some View {
        DSGlassSurface(role: .popover) {
            HStack(spacing: DSTokens.Spacing.xs) {
                Circle()
                    .fill(dotColor)
                    .frame(width: DSTokens.Icon.indicator, height: DSTokens.Icon.indicator)
                Text(label)
                    .dsFont(.badge)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                if let trailing {
                    Text(trailing)
                        .dsFont(.metric)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                }
            }
            .padding(.horizontal, DSTokens.Spacing.smMd)
            .padding(.vertical, DSTokens.Spacing.xs)
        }
    }

    @ViewBuilder
    private var renderHealthPill: some View {
        switch store.renderStatus {
        case .rendered:
            renderStatusPill(kind: .success, label: "ok · L 0ms · P 0ms")
        case .failed:
            renderStatusPill(kind: .error, label: "failed · \(failureMessage)")
                .help(failureMessage)
        case .pending, .rendering:
            renderStatusPill(kind: .info, label: "rendering · worker · 8 MB")
                .help("Render in flight on the worker · 8 MB stack")
        case .idle:
            EmptyView()
        }
    }

    private func renderStatusPill(kind: DSStatusKind, label: String) -> some View {
        DSGlassSurface(role: .popover) {
            HStack(spacing: DSTokens.Spacing.xs) {
                DSStatusIndicator(kind, label: label)
                Text(label)
                    .dsFont(.metric)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
            }
            .padding(.horizontal, DSTokens.Spacing.smMd)
            .padding(.vertical, DSTokens.Spacing.xs)
        }
        .accessibilityIdentifier("preview.renderHealth")
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

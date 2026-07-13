//
//  StatusbarView.swift
//  DiagramPlayground
//
//  Bottom chrome of the v2 PlaygroundShell: engine + worker + Swift +
//  fonts + diagnostics on the left, backend + corpus + active sample on
//  the right. Only real signals are shown — placeholder readouts (fake
//  last-render ms / snapshot count) were removed rather than stubbed.
//

import SwiftUI
import DiagramKit
import DesignKitThemes

struct StatusbarView: View {
    @Bindable var store: LiveEditorStore

    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        ViewThatFits(in: .horizontal) {
            fullStatus
                .fixedSize(horizontal: true, vertical: false)
            compactStatus
        }
        .padding(.horizontal, DSTokens.Spacing.md)
        .frame(minHeight: DSTokens.Control.statusBar)
        .background {
            DSSurface(role: .statusBar) { Color.clear }
        }
        .foregroundStyle(environment.theme.colors.textSecondary.color)
    }

    private var fullStatus: some View {
        HStack(spacing: DSTokens.Spacing.md) {
            engineSegment
            divider
            workerSegment
            divider
            swiftSegment
            divider
            fontsSegment
            divider
            diagnosticsButton

            Spacer(minLength: DSTokens.Spacing.md)

            backendSegment
            divider
            corpusSegment
            divider
            activeSampleBadge
        }
    }

    private var compactStatus: some View {
        HStack(spacing: DSTokens.Spacing.sm) {
            engineSegment
            Spacer(minLength: DSTokens.Spacing.sm)
            diagnosticsButton
            backendSegment
            activeSampleBadge
        }
        .lineLimit(1)
    }

    // MARK: - Segments

    private var engineSegment: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text("DiagramEngine")
                .dsFont(.badge)
                .foregroundStyle(environment.theme.colors.textPrimary.color)
            Text("· \(statusText)")
                .dsFont(.caption2)
        }
    }

    private var workerSegment: some View {
        labeledMetric(key: "worker thread", value: "8 MB stack", monospace: false)
    }

    private var swiftSegment: some View {
        labeledMetric(key: "Swift", value: swiftVersion)
    }

    private var fontsSegment: some View {
        let names = DiagramFontRegistry.registeredFontNames
        let label = names.isEmpty ? "—" : names.joined(separator: " · ")
        return labeledMetric(key: "fonts", value: label)
    }

    private var backendSegment: some View {
        HStack(spacing: 5) {
            Text("backend")
                .dsFont(.caption2)
            Text(store.state.renderBackend.label.lowercased())
                .dsFont(.metric)
                .foregroundStyle(environment.theme.colors.accent.color)
        }
        .a11yToggle(
            label: "Render backend",
            isOn: true,
            id: A11yID.Statusbar.backend
        )
    }

    private var corpusSegment: some View {
        labeledMetric(key: "corpus", value: "\(TestDiagrams.all.count)")
    }

    @ViewBuilder
    private var activeSampleBadge: some View {
        if let id = store.state.activeTabId, !id.isEmpty {
            DSCodeBadge(id)
        } else {
            Text("—")
                .dsFont(.badge)
                .foregroundStyle(environment.theme.colors.textDisabled.color)
        }
    }

    // MARK: - Diagnostics

    private var diagnosticsButton: some View {
        let count = store.allDiagnostics.count
        return Button {
            store.toggleDiagnosticsDrawer()
        } label: {
            HStack(spacing: DSTokens.Spacing.xs) {
                DSIconView(
                    .diagnostics,
                    size: DSTokens.Icon.micro,
                    colorRole: count > 0 ? .warning : .muted
                )
                Text("Diagnostics · \(count)")
                    .dsFont(.badge)
            }
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .a11yToggle(
            label: "Diagnostics drawer",
            isOn: store.state.diagDrawer.isOpen,
            id: A11yID.Statusbar.diagnostics
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private func labeledMetric(key: String, value: String, monospace: Bool = true) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .dsFont(.caption2)
            Text(value)
                .dsFont(monospace ? .metric : .badge)
                .foregroundStyle(environment.theme.colors.textPrimary.color)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(environment.theme.colors.borderVariant.color)
            .frame(width: DSTokens.Stroke.hairline, height: DSTokens.Spacing.smMd)
            .accessibilityHidden(true)
    }

    private var statusText: String {
        switch store.renderStatus {
        case .idle:      return "idle"
        case .pending:   return "pending"
        case .rendering: return "rendering"
        case .rendered:  return "ready"
        case .failed:    return "render failed"
        }
    }

    private var statusColor: Color {
        switch store.renderStatus {
        case .idle:      return environment.theme.colors.iconMuted.color
        case .pending:   return environment.theme.colors.warning.color
        case .rendering: return environment.theme.colors.info.color
        case .rendered:  return environment.theme.colors.success.color
        case .failed:    return environment.theme.colors.error.color
        }
    }

    private var swiftVersion: String {
        #if compiler(>=6.3)
        return "6.3"
        #elseif compiler(>=6.0)
        return "6.0"
        #else
        return "5"
        #endif
    }

}

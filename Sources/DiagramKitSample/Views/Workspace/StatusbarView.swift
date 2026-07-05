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

struct StatusbarView: View {
    @Bindable var store: LiveEditorStore

    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        HStack(spacing: PlaygroundSpacing.md) {
            engineSegment
            divider
            workerSegment
            divider
            swiftSegment
            divider
            fontsSegment
            divider
            diagnosticsButton

            Spacer(minLength: PlaygroundSpacing.md)

            backendSegment
            divider
            corpusSegment
            divider
            activeSampleBadge
        }
        .padding(.horizontal, PlaygroundSpacing.md)
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(tokens.palette.bgApp)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(tokens.palette.borderHairline)
                        .frame(height: 0.5)
                }
        )
        .foregroundStyle(tokens.palette.fg2)
    }

    // MARK: - Segments

    private var engineSegment: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text("DiagramEngine")
                .font(PlaygroundFont.label)
                .foregroundStyle(tokens.palette.fg1)
            Text("· \(statusText)")
                .font(PlaygroundFont.caption)
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
                .font(PlaygroundFont.caption)
            Text(store.state.renderBackend.label.lowercased())
                .font(PlaygroundFont.metric)
                .foregroundStyle(tokens.palette.accent)
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
            Text(id)
                .font(PlaygroundFont.codeChip)
                .foregroundStyle(tokens.palette.fg2)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: PlaygroundRadius.xs, style: .continuous)
                        .stroke(tokens.palette.borderHairline, lineWidth: 0.5)
                )
        } else {
            Text("—")
                .font(PlaygroundFont.codeChip)
                .foregroundStyle(tokens.palette.fg3)
        }
    }

    // MARK: - Diagnostics

    private var diagnosticsButton: some View {
        let count = store.allDiagnostics.count
        let tone: KPillTone = count > 0 ? .warn : .neutral
        return Button {
            store.toggleDiagnosticsDrawer()
        } label: {
            KPill(
                text: "Diagnostics · \(count)",
                systemImage: "exclamationmark.bubble",
                tone: tone
            )
        }
        .buttonStyle(.plain)
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
                .font(PlaygroundFont.caption)
            Text(value)
                .font(monospace ? PlaygroundFont.metric : PlaygroundFont.label)
                .foregroundStyle(tokens.palette.fg1)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(tokens.palette.borderHairline)
            .frame(width: 1, height: 10)
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
        case .idle:      return tokens.palette.fg3
        case .pending:   return tokens.palette.statusWarning
        case .rendering: return tokens.palette.statusInfo
        case .rendered:  return tokens.palette.statusSuccess
        case .failed:    return tokens.palette.statusError
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

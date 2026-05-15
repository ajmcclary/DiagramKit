//
//  StatusbarView.swift
//  DiagramPlayground
//
//  Bottom chrome of the v2 PlaygroundShell. Phase 1 surfaces what we
//  can answer today: render status, render backend, Swift compiler
//  version, source format and length. Later phases extend with
//  last-render timing, snapshot counts, and corpus stats.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct StatusbarView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        HStack(spacing: 12) {
            statusDot
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
            divider
            KPill(text: "worker · 8 MB stack", systemImage: "cpu", tone: .info)
            divider
            KPill(text: swiftVersion, systemImage: "swift", tone: .neutral)
            divider
            diagnosticsButton
            Spacer()
            KPill(
                text: store.state.renderBackend.label,
                systemImage: store.state.renderBackend.sfSymbol,
                tone: .accent
            )
            .a11yToggle(
                label: "Render backend",
                isOn: true,
                id: A11yID.Statusbar.backend
            )
            divider
            Text(store.state.sourceFormat.shortName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text("\(store.state.source.count) chars")
                .font(.system(size: 11, weight: .regular).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 7, height: 7)
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
        case .idle:      return .gray
        case .pending:   return .yellow
        case .rendering: return .blue
        case .rendered:  return .green
        case .failed:    return .red
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 1, height: 10)
            .accessibilityHidden(true)
    }

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
            id: "statusbar.diagnostics"
        )
    }

    private var swiftVersion: String {
        #if compiler(>=6.3)
        return "Swift 6.3"
        #elseif compiler(>=6.0)
        return "Swift 6.0"
        #else
        return "Swift 5"
        #endif
    }
}

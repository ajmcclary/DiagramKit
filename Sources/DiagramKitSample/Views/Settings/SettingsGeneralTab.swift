//
//  SettingsGeneralTab.swift
//  DiagramPlayground
//
//  Settings ▸ General (transcription §5.1).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct SettingsGeneralTab: View {
    @Bindable var store: LiveEditorStore
    @AppStorage(PlaygroundSettingsKeys.confirmBeforeDelete) private var confirmBeforeDelete = true
    @AppStorage(PlaygroundSettingsKeys.sendAnonymousDiagnostics) private var sendDiagnostics = false
    @AppStorage(PlaygroundSettingsKeys.restoreLastDocument) private var restoreLast = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "General", subtitle: "Workspace and document defaults.")
            DSSettingGroup {
                MenuRow(title: "Default format", value: "Auto-detect") { Button("Auto-detect") {} }
                MenuRow(title: "On startup", value: restoreLast ? "Restore last document" : "New document") {
                    Button("Restore last document") { restoreLast = true }
                    Button("New document") { restoreLast = false }
                }
                settingsToggleRow(
                    "Confirm before delete",
                    detail: "Ask before removing nodes or edges",
                    isOn: $confirmBeforeDelete
                )
                settingsToggleRow(
                    "Send anonymous diagnostics",
                    detail: "Crash reports and usage counts",
                    isOn: $sendDiagnostics
                )
                settingsToggleRow(
                    "Show source citations",
                    detail: "Trace nodes back to source lines",
                    isOn: Binding(get: { store.state.showCitations }, set: { store.setShowCitations($0) })
                )
            }
            .padding(.bottom, 18)
            SettingsSectionCaption(text: "Reset")
            Button {
                PlaygroundSettingsKeys.resetAll()
            } label: {
                HStack(spacing: DSTokens.Spacing.sm) {
                    DSIconView(.reset, size: DSTokens.Icon.micro, colorRole: .error)
                    Text("Reset All Settings").dsFont(.caption)
                }
            }
            .buttonStyle(.ds(role: .destructive, size: .regular))
            Spacer(minLength: 0)
        }
    }

    private func settingsToggleRow(
        _ title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        DSSettingRow(title, detail: detail) {
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.dsSwitchOnly)
        }
        .padding(.horizontal, DSTokens.Spacing.lg)
        .contentShape(Rectangle())
    }
}

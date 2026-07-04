//
//  SettingsGeneralTab.swift
//  DiagramPlayground
//
//  Settings ▸ General (transcription §5.1).
//

import SwiftUI

struct SettingsGeneralTab: View {
    @Bindable var store: LiveEditorStore
    @AppStorage(PlaygroundSettingsKeys.confirmBeforeDelete) private var confirmBeforeDelete = true
    @AppStorage(PlaygroundSettingsKeys.sendAnonymousDiagnostics) private var sendDiagnostics = false
    @AppStorage(PlaygroundSettingsKeys.restoreLastDocument) private var restoreLast = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "General", subtitle: "Workspace and document defaults.")
            SettingsGroupCard {
                MenuRow(title: "Default format", value: "Auto-detect") { Button("Auto-detect") {} }
                MenuRow(title: "On startup", value: restoreLast ? "Restore last document" : "New document") {
                    Button("Restore last document") { restoreLast = true }
                    Button("New document") { restoreLast = false }
                }
                ToggleRow(title: "Confirm before delete", description: "Ask before removing nodes or edges", isOn: $confirmBeforeDelete)
                ToggleRow(title: "Send anonymous diagnostics", description: "Crash reports and usage counts", isOn: $sendDiagnostics)
                ToggleRow(title: "Show source citations", description: "Trace nodes back to source lines",
                          isOn: Binding(get: { store.state.showCitations }, set: { store.setShowCitations($0) }))
            }
            .padding(.bottom, 18)
            SettingsSectionCaption(text: "Reset")
            DestructiveButton(title: "Reset All Settings") { PlaygroundSettingsKeys.resetAll() }
            Spacer(minLength: 0)
        }
    }
}

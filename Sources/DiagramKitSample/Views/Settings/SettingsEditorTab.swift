//
//  SettingsEditorTab.swift
//  DiagramPlayground
//
//  Settings ▸ Editor (transcription §5.2). "Snap to grid" binds to the existing
//  grid-visibility state (the app has no free-node snapping); grid size / nudge /
//  shape / edge style are net-new prefs persisted via @AppStorage.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct SettingsEditorTab: View {
    @Bindable var store: LiveEditorStore
    @AppStorage(PlaygroundSettingsKeys.showConnectionHandles) private var showHandles = true
    @AppStorage(PlaygroundSettingsKeys.gridSize) private var gridSize = 26
    @AppStorage(PlaygroundSettingsKeys.keyboardNudge) private var nudge = 8
    @AppStorage(PlaygroundSettingsKeys.defaultNodeShape) private var nodeShape = "Rectangle"
    @AppStorage(PlaygroundSettingsKeys.defaultEdgeStyle) private var edgeStyle = "Solid arrow"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Editor", subtitle: "Canvas and interaction.")
            DSSettingGroup {
                settingsToggleRow("Snap to grid", isOn: $store.state.gridEnabled)
                StepperRow(title: "Grid size", value: $gridSize, range: 8...64, step: 2, unit: "px")
                settingsToggleRow("Show connection handles", isOn: $showHandles)
                MenuRow(title: "Default node shape", value: nodeShape) {
                    ForEach(["Rectangle", "Rounded", "Stadium", "Circle", "Diamond"], id: \.self) { s in
                        Button(s) { nodeShape = s }
                    }
                }
                MenuRow(title: "Default edge style", value: edgeStyle) {
                    ForEach(["Solid arrow", "Dotted", "Thick", "Open"], id: \.self) { s in
                        Button(s) { edgeStyle = s }
                    }
                }
                StepperRow(title: "Keyboard nudge", description: "Arrow-key move distance", value: $nudge, range: 1...32, unit: "px")
            }
            Spacer(minLength: 0)
        }
    }

    private func settingsToggleRow(
        _ title: String,
        detail: String? = nil,
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

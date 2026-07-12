//
//  SettingsRenderBackendTab.swift
//  DiagramPlayground
//
//  Settings ▸ Render Backend — re-hosts InspectorRenderBackendSection (§5.3).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct SettingsRenderBackendTab: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Render Backend", subtitle: "How diagrams are rasterized and rendered.")
            DSSegmentedControl(RenderBackend.allCases, selection: $store.state.renderBackend) { backend in
                Text(backend.label)
            }
            .padding(.bottom, DSTokens.Spacing.lg)
            SettingsGroupCard {
                StatusRow(title: "Renderer", value: rendererText, valueColor: environment.theme.colors.accent.color, monospaced: true)
                MenuRow(title: "ID policy", value: "Stable") {
                    Button("Stable") {}
                    Button("Random per render") {}
                }
                ToggleRow(title: "Render on every keystroke", description: "auto vs manual",
                          isOn: Binding(get: { store.state.updateMode == .auto },
                                        set: { store.state.updateMode = $0 ? .auto : .manual }))
                StatusRow(title: "Worker thread", description: "8 MB stack · fresh per call", value: "on",
                          valueColor: environment.theme.colors.success.color, dotColor: environment.theme.colors.success.color, monospaced: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var rendererText: String {
        switch store.state.renderBackend {
        case .svg: return "renderSVG(_:)"
        case .image: return "renderImage(_:)"
        case .ascii: return "renderASCII(_:)"
        }
    }
}

//
//  SettingsRenderBackendTab.swift
//  DiagramPlayground
//
//  Settings ▸ Render Backend — re-hosts InspectorRenderBackendSection (§5.3).
//

import SwiftUI
import DesignKitThemes

struct SettingsRenderBackendTab: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Render Backend", subtitle: "How diagrams are rasterized and rendered.")
            DSSegmentedControl(RenderBackend.allCases, selection: $store.state.renderBackend) { backend in
                Text(backend.label)
            }
            .padding(.bottom, Tokens.Spacing.lg)
            DSSettingGroup {
                StatusRow(title: "Renderer", value: rendererText, valueColor: theme.colors.accent.color, monospaced: true)
                MenuRow(title: "ID policy", value: "Stable") {
                    Button("Stable") {}
                    Button("Random per render") {}
                }
                DSSettingRow("Render on every keystroke", detail: "auto vs manual") {
                    Toggle("Render on every keystroke", isOn: Binding(
                        get: { store.state.updateMode == .auto },
                        set: { store.state.updateMode = $0 ? .auto : .manual }
                    ))
                    .labelsHidden()
                    .toggleStyle(.dsSwitchOnly)
                }
                .padding(.horizontal, Tokens.Spacing.lg)
                .contentShape(Rectangle())
                StatusRow(title: "Worker thread", description: "8 MB stack · fresh per call", value: "on",
                          valueColor: theme.colors.success.color, dotColor: theme.colors.success.color, monospaced: true)
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

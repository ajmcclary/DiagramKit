//
//  SettingsRenderBackendTab.swift
//  DiagramPlayground
//
//  Settings ▸ Render Backend — re-hosts InspectorRenderBackendSection (§5.3).
//

import SwiftUI

struct SettingsRenderBackendTab: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Render Backend", subtitle: "How diagrams are rasterized and rendered.")
            SegmentedFormatControl(segments: [
                .init(value: RenderBackend.svg, label: "SVG", systemImage: "doc.text"),
                .init(value: RenderBackend.image, label: "Image", systemImage: "photo"),
                .init(value: RenderBackend.ascii, label: "ASCII", monospaced: true),
            ], selection: $store.state.renderBackend)
            .padding(.bottom, 16)
            SettingsGroupCard {
                StatusRow(title: "Renderer", value: rendererText, valueColor: tokens.palette.accentSecondary, monospaced: true)
                MenuRow(title: "ID policy", value: "Stable") {
                    Button("Stable") {}
                    Button("Random per render") {}
                }
                ToggleRow(title: "Render on every keystroke", description: "auto vs manual",
                          isOn: Binding(get: { store.state.updateMode == .auto },
                                        set: { store.state.updateMode = $0 ? .auto : .manual }))
                StatusRow(title: "Worker thread", description: "8 MB stack · fresh per call", value: "on",
                          valueColor: tokens.palette.statusSuccess, dotColor: tokens.palette.statusSuccess, monospaced: true)
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

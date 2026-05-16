//
//  InspectorRenderBackendSection.swift
//  DiagramPlayground
//
//  RENDER BACKEND section of the v2.1 inspector. ChipGroup picker for
//  SVG / Image / ASCII, plus backend-specific KV readouts and the
//  render-on-keystroke / worker-thread toggles.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct InspectorRenderBackendSection: View {
    @Bindable var store: LiveEditorStore

    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: PlaygroundSpacing.sm) {
            SectionHeader("Render backend", systemImage: "rectangle.on.rectangle")
            Surface(.card, padding: PlaygroundSpacing.md) {
                VStack(alignment: .leading, spacing: PlaygroundSpacing.sm) {
                    backendChips
                    Divider().overlay(tokens.palette.borderHairline)
                    KeyValueRow("renderer", value: rendererText)
                    KeyValueRow("size", value: sizeText)
                    KeyValueRow("viewBox", value: viewBoxText)
                    Divider().overlay(tokens.palette.borderHairline)
                    autoRenderToggle
                    workerThreadRow
                }
            }
        }
        .accessibilityIdentifier(A11yID.Inspector.renderBackendSection)
        .accessibilityElement(children: .contain)
    }

    private var backendChips: some View {
        let items = RenderBackend.allCases.map { backend in
            ChipItem(value: backend, label: backend.label, systemImage: backend.sfSymbol)
        }
        return ChipGroup(items: items, selection: $store.state.renderBackend)
    }

    private var rendererText: String {
        switch store.state.renderBackend {
        case .svg:   return "renderSVG(_:)"
        case .image: return "renderImage(_:)"
        case .ascii: return "renderASCII(_:)"
        }
    }

    private var sizeText: String {
        // Phase 4 will replace with real PreparedDiagram dimensions.
        switch store.state.renderBackend {
        case .svg:   return "—"
        case .image: return "@2x"
        case .ascii: return "—"
        }
    }

    private var viewBoxText: String {
        switch store.state.renderBackend {
        case .svg:   return "—"
        case .image: return "—"
        case .ascii: return "—"
        }
    }

    private var autoRenderToggle: some View {
        Toggle(isOn: Binding(
            get: { store.state.updateMode == .auto },
            set: { store.state.updateMode = $0 ? .auto : .manual }
        )) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Render on every keystroke")
                    .font(PlaygroundFont.body)
                    .foregroundStyle(tokens.palette.fg1)
                Text("auto vs manual")
                    .font(PlaygroundFont.badge)
                    .foregroundStyle(tokens.palette.fg3)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .tint(tokens.palette.accent)
    }

    private var workerThreadRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Worker thread")
                    .font(PlaygroundFont.body)
                    .foregroundStyle(tokens.palette.fg1)
                Text("8 MB stack · fresh per call")
                    .font(PlaygroundFont.badge)
                    .foregroundStyle(tokens.palette.fg3)
            }
            Spacer()
            Circle()
                .fill(tokens.palette.statusSuccess)
                .frame(width: 7, height: 7)
            Text("on")
                .font(PlaygroundFont.metric)
                .foregroundStyle(tokens.palette.statusSuccess)
        }
    }
}

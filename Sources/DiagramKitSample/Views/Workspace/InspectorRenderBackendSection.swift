//
//  InspectorRenderBackendSection.swift
//  DiagramPlayground
//
//  RENDER BACKEND section of the v2.1 inspector. Segmented picker for
//  SVG / Image / ASCII, plus backend-specific KV readouts and the
//  render-on-keystroke / worker-thread toggles.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct InspectorRenderBackendSection: View {
    @Bindable var store: LiveEditorStore

    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            DSSectionHeader("Render backend")
            DSSurface(role: .card) {
                VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
                    backendChips
                    separator
                    KeyValueRow("renderer", value: rendererText)
                    KeyValueRow("size", value: sizeText)
                    KeyValueRow("viewBox", value: viewBoxText)
                    separator
                    autoRenderToggle
                    workerThreadRow
                }
                .padding(DSTokens.Spacing.md)
            }
        }
        .accessibilityIdentifier(A11yID.Inspector.renderBackendSection)
        .accessibilityElement(children: .contain)
    }

    private var backendChips: some View {
        DSSegmentedControl(RenderBackend.allCases, selection: $store.state.renderBackend) { backend in
            Text(backend.label)
        }
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
                    .dsFont(.body)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                Text("auto vs manual")
                    .dsFont(.badge)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
            }
        }
        .toggleStyle(.ds)
    }

    private var workerThreadRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Worker thread")
                    .dsFont(.body)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                Text("8 MB stack · fresh per call")
                    .dsFont(.badge)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
            }
            Spacer()
            Circle()
                .fill(environment.theme.colors.success.color)
                .frame(width: DSTokens.Icon.indicator, height: DSTokens.Icon.indicator)
            Text("on")
                .dsFont(.metric)
                .foregroundStyle(environment.theme.colors.success.color)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(environment.theme.colors.borderVariant.color)
            .frame(height: DSTokens.Stroke.hairline)
            .accessibilityHidden(true)
    }
}

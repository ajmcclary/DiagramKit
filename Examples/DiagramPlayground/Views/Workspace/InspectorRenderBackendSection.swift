//
//  InspectorRenderBackendSection.swift
//  DiagramPlayground
//
//  3-way segmented selector for SVG / Image / ASCII. Phase 1 persists
//  the choice on `LiveEditorState.renderBackend`; PreviewCanvas wires
//  the routing in Phase 2.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct InspectorRenderBackendSection: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        InspectorSectionHeader(title: "Render backend", systemImage: "rectangle.on.rectangle")
            .padding(.bottom, 4)
        VStack(alignment: .leading, spacing: 8) {
            Picker("Backend", selection: $store.state.renderBackend) {
                ForEach(RenderBackend.allCases, id: \.self) { backend in
                    Label(backend.label, systemImage: backend.sfSymbol).tag(backend)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 4) {
                KPill(text: "worker · 8 MB stack", systemImage: "cpu", tone: .info)
                Spacer()
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.06))
        )
        .accessibilityIdentifier(A11yID.Inspector.renderBackendSection)
        .accessibilityElement(children: .contain)
    }
}

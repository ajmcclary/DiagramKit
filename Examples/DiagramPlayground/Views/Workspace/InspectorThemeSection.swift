//
//  InspectorThemeSection.swift
//  DiagramPlayground
//
//  Phase 1 — wraps the existing ThemePicker inside the new accordion
//  layout. Phase 10 swaps this for the full ThemeBuilderCard.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct InspectorThemeSection: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        InspectorSectionHeader(title: "Theme", systemImage: "paintpalette")
            .padding(.bottom, 4)
        ThemePicker(store: store)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.06))
            )
            .accessibilityIdentifier(A11yID.Inspector.themeSection)
            .accessibilityElement(children: .contain)
    }
}

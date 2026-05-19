//
//  InspectorView.swift
//  DiagramPlayground
//
//  v2.1 inspector. Scrollable column of section cards:
//  DOCUMENT / RENDER BACKEND / THEME / PLATFORM / MUTATIONS /
//  DIAGNOSTICS / HISTORY / CITATIONS.
//

import SwiftUI

struct InspectorView: View {
    @Bindable var store: LiveEditorStore

    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: PlaygroundSpacing.lg) {
                    InspectorDocumentSection(store: store)
                    InspectorRenderBackendSection(store: store)
                    InspectorThemeSection(store: store)
                    PlatformRow(store: store)
                    MutationsCatalogCard(store: store)
                    InspectorDiagnosticsSection(store: store)
                    InspectorHistorySection(store: store)
                    InspectorCitationsToggle(store: store)
                }
                .padding(PlaygroundSpacing.md)
            }
        }
        .frame(width: 350)
        .background(tokens.palette.bgApp)
    }

    private var header: some View {
        HStack(spacing: PlaygroundSpacing.sm) {
            Text("INSPECTOR")
                .font(PlaygroundFont.overline)
                .tracking(0.6)
                .foregroundStyle(tokens.palette.fg2)
            Spacer()
            Text(store.state.sourceFormat.shortName)
                .font(PlaygroundFont.codeChip)
                .foregroundStyle(tokens.palette.fg2)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .stroke(tokens.palette.borderHairline, lineWidth: 0.5)
                )
        }
        .padding(.horizontal, PlaygroundSpacing.md)
        .padding(.vertical, PlaygroundSpacing.sm)
        .background(
            Rectangle()
                .fill(tokens.palette.bgApp)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(tokens.palette.borderHairline)
                        .frame(height: 0.5)
                }
        )
    }
}

//
//  BrowsePanel.swift
//  DiagramPlayground
//
//  Activity-rail Browse panel: full-window nav links + the sample library
//  (the old left sidebar, transcription §6.2).
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct BrowsePanel: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    private let navLinks: [(FullScreenSurface, String, DSIcon, String?)] = [
        (.coverage, "Coverage matrix", .diagram, "28×5"),
        (.corpus, "Corpus", .code, nil),
        (.crossFormat, "Cross-format", .rearrange, nil),
        (.probe, "Importer probe", .search, nil),
        (.snippets, "Snippets library", .copy, nil),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Browse")
            VStack(spacing: DSTokens.Stroke.thin) {
                ForEach(Array(navLinks.enumerated()), id: \.offset) { _, link in
                    Button { store.setFullScreen(link.0) } label: {
                        HStack(spacing: DSTokens.Spacing.smMd) {
                            DSIconView(link.2, size: DSTokens.Icon.micro, colorRole: .muted)
                            Text(link.1)
                                .dsFont(.caption)
                                .foregroundStyle(environment.theme.colors.textPrimary.color)
                            Spacer(minLength: DSTokens.Spacing.xxs)
                            if let count = link.3 {
                                Text(count)
                                    .dsFont(.code)
                                    .foregroundStyle(environment.theme.colors.textDisabled.color)
                            }
                        }
                        .padding(.horizontal, DSTokens.Spacing.sm)
                        .frame(minHeight: DSTokens.Control.rowCompact)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.ds(role: .ghost, size: .compact))
                }
            }
            .padding(.horizontal, DSTokens.Spacing.sm)
            .padding(.bottom, DSTokens.Spacing.xs)
            Rectangle()
                .fill(environment.theme.colors.borderVariant.color)
                .frame(height: DSTokens.Stroke.hairline)
                .padding(.horizontal, DSTokens.Spacing.md)
                .padding(.vertical, DSTokens.Spacing.xxs)
            // The categorized, searchable sample library.
            SampleDiagramPanel(store: store)
                .frame(maxHeight: .infinity)
        }
    }
}

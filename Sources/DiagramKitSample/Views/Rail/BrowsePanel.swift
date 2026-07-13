//
//  BrowsePanel.swift
//  DiagramPlayground
//
//  Activity-rail Browse panel: full-window nav links + the sample library
//  (the old left sidebar, transcription §6.2).
//

import SwiftUI
import DesignKitThemes

struct BrowsePanel: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

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
            VStack(spacing: Tokens.Shape.strokeThin) {
                ForEach(Array(navLinks.enumerated()), id: \.offset) { _, link in
                    Button { store.setFullScreen(link.0) } label: {
                        HStack(spacing: Tokens.Spacing.smMd) {
                            DSIconView(link.2, size: Tokens.Size.Icon.micro, colorRole: .muted)
                            Text(link.1)
                                .dsFont(.caption)
                                .foregroundStyle(theme.colors.textPrimary.color)
                            Spacer(minLength: Tokens.Spacing.xxs)
                            if let count = link.3 {
                                Text(count)
                                    .dsFont(.code)
                                    .foregroundStyle(theme.colors.textDisabled.color)
                            }
                        }
                        .padding(.horizontal, Tokens.Spacing.sm)
                        .frame(minHeight: Tokens.Size.Control.rowCompact)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.ds(role: .ghost, size: .compact))
                }
            }
            .padding(.horizontal, Tokens.Spacing.sm)
            .padding(.bottom, Tokens.Spacing.xs)
            Rectangle()
                .fill(theme.colors.borderVariant.color)
                .frame(height: Tokens.Shape.strokeHairline)
                .padding(.horizontal, Tokens.Spacing.md)
                .padding(.vertical, Tokens.Spacing.xxs)
            // The categorized, searchable sample library.
            SampleDiagramPanel(store: store)
                .frame(maxHeight: .infinity)
        }
    }
}

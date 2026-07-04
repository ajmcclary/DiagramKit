//
//  BrowsePanel.swift
//  DiagramPlayground
//
//  Activity-rail Browse panel: full-window nav links + the sample library
//  (the old left sidebar, transcription §6.2).
//

import SwiftUI

struct BrowsePanel: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.playgroundTokens) private var tokens

    private let navLinks: [(FullScreenSurface, String, String, String?)] = [
        (.coverage, "Coverage matrix", "square.grid.3x3", "28×5"),
        (.corpus, "Corpus", "book", nil),
        (.crossFormat, "Cross-format", "rectangle.split.3x1", nil),
        (.probe, "Importer probe", "magnifyingglass", nil),
        (.snippets, "Snippets library", "doc.text", nil),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader("Browse")
            VStack(spacing: 1) {
                ForEach(Array(navLinks.enumerated()), id: \.offset) { _, link in
                    Button { store.setFullScreen(link.0) } label: {
                        HStack(spacing: 9) {
                            Image(systemName: link.2).font(.system(size: 13)).foregroundStyle(tokens.palette.fg3).frame(width: 15)
                            Text(link.1).font(PlaygroundFont.sans(12.5)).foregroundStyle(tokens.palette.fg1)
                            Spacer(minLength: 4)
                            if let count = link.3 {
                                Text(count).font(PlaygroundFont.mono(10.5)).foregroundStyle(tokens.palette.textFaintest)
                            }
                        }
                        .padding(.horizontal, 8).frame(height: 28)
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8).padding(.bottom, 6)
            Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5).padding(.horizontal, 12).padding(.vertical, 4)
            // The categorized, searchable sample library.
            SampleDiagramPanel(store: store)
                .frame(maxHeight: .infinity)
        }
    }
}

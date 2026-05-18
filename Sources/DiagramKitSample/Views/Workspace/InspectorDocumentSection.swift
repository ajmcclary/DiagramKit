//
//  InspectorDocumentSection.swift
//  DiagramPlayground
//
//  DOCUMENT section of the v2.1 inspector. KV grid covering file,
//  family, format, line/char counts, and placeholders for node /
//  edge / layout / paint readouts that Phase 4 will populate from
//  PreparedDiagram SPI.
//

import SwiftUI

struct InspectorDocumentSection: View {
    @Bindable var store: LiveEditorStore

    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: PlaygroundSpacing.sm) {
            SectionHeader("Document", systemImage: "doc.text") {
                Text(store.state.sourceFormat.shortName)
                    .font(PlaygroundFont.badge)
                    .foregroundStyle(tokens.palette.fg2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(tokens.palette.borderHairline, lineWidth: 0.5)
                    )
            }
            Surface(.card, padding: PlaygroundSpacing.md) {
                VStack(spacing: 4) {
                    KeyValueRow("File", value: fileLabel, copyable: false)
                    KeyValueRow("Family", value: store.state.sourceFormat.displayName)
                    KeyValueRow("Format", value: store.state.sourceFormat.shortName)
                    KeyValueRow("Nodes", value: nodeCountText)
                    KeyValueRow("Edges", value: edgeCountText)
                    KeyValueRow("Layout", value: layoutText)
                    KeyValueRow("Paint", value: paintText)
                    KeyValueRow("Lines", value: "\(lineCount)")
                    KeyValueRow("Characters", value: "\(store.state.source.count)")
                    KeyValueRow("Bundled fonts", value: bundledFontsText)
                }
            }
        }
        .accessibilityIdentifier(A11yID.Inspector.documentSection)
        .accessibilityElement(children: .contain)
    }

    private var lineCount: Int {
        store.state.source.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    private var fileLabel: String {
        store.state.activeTabId ?? "untitled"
    }

    // Phase 4 will replace these placeholders with PreparedDiagram SPI.
    private var nodeCountText: String { "—" }
    private var edgeCountText: String { "—" }
    private var layoutText: String { "—" }
    private var paintText: String { "—" }
    private var bundledFontsText: String { "Noto Sans · Mono" }
}

/// Bridge for legacy sections still calling `InspectorSectionHeader`.
/// New code should use `SectionHeader` directly.
struct InspectorSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        SectionHeader(title, systemImage: systemImage)
    }
}

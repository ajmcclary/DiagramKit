//
//  InspectorDocumentSection.swift
//  DiagramPlayground
//
//  KV grid summarising the active document. Phase 1 surfaces what
//  the store can answer today (format, source length, dirty state).
//  Layout/paint timing + node/edge counts land in Phase 2 when the
//  PreviewCanvas exposes its last-render stats on the store.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct InspectorDocumentSection: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        InspectorSectionHeader(title: "Document", systemImage: "doc.text")
            .padding(.bottom, 4)
        VStack(alignment: .leading, spacing: 4) {
            row("Format", value: store.state.sourceFormat.displayName)
            row("Theme", value: store.state.selectedThemeName)
            row("Lines", value: "\(lineCount)")
            row("Characters", value: "\(store.state.source.count)")
            row("Dirty", value: store.isDirty ? "yes" : "no")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.06))
        )
        .accessibilityIdentifier(A11yID.Inspector.documentSection)
        .accessibilityElement(children: .contain)
    }

    private var lineCount: Int {
        store.state.source.split(separator: "\n", omittingEmptySubsequences: false).count
    }

    private func row(_ key: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 11, weight: .regular).monospacedDigit())
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct InspectorSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Spacer()
        }
    }
}

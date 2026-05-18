//
//  TitlebarView.swift
//  DiagramPlayground
//
//  Phase 1 / Task 1.3 — top chrome with title + WorkspaceModePicker.
//  Render button forwards to `LiveEditorStore.requestRender(reason:)`;
//  the export button is a Phase 7 placeholder.
//

import SwiftUI

struct TitlebarView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.3.group")
                .foregroundStyle(.secondary)
            Text(titleText)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            if store.isDirty {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
            Spacer()
            WorkspaceModePicker(store: store)
            Spacer()
            renderButton
            convertButton
            exportButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var titleText: String {
        // Phase 1 derives the title from `sourceFormat` + a short
        // preview of the first non-blank line. A richer "active sample"
        // identifier is wired in later phases that introduce the
        // Sidebar tree + corpus browser.
        let firstLine = store.state.source
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let preview = firstLine.isEmpty ? "untitled" : firstLine
        return "\(store.state.sourceFormat.displayName) · \(preview)"
    }

    private var renderButton: some View {
        Button {
            store.requestRender(reason: .manual)
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .keyboardShortcut("r", modifiers: .command)
        .a11y(label: "Render now", id: A11yID.Titlebar.render)
    }

    private var convertButton: some View {
        Button {
            store.openConvertSheet()
        } label: {
            Image(systemName: "arrow.left.arrow.right")
        }
        .keyboardShortcut("k", modifiers: [.command, .shift])
        .a11y(label: "Convert", id: "titlebar.convert")
    }

    private var exportButton: some View {
        Button {
            store.openExportSheet()
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .keyboardShortcut("e", modifiers: .command)
        .a11y(label: "Export", id: A11yID.Titlebar.export)
    }
}

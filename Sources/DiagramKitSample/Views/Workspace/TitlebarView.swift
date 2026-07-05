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
            WorkspaceModePicker(store: store)
            Spacer()
            convertButton
            exportButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var convertButton: some View {
        Button {
            store.openConvertSheet()
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .touchTarget()
        }
        .keyboardShortcut("k", modifiers: [.command, .shift])
        .a11y(label: "Convert", id: "titlebar.convert")
    }

    private var exportButton: some View {
        Button {
            store.openExportSheet()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .touchTarget()
        }
        .keyboardShortcut("e", modifiers: .command)
        .a11y(label: "Export", id: A11yID.Titlebar.export)
    }
}

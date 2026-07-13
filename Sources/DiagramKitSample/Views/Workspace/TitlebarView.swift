//
//  TitlebarView.swift
//  DiagramPlayground
//
//  Phase 1 / Task 1.3 — top chrome with title + WorkspaceModePicker.
//  Render button forwards to `LiveEditorStore.requestRender(reason:)`;
//  the export button is a Phase 7 placeholder.
//

import SwiftUI
import DesignKitThemes

struct TitlebarView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        HStack(spacing: Tokens.Spacing.md) {
            WorkspaceModePicker(store: store)
            Spacer()
            convertButton
            exportButton
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .frame(minHeight: Tokens.Size.Control.titleBar)
        .background {
            DSSurface(role: .titleBar) { Color.clear }
        }
    }

    private var convertButton: some View {
        Button {
            store.openConvertSheet()
        } label: {
            DSIconView(.convert)
        }
        .keyboardShortcut("k", modifiers: [.command, .shift])
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .a11y(label: "Convert", id: "titlebar.convert")
    }

    private var exportButton: some View {
        Button {
            store.openExportSheet()
        } label: {
            DSIconView(.export)
        }
        .keyboardShortcut("e", modifiers: .command)
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .a11y(label: "Export", id: A11yID.Titlebar.export)
    }
}

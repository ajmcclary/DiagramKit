//
//  DiagramEditorPane.swift
//  DiagramPlayground
//
//  Floating Inspector drawer that hosts DiagramKitInteractive's
//  DiagramEditor. Replaces the modal InspectorView. Renders disabled
//  banners when the document is missing or non-flowchart.
//

import SwiftUI
import DiagramKit
import DiagramKitInteractive
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct DiagramEditorPane: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                content
                    .padding(16)
            }
        }
        .frame(minWidth: 320, idealWidth: 360)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(store.theme.effectiveLine()).opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, x: -2, y: 0)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Inspector")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(store.theme.foreground))
            Spacer(minLength: 0)
            Button {
                store.toggleInspector()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            // Cmd-I lives on the toolbar button (Task 24) — keep this button
            // shortcut-free to avoid duplicate shortcut warnings.
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        if store.editor == nil {
            disabledBanner(
                icon: "doc.text",
                message: "Parse the source to enable interactive editing."
            )
        } else if let editor = store.editor, editor.document.type != .flowchart {
            disabledBanner(
                icon: "exclamationmark.triangle",
                message: "Interactive editing is not yet available for \(editor.document.type.rawValue) diagrams."
            )
        } else {
            // Real sections land in Tasks 15–18.
            placeholderSection
        }
    }

    private var placeholderSection: some View {
        Text("Editor sections will land in subsequent tasks.")
            .font(.system(size: 12))
            .foregroundColor(Color(store.theme.effectiveMuted()))
    }

    private func disabledBanner(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(store.theme.effectiveMuted()))
            Text(message)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(store.theme.effectiveMuted()))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

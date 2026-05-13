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
        } else if let editor = store.editor {
            VStack(alignment: .leading, spacing: 18) {
                TitleSection(store: store, editor: editor)
                if let message = store.lastMutationError {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
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

// MARK: - Title section

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct TitleSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    @SwiftUI.State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Document title", store: store)
            HStack(spacing: 6) {
                TextField("Untitled", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                Button("Set") {
                    try? store.performMutation(.setTitle(draft.isEmpty ? nil : draft))
                }
                Button("Clear") {
                    try? store.performMutation(.setTitle(nil))
                }
                .disabled(editor.document.title == nil)
            }
            Text("Currently: \(editor.document.title ?? "—")")
                .font(.system(size: 10))
                .foregroundColor(Color(store.theme.effectiveMuted()))
        }
        .onAppear {
            draft = editor.document.title ?? ""
        }
        .onChange(of: editor.document.title) { _, newValue in
            draft = newValue ?? ""
        }
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
@MainActor
private func sectionLabel(_ text: String, store: LiveEditorStore) -> some View {
    Text(text)
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(Color(store.theme.effectiveMuted()))
        .textCase(.uppercase)
}

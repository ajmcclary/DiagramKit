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
                Divider()
                SelectionSection(store: store, editor: editor)
                Divider()
                LabelSection(store: store, editor: editor)
                Divider()
                InsertNodeSection(store: store, editor: editor)
                Divider()
                InsertEdgeSection(store: store, editor: editor)
                Divider()
                DeleteSection(store: store, editor: editor)
                Divider()
                UndoRedoFooter(store: store, editor: editor)
                if let message = store.lastMutationError {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                if !editor.lastExportDiagnostics.isEmpty {
                    ForEach(editor.lastExportDiagnostics.indices, id: \.self) { idx in
                        let d = editor.lastExportDiagnostics[idx]
                        Text("\(String(describing: d.severity)): \(d.message)")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
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

// MARK: - Selection section

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct SelectionSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Selection", store: store)
            if let lookup = store.boundsLookup, !lookup.allElementIDs.isEmpty {
                Picker("Selected element", selection: pickerBinding(lookup: lookup)) {
                    Text("None").tag(String?.none)
                    Section("Nodes") {
                        ForEach(nodeIDs(lookup: lookup), id: \.self) { id in
                            Text(displayName(id: id, lookup: lookup)).tag(String?.some(id))
                        }
                    }
                    Section("Edges") {
                        ForEach(edgeIDs(lookup: lookup), id: \.self) { id in
                            Text(displayName(id: id, lookup: lookup)).tag(String?.some(id))
                        }
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            } else {
                Text("No selectable elements in this diagram.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(store.theme.effectiveMuted()))
            }
        }
    }

    private func pickerBinding(lookup: DiagramBoundsLookup) -> Binding<String?> {
        Binding(
            get: { editor.selection?.elementID },
            set: { newID in
                if let newID, let selection = lookup.selection(for: newID) {
                    store.setSelection(selection)
                } else {
                    store.setSelection(nil)
                }
            }
        )
    }

    private func nodeIDs(lookup: DiagramBoundsLookup) -> [String] {
        lookup.allElementIDs.filter { $0.hasPrefix("node:") }
    }

    private func edgeIDs(lookup: DiagramBoundsLookup) -> [String] {
        lookup.allElementIDs.filter { $0.hasPrefix("edge:") }
    }

    private func displayName(id: String, lookup: DiagramBoundsLookup) -> String {
        guard let sel = lookup.selection(for: id) else { return id }
        if let label = lookup.label(for: sel), !label.isEmpty {
            return "\(label) (\(id))"
        }
        return id
    }
}

// MARK: - Label section

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct LabelSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    @SwiftUI.State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Label", store: store)
            HStack(spacing: 6) {
                TextField("Label…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                Button("Rename") {
                    guard let selection = editor.selection else { return }
                    try? store.performMutation(.setLabel(of: selection, to: draft))
                }
                .disabled(editor.selection == nil)
            }
        }
        .onChange(of: editor.selection) { _, _ in
            updateDraft()
        }
        .onAppear { updateDraft() }
    }

    private func updateDraft() {
        guard let selection = editor.selection,
              let label = store.boundsLookup?.label(for: selection) else {
            draft = ""
            return
        }
        draft = label
    }
}

// MARK: - Insert-node section

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct InsertNodeSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    @SwiftUI.State private var idDraft: String = ""
    @SwiftUI.State private var labelDraft: String = ""
    @SwiftUI.State private var shape: ShapeChoice = .rectangle
    // Mutation errors are surfaced from `store.lastMutationError` so the
    // single source of truth (the store) drives the UI. Previously this
    // pane mirrored the error locally too, producing duplicate display.

    enum ShapeChoice: String, CaseIterable, Identifiable {
        case rectangle, round, stadium, circle, rhombus
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Insert node", store: store)
            HStack(spacing: 6) {
                TextField("ID (e.g. n3)", text: $idDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .frame(maxWidth: 80)
                TextField("Label", text: $labelDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
            HStack(spacing: 6) {
                Picker("Shape", selection: $shape) {
                    ForEach(ShapeChoice.allCases) { c in
                        Text(c.label).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 140)
                Spacer(minLength: 0)
                Button("Insert") {
                    insert()
                }
                .disabled(labelDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func insert() {
        let id = idDraft.trimmingCharacters(in: .whitespaces).isEmpty
            ? Self.nextDefaultID(existing: store.boundsLookup?.allElementIDs ?? [])
            : idDraft
        do {
            try store.performFlowchartMutation(.insertNode(id: id, label: labelDraft, type: shape.rawValue))
            idDraft = ""
            labelDraft = ""
        } catch {
            // Error already surfaced via `store.lastMutationError`.
        }
    }

    static func nextDefaultID(existing: [String]) -> String {
        let nodeIDs = Set(existing.compactMap { $0.hasPrefix("node:") ? String($0.dropFirst(5)) : nil })
        var n = 1
        while nodeIDs.contains("n\(n)") { n += 1 }
        return "n\(n)"
    }
}

// MARK: - Insert-edge section

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct InsertEdgeSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    @SwiftUI.State private var fromID: String?
    @SwiftUI.State private var toID: String?
    @SwiftUI.State private var labelDraft: String = ""
    @SwiftUI.State private var idDraft: String = ""
    // Mutation errors are surfaced from `store.lastMutationError` —
    // see InsertNodeSection for rationale.

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Insert edge", store: store)
            HStack(spacing: 6) {
                fromPicker
                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundColor(Color(store.theme.effectiveMuted()))
                toPicker
            }
            HStack(spacing: 6) {
                TextField("Label (optional)", text: $labelDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                TextField("Edge ID (optional)", text: $idDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .frame(maxWidth: 100)
                Button("Insert") {
                    insert()
                }
                .disabled(fromID == nil || toID == nil)
            }
        }
        .onAppear { seedFromCurrentSelection() }
        .onChange(of: editor.selection) { _, _ in seedFromCurrentSelection() }
    }

    private var fromPicker: some View {
        Picker("From", selection: $fromID) {
            Text("From…").tag(String?.none)
            ForEach(nodeIDs(), id: \.self) { id in
                Text(displayName(id: id)).tag(String?.some(id))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private var toPicker: some View {
        Picker("To", selection: $toID) {
            Text("To…").tag(String?.none)
            ForEach(nodeIDs(), id: \.self) { id in
                Text(displayName(id: id)).tag(String?.some(id))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private func nodeIDs() -> [String] {
        (store.boundsLookup?.allElementIDs ?? []).filter { $0.hasPrefix("node:") }
    }

    private func displayName(id: String) -> String {
        guard let sel = store.boundsLookup?.selection(for: id) else { return id }
        if let label = store.boundsLookup?.label(for: sel), !label.isEmpty {
            return label
        }
        return id
    }

    private func seedFromCurrentSelection() {
        if let selection = editor.selection,
           selection.elementID.hasPrefix("node:"),
           fromID == nil {
            fromID = selection.elementID
        }
    }

    private func insert() {
        guard
            let fromID,
            let toID,
            let lookup = store.boundsLookup,
            let fromSel = lookup.selection(for: fromID),
            let toSel = lookup.selection(for: toID)
        else { return }
        let id = idDraft.trimmingCharacters(in: .whitespaces)
        let label = labelDraft.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : labelDraft
        do {
            try store.performFlowchartMutation(.insertEdge(id: id, from: fromSel, to: toSel, label: label))
            labelDraft = ""
            idDraft = ""
            self.fromID = nil
            self.toID = nil
        } catch {
            // Error already surfaced via `store.lastMutationError`.
        }
    }
}

// MARK: - Delete section

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct DeleteSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    var body: some View {
        HStack {
            Button("Delete selected", role: .destructive) {
                guard let selection = editor.selection else { return }
                try? store.performMutation(.deleteElement(selection))
            }
            .disabled(editor.selection == nil)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Undo / redo footer

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct UndoRedoFooter: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.undoStructural()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!editor.undoManager.canUndo)

            Button {
                store.redoStructural()
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!editor.undoManager.canRedo)

            Spacer(minLength: 0)

            if !editor.undoManager.undoActionName.isEmpty {
                Text("Last: \(editor.undoManager.undoActionName)")
                    .font(.system(size: 10))
                    .foregroundColor(Color(store.theme.effectiveMuted()))
            }
        }
    }
}

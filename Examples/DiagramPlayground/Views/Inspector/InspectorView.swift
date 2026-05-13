//
//  InspectorView.swift
//  DiagramPlayground
//
//  Demonstrates DiagramKitInteractive's DiagramEditor: structured
//  mutations (setTitle, setLabel, deleteElement), element selection
//  driven by DiagramBoundsLookup, undo/redo through the editor's own
//  UndoManager, and round-tripping the mutated source back to the
//  store. Seeded on appear from the store's current source; users
//  can re-seed manually or "Apply" the edited source back to the
//  store to drive a live re-render.
//

import SwiftUI
import DiagramKit
import DiagramKitExport
import DiagramKitInteractive
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct InspectorView: View {
    @Bindable var store: LiveEditorStore
    @Binding var isPresented: Bool

    @SwiftUI.State private var editor: DiagramEditor?
    @SwiftUI.State private var lookup: DiagramBoundsLookup?
    @SwiftUI.State private var seedError: String?
    @SwiftUI.State private var actionError: String?
    @SwiftUI.State private var isSeeding: Bool = false
    @SwiftUI.State private var titleDraft: String = ""
    @SwiftUI.State private var labelDraft: String = ""
    @SwiftUI.State private var selectedElementID: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 520, minHeight: 560)
        .background(Color(store.theme.background))
        .task {
            await seedFromStore()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("Inspector")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(store.theme.foreground))
            Spacer(minLength: 0)
            Button("Re-seed") {
                Task { await seedFromStore() }
            }
            .disabled(isSeeding)
            Button("Apply") {
                applyToStore()
            }
            .disabled(!hasApplicableSource)
            Button("Close") {
                isPresented = false
            }
        }
        .padding(12)
        .background(Color(store.theme.background))
    }

    // MARK: - Body

    @ViewBuilder
    private var content: some View {
        if isSeeding {
            ProgressView("Parsing source…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let seedError {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
                Text(seedError)
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("Try again") {
                    Task { await seedFromStore() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let editor, let lookup {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleSection(editor: editor)
                    Divider()
                    selectionSection(editor: editor, lookup: lookup)
                    Divider()
                    undoSection(editor: editor)
                    if let actionError {
                        Text(actionError)
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    Divider()
                    sourcePreview(editor: editor)
                }
                .padding(16)
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Title

    private func titleSection(editor: DiagramEditor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Document title")
            HStack(spacing: 6) {
                TextField("Untitled", text: $titleDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                Button("Set") {
                    apply { try editor.perform(.setTitle(titleDraft.isEmpty ? nil : titleDraft)) }
                }
                Button("Clear") {
                    apply { try editor.perform(.setTitle(nil)) }
                }
                .disabled(editor.document.title == nil)
            }
            Text("Currently: \(editor.document.title ?? "—")")
                .font(.system(size: 10))
                .foregroundColor(Color(store.theme.effectiveMuted()))
        }
    }

    // MARK: - Selection / label / delete

    private func selectionSection(editor: DiagramEditor, lookup: DiagramBoundsLookup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Element")
            if lookup.allElementIDs.isEmpty {
                Text("No selectable elements in this diagram.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(store.theme.effectiveMuted()))
            } else {
                Picker("Element", selection: $selectedElementID) {
                    Text("None").tag(String?.none)
                    ForEach(lookup.allElementIDs, id: \.self) { id in
                        Text(displayName(for: id, lookup: lookup))
                            .tag(String?.some(id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .onChange(of: selectedElementID) { _, newID in
                    if let newID, let selection = lookup.selection(for: newID) {
                        editor.selection = selection
                        labelDraft = lookup.label(for: selection) ?? ""
                    } else {
                        editor.selection = nil
                        labelDraft = ""
                    }
                }

                HStack(spacing: 6) {
                    TextField("Label…", text: $labelDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    Button("Rename") {
                        guard let selection = editor.selection else { return }
                        apply { try editor.perform(.setLabel(of: selection, to: labelDraft)) }
                    }
                    .disabled(editor.selection == nil)
                    Button("Delete") {
                        guard let selection = editor.selection else { return }
                        apply { try editor.perform(.deleteElement(selection)) }
                    }
                    .disabled(editor.selection == nil)
                }
            }
        }
    }

    // MARK: - Undo / Redo

    private func undoSection(editor: DiagramEditor) -> some View {
        HStack(spacing: 8) {
            Button {
                editor.undoManager.undo()
                Task { await refreshLookup() }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!editor.undoManager.canUndo)

            Button {
                editor.undoManager.redo()
                Task { await refreshLookup() }
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!editor.undoManager.canRedo)

            Spacer(minLength: 0)

            if let name = editor.undoManager.undoActionName.nilIfEmpty {
                Text("Last: \(name)")
                    .font(.system(size: 10))
                    .foregroundColor(Color(store.theme.effectiveMuted()))
            }
        }
    }

    // MARK: - Source preview

    private func sourcePreview(editor: DiagramEditor) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Editor source (\(editor.preferredExportFormat.rawValue))")
            ScrollView {
                Text(displayedSource(for: editor))
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(maxHeight: 180)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(store.theme.foreground).opacity(0.04))
            )
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

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(store.theme.effectiveMuted()))
            .textCase(.uppercase)
    }

    private var hasApplicableSource: Bool {
        guard let source = editor?.source else { return false }
        return !source.isEmpty
    }

    private func displayedSource(for editor: DiagramEditor) -> String {
        guard let source = editor.source, !source.isEmpty else { return "—" }
        return source
    }

    private func displayName(for id: String, lookup: DiagramBoundsLookup) -> String {
        let selection = lookup.selection(for: id).map { lookup.label(for: $0) ?? "" } ?? ""
        if selection.isEmpty {
            return id
        }
        return "\(selection) (\(id))"
    }

    /// Wrap a throwing editor mutation so failures surface as an error
    /// message and the lookup is refreshed afterward.
    private func apply(_ work: () throws -> Void) {
        do {
            try work()
            actionError = nil
            Task { await refreshLookup() }
        } catch {
            actionError = error.localizedDescription
        }
    }

    // MARK: - Seed / refresh / apply

    @MainActor
    private func seedFromStore() async {
        isSeeding = true
        seedError = nil
        actionError = nil
        let source = store.state.source
        let formatID = store.state.sourceFormat.formatID
        do {
            let document = try await DiagramEngine.parse(source)
            let graph = try await DiagramEngine.layout(source)
            let newEditor = DiagramEditor(
                document: document,
                preferredExportFormat: formatID,
                exportRegistry: DiagramPipeline.defaultExportRegistry
            )
            try newEditor.syncSource()
            editor = newEditor
            lookup = graph.lookup
            titleDraft = document.title ?? ""
            selectedElementID = nil
            labelDraft = ""
        } catch {
            editor = nil
            lookup = nil
            seedError = error.localizedDescription
        }
        isSeeding = false
    }

    @MainActor
    private func refreshLookup() async {
        guard let editor, let source = editor.source else { return }
        do {
            let graph = try await DiagramEngine.layout(source)
            lookup = graph.lookup
            titleDraft = editor.document.title ?? ""
            // If the previously selected element no longer exists, clear.
            if let id = selectedElementID,
               lookup?.selection(for: id) == nil {
                selectedElementID = nil
                labelDraft = ""
            } else if let selection = editor.selection {
                labelDraft = lookup?.label(for: selection) ?? labelDraft
            }
        } catch {
            // Layout can fail on an intermediate state; surface but keep the editor alive.
            actionError = "Re-layout failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func applyToStore() {
        guard let source = editor?.source else { return }
        store.setSource(source, origin: .system)
        isPresented = false
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

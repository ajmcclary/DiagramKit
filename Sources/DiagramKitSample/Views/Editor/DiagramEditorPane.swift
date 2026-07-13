//
//  DiagramEditorPane.swift
//  DiagramPlayground
//
//  Floating Inspector drawer that hosts DiagramKitInteractive's
//  DiagramEditor. Renders disabled banners when the document is missing
//  or non-flowchart.
//

import SwiftUI
import DiagramKit
import DiagramKitInteractive
import DiagramKitModel
import DesignKitThemes

struct DiagramEditorPane: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                content
                    .padding(DSTokens.Spacing.lg)
            }
        }
        .frame(minWidth: 320, idealWidth: 360)
        .background(environment.theme.colors.panelBackground.color)
        .overlay(
            RoundedRectangle(cornerRadius: DSTokens.Radius.md)
                .stroke(
                    environment.theme.colors.borderVariant.color,
                    lineWidth: DSTokens.Stroke.hairline
                )
        )
    }

    private var header: some View {
        HStack(spacing: DSTokens.Spacing.sm) {
            Text("Inspector")
                .dsFont(.headline)
                .foregroundStyle(environment.theme.colors.textPrimary.color)
            Spacer(minLength: 0)
            DSIconButton(.close, label: "Close inspector") {
                store.toggleInspector()
            }
            // Cmd-I lives on the toolbar button (Task 24) — keep this button
            // shortcut-free to avoid duplicate shortcut warnings.
            .a11y(label: "Close inspector", id: A11yID.Editor.titleClose)
        }
        .padding(DSTokens.Spacing.md)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: DSTokens.Spacing.md) {
            if let metadata = store.loadedCorpusMetadata {
                CorpusMetadataBanner(metadata: metadata, store: store)
            }
            primaryContent
        }
    }

    @ViewBuilder
    private var primaryContent: some View {
        if store.editor == nil {
            disabledBanner(
                icon: .code,
                message: "Parse the source to enable interactive editing."
            )
        } else if let editor = store.editor, editor.document.type != .flowchart {
            disabledBanner(
                icon: .warning,
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
                    DSStatusIndicator(.error, label: message)
                }
                if !editor.lastExportDiagnostics.isEmpty {
                    ForEach(editor.lastExportDiagnostics.indices, id: \.self) { idx in
                        let d = editor.lastExportDiagnostics[idx]
                        DSStatusIndicator(
                            d.severity == .unsupported ? .unsupported : .warning,
                            label: d.message
                        )
                    }
                }
            }
        }
    }

    private func disabledBanner(icon: DSIcon, message: String) -> some View {
        VStack(spacing: DSTokens.Spacing.sm) {
            DSIconView(icon, size: DSTokens.Icon.md, colorRole: .muted)
            Text(message)
                .dsFont(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
        }
        .padding(DSTokens.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Title section

private struct TitleSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor
    @Environment(\.dsEnvironment) private var environment

    @SwiftUI.State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader("Document title")
            HStack(spacing: 6) {
                TextField("Untitled", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .dsFont(.caption)
                Button("Set") {
                    Task { try? await store.performMutation(.setTitle(draft.isEmpty ? nil : draft)) }
                }
                .buttonStyle(.ds(role: .primary, size: .compact))
                .disabled(editor.isExporting)
                .a11yIdentifier(A11yID.Editor.titleSet)
                Button("Clear") {
                    Task { try? await store.performMutation(.setTitle(nil)) }
                }
                .buttonStyle(.ds(role: .ghost, size: .compact))
                .disabled(editor.isExporting || editor.document.title == nil)
                .a11yIdentifier(A11yID.Editor.titleClear)
            }
            Text("Currently: \(editor.document.title ?? "—")")
                .dsFont(.caption2)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
        }
        .onAppear {
            draft = editor.document.title ?? ""
        }
        .onChange(of: editor.document.title) { _, newValue in
            draft = newValue ?? ""
        }
    }
}

// MARK: - Selection section

private struct SelectionSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader("Selection")
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
                .a11yIdentifier(A11yID.Editor.selectionPicker)
            } else {
                Text("No selectable elements in this diagram.")
                    .dsFont(.caption2)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
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

private struct LabelSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    @SwiftUI.State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DSSectionHeader("Label")
            HStack(spacing: 6) {
                TextField("Label…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .dsFont(.caption)
                Button("Rename") {
                    guard let selection = editor.selection else { return }
                    Task { try? await store.performMutation(.setLabel(of: selection, to: draft)) }
                }
                .buttonStyle(.ds(role: .primary, size: .compact))
                .disabled(editor.selection == nil || editor.isExporting)
                .a11yIdentifier(A11yID.Editor.labelRename)
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
            DSSectionHeader("Insert node")
            HStack(spacing: 6) {
                TextField("ID (e.g. n3)", text: $idDraft)
                    .textFieldStyle(.roundedBorder)
                    .dsFont(.caption)
                    .frame(maxWidth: 80)
                TextField("Label", text: $labelDraft)
                    .textFieldStyle(.roundedBorder)
                    .dsFont(.caption)
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
                .a11yIdentifier(A11yID.Editor.insertNodeShapePicker)
                Spacer(minLength: 0)
                Button("Insert") {
                    insert()
                }
                .buttonStyle(.ds(role: .primary, size: .compact))
                .disabled(labelDraft.trimmingCharacters(in: .whitespaces).isEmpty || editor.isExporting)
                .a11yIdentifier(A11yID.Editor.insertNodeButton)
            }
        }
    }

    private func insert() {
        let id = idDraft.trimmingCharacters(in: .whitespaces).isEmpty
            ? Self.nextDefaultID(existing: store.boundsLookup?.allElementIDs ?? [])
            : idDraft
        Task {
            do {
                try await store.performFlowchartMutation(.insertNode(id: id, label: labelDraft, type: shape.rawValue))
                idDraft = ""
                labelDraft = ""
            } catch {
                // Error already surfaced via `store.lastMutationError`.
            }
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
            DSSectionHeader("Insert edge")
            HStack(spacing: 6) {
                fromPicker
                DSIconView(.disclosureRight, size: DSTokens.Icon.micro, colorRole: .muted)
                toPicker
            }
            HStack(spacing: 6) {
                TextField("Label (optional)", text: $labelDraft)
                    .textFieldStyle(.roundedBorder)
                    .dsFont(.caption)
                TextField("Edge ID (optional)", text: $idDraft)
                    .textFieldStyle(.roundedBorder)
                    .dsFont(.caption)
                    .frame(maxWidth: 100)
                Button("Insert") {
                    insert()
                }
                .buttonStyle(.ds(role: .primary, size: .compact))
                .disabled(fromID == nil || toID == nil || editor.isExporting)
                .a11yIdentifier(A11yID.Editor.insertEdgeButton)
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
        .a11yIdentifier(A11yID.Editor.insertEdgeFromPicker)
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
        .a11yIdentifier(A11yID.Editor.insertEdgeToPicker)
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
        Task {
            do {
                try await store.performFlowchartMutation(.insertEdge(id: id, from: fromSel, to: toSel, label: label))
                labelDraft = ""
                idDraft = ""
                self.fromID = nil
                self.toID = nil
            } catch {
                // Error already surfaced via `store.lastMutationError`.
            }
        }
    }
}

// MARK: - Delete section

private struct DeleteSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    var body: some View {
        HStack {
            Button("Delete selected", role: .destructive) {
                guard let selection = editor.selection else { return }
                Task { try? await store.performMutation(.deleteElement(selection)) }
            }
            .buttonStyle(.ds(role: .destructive, size: .compact))
            .disabled(editor.selection == nil || editor.isExporting)
            .a11yIdentifier(A11yID.Editor.deleteSelected)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Undo / redo footer

private struct UndoRedoFooter: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.undoStructural()
            } label: {
                Text("Undo")
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
            .disabled(!(store.editor?.canUndo ?? false))
            .a11yToggle(
                label: "Undo",
                isOn: store.editor?.canUndo ?? false,
                hint: LocalizedStringKey(store.editor?.undoActionName ?? ""),
                id: A11yID.Editor.undo
            )

            Button {
                store.redoStructural()
            } label: {
                Text("Redo")
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
            .disabled(!(store.editor?.canRedo ?? false))
            .a11yToggle(
                label: "Redo",
                isOn: store.editor?.canRedo ?? false,
                hint: LocalizedStringKey(store.editor?.redoActionName ?? ""),
                id: A11yID.Editor.redo
            )

            Spacer(minLength: 0)

            if let actionName = store.editor?.undoActionName, !actionName.isEmpty {
                Text("Last: \(actionName)")
                    .dsFont(.caption2)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
            }
        }
    }
}

// MARK: - CorpusMetadataBanner

private struct CorpusMetadataBanner: View {
    let metadata: CorpusMetadata
    let store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let note = metadata.unsupportedNote, !note.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    DSIconView(.remove, size: DSTokens.Icon.micro, colorRole: .muted)
                    Text(note)
                        .dsFont(.caption2)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let diagnostics = metadata.expectedDiagnostics, !diagnostics.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    DSIconView(.diagnostics, size: DSTokens.Icon.micro, colorRole: .info)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Expected diagnostics from corpus (\(diagnostics.count)):")
                            .dsFont(.badge)
                            .foregroundStyle(environment.theme.colors.accent.color)
                        ForEach(diagnostics.indices, id: \.self) { idx in
                            let d = diagnostics[idx]
                            Text("• \(d.severity)\(d.messageContains.map { ": \($0)" } ?? "")")
                                .dsFont(.caption2)
                                .foregroundStyle(environment.theme.colors.textSecondary.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DSTokens.Radius.sm)
                .fill(environment.theme.colors.accent.color.opacity(DSTokens.Opacity.mist))
        )
    }
}

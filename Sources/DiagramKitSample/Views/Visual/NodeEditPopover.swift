//
//  NodeEditPopover.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.5 — node label / shape / style editor presented
//  when state.visualStage == .labelEdited. Commit fires
//  DiagramMutation.setLabel; the delete button fires
//  DiagramMutation.deleteElement.
//

import SwiftUI
import DiagramKitInteractive
import DiagramKitModel

struct NodeEditPopover: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var labelDraft: String = ""
    @SwiftUI.State private var subLabelDraft: String = ""
    @SwiftUI.State private var shape: ShapeChoice = .rectangle
    @SwiftUI.State private var styleChip: StyleChip = .default

    enum ShapeChoice: String, CaseIterable, Identifiable {
        case rectangle, rounded, diamond, subroutine
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var sfSymbol: String {
            switch self {
            case .rectangle:  return "rectangle"
            case .rounded:    return "rectangle.roundedtop"
            case .diamond:    return "diamond"
            case .subroutine: return "rectangle.split.3x1"
            }
        }
    }

    enum StyleChip: String, CaseIterable, Identifiable {
        case `default`, ok, warn, err, muted
        var id: String { rawValue }
        var label: String { rawValue }
        var color: Color {
            switch self {
            case .default: return .gray
            case .ok:      return .green
            case .warn:    return .orange
            case .err:     return .red
            case .muted:   return .secondary
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Edit node")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let selection = store.editor?.selection {
                    Text(selection.elementID)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Label", text: $labelDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            TextField("Sub-label (optional)", text: $subLabelDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Picker("Shape", selection: $shape) {
                ForEach(ShapeChoice.allCases) { choice in
                    Label(choice.label, systemImage: choice.sfSymbol).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 4) {
                ForEach(StyleChip.allCases) { chip in
                    Button {
                        styleChip = chip
                    } label: {
                        Text(chip.label)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(
                                    styleChip == chip ? chip.color.opacity(0.25) : Color.gray.opacity(0.12)
                                )
                            )
                            .foregroundStyle(styleChip == chip ? chip.color : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button(role: .destructive, action: deleteSelected) {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                Spacer()
                Button("Cancel") {
                    store.setVisualStage(.nodeSelected)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                Button("Commit") {
                    commit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(labelDraft.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .accessibilityIdentifier(A11yID.Visual.nodePopover)
        .onAppear {
            seedDraftFromSelection()
        }
    }

    private func seedDraftFromSelection() {
        guard let selection = store.editor?.selection,
              let label = store.boundsLookup?.label(for: selection)
        else { return }
        labelDraft = label
    }

    private func commit() {
        guard let selection = store.editor?.selection else { return }
        Task {
            try? await store.performMutation(
                .setLabel(of: selection, to: labelDraft)
            )
        }
        store.setVisualStage(.nodeSelected)
    }

    private func deleteSelected() {
        guard let selection = store.editor?.selection else { return }
        Task {
            try? await store.performMutation(.deleteElement(selection))
        }
        store.setVisualStage(.idle)
    }
}

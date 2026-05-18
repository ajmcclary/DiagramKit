//
//  DiagnosticExplainPopover.swift
//  DiagramPlayground
//
//  Phase 6 / Task 6.2 — floating card explaining one diagnostic row.
//  Title + category chip + rationale + action buttons.
//

import SwiftUI
import DiagramKitCommon

struct DiagnosticExplainPopover: View {
    @Bindable var store: LiveEditorStore
    let row: DrawerDiagnostic

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: severityIcon)
                    .foregroundStyle(severityColor)
                Text(headline)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                Spacer()
                Button {
                    store.dismissExplain()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            if let cat = row.category {
                HStack(spacing: 6) {
                    Text(cat.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.gray.opacity(0.18)))
                    Text(severityCopy(cat.severity))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(rationale)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("See `docs/diagnostic-severity-discipline.md §1` for the decision tree.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(spacing: 6) {
                Button("Rename label") { applyRenameLabel() }
                    .buttonStyle(.bordered)
                Button("Wrap with <br/>") { applyWrap() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Open in source") { jumpToSource() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .accessibilityIdentifier(A11yID.Diagnostics.explainPopover)
    }

    // MARK: - Copy

    private var headline: String {
        row.editor.message
    }

    private var rationale: String {
        guard let cat = row.category else {
            return "This diagnostic isn't paired with a typed category yet. Future phases will route it through the importer's typed factories."
        }
        switch cat.severity {
        case .warning:
            return "Lossy structural transform — the import preserved the diagram structurally but reshaped it. Round-trip is safe but identifiers, shapes, or grouping may differ."
        case .unsupported:
            return "Feature dropped — the target format doesn't model this construct. The import proceeded without it; round-trip won't reintroduce the original."
        case .info:
            return "Informational — encoding-level transform that's round-trip stable (e.g. identifier escapes, comment preservation)."
        }
    }

    private var severityIcon: String {
        switch row.editor.severity {
        case .error:   return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    private var severityColor: Color {
        switch row.editor.severity {
        case .error:   return .red
        case .warning: return .orange
        case .info:    return .blue
        }
    }

    private func severityCopy(_ severity: DiagramDiagnostic.Severity) -> String {
        switch severity {
        case .warning:     return "lossy"
        case .info:        return "info"
        case .unsupported: return "unsupported"
        }
    }

    // MARK: - Actions

    private func applyRenameLabel() {
        // Phase 3's NodeEditPopover handles label edits. Bounce visual
        // stage to .labelEdited so it surfaces.
        store.setVisualStage(.labelEdited)
        store.dismissExplain()
    }

    private func applyWrap() {
        guard let line = row.editor.line else { return }
        let lines = store.state.source.split(separator: "\n", omittingEmptySubsequences: false)
        guard line - 1 >= 0 && line - 1 < lines.count else { return }
        var copy = lines.map(String.init)
        copy[line - 1] = "<br/>" + copy[line - 1]
        store.setSource(copy.joined(separator: "\n"), origin: .system)
        store.dismissExplain()
    }

    private func jumpToSource() {
        if let line = row.editor.line {
            store.hoverEditorLine(line - 1)
        }
        store.dismissExplain()
    }
}

//
//  DiagnosticExplainPopover.swift
//  DiagramPlayground
//
//  Phase 6 / Task 6.2 — floating card explaining one diagnostic row.
//  Title + category chip + rationale + action buttons.
//

import SwiftUI
import DiagramKitCommon
import DesignKitThemes

struct DiagnosticExplainPopover: View {
    @Bindable var store: LiveEditorStore
    let row: DrawerDiagnostic
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        DSSurface(role: .popover) {
            VStack(alignment: .leading, spacing: DSTokens.Spacing.smMd) {
            HStack(spacing: DSTokens.Spacing.sm) {
                DSIconView(
                    row.editor.severity.dsIcon,
                    colorRole: row.editor.severity.dsIconColorRole
                )
                Text(headline)
                    .dsFont(.headline)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                    .lineLimit(2)
                Spacer()
                DSIconButton(.close, label: "Close explanation") {
                    store.dismissExplain()
                }
                .keyboardShortcut(.cancelAction)
            }

            if let cat = row.category {
                HStack(spacing: DSTokens.Spacing.xs) {
                    DSCodeBadge(cat.rawValue)
                    Text(severityCopy(cat.severity))
                        .dsFont(.badge)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                }
            }

            Text(rationale)
                .dsFont(.caption2)
                .foregroundStyle(environment.theme.colors.textPrimary.color)
                .fixedSize(horizontal: false, vertical: true)

            Text("See `docs/diagnostic-severity-discipline.md §1` for the decision tree.")
                .dsFont(.caption2)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(environment.theme.colors.borderVariant.color)
                .frame(height: DSTokens.Stroke.hairline)

            HStack(spacing: DSTokens.Spacing.xs) {
                Button("Rename label") { applyRenameLabel() }
                    .buttonStyle(.ds(role: .secondary, size: .compact))
                Button("Wrap with <br/>") { applyWrap() }
                    .buttonStyle(.ds(role: .secondary, size: .compact))
                Spacer()
                Button("Open in source") { jumpToSource() }
                    .buttonStyle(.ds(role: .primary, size: .compact))
            }
            }
            .padding(DSTokens.Spacing.lg)
        }
        .frame(width: 340)
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

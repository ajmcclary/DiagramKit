//
//  QuickFixCard.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.5 — small floating card surfacing
//  store.diagnostics filtered by the currently hovered editor line.
//  Shipping a slim set of well-bounded actions: focus the label
//  popover, insert a `<br/>` at the hovered line for wrapping, and
//  open the inspector's diagnostics section for the rest.
//

import SwiftUI
import DesignKitThemes

struct QuickFixCard: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    var body: some View {
        if let line = store.state.biSelLine,
           let diagnostic = matching(line: line) {
            DSSurface(role: .popover) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                HStack(spacing: Tokens.Spacing.xs) {
                    DSIconView(.success, size: Tokens.Size.Icon.xs, colorRole: .info)
                    Text("Quick fix")
                        .dsFont(.headline)
                    Spacer()
                    Text("line \(line + 1)")
                        .dsFont(.metric)
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
                Text(diagnostic.message)
                    .dsFont(.caption2)
                    .foregroundStyle(theme.colors.textPrimary.color)
                    .lineLimit(3)
                HStack(spacing: Tokens.Spacing.xs) {
                    Button("Rename label") {
                        store.setVisualStage(.labelEdited)
                    }
                    .buttonStyle(.ds(role: .secondary, size: .compact))
                    Button("Wrap text") {
                        wrapTextAtCurrentLine(line)
                    }
                    .buttonStyle(.ds(role: .secondary, size: .compact))
                }
            }
            .padding(Tokens.Spacing.md)
            }
            .frame(width: 280)
            .accessibilityIdentifier(A11yID.Visual.quickFixCard)
        }
    }

    private func matching(line: Int) -> EditorDiagnostic? {
        store.diagnostics.first(where: { $0.line == line })
            ?? store.diagnostics.first
    }

    /// Insert a `<br/>` at the start of the hovered line. Mirrors the
    /// JSX "wrap text" quick-fix without dragging in a markdown
    /// rewriter: cheap and reversible by undo.
    private func wrapTextAtCurrentLine(_ line: Int) {
        let lines = store.state.source.split(separator: "\n", omittingEmptySubsequences: false)
        guard line >= 0 && line < lines.count else { return }
        var copy = lines.map(String.init)
        copy[line] = "<br/>" + copy[line]
        store.setSource(copy.joined(separator: "\n"), origin: .system)
    }
}

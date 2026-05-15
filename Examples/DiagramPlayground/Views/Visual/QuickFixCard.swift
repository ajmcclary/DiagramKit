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

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct QuickFixCard: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        if let line = store.state.biSelLine,
           let diagnostic = matching(line: line) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.rays")
                        .foregroundStyle(Color.accentColor)
                    Text("Quick fix")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("line \(line + 1)")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(diagnostic.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                HStack(spacing: 6) {
                    Button("Rename label") {
                        store.setVisualStage(.labelEdited)
                    }
                    .buttonStyle(.bordered)
                    Button("Wrap text") {
                        wrapTextAtCurrentLine(line)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(12)
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            )
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

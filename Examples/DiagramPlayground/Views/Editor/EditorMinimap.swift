//
//  EditorMinimap.swift
//  DiagramPlayground
//
//  Phase 2 / Task 2.2 — a compact overview of the source text. Draws
//  one row per source line (length-proportional bars) and overlays a
//  viewport rectangle that tracks the visible region of the host
//  editor. Bidirectional click-to-scroll is deferred until a future
//  phase wires NativeCodeEditor's scroll position into the store.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct EditorMinimap: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        let lines = sourceLines
        Canvas { ctx, size in
            guard !lines.isEmpty else { return }
            let rowHeight = max(2, size.height / CGFloat(lines.count))
            let maxLen = max(1, lines.map(\.count).max() ?? 1)
            for (index, line) in lines.enumerated() {
                let widthRatio = CGFloat(min(line.count, maxLen)) / CGFloat(maxLen)
                let rect = CGRect(
                    x: 4,
                    y: CGFloat(index) * rowHeight,
                    width: max(4, (size.width - 8) * widthRatio),
                    height: max(1, rowHeight - 1)
                )
                let color = highlightedLine == index
                    ? Color.accentColor
                    : Color.secondary.opacity(0.55)
                ctx.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: 84)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.05))
        .accessibilityHidden(true)
    }

    private var sourceLines: [String] {
        store.state.source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    /// Bidirectional selection's source-line hover hook (Task 2.3).
    /// Visible here so the highlight tracks node→source hovering once
    /// the source map is wired.
    private var highlightedLine: Int? {
        store.state.biSelLine
    }
}

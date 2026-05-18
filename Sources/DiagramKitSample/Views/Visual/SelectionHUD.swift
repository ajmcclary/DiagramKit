//
//  SelectionHUD.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.2 — top-right accent pill summarising the current
//  selection. Shows `node:A`, `edge:G→H`, or `marquee × N`.
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct SelectionHUD: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        if let label = summary {
            HStack(spacing: 5) {
                Image(systemName: "selection.pin.in.out")
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.accentColor.opacity(0.18)))
            .foregroundStyle(Color.accentColor)
            .accessibilityIdentifier(A11yID.Visual.selectionHUD)
            .accessibilityLabel("Selection: \(label)")
        }
    }

    private var summary: String? {
        if !store.state.marqueeSelection.isEmpty {
            return "marquee × \(store.state.marqueeSelection.count)"
        }
        if let selection = store.editor?.selection {
            return "\(selection.diagramType.rawValue):\(selection.elementID)"
        }
        return nil
    }
}

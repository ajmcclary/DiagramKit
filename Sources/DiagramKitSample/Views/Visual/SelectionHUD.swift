//
//  SelectionHUD.swift
//  DiagramPlayground
//
//  Phase 3 / Task 3.2 — top-right accent pill summarising the current
//  selection. Shows `node:A`, `edge:G→H`, or `marquee × N`.
//

import SwiftUI
import DesignKitThemes

struct SelectionHUD: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        if let label = summary {
            DSGlassSurface(role: .popover) {
            HStack(spacing: Tokens.Spacing.xxs) {
                DSIconView(.node, size: Tokens.Size.Icon.micro, colorRole: .info)
                Text(label)
                    .dsFont(.badge)
            }
            .padding(.horizontal, Tokens.Spacing.smMd)
            .padding(.vertical, Tokens.Spacing.xxs)
            }
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

//
//  PlatformRow.swift
//  DiagramPlayground
//
//  Phase 10 / Task 10.3 — Inspector row reporting the active
//  document's Linux parity. Green dot + "✓ full parity" by default;
//  amber dot + "⚠ approximate · char-count fallback" for the three
//  CoreText-bound families (ishikawa / treeView / eventModeling).
//

import SwiftUI
import DiagramKitModel
import DesignKitThemes

struct PlatformRow: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    var body: some View {
        InspectorSectionHeader(title: "Platform parity", systemImage: "laptopcomputer")
            .padding(.bottom, 4)
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
            HStack(spacing: Tokens.Spacing.xs) {
                DSStatusIndicator(
                    isApproximate ? .warning : .success,
                    label: isApproximate ? "Approximate parity" : "Full parity"
                )
                Text(isApproximate ? "approximate · char-count fallback" : "full parity")
                    .dsFont(.badge)
                Spacer()
            }
            HStack(spacing: Tokens.Spacing.xxs) {
                DSIconView(.code, size: Tokens.Size.Icon.indicator, colorRole: .muted)
                Text("Sources/DiagramKitCommon/src_text_metrics.swift")
                    .dsFont(.code)
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .textSelection(.enabled)
            }
            if isApproximate {
                Text("\(currentFamily?.rawValue ?? "this family") falls back to char-count text width on Linux per CLAUDE.md; geometry is valid but not pixel-equivalent to Apple's CoreText measurement.")
                    .dsFont(.caption2)
                    .foregroundStyle(theme.colors.textSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Tokens.Spacing.sm)
        .background { DSSurface(role: .card) { Color.clear } }
        .accessibilityIdentifier("inspector.platformRow")
        .accessibilityElement(children: .contain)
    }

    private var currentFamily: DiagramType? {
        store.editor?.document.type
    }

    private var isApproximate: Bool {
        guard let family = currentFamily else { return false }
        switch family {
        case .ishikawa, .treeView, .eventModeling: return true
        default:                                   return false
        }
    }
}

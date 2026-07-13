//
//  RenderFailedSheet.swift
//  DiagramPlayground
//
//  Phase 10 / Task 10.4 — bottom-sheet popover surfaced
//  automatically when store.renderStatus == .failed. Shows the
//  typed error + a "↻ Run on worker · 8 MB stack" retry that
//  re-issues the render. The DiagramEngine worker thread is
//  already canonical, so the button simply re-arms a render.
//

import SwiftUI
import DesignKitThemes

struct RenderFailedSheet: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.designTheme) private var theme

    var body: some View {
        DSGlassSurface(role: .popover) {
        VStack(alignment: .leading, spacing: Tokens.Spacing.smMd) {
            HStack(spacing: Tokens.Spacing.xs) {
                DSIconView(.error, colorRole: .error)
                Text("Render failed")
                    .dsFont(.headline)
                Spacer()
            }
            Text(message)
                .dsFont(.code)
                .foregroundStyle(theme.colors.textPrimary.color)
                .padding(Tokens.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM, style: .continuous)
                        .fill(theme.colors.error.color.opacity(Tokens.Opacity.tint))
                )
            Text("Worker contract: every render runs on a fresh 8 MB-stack Thread per CLAUDE.md. Retrying re-arms the same canonical path.")
                .dsFont(.caption2)
                .foregroundStyle(theme.colors.textSecondary.color)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button {
                    store.requestRender(reason: .manual)
                } label: {
                    Label("Run on worker · 8 MB stack", systemImage: "arrow.clockwise")
                        .dsFont(.badge)
                }
                .buttonStyle(.ds(role: .primary, size: .compact))
                .a11y(label: "Retry render", id: "renderFailed.retry")
            }
        }
        .padding(Tokens.Spacing.lg)
        }
        .frame(width: 380)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("renderFailed.sheet")
    }

    private var message: String {
        if let error = store.parseError {
            return error.localizedDescription
        }
        return "Render failed (no error message available)"
    }
}

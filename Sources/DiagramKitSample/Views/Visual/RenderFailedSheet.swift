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

struct RenderFailedSheet: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                Text("Render failed")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            Text(message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.red.opacity(0.10))
                )
            Text("Worker contract: every render runs on a fresh 8 MB-stack Thread per CLAUDE.md. Retrying re-arms the same canonical path.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button {
                    store.requestRender(reason: .manual)
                } label: {
                    Label("Run on worker · 8 MB stack", systemImage: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .a11y(label: "Retry render", id: "renderFailed.retry")
            }
        }
        .padding(14)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
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

//
//  PreviewToolbar.swift
//  MermaidPlayground
//
//  Floating toolbar for preview controls: zoom in/out, fit-to-view,
//  reset, and percentage readout.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct PreviewToolbar: View {
    let theme: DiagramTheme
    @Binding var zoomScale: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let onFitToView: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            zoomOutButton
            divider
            percentageLabel
            divider
            zoomInButton
            divider
            fitButton
        }
        .font(.system(size: 13))
        .foregroundColor(Color(theme.foreground))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(theme.background).opacity(0.85))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Buttons

    private var zoomOutButton: some View {
        Button {
            zoomScale = max(zoomScale / 1.25, minZoom)
        } label: {
            Image(systemName: "minus")
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(zoomScale <= minZoom)
        .opacity(zoomScale <= minZoom ? 0.4 : 1.0)
    }

    private var zoomInButton: some View {
        Button {
            zoomScale = min(zoomScale * 1.25, maxZoom)
        } label: {
            Image(systemName: "plus")
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(zoomScale >= maxZoom)
        .opacity(zoomScale >= maxZoom ? 0.4 : 1.0)
    }

    private var fitButton: some View {
        Button(action: onFitToView) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    private var percentageLabel: some View {
        Text("\(Int(round(zoomScale * 100)))%")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .frame(width: 44)
    }

    private var divider: some View {
        Divider()
            .frame(height: 18)
    }
}

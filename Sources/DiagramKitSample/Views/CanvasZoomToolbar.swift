//
//  CanvasZoomToolbar.swift
//  DiagramPlayground
//
//  Floating zoom control cluster shared by the preview canvas and the
//  visual editor canvases: fit, zoom in/out, percent readout, actual size,
//  and (preview only) pan/grid toggles + full-window.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

struct CanvasZoomToolbar: View {
    let theme: DiagramTheme
    @Binding var zoomScale: CGFloat
    @Binding var gridEnabled: Bool
    @Binding var panZoomEnabled: Bool
    let isAtAutomaticFit: Bool
    let minZoom: CGFloat
    let maxZoom: CGFloat
    let onFitToView: () -> Void
    let onActualSize: () -> Void
    let onFullWindowPreview: (() -> Void)?
    /// When false, the grid toggle is omitted (visual editor has no grid).
    var showsGrid: Bool = true

    var body: some View {
        HStack(spacing: 2) {
            fitButton
            divider
            zoomOutButton
            zoomLabel
            zoomInButton
            divider
            actualSizeButton
            divider
            panZoomToggleButton
            if showsGrid {
                gridToggleButton
            }
            if onFullWindowPreview != nil {
                divider
                fullWindowButton
            }
        }
        .font(.system(size: 13))
        .foregroundColor(Color(theme.foreground))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(theme.effectiveLine()).opacity(0.2), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
    }

    // MARK: - Buttons

    private var fitButton: some View {
        Button(action: onFitToView) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .medium))
                Text("Fit")
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isAtAutomaticFit
                        ? Color(theme.effectiveAccent()).opacity(0.15)
                        : Color.clear)
            )
            .foregroundColor(isAtAutomaticFit
                ? Color(theme.effectiveAccent())
                : Color(theme.foreground))
        }
        .buttonStyle(.plain)
        .help("Fit diagram to view")
        .keyboardShortcut("0", modifiers: .command)
        .a11yIdentifier(A11yID.Preview.fit)
    }

    private var zoomOutButton: some View {
        Button {
            zoomScale = max(zoomScale / 1.25, minZoom)
        } label: {
            Image(systemName: "minus")
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .disabled(!panZoomEnabled || zoomScale <= minZoom)
        .opacity(!panZoomEnabled || zoomScale <= minZoom ? 0.35 : 1.0)
        .help("Zoom out")
        .keyboardShortcut("-", modifiers: .command)
        .a11y(label: "Zoom out", id: A11yID.Preview.zoomOut)
    }

    private var zoomInButton: some View {
        Button {
            zoomScale = min(zoomScale * 1.25, maxZoom)
        } label: {
            Image(systemName: "plus")
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .disabled(!panZoomEnabled || zoomScale >= maxZoom)
        .opacity(!panZoomEnabled || zoomScale >= maxZoom ? 0.35 : 1.0)
        .help("Zoom in")
        .keyboardShortcut("=", modifiers: .command)
        .a11y(label: "Zoom in", id: A11yID.Preview.zoomIn)
    }

    private var actualSizeButton: some View {
        Button(action: onActualSize) {
            Text("1:1")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .frame(width: 28, height: 26)
        }
        .buttonStyle(.plain)
        .help("Actual size (100%)")
        .keyboardShortcut("1", modifiers: .command)
        .a11yIdentifier(A11yID.Preview.actualSize)
    }

    private var panZoomToggleButton: some View {
        Button {
            panZoomEnabled.toggle()
        } label: {
            Image(systemName: panZoomEnabled ? "hand.draw.fill" : "hand.draw")
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .foregroundColor(panZoomEnabled
            ? Color(theme.effectiveAccent())
            : Color(theme.foreground))
        .help(panZoomEnabled ? "Disable pan and zoom" : "Enable pan and zoom")
        .a11yToggle(
            label: "Pan and zoom",
            isOn: panZoomEnabled,
            hint: "Allows dragging and pinch-to-zoom on the preview",
            id: A11yID.Preview.panZoomToggle
        )
    }

    private var gridToggleButton: some View {
        Button {
            gridEnabled.toggle()
        } label: {
            Image(systemName: "grid")
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .foregroundColor(gridEnabled
            ? Color(theme.effectiveAccent())
            : Color(theme.foreground))
        .help(gridEnabled ? "Hide grid" : "Show grid")
        .a11yToggle(
            label: "Grid overlay",
            isOn: gridEnabled,
            hint: "Shows a reference grid behind the diagram",
            id: A11yID.Preview.gridToggle
        )
    }

    private var fullWindowButton: some View {
        Button(action: { onFullWindowPreview?() }) {
            Image(systemName: "rectangle.inset.filled")
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help("Full-window preview")
        .a11y(label: "Full-window preview", id: A11yID.Preview.fullWindow)
    }

    private var zoomLabel: some View {
        Text(isAtAutomaticFit ? "Fit" : "\(Int(round(zoomScale * 100)))%")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(isAtAutomaticFit
                ? Color(theme.effectiveMuted())
                : Color(theme.foreground))
            .frame(width: 42)
    }

    private var divider: some View {
        Divider()
            .frame(height: 16)
            .opacity(0.6)
    }
}

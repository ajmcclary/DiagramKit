//
//  CanvasZoomToolbar.swift
//  DiagramPlayground
//
//  Floating zoom control cluster shared by the preview canvas and the
//  visual editor canvases: fit, zoom in/out, percent readout, actual size,
//  and (preview only) pan/grid toggles + full-window.
//

import SwiftUI
import DesignKitThemes

struct CanvasZoomToolbar: View {
    @Environment(\.designTheme) private var theme
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
        DSGlassSurface(role: .popover) {
            HStack(spacing: Tokens.Shape.strokeMedium) {
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
            .padding(.horizontal, Tokens.Spacing.xs)
            .padding(.vertical, Tokens.Spacing.xxs)
        }
    }

    // MARK: - Buttons

    private var fitButton: some View {
        Button(action: onFitToView) {
            Text("Fit")
                .dsFont(.badge)
        }
        .buttonStyle(.ds(role: isAtAutomaticFit ? .secondary : .ghost, size: .compact))
        .help("Fit diagram to view")
        .keyboardShortcut("0", modifiers: .command)
        .a11yIdentifier(A11yID.Preview.fit)
    }

    private var zoomOutButton: some View {
        Button {
            zoomScale = max(zoomScale / 1.25, minZoom)
        } label: {
            DSIconView(.remove, size: Tokens.Size.Icon.micro)
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .disabled(!panZoomEnabled || zoomScale <= minZoom)
        .help("Zoom out")
        .keyboardShortcut("-", modifiers: .command)
        .a11y(label: "Zoom out", id: A11yID.Preview.zoomOut)
    }

    private var zoomInButton: some View {
        Button {
            zoomScale = min(zoomScale * 1.25, maxZoom)
        } label: {
            DSIconView(.add, size: Tokens.Size.Icon.micro)
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .disabled(!panZoomEnabled || zoomScale >= maxZoom)
        .help("Zoom in")
        .keyboardShortcut("=", modifiers: .command)
        .a11y(label: "Zoom in", id: A11yID.Preview.zoomIn)
    }

    private var actualSizeButton: some View {
        Button(action: onActualSize) {
            Text("1:1")
                .dsFont(.metric)
                .fixedSize()
                .frame(minWidth: Tokens.Size.Control.chip)
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .help("Actual size (100%)")
        .keyboardShortcut("1", modifiers: .command)
        .a11yIdentifier(A11yID.Preview.actualSize)
    }

    private var panZoomToggleButton: some View {
        Button {
            panZoomEnabled.toggle()
        } label: {
            DSIconView(.panZoom, size: Tokens.Size.Icon.micro)
        }
        .buttonStyle(.ds(role: panZoomEnabled ? .secondary : .ghost, size: .compact))
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
            DSIconView(.grid, size: Tokens.Size.Icon.micro)
        }
        .buttonStyle(.ds(role: gridEnabled ? .secondary : .ghost, size: .compact))
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
            DSIconView(.expand, size: Tokens.Size.Icon.micro)
        }
        .buttonStyle(.ds(role: .ghost, size: .compact))
        .help("Full-window preview")
        .a11y(label: "Full-window preview", id: A11yID.Preview.fullWindow)
    }

    private var zoomLabel: some View {
        Text("\(Int(round(zoomScale * 100)))%")
            .dsFont(.metric)
            .foregroundStyle(
                isAtAutomaticFit
                    ? theme.colors.textSecondary.color
                    : theme.colors.textPrimary.color
            )
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: 42)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.colors.borderVariant.color)
            .frame(width: Tokens.Shape.strokeHairline, height: Tokens.Spacing.lg)
            .accessibilityHidden(true)
    }
}

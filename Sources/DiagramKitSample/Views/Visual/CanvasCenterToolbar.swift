//
//  CanvasCenterToolbar.swift
//  DiagramPlayground
//
//  Floating bottom-center toolbar for the visual canvas. Plan 2
//  ships the Shapes catalog button; Subgraph / Icon / Image /
//  Rearrange / Theme buttons land with visual-editor plans 3–6.
//

import SwiftUI
import DesignKitThemes

struct CanvasCenterToolbar: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    @SwiftUI.State private var showShapeCatalog = false
    @SwiftUI.State private var showIconBrowser = false
    @SwiftUI.State private var showRearrange = false
    @SwiftUI.State private var showThemePicker = false

    var body: some View {
        DSGlassSurface(role: .toolbar) {
        HStack(spacing: DSTokens.Spacing.xxs) {
            Button {
                showShapeCatalog.toggle()
            } label: {
                Label("Shapes", systemImage: "square.on.circle")
                    .dsFont(.badge)
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
            .help("Browse and add shapes")
            .accessibilityIdentifier(A11yID.Visual.shapesButton)
            .popover(isPresented: $showShapeCatalog, arrowEdge: .top) {
                ShapeCatalogView(theme: store.previewTheme) { alias in
                    showShapeCatalog = false
                    Task { await store.insertShapeFromCatalog(alias: alias) }
                }
            }

            Button {
                store.openEmptySubgraphPrompt()
            } label: {
                Label("Subgraph", systemImage: "rectangle.3.group")
                    .dsFont(.badge)
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
            .help("Add a labeled group to the canvas")
            .accessibilityIdentifier(A11yID.Visual.subgraphButton)

            Button {
                showIconBrowser.toggle()
            } label: {
                Label("Icon", systemImage: "star.circle")
                    .dsFont(.badge)
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
            .help("Search and add an icon node")
            .accessibilityIdentifier(A11yID.Visual.iconButton)
            .popover(isPresented: $showIconBrowser, arrowEdge: .top) {
                IconBrowserView { faName in
                    showIconBrowser = false
                    Task { await store.insertIconFromBrowser(faName: faName) }
                }
            }

            Button {
                store.openImageSheet()
            } label: {
                Label("Image", systemImage: "photo")
                    .dsFont(.badge)
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
            .help("Add an image node from a URL")
            .accessibilityIdentifier(A11yID.Visual.imageButton)

            Button {
                showRearrange.toggle()
            } label: {
                Label("Rearrange", systemImage: "arrow.triangle.2.circlepath")
                    .dsFont(.badge)
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
            .help("Auto-arrange the diagram")
            .accessibilityIdentifier(A11yID.Visual.rearrangeButton)
            .popover(isPresented: $showRearrange, arrowEdge: .top) {
                RearrangePopover(store: store) { showRearrange = false }
            }

            Button {
                showThemePicker.toggle()
            } label: {
                Label("Theme", systemImage: "paintpalette")
                    .dsFont(.badge)
            }
            .buttonStyle(.ds(role: .ghost, size: .compact))
            .help("Apply a theme (saved into the source)")
            .accessibilityIdentifier(A11yID.Visual.themeButton)
            .popover(isPresented: $showThemePicker, arrowEdge: .top) {
                ThemeSwatchPicker(store: store) { showThemePicker = false }
            }
        }
        .foregroundStyle(environment.theme.colors.textSecondary.color)
        .padding(DSTokens.Spacing.xxs)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.centerToolbar)
    }
}

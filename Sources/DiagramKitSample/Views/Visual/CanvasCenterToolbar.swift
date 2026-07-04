//
//  CanvasCenterToolbar.swift
//  DiagramPlayground
//
//  Floating bottom-center toolbar for the visual canvas. Plan 2
//  ships the Shapes catalog button; Subgraph / Icon / Image /
//  Rearrange / Theme buttons land with visual-editor plans 3–6.
//

import SwiftUI

struct CanvasCenterToolbar: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.playgroundTokens) private var tokens

    @SwiftUI.State private var showShapeCatalog = false
    @SwiftUI.State private var showIconBrowser = false
    @SwiftUI.State private var showRearrange = false
    @SwiftUI.State private var showThemePicker = false

    var body: some View {
        HStack(spacing: 4) {
            Button {
                showShapeCatalog.toggle()
            } label: {
                Label("Shapes", systemImage: "square.on.circle")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
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
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Add a labeled group to the canvas")
            .accessibilityIdentifier(A11yID.Visual.subgraphButton)

            Button {
                showIconBrowser.toggle()
            } label: {
                Label("Icon", systemImage: "star.circle")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
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
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Add an image node from a URL")
            .accessibilityIdentifier(A11yID.Visual.imageButton)

            Button {
                showRearrange.toggle()
            } label: {
                Label("Rearrange", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Auto-arrange the diagram")
            .accessibilityIdentifier(A11yID.Visual.rearrangeButton)
            .popover(isPresented: $showRearrange, arrowEdge: .top) {
                RearrangePopover(store: store) { showRearrange = false }
            }

            Button {
                showThemePicker.toggle()
            } label: {
                Label("Theme", systemImage: "paintpalette")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Apply a theme (saved into the source)")
            .accessibilityIdentifier(A11yID.Visual.themeButton)
            .popover(isPresented: $showThemePicker, arrowEdge: .top) {
                ThemeSwatchPicker(store: store) { showThemePicker = false }
            }
        }
        .foregroundStyle(tokens.palette.fg2)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tokens.palette.bgChrome.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(tokens.palette.borderHairline, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.centerToolbar)
    }
}

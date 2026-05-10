//
//  PreviewCanvas.swift
//  MermaidPlayground
//
//  Preview surface that wraps MermaidViewRepresentable, manages zoom
//  state, and overlays error/dim-state on render failure.
//

import SwiftUI
import DiagramKit

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct PreviewCanvas: View {
    @Bindable var store: LiveEditorStore
    let onFullWindowPreview: (() -> Void)?

    @SwiftUI.State private var zoomScale: CGFloat = 1.0
    @SwiftUI.State private var hasSetInitialZoom: Bool = false
    @SwiftUI.State private var lastRenderGeneration: Int = 0

    private let minZoom: CGFloat = 0.25
    private let maxZoom: CGFloat = 4.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(store.theme.background)
                    .ignoresSafeArea()

                // Grid overlay
                if store.state.gridEnabled {
                    gridOverlay(size: geometry.size)
                }

                // Mermaid view at zoomed size
                let scaledWidth = max(store.diagramBounds.width * zoomScale, 1)
                let scaledHeight = max(store.diagramBounds.height * zoomScale, 1)

                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack {
                        // Scroll content sized to at least the viewport
                        Color.clear
                            .frame(
                                width: max(scaledWidth, geometry.size.width),
                                height: max(scaledHeight, geometry.size.height)
                            )

                        // MermaidView at exact zoomed diagram size, centered
                        MermaidViewRepresentable(
                            source: store.state.source,
                            theme: store.theme,
                            layoutConfig: store.layoutConfig,
                            store: store
                        )
                        .frame(width: scaledWidth, height: scaledHeight)
                    }
                }
                .defaultScrollAnchor(.center)
                .scrollBounceBehavior(.basedOnSize)
                #if targetEnvironment(macCatalyst)
                .simultaneousGesture(magnificationGesture)
                #else
                .highPriorityGesture(magnificationGesture)
                #endif
                .onChange(of: store.renderGeneration) { _, _ in
                    // Reset zoom to fit when diagram identity changes
                    if !hasSetInitialZoom || store.renderGeneration != lastRenderGeneration {
                        let fitScale = calculateFitScale(
                            diagramBounds: store.diagramBounds,
                            viewSize: geometry.size
                        )
                        zoomScale = fitScale
                        hasSetInitialZoom = true
                        lastRenderGeneration = store.renderGeneration
                    }
                }
                .onChange(of: store.diagramBounds) { _, newBounds in
                    // First-render fit
                    if !hasSetInitialZoom, newBounds.width > 0 {
                        let fitScale = calculateFitScale(
                            diagramBounds: newBounds,
                            viewSize: geometry.size
                        )
                        zoomScale = fitScale
                        hasSetInitialZoom = true
                        lastRenderGeneration = store.renderGeneration
                    }
                }

                // Dim overlay on render failure
                if store.renderStatus == .failed {
                    Rectangle()
                        .fill(Color(store.theme.background).opacity(0.35))
                        .allowsHitTesting(false)
                }

                // Error overlay
                if let error = store.parseError, store.renderStatus == .failed {
                    errorOverlay(error)
                }

                // Config warnings (Phase 3)
                if !store.configWarnings.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            configWarningsOverlay
                                .padding(12)
                            Spacer()
                        }
                    }
                }

                // Dirty indicator (manual mode)
                if store.isDirty && store.state.updateMode == .manual {
                    VStack {
                        HStack {
                            Spacer()
                            dirtyBadge
                                .padding(12)
                        }
                        Spacer()
                    }
                }

                // Empty state
                if store.renderStatus == .idle {
                    idleOverlay
                }

                // Zoom toolbar
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        PreviewToolbar(
                            theme: store.theme,
                            zoomScale: $zoomScale,
                            gridEnabled: $store.state.gridEnabled,
                            minZoom: minZoom,
                            maxZoom: maxZoom,
                            onFitToView: {
                                zoomScale = calculateFitScale(
                                    diagramBounds: store.diagramBounds,
                                    viewSize: geometry.size
                                )
                            },
                            onResetView: {
                                zoomScale = 1.0
                            },
                            onFullWindowPreview: onFullWindowPreview
                        )
                        .padding(12)
                    }
                }
            }
        }
    }

    // MARK: - Magnification gesture

    #if targetEnvironment(macCatalyst)
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = min(max(zoomScale * value, minZoom), maxZoom)
            }
    }
    #else
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = min(max(zoomScale * value, minZoom), maxZoom)
            }
    }
    #endif

    // MARK: - Fit scale

    private func calculateFitScale(diagramBounds: CGRect, viewSize: CGSize) -> CGFloat {
        guard diagramBounds.width > 0, diagramBounds.height > 0 else {
            return 1.0
        }
        let scaleX = viewSize.width / diagramBounds.width
        let scaleY = viewSize.height / diagramBounds.height
        return min(max(min(scaleX, scaleY), minZoom), maxZoom)
    }

    // MARK: - Grid overlay

    private func gridOverlay(size: CGSize) -> some View {
        Canvas { context, _ in
            let gridSpacing: CGFloat = 20
            let lineColor = Color(store.theme.effectiveLine()).opacity(0.15)

            context.stroke(
                Path { path in
                    var x: CGFloat = 0
                    while x <= size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += gridSpacing
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += gridSpacing
                    }
                },
                with: .color(lineColor),
                lineWidth: 0.5
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Dirty badge

    private var dirtyBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
            Text("Unsaved changes")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(store.theme.background).opacity(0.85))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Overlays

    private var configWarningsOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(store.configWarnings) { warning in
                HStack(spacing: 6) {
                    Image(systemName: warning.level.iconName)
                        .font(.system(size: 10))
                        .foregroundColor(warning.level.color)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(warning.keyPath)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        Text(warning.message)
                            .font(.system(size: 10))
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(store.theme.background).opacity(0.88))
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
        )
        .frame(maxWidth: 320)
    }

    private func errorOverlay(_ error: Error) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(.red)
            Text("Parse Error")
                .font(.headline)
                .foregroundColor(.red)
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(store.theme.background).opacity(0.92))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }

    private var idleOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundColor(Color(store.theme.effectiveMuted()))
            Text("Enter Mermaid syntax to preview")
                .font(.body)
                .foregroundColor(Color(store.theme.effectiveMuted()))
        }
    }
}

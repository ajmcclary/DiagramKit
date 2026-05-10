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
    let store: LiveEditorStore

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
                            minZoom: minZoom,
                            maxZoom: maxZoom,
                            onFitToView: {
                                zoomScale = calculateFitScale(
                                    diagramBounds: store.diagramBounds,
                                    viewSize: geometry.size
                                )
                            }
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

    // MARK: - Overlays

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

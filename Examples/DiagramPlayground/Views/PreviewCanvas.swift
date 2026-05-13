//
//  PreviewCanvas.swift
//  DiagramPlayground
//
//  Preview surface that wraps DiagramNativeViewRepresentable, manages zoom
//  state, and overlays error/dim-state on render failure.
//

import SwiftUI
import DiagramKit

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct PreviewCanvas: View {
    @Bindable var store: LiveEditorStore
    let onFullWindowPreview: (() -> Void)?

    @SwiftUI.State private var automaticZoomScale: CGFloat = 1.0
    @SwiftUI.State private var gestureBaseZoomScale: CGFloat?
    @SwiftUI.State private var activePanTranslation: CGSize = .zero
    @SwiftUI.State private var previewMode: PreviewMode = .diagram

    private let minZoom: CGFloat = 0.25
    private let maxZoom: CGFloat = 4.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(store.previewTheme.background)
                    .ignoresSafeArea()

                // Grid overlay (diagram mode only)
                if previewMode == .diagram && store.state.gridEnabled {
                    gridOverlay(size: geometry.size)
                }

                // Main content — diagram or ASCII
                if previewMode == .diagram {
                    diagramContent(in: geometry)
                } else {
                    AsciiPreviewView(store: store)
                }

                // Dim overlay on render failure
                if store.renderStatus == .failed {
                    Rectangle()
                        .fill(Color(store.previewTheme.background).opacity(0.35))
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

                // Preview-mode toggle (top-trailing)
                VStack {
                    HStack {
                        Spacer()
                        previewModePicker
                            .padding(12)
                    }
                    Spacer()
                }

                // Zoom toolbar (only meaningful in diagram mode)
                if previewMode == .diagram {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            PreviewToolbar(
                                theme: store.previewTheme,
                                zoomScale: zoomScaleBinding,
                                gridEnabled: $store.state.gridEnabled,
                                panZoomEnabled: $store.state.panZoomEnabled,
                                isAtAutomaticFit: store.state.zoomScale == nil,
                                minZoom: minZoom,
                                maxZoom: maxZoom,
                                onFitToView: {
                                    let fitScale = calculateFitScale(
                                        diagramBounds: store.diagramBounds,
                                        viewSize: geometry.size
                                    )
                                    applyAutomaticFitScale(fitScale)
                                    store.setPreviewZoomScale(nil)
                                    store.setPreviewPanOffset(.zero)
                                },
                                onActualSize: {
                                    setZoomScale(1.0)
                                    store.setPreviewPanOffset(.zero)
                                },
                                onFullWindowPreview: onFullWindowPreview
                            )
                            .padding(12)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preview mode picker

    private var previewModePicker: some View {
        HStack(spacing: 2) {
            ForEach(PreviewMode.allCases, id: \.self) { mode in
                Button {
                    previewMode = mode
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 10, weight: .medium))
                        Text(mode.label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .foregroundColor(previewMode == mode
                        ? Color(store.previewTheme.effectiveAccent())
                        : Color(store.previewTheme.foreground))
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(previewMode == mode
                                ? Color(store.previewTheme.effectiveAccent()).opacity(0.15)
                                : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(store.previewTheme.effectiveLine()).opacity(0.2), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
    }

    // MARK: - Diagram content (extracted so the body can swap in ASCII)

    @ViewBuilder
    private func diagramContent(in geometry: GeometryProxy) -> some View {
        let zoomScale = currentZoomScale
        let scaledWidth = max(store.diagramBounds.width * zoomScale, 1)
        let scaledHeight = max(store.diagramBounds.height * zoomScale, 1)

        panZoomInteractions(
            ZStack {
                DiagramNativeViewRepresentable(
                    source: store.previewSource,
                    theme: store.previewTheme,
                    layoutConfig: store.previewLayoutConfig,
                    store: store
                )
                .frame(width: scaledWidth, height: scaledHeight)
                .offset(effectivePanOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .clipped()
        )
        .onChange(of: store.diagramBounds) { _, newBounds in
            refreshAutomaticFit(bounds: newBounds, viewSize: geometry.size)
        }
        .onChange(of: geometry.size) { _, newSize in
            refreshAutomaticFit(bounds: store.diagramBounds, viewSize: newSize)
        }
    }

    // MARK: - Magnification gesture

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if gestureBaseZoomScale == nil {
                    gestureBaseZoomScale = currentZoomScale
                }
                let baseScale = gestureBaseZoomScale ?? currentZoomScale
                setZoomScale(Self.zoomScale(
                    forGestureValue: value,
                    baseScale: baseScale,
                    minZoom: minZoom,
                    maxZoom: maxZoom
                ))
            }
            .onEnded { _ in
                gestureBaseZoomScale = nil
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                activePanTranslation = value.translation
            }
            .onEnded { value in
                let baseOffset = store.state.panOffset ?? .zero
                store.setPreviewPanOffset(CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                ))
                activePanTranslation = .zero
            }
    }

    @ViewBuilder
    private func panZoomInteractions<Content: View>(_ content: Content) -> some View {
        if store.state.panZoomEnabled {
            content
                .highPriorityGesture(dragGesture)
                .simultaneousGesture(magnificationGesture)
        } else {
            content
        }
    }

    static func zoomScale(
        forGestureValue value: CGFloat,
        baseScale: CGFloat,
        minZoom: CGFloat,
        maxZoom: CGFloat
    ) -> CGFloat {
        min(max(baseScale * value, minZoom), maxZoom)
    }

    // MARK: - Persisted preview transform

    private var currentZoomScale: CGFloat {
        min(max(store.state.zoomScale ?? automaticZoomScale, minZoom), maxZoom)
    }

    private var zoomScaleBinding: Binding<CGFloat> {
        Binding(
            get: { currentZoomScale },
            set: { setZoomScale($0) }
        )
    }

    private var effectivePanOffset: CGSize {
        let baseOffset = store.state.panOffset ?? .zero
        return CGSize(
            width: baseOffset.width + activePanTranslation.width,
            height: baseOffset.height + activePanTranslation.height
        )
    }

    private func setZoomScale(_ scale: CGFloat) {
        store.setPreviewZoomScale(min(max(scale, minZoom), maxZoom))
    }

    private func applyAutomaticFitScale(_ scale: CGFloat) {
        automaticZoomScale = min(max(scale, minZoom), maxZoom)
        if store.state.zoomScale == nil {
            store.setPreviewPanOffset(.zero)
        }
    }

    /// Recompute the automatic fit scale whenever either the diagram bounds
    /// or the viewport size changes. User-set zoom (`state.zoomScale != nil`)
    /// is preserved — auto-fit only affects the value used when the user is
    /// in "Fit" mode.
    private func refreshAutomaticFit(bounds: CGRect, viewSize: CGSize) {
        guard bounds.width > 0, viewSize.width > 0 else { return }
        let fitScale = calculateFitScale(diagramBounds: bounds, viewSize: viewSize)
        automaticZoomScale = min(max(fitScale, minZoom), maxZoom)
    }

    // MARK: - Fit scale

    private func calculateFitScale(diagramBounds: CGRect, viewSize: CGSize) -> CGFloat {
        guard diagramBounds.width > 0, diagramBounds.height > 0 else {
            return 1.0
        }
        // Leave ~8% breathing room so the diagram doesn't kiss the viewport edges
        // (and so the floating zoom toolbar doesn't overlap content).
        let fitMargin: CGFloat = 0.92
        let scaleX = (viewSize.width * fitMargin) / diagramBounds.width
        let scaleY = (viewSize.height * fitMargin) / diagramBounds.height
        return min(max(min(scaleX, scaleY), minZoom), maxZoom)
    }

    // MARK: - Grid overlay

    private func gridOverlay(size: CGSize) -> some View {
        Canvas { context, _ in
            let gridSpacing: CGFloat = 20
            let lineColor = Color(store.previewTheme.effectiveLine()).opacity(0.15)

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
                .fill(Color(store.previewTheme.background).opacity(0.85))
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
                .fill(Color(store.previewTheme.background).opacity(0.88))
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
                .fill(Color(store.previewTheme.background).opacity(0.92))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }

    private var idleOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundColor(Color(store.previewTheme.effectiveMuted()))
            Text("Enter \(store.state.sourceFormat.displayName) syntax to preview")
                .font(.body)
                .foregroundColor(Color(store.previewTheme.effectiveMuted()))
        }
    }
}

// MARK: - Preview mode

/// Which renderer drives the preview surface.
enum PreviewMode: CaseIterable, Hashable {
    case diagram
    case ascii

    var label: String {
        switch self {
        case .diagram: return "Diagram"
        case .ascii:   return "ASCII"
        }
    }

    var iconName: String {
        switch self {
        case .diagram: return "rectangle.on.rectangle"
        case .ascii:   return "text.alignleft"
        }
    }
}

// MARK: - ASCII preview

/// Renders `DiagramEngine.renderASCII(...)` of the live preview source
/// into a scrollable monospaced text view.
///
/// Only flowchart, sequence, class, ER, and state diagrams support ASCII
/// today; other families come back empty or with a `notYetImplemented`
/// error, which is rendered as a friendly inline message.
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct AsciiPreviewView: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var ascii: String = ""
    @SwiftUI.State private var errorMessage: String?
    @SwiftUI.State private var isLoading: Bool = false
    @SwiftUI.State private var renderTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isLoading && ascii.isEmpty {
                ProgressView()
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "text.badge.xmark")
                        .font(.system(size: 28))
                        .foregroundColor(Color(store.previewTheme.effectiveMuted()))
                    Text(errorMessage)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(store.previewTheme.effectiveMuted()))
                        .padding(.horizontal, 24)
                }
            } else if ascii.isEmpty {
                Text("ASCII rendering is not available for this diagram type.")
                    .font(.body)
                    .foregroundColor(Color(store.previewTheme.effectiveMuted()))
                    .padding(24)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(ascii)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(store.previewTheme.foreground))
                        .padding(16)
                        .textSelection(.enabled)
                }
                .background(Color(store.previewTheme.background))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: previewKey) {
            await refreshAscii()
        }
    }

    /// Combined key so the task fires when source or theme/format changes.
    private var previewKey: String {
        "\(store.previewSource.hashValue)|\(store.previewThemeName)|\(store.state.sourceFormat.rawValue)"
    }

    private func refreshAscii() async {
        let source = store.previewSource
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                ascii = ""
                errorMessage = nil
                isLoading = false
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        let theme = store.previewTheme
        do {
            let rendered = try await DiagramEngine.renderASCII(source: source, theme: theme)
            await MainActor.run {
                ascii = rendered
                isLoading = false
            }
        } catch {
            await MainActor.run {
                ascii = ""
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

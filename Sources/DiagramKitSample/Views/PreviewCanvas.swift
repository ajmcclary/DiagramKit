//
//  PreviewCanvas.swift
//  DiagramPlayground
//
//  Preview surface that wraps the library's SwiftUI DiagramView, manages
//  zoom state, and overlays error/dim-state on render failure.
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import DiagramKitSampleDesignSystem

struct PreviewCanvas: View {
    @Bindable var store: LiveEditorStore
    let onFullWindowPreview: (() -> Void)?
    @Environment(\.dsEnvironment) private var environment

    @SwiftUI.State private var automaticZoomScale: CGFloat = 1.0
    @SwiftUI.State private var gestureBaseZoomScale: CGFloat?
    @SwiftUI.State private var activePanTranslation: CGSize = .zero

    /// Derived from `store.state.renderBackend` so the Inspector's
    /// 3-way segmented picker is the single source of truth for which
    /// preview surface is active. `.svg` and `.image` both feed
    /// DiagramView (the playground hosts a single CG renderer on
    /// Apple); `.ascii` feeds AsciiPreviewView.
    private var previewMode: PreviewMode {
        store.state.renderBackend == .ascii ? .ascii : .diagram
    }

    // Bridges DiagramView's @Binding-based completion publishing into
    // the store's didCompleteRender(...) entry point. liveParseError
    // carries the raw Error for forwarding; liveParseErrorMessage is the
    // Equatable signal we observe via `.onChange` (Error itself isn't
    // Equatable).
    @SwiftUI.State private var liveParseError: Error?
    @SwiftUI.State private var liveParseErrorMessage: String?
    @SwiftUI.State private var liveDiagramBounds: CGRect = .zero
    @SwiftUI.State private var liveBoundsLookup: DiagramBoundsLookup?

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
                        .opacity(store.renderStatus == .rendering ? 0.6 : 1.0)
                } else {
                    AsciiPreviewView(store: store)
                }

                // Dim overlay on render failure
                if store.renderStatus == .failed {
                    Rectangle()
                        .fill(environment.theme.colors.windowBackground.color.opacity(DSTokens.Opacity.disabled))
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
                                .padding(DSTokens.Spacing.md)
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
                                .padding(DSTokens.Spacing.md)
                        }
                        Spacer()
                    }
                }

                // Empty state
                if store.renderStatus == .idle {
                    idleOverlay
                }

                // Rendering indicator. The canvas stays mounted across renders,
                // so this shows the stale (dimmed) diagram plus a spinner while a
                // large diagram re-renders on the worker thread.
                if store.renderStatus == .rendering {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            DSGlassSurface(role: .popover) {
                                HStack(spacing: DSTokens.Spacing.xs) {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(environment.theme.colors.info.color)
                                    Text("Rendering")
                                        .dsFont(.badge)
                                        .foregroundStyle(environment.theme.colors.textPrimary.color)
                                }
                                .padding(DSTokens.Spacing.sm)
                            }
                            .padding(DSTokens.Spacing.md)
                        }
                    }
                    .allowsHitTesting(false)
                }

                // Zoom toolbar (only meaningful in diagram mode)
                if previewMode == .diagram {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            CanvasZoomToolbar(
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
                            .padding(DSTokens.Spacing.md)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Diagram content (extracted so the body can swap in ASCII)

    @ViewBuilder
    private func diagramContent(in geometry: GeometryProxy) -> some View {
        let zoomScale = currentZoomScale
        let scaledWidth = max(store.diagramBounds.width * zoomScale, 1)
        let scaledHeight = max(store.diagramBounds.height * zoomScale, 1)

        panZoomInteractions(
            ZStack {
                DiagramView(
                    source: store.previewSource,
                    theme: store.previewTheme,
                    layoutConfig: store.previewLayoutConfig,
                    sourceFormat: store.state.sourceFormat.formatID,
                    parseError: parseErrorBinding,
                    diagramBounds: $liveDiagramBounds,
                    boundsLookup: $liveBoundsLookup
                )
                .frame(width: scaledWidth, height: scaledHeight)
                .offset(effectivePanOffset)

                selectionOverlay(geometry: geometry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .clipped()
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { event in
                        let isMidGesture = gestureBaseZoomScale != nil || activePanTranslation != .zero
                        guard !isMidGesture else { return }
                        store.handleTapAt(viewPoint: event.location, viewSize: geometry.size)
                    }
            )
        )
        .onChange(of: store.diagramBounds) { _, newBounds in
            refreshAutomaticFit(bounds: newBounds, viewSize: geometry.size)
        }
        .onChange(of: geometry.size) { _, newSize in
            refreshAutomaticFit(bounds: store.diagramBounds, viewSize: newSize)
        }
        .onChange(of: liveDiagramBounds) { _, _ in
            forwardRenderCompletion()
        }
        .onChange(of: liveParseErrorMessage) { _, _ in
            forwardRenderCompletion()
        }
    }

    @ViewBuilder
    private func selectionOverlay(geometry: GeometryProxy) -> some View {
        if let selection = store.editor?.selection,
           let bounds = store.boundsLookup?.bounds(of: selection) {
            let zoom = currentZoomScale
            let scaledWidth = store.diagramBounds.width * zoom
            let scaledHeight = store.diagramBounds.height * zoom
            let centerX = (geometry.size.width - scaledWidth) / 2 + effectivePanOffset.width
            let centerY = (geometry.size.height - scaledHeight) / 2 + effectivePanOffset.height
            let originX = centerX + CGFloat(bounds.minX) * zoom
            let originY = centerY + CGFloat(bounds.minY) * zoom
            let width = CGFloat(bounds.width) * zoom
            let height = CGFloat(bounds.height) * zoom

            RoundedRectangle(cornerRadius: DSTokens.Radius.xs)
                .stroke(
                    Color(store.previewTheme.effectiveAccent()),
                    lineWidth: DSTokens.Stroke.medium
                )
                .frame(width: width, height: height)
                .position(x: originX + width / 2, y: originY + height / 2)
                .allowsHitTesting(false)
        }
    }

    /// Bridges `DiagramView`'s `Error?` binding so we can also mirror an
    /// Equatable `String?` for `.onChange` change-detection. The raw
    /// `liveParseError` is what we forward to the store.
    private var parseErrorBinding: Binding<Error?> {
        Binding(
            get: { liveParseError },
            set: { newValue in
                liveParseError = newValue
                liveParseErrorMessage = newValue?.localizedDescription
            }
        )
    }

    private func forwardRenderCompletion() {
        store.boundsLookup = liveBoundsLookup
        store.didCompleteRender(
            parseError: liveParseError,
            diagramBounds: liveDiagramBounds
        )
    }

    // MARK: - Magnification gesture

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if gestureBaseZoomScale == nil {
                    gestureBaseZoomScale = currentZoomScale
                }
                let baseScale = gestureBaseZoomScale ?? currentZoomScale
                setZoomScale(CanvasTransform.gestureScale(base: baseScale, value: value))
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
        DSGlassSurface(role: .popover) {
            HStack(spacing: DSTokens.Spacing.xs) {
                DSStatusIndicator(.warning, label: "Unsaved changes")
                Text("Unsaved changes")
                    .dsFont(.badge)
                    .foregroundStyle(environment.theme.colors.warning.color)
            }
            .padding(.horizontal, DSTokens.Spacing.smMd)
            .padding(.vertical, DSTokens.Spacing.xs)
        }
    }

    // MARK: - Overlays

    private var configWarningsOverlay: some View {
        DSGlassSurface(role: .popover) {
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xxs) {
                ForEach(store.configWarnings) { warning in
                    HStack(alignment: .top, spacing: DSTokens.Spacing.xs) {
                        DSStatusIndicator(warningStatusKind(warning.level), label: warning.message)

                        VStack(alignment: .leading, spacing: DSTokens.Spacing.xxxs) {
                            Text(warning.keyPath)
                                .dsFont(.metric)
                                .foregroundStyle(environment.theme.colors.textPrimary.color)
                            Text(warning.message)
                                .dsFont(.caption2)
                                .foregroundStyle(environment.theme.colors.textSecondary.color)
                                .lineLimit(2)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, DSTokens.Spacing.sm)
                    .padding(.vertical, DSTokens.Spacing.xxs)
                }
            }
            .padding(DSTokens.Spacing.sm)
        }
        .frame(maxWidth: 320)
    }

    private func errorOverlay(_ error: Error) -> some View {
        DSGlassSurface(role: .popover) {
            VStack(spacing: DSTokens.Spacing.sm) {
                DSIconView(.error, size: DSTokens.Icon.md, colorRole: .error)
                Text("Parse Error")
                    .dsFont(.headline)
                    .foregroundStyle(environment.theme.colors.error.color)
                Text(error.localizedDescription)
                    .dsFont(.body)
                    .foregroundStyle(environment.theme.colors.error.color)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSTokens.Spacing.xxl)
            }
            .padding(DSTokens.Spacing.xl)
        }
    }

    private var idleOverlay: some View {
        VStack(spacing: DSTokens.Spacing.md) {
            DSIconView(.diagram, size: DSTokens.Icon.lg, colorRole: .muted)
            Text("Enter \(store.state.sourceFormat.displayName) syntax to preview")
                .dsFont(.body)
                .foregroundStyle(environment.theme.colors.textSecondary.color)
        }
    }

    private func warningStatusKind(_ level: ConfigSanitizer.Warning.Level) -> DSStatusKind {
        switch level {
        case .unsupported: .unsupported
        case .caution: .warning
        case .info: .info
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

    var icon: DSIcon {
        switch self {
        case .diagram: return .diagram
        case .ascii:   return .code
        }
    }
}

// MARK: - ASCII preview

/// Renders `DiagramEngine.renderASCII(...)` of the live preview source
/// into a scrollable monospaced text view.
///
/// Mermaid sources render directly; supported imported formats are normalized
/// through Mermaid export before ASCII rendering. Unsupported families come
/// back empty or with a `notYetImplemented` error, rendered as a friendly
/// inline message.
struct AsciiPreviewView: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.dsEnvironment) private var environment

    @SwiftUI.State private var ascii: String = ""
    @SwiftUI.State private var errorMessage: String?
    @SwiftUI.State private var isLoading: Bool = false

    var body: some View {
        Group {
            if isLoading && ascii.isEmpty {
                VStack(spacing: DSTokens.Spacing.sm) {
                    ProgressView()
                        .tint(environment.theme.colors.info.color)
                    Text("Rendering ASCII")
                        .dsFont(.badge)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                }
            } else if let errorMessage {
                VStack(spacing: DSTokens.Spacing.md) {
                    DSIconView(.error, size: DSTokens.Icon.md, colorRole: .error)
                    Text(errorMessage)
                        .dsFont(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(environment.theme.colors.error.color)
                        .padding(.horizontal, DSTokens.Spacing.xxl)
                }
            } else if ascii.isEmpty {
                Text("ASCII rendering is not available for this diagram type.")
                    .dsFont(.body)
                    .foregroundStyle(environment.theme.colors.textSecondary.color)
                    .padding(DSTokens.Spacing.xxl)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    Text(ascii)
                        .dsFont(.code)
                        .foregroundColor(Color(store.previewTheme.foreground))
                        .padding(DSTokens.Spacing.lg)
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
    ///
    /// Uses the source text itself, not its `hashValue`: two distinct sources
    /// that hash-collide within the process would otherwise leave the ASCII
    /// pane showing the previous diagram's output.
    private var previewKey: String {
        "\(store.previewSource)|\(store.previewThemeName)|\(store.state.sourceFormat.rawValue)"
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
            let rendered = try await DiagramEngine.renderASCII(
                source: source,
                theme: theme,
                sourceFormat: store.state.sourceFormat.formatID
            )
            await MainActor.run {
                ascii = rendered.text
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

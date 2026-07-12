//
//  PlaygroundShell.swift
//  DiagramPlayground
//
//  Custom three-column shell that replaces NavigationSplitView for
//  iPad-regular / macOS layouts. Phase 1 wires Titlebar / Sidebar /
//  EditorPane / Inspector / Statusbar; Phases 2+ swap the body for
//  Visual / Split surfaces.
//

import SwiftUI
import DiagramKitSampleDesignSystem

struct PlaygroundShell: View {
    @Bindable var store: LiveEditorStore

    @AppStorage("playground.shell.sidebarVisible") private var sidebarVisible = true

    /// Panel (sidebar) column visibility for the NavigationSplitView, mirrored
    /// to the persisted `sidebarVisible` so it survives relaunch. The activity
    /// rail stays fixed outside the split; only the switchable panel collapses.
    /// The inspector is driven separately by `store.state.inspectorOpen` so the
    /// toolbar toggle and `⌘I` stay in lockstep.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Environment(\.dsEnvironment) private var environment

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                #if !os(macOS)
                TitlebarView(store: store)
                separator
                #endif
                HStack(spacing: 0) {
                    // The activity rail is a fixed leading strip (section
                    // switcher) outside the split; the switchable panel is the
                    // split's sidebar, and the inspector is the trailing
                    // `.inspector` column. This restores native collapse,
                    // drag-to-resize, and adaptive column behavior (esp. iPad).
                    ActivityRail(store: store)
                    NavigationSplitView(columnVisibility: $columnVisibility) {
                        ActivityPanel(store: store)
                            .navigationSplitViewColumnWidth(min: 220, ideal: 236, max: 320)
                    } detail: {
                        bodyForMode
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .inspector(isPresented: Binding(
                                get: { store.state.inspectorOpen },
                                set: { store.state.inspectorOpen = $0 }
                            )) {
                                InspectorView(store: store)
                                    .inspectorColumnWidth(min: 280, ideal: 312, max: 380)
                            }
                    }
                    .navigationSplitViewStyle(.balanced)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if store.state.diagDrawer.isOpen {
                    separator
                    DiagnosticsDrawer(store: store)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                StatusbarView(store: store)
            }
            .animation(drawerAnimation, value: store.state.diagDrawer.isOpen)
            .onChange(of: store.state.inspectorOpen) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "playground.shell.inspectorVisible")
            }
            .onAppear { columnVisibility = sidebarVisible ? .all : .detailOnly }
            .onChange(of: columnVisibility) { _, newValue in
                sidebarVisible = (newValue != .detailOnly)
            }
            // Native modality for the panels (Escape/focus/VoiceOver). Fitted
            // sizing keeps the wide desktop cards content-sized instead of
            // clipping inside an iPad form sheet.
            .sheet(isPresented: Binding(
                get: { store.state.exportSheet.isOpen },
                set: { if !$0 { store.closeExportSheet() } }
            )) {
                ExportSheet(store: store)
                    .presentationSizing(.fitted)
            }
            .sheet(isPresented: Binding(
                get: { store.state.convertSheet.isOpen },
                set: { if !$0 { store.closeConvertSheet() } }
            )) {
                ConvertSheet(store: store)
                    .presentationSizing(.fitted)
            }
            .sheet(isPresented: Binding(
                get: { store.state.settingsPresented },
                set: { if !$0 { store.dismissSettings() } }
            )) {
                SettingsSheet(store: store)
                    .presentationSizing(.fitted)
            }

            // Explain popover overlays the entire shell.
            if let target = store.diagnosticExplainTarget {
                ZStack {
                    environment.theme.colors.windowBackground.color
                        .opacity(DSTokens.Opacity.disabled)
                        .ignoresSafeArea()
                        .onTapGesture { store.dismissExplain() }
                    DiagnosticExplainPopover(store: store, row: target)
                }
            }

            // Render-failed sheet (Phase 10 / Task 10.4)
            if store.renderStatus == .failed {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        RenderFailedSheet(store: store)
                            .padding(.trailing, DSTokens.Spacing.xl)
                            .padding(.bottom, DSTokens.Spacing.xxxl * 2)
                    }
                }
            }

            // Source-citation overlay (Phase 10 / Task 10.5)
            CitationOverlay(store: store)
        }
        .background(environment.theme.colors.windowBackground.color)
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
    }

    @ViewBuilder
    private var bodyForMode: some View {
        if store.state.fullScreen != .none {
            fullScreenBody
        } else {
            switch store.state.workspaceMode {
            case .code:
                EditorPane(store: store)
            case .split:
                HStack(spacing: 0) {
                    EditorPane(store: store)
                        .frame(minWidth: 260)
                    verticalSeparator
                    PreviewCanvas(store: store, onFullWindowPreview: nil)
                        .frame(minWidth: 260)
                }
            case .visual:
                VisualPane(store: store)
            }
        }
    }

    @ViewBuilder
    private var fullScreenBody: some View {
        switch store.state.fullScreen {
        case .none:
            EmptyView()
        case .coverage:
            CoverageMatrixView(store: store)
        case .corpus:
            CorpusBrowserView(store: store)
        case .crossFormat:
            ThreeFormatView(store: store)
        case .probe:
            ImporterProbeView(store: store)
        case .snippets:
            SnippetsLibraryView(store: store)
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(environment.theme.colors.borderVariant.color)
            .frame(height: DSTokens.Stroke.hairline)
            .accessibilityHidden(true)
    }

    private var verticalSeparator: some View {
        Rectangle()
            .fill(environment.theme.colors.borderVariant.color)
            .frame(width: DSTokens.Stroke.hairline)
            .accessibilityHidden(true)
    }

    private var drawerAnimation: Animation? {
        guard environment.motion == .standard else { return nil }
        return .easeInOut(
            duration: environment.motion.duration(
                milliseconds: DSTokens.DurationMilliseconds.drawer
            )
        )
    }

}

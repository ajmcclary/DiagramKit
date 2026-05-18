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

struct PlaygroundShell: View {
    @Bindable var store: LiveEditorStore

    @AppStorage("playground.shell.sidebarVisible") private var sidebarVisible = true

    /// Inspector visibility is driven by `store.state.inspectorOpen` so the
    /// toolbar toggle button and the `⌘I` shortcut stay in lockstep with
    /// the shell layout.
    private var inspectorVisible: Bool { store.state.inspectorOpen }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                #if !os(macOS)
                TitlebarView(store: store)
                Divider()
                #endif
                HStack(spacing: 0) {
                    if sidebarVisible {
                        SidebarView(store: store)
                            .frame(width: 220)
                        Divider()
                    }
                    bodyForMode
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if inspectorVisible {
                        Divider()
                        InspectorView(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if store.state.diagDrawer.isOpen {
                    Divider()
                    DiagnosticsDrawer(store: store)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Divider()
                StatusbarView(store: store)
            }
            .animation(.easeInOut(duration: 0.18), value: store.state.diagDrawer.isOpen)
            .onChange(of: store.state.inspectorOpen) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: "playground.shell.inspectorVisible")
            }

            // Explain popover overlays the entire shell.
            if let target = store.diagnosticExplainTarget {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                        .onTapGesture { store.dismissExplain() }
                    DiagnosticExplainPopover(store: store, row: target)
                }
            }

            // Export sheet (Phase 7 / Task 7.1)
            if store.state.exportSheet.isOpen {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture { store.closeExportSheet() }
                    ExportSheet(store: store)
                }
            }

            // Convert sheet (Phase 7 / Task 7.2)
            if store.state.convertSheet.isOpen {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture { store.closeConvertSheet() }
                    ConvertSheet(store: store)
                }
            }

            // Render-failed sheet (Phase 10 / Task 10.4)
            if store.renderStatus == .failed {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        RenderFailedSheet(store: store)
                            .padding(.trailing, 18)
                            .padding(.bottom, 70)
                    }
                }
            }

            // Source-citation overlay (Phase 10 / Task 10.5)
            CitationOverlay(store: store)
        }
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
                    Divider()
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

}

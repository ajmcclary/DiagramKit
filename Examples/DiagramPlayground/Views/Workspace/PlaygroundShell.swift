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

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct PlaygroundShell: View {
    @Bindable var store: LiveEditorStore

    @AppStorage("playground.shell.sidebarVisible") private var sidebarVisible = true
    @AppStorage("playground.shell.inspectorVisible") private var inspectorVisible = true

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                TitlebarView(store: store)
                Divider()
                HStack(spacing: 0) {
                    if sidebarVisible {
                        SidebarView(store: store)
                            .frame(width: 260)
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
                        .frame(minWidth: 320)
                    Divider()
                    PreviewCanvas(store: store, onFullWindowPreview: nil)
                        .frame(minWidth: 320)
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

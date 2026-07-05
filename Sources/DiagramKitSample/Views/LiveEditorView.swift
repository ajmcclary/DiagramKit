//
//  LiveEditorView.swift
//  DiagramPlayground
//
//  Root view for the live editor. Replaces the old ContentView with a
//  store-driven architecture: editor pane + preview canvas as the main
//  workspace, with controls in a sidebar (regular) or sheet (compact).
//

import SwiftUI
import DiagramKit

struct LiveEditorView: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var showingControls = false
    @SwiftUI.State private var showingFullWindowPreview = false
    @SwiftUI.State private var nonInspectorMode: CompactMode = .edit

    @AppStorage(PlaygroundChromePersistence.themeKey)
    private var familyRaw = ZedTrekTheme.lcars.rawValue
    @AppStorage(PlaygroundChromePersistence.modeKey)
    private var modeRaw = ThemeMode.dark.rawValue
    @AppStorage(PlaygroundChromePersistence.canvasFollowsKey)
    private var canvasFollows = true

    /// The resolved light/dark scheme, reported by `PlaygroundThemeHost` (so
    /// `.system` mode reflects the live OS appearance). Drives the toolbar
    /// background and the diagram canvas-follow sync.
    @SwiftUI.State private var effectiveScheme: ColorScheme = .dark

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var chromeFamily: ZedTrekTheme { ZedTrekTheme(rawValue: familyRaw) ?? .lcars }
    private var chromeMode: ThemeMode { ThemeMode(rawValue: modeRaw) ?? .dark }

    /// Chrome background for the current theme. Used to paint the window toolbar
    /// so its full-screen background matches the app body instead of falling
    /// back to the default system material band.
    private var chromeBackground: Color {
        PlaygroundTokens(family: chromeFamily, scheme: effectiveScheme).palette.bgApp
    }

    private func syncCanvasIfFollowing() {
        guard canvasFollows else { return }
        store.syncCanvasToApp(family: chromeFamily, isDark: effectiveScheme == .dark)
    }

    // Bridges the iPhone compact-layout picker to `store.state.inspectorOpen`
    // so the Cmd-I shortcut (which flips `inspectorOpen` via `toggleInspector`)
    // and the segmented picker stay in lockstep. Picking `.inspector` opens
    // the inspector; picking `.edit`/`.view` closes it and is remembered as
    // the preferred non-inspector mode.
    private var compactMode: Binding<CompactMode> {
        Binding(
            get: { store.state.inspectorOpen ? .inspector : nonInspectorMode },
            set: { newValue in
                if newValue == .inspector {
                    store.state.inspectorOpen = true
                } else {
                    store.state.inspectorOpen = false
                    nonInspectorMode = newValue
                }
            }
        )
    }

    var body: some View {
        Group {
            #if os(iOS)
            if horizontalSizeClass == .compact {
                NavigationStack {
                    compactLayout
                        .navigationTitle("Diagram")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(Color(store.theme.background), for: .navigationBar)
                        .toolbarColorScheme(store.theme.background.isLight ? .light : .dark, for: .navigationBar)
                        .toolbar {
                            LiveEditorToolbar(store: store)
                        }
                }
            } else {
                // iPad-regular: PlaygroundShell now hosts its own
                // NavigationSplitView, which is the toolbar host (supersedes the
                // Phase 0 interim NavigationStack wrap for B1).
                regularLayout
                    .toolbar {
                        LiveEditorToolbar(store: store)
                    }
            }
            #else
            regularLayout
            #endif
        }
        .playgroundTheme(family: chromeFamily, mode: chromeMode) { newScheme in
            effectiveScheme = newScheme
            syncCanvasIfFollowing()
        }
        .onChange(of: familyRaw) { _, _ in syncCanvasIfFollowing() }
        .onChange(of: canvasFollows) { _, _ in syncCanvasIfFollowing() }
        #if os(macOS)
        .toolbarBackground(chromeBackground, for: .windowToolbar)
        #endif
    }

    // MARK: - Compact Layout (iPhone)

    #if os(iOS)
    private var compactLayout: some View {
        VStack(spacing: 0) {
            // Edit / View segmented toggle
            Picker("Mode", selection: compactMode) {
                ForEach(CompactMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(store.theme.background))

            // Main content
            Group {
                switch compactMode.wrappedValue {
                case .edit:
                    EditorPane(store: store)
                case .view:
                    PreviewCanvas(store: store, onFullWindowPreview: nil)
                case .inspector:
                    DiagramEditorPane(store: store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showingControls = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(store.theme.foreground))
                    .padding(12)
                    .background(
                        Circle()
                            .fill(Color(store.theme.background).opacity(0.9))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    )
            }
            .padding()
        }
        .sheet(isPresented: $showingControls) {
            NavigationStack {
                SidebarView(store: store, onOpenSettings: {
                    // Dismiss the controls sheet first, then present Settings so
                    // the two sheets don't conflict (B2: Settings is otherwise
                    // unreachable on iPhone).
                    showingControls = false
                    store.presentSettings()
                })
                    .navigationTitle("Samples")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(Color(store.theme.background), for: .navigationBar)
                    .toolbarColorScheme(store.theme.background.isLight ? .light : .dark, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingControls = false
                            }
                        }
                    }
            }
            .presentationDetents([.height(80), .medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(isPresented: Binding(
            get: { store.state.settingsPresented },
            set: { if !$0 { store.dismissSettings() } }
        )) {
            NavigationStack {
                SettingsSheet(store: store)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { store.dismissSettings() }
                        }
                    }
            }
        }
    }
    #endif

    // MARK: - Regular Layout (iPad / macOS)

    private var regularLayout: some View {
        PlaygroundShell(store: store)
            .sheet(isPresented: $showingFullWindowPreview) {
                fullWindowPreviewSheet
            }
    }

    // MARK: - Full-window preview sheet

    private var fullWindowPreviewSheet: some View {
        NavigationStack {
            PreviewCanvas(store: store, onFullWindowPreview: nil)
                .navigationTitle("Preview")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingFullWindowPreview = false
                        }
                    }
                }
            #if os(iOS)
                .toolbarBackground(Color(store.theme.background), for: .navigationBar)
            #endif
        }
    }
}

// MARK: - Compact mode

private enum CompactMode: CaseIterable {
    case edit
    case view
    case inspector

    var label: String {
        switch self {
        case .edit: return "Edit"
        case .view: return "View"
        case .inspector: return "Inspect"
        }
    }
}

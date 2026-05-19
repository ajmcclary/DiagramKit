//
//  LiveEditorToolbar.swift
//  DiagramPlayground
//
//  Master toolbar for the live editor. Hosts action buttons that
//  open popover panels for samples, actions, and version info.
//  On macOS this integrates with the unified window toolbar;
//  on iOS it provides navigation-bar-appropriate items.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

// MARK: - macOS Toolbar

#if os(macOS)

/// macOS unified-window toolbar content.
///
/// Attached to the WindowGroup via `.toolbar { LiveEditorToolbar(store: store) }`.
struct LiveEditorToolbar: ToolbarContent {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var showingTheme = false
    @SwiftUI.State private var showingView = false
    @SwiftUI.State private var showingActions = false
    @SwiftUI.State private var showingFullWindowPreview = false

    var body: some ToolbarContent {
        // Principal: workspace mode picker.
        ToolbarItem(placement: .principal) {
            WorkspaceModePicker(store: store)
        }

        // Primary actions: theme, view, actions, inspector toggle.
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showingTheme.toggle()
            } label: {
                Label("Theme", systemImage: "paintpalette")
            }
            .popover(isPresented: $showingTheme) {
                ThemePicker(store: store)
                    .padding(16)
                    .frame(width: 280)
            }
            .help("Theme")
            .a11yIdentifier(A11yID.Toolbar.theme)

            Button {
                showingView.toggle()
            } label: {
                Label("View", systemImage: "eye")
            }
            .popover(isPresented: $showingView) {
                ViewOptionsPanel(store: store)
                    .padding(16)
                    .frame(width: 220)
            }
            .help("View options")
            .a11yIdentifier(A11yID.Toolbar.view)

            Button {
                showingActions.toggle()
            } label: {
                Label("Actions", systemImage: "square.and.arrow.up")
            }
            .popover(isPresented: $showingActions) {
                ActionsPanel(store: store, showingFullWindowPreview: $showingFullWindowPreview)
                    .frame(width: 300, height: 520)
            }
            .help("Export, copy, and share")
            .a11yIdentifier(A11yID.Toolbar.actions)

            Button {
                store.toggleInspector()
            } label: {
                Image(systemName: "sidebar.right")
            }
            .help("Inspector (⌘I)")
            .a11yToggle(
                label: "Inspector",
                isOn: store.state.inspectorOpen,
                hint: "Shows the editing controls panel",
                id: A11yID.Toolbar.inspectorToggle
            )
            .keyboardShortcut("i", modifiers: [.command])
        }
    }
}

#endif

// MARK: - iOS Toolbar

#if os(iOS)

/// iOS navigation-bar toolbar items.
///
/// Provides the same action buttons as the macOS toolbar via the
/// navigation bar's trailing item area. Panels open as sheets on
/// compact width and popovers on regular width.
struct LiveEditorToolbar: ToolbarContent {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var showingTheme = false
    @SwiftUI.State private var showingView = false
    @SwiftUI.State private var showingActions = false
    @SwiftUI.State private var showingFullWindowPreview = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showingTheme = true
            } label: {
                Image(systemName: "paintpalette")
            }
            .a11y(label: "Theme", id: A11yID.Toolbar.theme)

            Button {
                showingView = true
            } label: {
                Image(systemName: "eye")
            }
            .a11y(label: "View options", id: A11yID.Toolbar.view)

            Button {
                showingActions = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .a11y(label: "Actions", hint: "Export, copy, share, history", id: A11yID.Toolbar.actions)

            Button {
                store.toggleInspector()
            } label: {
                Image(systemName: "sidebar.right")
            }
            .a11yToggle(
                label: "Inspector",
                isOn: store.state.inspectorOpen,
                hint: "Shows the editing controls panel",
                id: A11yID.Toolbar.inspectorToggle
            )
            .keyboardShortcut("i", modifiers: [.command])
        }

        // Panels as sheets/popovers
        // Theme
        .sheet(isPresented: $showingTheme) {
            NavigationStack {
                ThemePicker(store: store)
                    .padding(16)
                    .navigationTitle("Theme")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingTheme = false }
                                .a11yIdentifier(A11yID.Panels.themePickerDone)
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        // View options
        .sheet(isPresented: $showingView) {
            NavigationStack {
                ViewOptionsPanel(store: store)
                    .padding(16)
                    .navigationTitle("View")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingView = false }
                                .a11yIdentifier(A11yID.Panels.viewOptionsDone)
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        // Actions
        .sheet(isPresented: $showingActions) {
            NavigationStack {
                ActionsPanel(store: store, showingFullWindowPreview: $showingFullWindowPreview)
                    .navigationTitle("Actions")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingActions = false }
                                .a11yIdentifier(A11yID.Panels.actionsShareDone)
                        }
                    }
            }
        }
    }
}

#endif

// MARK: - View Options Panel

/// Grid overlay and pan & zoom toggles, hosted in the toolbar's View popover.
struct ViewOptionsPanel: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $store.state.gridEnabled) {
                Label("Grid overlay", systemImage: "square.grid.3x3")
                    .labelStyle(.titleAndIcon)
            }
            Toggle(isOn: $store.state.panZoomEnabled) {
                Label("Pan & zoom", systemImage: "hand.draw")
                    .labelStyle(.titleAndIcon)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


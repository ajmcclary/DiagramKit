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
import DesignKitThemes

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
            DSIconButton(.theme, label: "Theme") {
                showingTheme.toggle()
            }
            .popover(isPresented: $showingTheme) {
                DSGlassSurface(role: .popover) {
                    ThemePicker(store: store)
                        .padding(Tokens.Spacing.lg)
                        .frame(width: 280)
                }
            }
            .help("Theme")
            .a11yIdentifier(A11yID.Toolbar.theme)

            DSIconButton(.image, label: "View options") {
                showingView.toggle()
            }
            .popover(isPresented: $showingView) {
                DSGlassSurface(role: .popover) {
                    ViewOptionsPanel(store: store)
                        .padding(Tokens.Spacing.lg)
                        .frame(width: 220)
                }
            }
            .help("View options")
            .a11yIdentifier(A11yID.Toolbar.view)

            DSIconButton(.export, label: "Actions") {
                showingActions.toggle()
            }
            .popover(isPresented: $showingActions) {
                ActionsPanel(store: store, showingFullWindowPreview: $showingFullWindowPreview)
                    .frame(width: 300, height: 520)
            }
            .help("Export, copy, and share")
            .a11yIdentifier(A11yID.Toolbar.actions)

            DSIconButton(.settings, label: "Inspector") {
                store.toggleInspector()
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
        ToolbarItem(placement: .topBarTrailing) {
            actionHost
        }
    }

    @ViewBuilder
    private var actionHost: some View {
        Group {
            if horizontalSizeClass == .compact {
                Menu {
                    Button("Theme") { showingTheme = true }
                    Button("View options") { showingView = true }
                    Button("Export, copy, and share") { showingActions = true }
                    Button(store.state.inspectorOpen ? "Hide inspector" : "Show inspector") {
                        store.toggleInspector()
                    }
                } label: {
                    DSIconView(.settings)
                }
                .menuStyle(.button)
                .frame(minWidth: Tokens.Size.Touch.min, minHeight: Tokens.Size.Touch.min)
                .a11y(label: "More actions", id: A11yID.Toolbar.actions)
            } else {
                HStack(spacing: Tokens.Spacing.xxs) {
                    DSIconButton(.theme, label: "Theme") { showingTheme = true }
                        .a11y(label: "Theme", id: A11yID.Toolbar.theme)
                    DSIconButton(.image, label: "View options") { showingView = true }
                        .a11y(label: "View options", id: A11yID.Toolbar.view)
                    DSIconButton(.export, label: "Actions") { showingActions = true }
                        .a11y(
                            label: "Actions",
                            hint: "Export, copy, share, history",
                            id: A11yID.Toolbar.actions
                        )
                    DSIconButton(.settings, label: "Inspector") { store.toggleInspector() }
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
        .sheet(isPresented: $showingTheme) {
            NavigationStack {
                ThemePicker(store: store)
                    .padding(Tokens.Spacing.xl)
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
        .sheet(isPresented: $showingView) {
            NavigationStack {
                ViewOptionsPanel(store: store)
                    .padding(Tokens.Spacing.xl)
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
        DSSurface(role: .panel) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            Toggle(isOn: $store.state.gridEnabled) {
                Text("Grid overlay")
            }
            .toggleStyle(.ds)
            Toggle(isOn: $store.state.panZoomEnabled) {
                Text("Pan & zoom")
            }
            .toggleStyle(.ds)
            }
            .padding(Tokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

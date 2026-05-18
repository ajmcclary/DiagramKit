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
    @SwiftUI.State private var showingVersionInfo = false
    @SwiftUI.State private var showingFullWindowPreview = false

    var body: some ToolbarContent {
        // Leading: navigation / mode controls
        ToolbarItemGroup(placement: .navigation) {
            // Auto / Manual segmented control
            UpdateModePicker(updateMode: $store.state.updateMode, theme: store.theme)

            // Render button (visible only in manual mode)
            if store.state.updateMode == .manual {
                renderButton
            }
        }

        // Principal: file title + workspace mode picker (replaces the
        // sunset custom TitlebarView on macOS).
        ToolbarItem(placement: .principal) {
            HStack(spacing: 12) {
                Text(titleText)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 260, alignment: .leading)
                WorkspaceModePicker(store: store)
            }
        }

        // Primary actions: theme, view, actions, info
        ToolbarItemGroup(placement: .primaryAction) {
            // Theme button
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

            // View button
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

            // Actions button
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

            // Version / Security button
            Button {
                showingVersionInfo.toggle()
            } label: {
                Label("Info", systemImage: "info.circle")
            }
            .popover(isPresented: $showingVersionInfo) {
                VersionSecurityPanel()
                    .frame(width: 320, height: 280)
            }
            .help("Version and security information")
            .a11yIdentifier(A11yID.Toolbar.info)

            // Inspector toggle (Cmd-I)
            Button {
                store.toggleInspector()
            } label: {
                Image(systemName: store.state.inspectorOpen
                    ? "slider.horizontal.below.rectangle.fill"
                    : "slider.horizontal.below.rectangle")
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

    // MARK: - Render button (manual mode)

    private var renderButton: some View {
        Button {
            store.renderNow()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Render")
            }
        }
        .disabled(!store.isDirty)
        .help("Render the current diagram")
        .a11yIdentifier(A11yID.Toolbar.render)
    }

    // MARK: - Title

    private var titleText: String {
        let firstLine = store.state.source
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let preview = firstLine.isEmpty ? "untitled" : firstLine
        return "\(store.state.sourceFormat.displayName) · \(preview)"
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
    @SwiftUI.State private var showingVersionInfo = false
    @SwiftUI.State private var showingFullWindowPreview = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            // Theme button
            Button {
                showingTheme = true
            } label: {
                Image(systemName: "paintpalette")
            }
            .a11y(label: "Theme", id: A11yID.Toolbar.theme)

            // View button
            Button {
                showingView = true
            } label: {
                Image(systemName: "eye")
            }
            .a11y(label: "View options", id: A11yID.Toolbar.view)

            // Actions button
            Button {
                showingActions = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .a11y(label: "Actions", hint: "Export, copy, share, history", id: A11yID.Toolbar.actions)

            // Info button
            Button {
                showingVersionInfo = true
            } label: {
                Image(systemName: "info.circle")
            }
            .a11y(label: "Version and security info", id: A11yID.Toolbar.info)

            // Inspector toggle (Cmd-I on hardware keyboards)
            Button {
                store.toggleInspector()
            } label: {
                Image(systemName: store.state.inspectorOpen
                    ? "slider.horizontal.below.rectangle.fill"
                    : "slider.horizontal.below.rectangle")
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
        // Version info
        .sheet(isPresented: $showingVersionInfo) {
            NavigationStack {
                VersionSecurityPanel()
                    .navigationTitle("Info")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingVersionInfo = false }
                                .a11yIdentifier(A11yID.Panels.versionInfoDone)
                        }
                    }
            }
        }
    }
}

#endif

// MARK: - Update Mode Picker

/// Segmented control for Auto / Manual update mode.
struct UpdateModePicker: View {
    @Binding var updateMode: UpdateMode
    let theme: DiagramTheme

    var body: some View {
        Picker("Update Mode", selection: $updateMode) {
            ForEach(UpdateMode.allCases, id: \.self) { mode in
                Text(mode.pickerLabel).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 120)
        .help(updateMode == .auto
            ? "Render automatically on changes"
            : "Render only when you click Render")
        .a11yIdentifier(A11yID.Toolbar.updateMode)
    }
}

extension UpdateMode {
    var pickerLabel: String {
        switch self {
        case .auto: return "Auto"
        case .manual: return "Manual"
        }
    }
}

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

#if DEBUG && !DIAGRAMKIT_SWIFTPM
#Preview("UpdateModePicker") {
    @Previewable @SwiftUI.State var mode: UpdateMode = .auto
    UpdateModePicker(updateMode: $mode, theme: .default)
        .padding()
}
#endif

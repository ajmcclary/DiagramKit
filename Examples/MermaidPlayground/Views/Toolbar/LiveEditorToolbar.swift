//
//  LiveEditorToolbar.swift
//  MermaidPlayground
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
@available(macOS 26.0, *)
struct LiveEditorToolbar: ToolbarContent {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var showingSamples = false
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

        // Primary actions: samples, actions, info
        ToolbarItemGroup(placement: .primaryAction) {
            // Samples button
            Button {
                showingSamples.toggle()
            } label: {
                Label("Samples", systemImage: "square.grid.2x2")
            }
            .popover(isPresented: $showingSamples) {
                SampleDiagramPanel(store: store)
                    .frame(width: 360, height: 480)
            }
            .help("Sample diagrams")

            // Actions button
            Button {
                showingActions.toggle()
            } label: {
                Label("Actions", systemImage: "square.and.arrow.up")
            }
            .popover(isPresented: $showingActions) {
                ActionsPanel(store: store, showingFullWindowPreview: $showingFullWindowPreview)
                    .frame(width: 300, height: 420)
            }
            .help("Export, copy, and share")

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
@available(iOS 26.0, *)
struct LiveEditorToolbar: ToolbarContent {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var showingSamples = false
    @SwiftUI.State private var showingActions = false
    @SwiftUI.State private var showingVersionInfo = false
    @SwiftUI.State private var showingFullWindowPreview = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            // Samples button
            Button {
                showingSamples = true
            } label: {
                Image(systemName: "square.grid.2x2")
            }

            // Actions button
            Button {
                showingActions = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }

            // Info button
            Button {
                showingVersionInfo = true
            } label: {
                Image(systemName: "info.circle")
            }
        }

        // Panels as sheets/popovers
        // Samples
        .sheet(isPresented: $showingSamples) {
            NavigationStack {
                SampleDiagramPanel(store: store)
                    .navigationTitle("Samples")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSamples = false }
                        }
                    }
            }
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
                        }
                    }
            }
        }
    }
}

#endif

// MARK: - Update Mode Picker

/// Segmented control for Auto / Manual update mode.
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
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

#if DEBUG
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
#Preview("UpdateModePicker") {
    @Previewable @SwiftUI.State var mode: UpdateMode = .auto
    UpdateModePicker(updateMode: $mode, theme: .default)
        .padding()
}
#endif

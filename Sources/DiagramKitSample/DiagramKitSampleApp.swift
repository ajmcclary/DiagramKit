//
//  DiagramKitSampleApp.swift
//  DiagramKitSample
//
//  SwiftUI app entry point for iOS and macOS.
//  Instantiates the LiveEditorStore and passes it to LiveEditorView.
//

import SwiftUI
import DiagramKit

#if os(macOS)
import AppKit
#endif

@main
struct DiagramKitSampleApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(DiagramKitSampleAppDelegate.self) private var appDelegate
    #endif

    @SwiftUI.State private var store = LiveEditorStore()

    init() {
        DiagramEngine.bootstrap()
        // First-launch UX: surface the inspector. Remembered across sessions
        // via the legacy "playground.shell.inspectorVisible" key (now mirrored
        // into `state.inspectorOpen` so the toolbar toggle is the single
        // source of truth).
        let hint = UserDefaults.standard.object(forKey: "playground.shell.inspectorVisible") as? Bool ?? true
        store.state.inspectorOpen = hint
        #if DEBUG
        Self.seedFromLaunchArgumentsIfNeeded(store: store)
        #endif
    }

    #if DEBUG
    /// Reads the `-uitest-state <state-id>` launch argument and seeds
    /// the store accordingly. Used by the UI test target's
    /// `launchPlayground(initialState:)` helper. No-op when the arg is
    /// missing or unrecognized.
    @MainActor
    private static func seedFromLaunchArgumentsIfNeeded(store: LiveEditorStore) {
        let args = CommandLine.arguments
        guard let flagIdx = args.firstIndex(of: "-uitest-state"),
              flagIdx + 1 < args.count else { return }
        let stateID = args[flagIdx + 1]
        switch stateID {
        case "empty":
            store.setSource("", origin: .system)
        case "editing-flow-1":
            // Inspector closed by default — preview is visible.
            // Editor-pane tests use "editing-flow-1-inspector" instead.
            if let sample = TestDiagrams.all.first(where: { $0.id == "flow-1-simple" }),
               let src = sample.source(for: "mermaid") {
                store.setSource(src, origin: .system)
            }
        case "editing-flow-1-inspector":
            if let sample = TestDiagrams.all.first(where: { $0.id == "flow-1-simple" }),
               let src = sample.source(for: "mermaid") {
                store.setSource(src, origin: .system)
                store.openInspector()
            }
        case "selection-flow-1":
            if let sample = TestDiagrams.all.first(where: { $0.id == "flow-1-simple" }),
               let src = sample.source(for: "mermaid") {
                store.setSource(src, origin: .system)
                store.openInspector()
            }
        case "error-garbage":
            store.setSource("not a real diagram \n garbage", origin: .system)
        case "theme-open":
            // Empty source — the test pops the Theme menu directly.
            store.setSource("", origin: .system)

        // v2 PlaygroundShell screens
        case "visual-flow":
            seedSample(id: "flow-1-simple", store: store)
            store.setWorkspaceMode(.visual)
        case "visual-sequence":
            seedFirstSample(matching: "sequence", store: store)
            store.setWorkspaceMode(.visual)
        case "visual-gantt":
            seedFirstSample(matching: "gantt", store: store)
            store.setWorkspaceMode(.visual)
        case "diag-drawer-open":
            seedSample(id: "flow-1-simple", store: store)
            store.setDiagnosticsDrawerOpen(true)
        case "export-sheet-open":
            seedSample(id: "flow-1-simple", store: store)
            store.openExportSheet()
        case "convert-sheet-open":
            seedSample(id: "flow-1-simple", store: store)
            store.openConvertSheet()
        case "coverage":
            seedSample(id: "flow-1-simple", store: store)
            store.setFullScreen(.coverage)
        case "corpus":
            seedSample(id: "flow-1-simple", store: store)
            store.setFullScreen(.corpus)
        case "cross-format":
            seedSample(id: "flow-1-simple", store: store)
            store.setFullScreen(.crossFormat)
        case "probe":
            seedSample(id: "flow-1-simple", store: store)
            store.setFullScreen(.probe)
        case "snippets":
            seedSample(id: "flow-1-simple", store: store)
            store.setFullScreen(.snippets)
        case "citations-on":
            seedSample(id: "flow-1-simple", store: store)
            store.openInspector()
            store.setShowCitations(true)

        default:
            break
        }
    }

    @MainActor
    private static func seedSample(id: String, store: LiveEditorStore) {
        if let sample = TestDiagrams.all.first(where: { $0.id == id }),
           let src = sample.source(for: "mermaid") {
            store.setSource(src, origin: .system)
        }
    }

    @MainActor
    private static func seedFirstSample(matching prefix: String, store: LiveEditorStore) {
        if let sample = TestDiagrams.all.first(where: { $0.id.hasPrefix(prefix) }),
           let src = sample.source(for: "mermaid") {
            store.setSource(src, origin: .system)
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            LiveEditorView(store: store)
                .toolbar {
                    #if os(macOS)
                    LiveEditorToolbar(store: store)
                    #endif
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Remove default "New" menu item
            }
            CommandGroup(replacing: .undoRedo) {
                // Route Cmd-Z to the focused NSTextView's UndoManager
                // first so typing in the source editor is not silently
                // unwound by a structural undo. Falls back to the
                // diagram editor's undo only when no text view holds
                // first responder.
                Button("Undo") { performScopedUndo(store: store) }
                    .keyboardShortcut("z", modifiers: [.command])
                Button("Redo") { performScopedRedo(store: store) }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
        }
        #endif
    }
}

#if os(macOS)
@MainActor
private func focusedTextViewUndoManager() -> UndoManager? {
    guard let responder = NSApp.keyWindow?.firstResponder as? NSTextView else {
        return nil
    }
    return responder.undoManager
}

@MainActor
private func performScopedUndo(store: LiveEditorStore) {
    if let textUndo = focusedTextViewUndoManager(), textUndo.canUndo {
        textUndo.undo()
        return
    }
    store.undoStructural()
}

@MainActor
private func performScopedRedo(store: LiveEditorStore) {
    if let textUndo = focusedTextViewUndoManager(), textUndo.canRedo {
        textUndo.redo()
        return
    }
    store.redoStructural()
}
#endif

//
//  DiagramPlaygroundApp.swift
//  DiagramPlayground
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
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct DiagramPlaygroundApp: App {
    @SwiftUI.State private var store = LiveEditorStore()

    init() {
        DiagramEngine.bootstrap()
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
        default:
            break
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
        .windowStyle(.titleBar)
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
@available(macOS 26.0, *)
@MainActor
private func focusedTextViewUndoManager() -> UndoManager? {
    guard let responder = NSApp.keyWindow?.firstResponder as? NSTextView else {
        return nil
    }
    return responder.undoManager
}

@available(macOS 26.0, *)
@MainActor
private func performScopedUndo(store: LiveEditorStore) {
    if let textUndo = focusedTextViewUndoManager(), textUndo.canUndo {
        textUndo.undo()
        return
    }
    store.undoStructural()
}

@available(macOS 26.0, *)
@MainActor
private func performScopedRedo(store: LiveEditorStore) {
    if let textUndo = focusedTextViewUndoManager(), textUndo.canRedo {
        textUndo.redo()
        return
    }
    store.redoStructural()
}
#endif

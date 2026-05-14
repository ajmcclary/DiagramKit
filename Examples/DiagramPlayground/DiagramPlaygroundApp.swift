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
    }

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

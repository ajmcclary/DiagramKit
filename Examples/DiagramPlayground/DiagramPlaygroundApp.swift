//
//  DiagramPlaygroundApp.swift
//  DiagramPlayground
//
//  SwiftUI app entry point for iOS and macOS.
//  Instantiates the LiveEditorStore and passes it to LiveEditorView.
//

import SwiftUI
import DiagramKit

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
                Button("Undo") { store.undoStructural() }
                    .keyboardShortcut("z", modifiers: [.command])
                    .disabled(store.editor?.undoManager.canUndo != true)
                Button("Redo") { store.redoStructural() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(store.editor?.undoManager.canRedo != true)
            }
        }
        #endif
    }
}

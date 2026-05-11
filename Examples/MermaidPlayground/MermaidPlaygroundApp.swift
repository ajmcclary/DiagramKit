//
//  MermaidPlaygroundApp.swift
//  MermaidPlayground
//
//  SwiftUI app entry point for iOS and macOS.
//  Instantiates the LiveEditorStore and passes it to LiveEditorView.
//

import SwiftUI
import DiagramKit

@main
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct MermaidPlaygroundApp: App {
    @SwiftUI.State private var store = LiveEditorStore()

    init() {
        MermaidRenderer.bootstrap()
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
        }
        #endif
    }
}

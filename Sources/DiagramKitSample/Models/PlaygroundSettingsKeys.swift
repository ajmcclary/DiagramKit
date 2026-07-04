//
//  PlaygroundSettingsKeys.swift
//  DiagramPlayground
//
//  Centralized @AppStorage keys for the genuinely-new redesign settings, plus
//  a reset that clears them (Settings ▸ General ▸ Reset All Settings).
//

import Foundation

enum PlaygroundSettingsKeys {
    static let confirmBeforeDelete      = "playground.settings.confirmBeforeDelete"
    static let sendAnonymousDiagnostics = "playground.settings.sendAnonymousDiagnostics"
    static let restoreLastDocument      = "playground.settings.restoreLastDocument"
    static let showConnectionHandles    = "playground.settings.showConnectionHandles"
    static let gridSize                 = "playground.settings.gridSize"
    static let keyboardNudge            = "playground.settings.keyboardNudge"
    static let defaultNodeShape         = "playground.settings.defaultNodeShape"
    static let defaultEdgeStyle         = "playground.settings.defaultEdgeStyle"
    static let uiTextSize               = "playground.settings.uiTextSize"

    static let all = [
        confirmBeforeDelete, sendAnonymousDiagnostics, restoreLastDocument,
        showConnectionHandles, gridSize, keyboardNudge, defaultNodeShape,
        defaultEdgeStyle, uiTextSize,
    ]

    @MainActor static func resetAll() {
        for key in all { UserDefaults.standard.removeObject(forKey: key) }
    }
}

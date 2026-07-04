//
//  LiveEditorStore+Settings.swift
//  DiagramPlayground
//
//  Presentation state for the redesign Settings sheet.
//

import Foundation

extension LiveEditorStore {
    /// Present the Settings sheet, optionally on a specific tab.
    public func presentSettings(tab: SettingsTab = .general) {
        state.settingsTab = tab
        state.settingsPresented = true
    }

    /// Dismiss the Settings sheet.
    public func dismissSettings() {
        state.settingsPresented = false
    }

    /// Switch the active Settings tab.
    public func setSettingsTab(_ tab: SettingsTab) {
        state.settingsTab = tab
    }
}

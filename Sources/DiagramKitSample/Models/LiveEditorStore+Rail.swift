//
//  LiveEditorStore+Rail.swift
//  DiagramPlayground
//
//  Activity-rail tab selection for the redesign shell.
//

import Foundation

extension LiveEditorStore {
    /// Switch the active activity-rail panel.
    public func setActiveRailTab(_ tab: ActivityRailTab) {
        state.activeRailTab = tab
    }
}

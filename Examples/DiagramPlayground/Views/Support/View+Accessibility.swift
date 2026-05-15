//
//  View+Accessibility.swift
//  DiagramPlayground
//
//  Typed accessibility modifiers + identifier namespace shared by
//  the views and the UI-test target.
//

import SwiftUI

// MARK: - A11yID namespace

/// Stable identifiers for every audited control in the playground.
/// The UI test target's `IdentifierPresenceTests` and the view code
/// both reference these constants — renaming one without the other
/// surfaces as a test failure.
public enum A11yID {
    public enum Editor {
        public static let titleSet = "editor.title.set"
        public static let titleClear = "editor.title.clear"
        public static let titleClose = "editor.title.close"
        public static let selectionPicker = "editor.selection.picker"
        public static let labelRename = "editor.label.rename"
        public static let insertNodeButton = "editor.insertNode.button"
        public static let insertNodeShapePicker = "editor.insertNode.shape"
        public static let insertEdgeButton = "editor.insertEdge.button"
        public static let insertEdgeFromPicker = "editor.insertEdge.from"
        public static let insertEdgeToPicker = "editor.insertEdge.to"
        public static let insertEdgeSwap = "editor.insertEdge.swap"
        public static let deleteSelected = "editor.delete.selected"
        public static let undo = "editor.undo"
        public static let redo = "editor.redo"
    }

    public enum Toolbar {
        public static let theme = "toolbar.theme"
        public static let view = "toolbar.view"
        public static let actions = "toolbar.actions"
        public static let info = "toolbar.info"
        public static let inspectorToggle = "toolbar.inspector"
        public static let render = "toolbar.render"
        public static let updateMode = "toolbar.updateMode"
    }

    public enum Preview {
        public static let fit = "preview.fit"
        public static let zoomIn = "preview.zoomIn"
        public static let zoomOut = "preview.zoomOut"
        public static let actualSize = "preview.actualSize"
        public static let panZoomToggle = "preview.panZoomToggle"
        public static let gridToggle = "preview.gridToggle"
        public static let fullWindow = "preview.fullWindow"
        public static let modePicker = "preview.mode"
    }

    public enum Pickers {
        public static let sourceFormat = "picker.sourceFormat"
        public static let editorMode = "picker.editorMode"
        public static let themeMenu = "picker.themeMenu"
        public static let sampleSearch = "picker.sampleSearch"
        public static let sampleSearchClear = "picker.sampleSearchClear"
    }

    public enum Panels {
        public static let versionInfoDone = "panel.versionInfo.done"
        public static let actionsShareDone = "panel.actions.shareDone"
        public static let actionsHistoryDone = "panel.actions.historyDone"
        public static let themePickerDone = "panel.themePicker.done"
        public static let viewOptionsDone = "panel.viewOptions.done"
    }
}

// MARK: - View modifiers

public extension View {
    /// Stateless control (Category C): label is the action verb.
    /// Optional hint clarifies non-obvious actions.
    func a11y(
        label: LocalizedStringKey,
        hint: LocalizedStringKey? = nil,
        id: String
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityIdentifier(id)
    }

    /// Stateful toggle (Category D): label is the noun, value reflects
    /// state, optional hint clarifies what toggling does. Applies the
    /// `.isSelected` trait when on.
    func a11yToggle(
        label: LocalizedStringKey,
        isOn: Bool,
        hint: LocalizedStringKey? = nil,
        id: String
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(isOn ? .isSelected : [])
            .accessibilityIdentifier(id)
    }

    /// Categories A + B: SwiftUI already derives the label from the
    /// button title or `Label` text. We just need a stable identifier.
    func a11yIdentifier(_ id: String) -> some View {
        accessibilityIdentifier(id)
    }
}

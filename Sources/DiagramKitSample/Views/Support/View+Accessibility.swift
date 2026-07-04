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

    // MARK: - v2 PlaygroundShell

    public enum Titlebar {
        public static let modeCode = "titlebar.mode.code"
        public static let modeVisual = "titlebar.mode.visual"
        public static let modeSplit = "titlebar.mode.split"
        public static let render = "titlebar.render"
        public static let export = "titlebar.export"
    }

    public enum Sidebar {
        public static let search = "sidebar.search"
        public static func formatChip(_ format: String) -> String {
            "sidebar.formatChip.\(format)"
        }
    }

    public enum Inspector {
        public static let documentSection = "inspector.section.document"
        public static let renderBackendSection = "inspector.section.renderBackend"
        public static let themeSection = "inspector.section.theme"
        public static let diagnosticsSection = "inspector.section.diagnostics"
        public static let historySection = "inspector.section.history"
        public static let citationsToggle = "inspector.citationsToggle"
    }

    public enum Statusbar {
        public static let backend = "statusbar.backend"
        public static let diagnostics = "statusbar.diagnostics"
    }

    public enum Sheets {
        public static let exportSheet = "sheet.export"
        public static let convertSheet = "sheet.convert"
        public static func exportTarget(_ value: String) -> String {
            "sheet.export.target.\(value)"
        }
        public static let exportRoundTripToggle = "sheet.export.rtToggle"
        public static let exportCopyButton = "sheet.export.copy"
        public static let exportSaveButton = "sheet.export.save"
        public static let exportRoundTripFooter = "sheet.export.rtFooter"
        public static func convertTarget(_ value: String) -> String {
            "sheet.convert.target.\(value)"
        }
        public static let convertLossList = "sheet.convert.lossList"
    }

    public enum Diagnostics {
        public static let drawer = "diagnostics.drawer"
        public static let categoryList = "diagnostics.categoryList"
        public static let rowList = "diagnostics.rowList"
        public static let explainPopover = "diagnostics.explainPopover"
        public static func severityChip(_ value: String) -> String {
            "diagnostics.severity.\(value)"
        }
        public static func tierChip(_ value: String) -> String {
            "diagnostics.tier.\(value)"
        }
        public static func pairedChip(_ value: String) -> String {
            "diagnostics.paired.\(value)"
        }
        public static func categoryChip(_ value: String) -> String {
            "diagnostics.category.\(value)"
        }
        public static func explainButton(forRow id: String) -> String {
            "diagnostics.explain.\(id)"
        }
    }

    public enum Visual {
        public static let pane = "visual.pane"
        public static let canvas = "visual.canvas"
        public static let toolPalette = "visual.toolPalette"
        public static func tool(_ name: String) -> String { "visual.tool.\(name)" }
        public static let selectionHUD = "visual.selectionHUD"
        public static let undoTimeline = "visual.undoTimeline"
        public static let stateStepper = "visual.stateStepper"
        public static func stateBanner(_ stage: String) -> String {
            "visual.state.\(stage).banner"
        }
        public static func node(_ id: String) -> String { "visual.node.\(id)" }
        public static let nodePopover = "visual.nodePopover"
        public static let edgePopover = "visual.edgePopover"
        public static let quickFixCard = "visual.quickFixCard"
        public static let groupButton = "visual.tool.group"
        public static let groupNameField = "visual.subgraph.nameField"
        public static let groupCommitButton = "visual.subgraph.commit"
        public static let subgraphOverlay = "visual.subgraphOverlay"
        public static let subgraphToast = "visual.subgraphToast"
        public static let centerToolbar = "visual.centerToolbar"
        public static let shapesButton = "visual.centerToolbar.shapes"
        public static let shapeCatalog = "visual.shapeCatalog"
        public static let shapeCatalogSearch = "visual.shapeCatalog.search"
        public static func shapeCell(_ alias: String) -> String { "visual.shapeCatalog.cell.\(alias)" }
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

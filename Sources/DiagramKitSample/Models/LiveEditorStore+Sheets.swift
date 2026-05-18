//
//  LiveEditorStore+Sheets.swift
//  DiagramPlayground
//
//  Phase 7 Export + Convert sheet state and the one-shot source export
//  helper used by ConvertSheet / ExportSheet / ThreeFormatView.
//

import SwiftUI
import DiagramKit
import DiagramKitExport

@available(iOS 26.0, macOS 26.0, *)
extension LiveEditorStore {

    // MARK: - Export sheet (Phase 7 / Task 7.1)

    public func openExportSheet(at target: ExportTarget? = nil) {
        if let target { state.exportSheet.target = target }
        state.exportSheet.isOpen = true
    }

    public func closeExportSheet() {
        state.exportSheet.isOpen = false
    }

    public func setExportTarget(_ target: ExportTarget) {
        state.exportSheet.target = target
    }

    public func setExportRoundTripCheck(_ flag: Bool) {
        state.exportSheet.rtCheck = flag
    }

    public func openConvertSheet(at target: SourceFormat? = nil) {
        if let target { state.convertSheet.target = target }
        state.convertSheet.isOpen = true
    }

    public func closeConvertSheet() {
        state.convertSheet.isOpen = false
    }

    public func setConvertTarget(_ target: SourceFormat) {
        state.convertSheet.target = target
    }

    /// One-shot source export against the current document for the
    /// Convert + Export sheets. Returns the exporter's source +
    /// diagnostics, or nil when the format isn't a source target.
    public func exportSourcePreview(to target: SourceFormat) async -> DiagramExportResult? {
        do {
            return try await exportSource(to: target)
        } catch {
            return nil
        }
    }
}

//
//  LiveEditorStore+Export.swift
//  DiagramPlayground
//
//  Export (PNG / SVG / ASCII / format conversion) and clipboard
//  operations split out of LiveEditorStore.swift to keep the root
//  observable model under the file-size gate. Methods stay on
//  LiveEditorStore via this extension — no public API change.
//

import SwiftUI
import DiagramKit
import DiagramKitExport
import DiagramKitModel

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

extension LiveEditorStore {

    // MARK: - Export (Phase 4)

    /// Export the current diagram as a PNG image to a temporary file.
    ///
    /// - Parameter options: Sizing and scale parameters.
    /// - Throws: Rendering or file I/O errors.
    /// - Returns: The URL of the temporary PNG file (caller cleans up).
    public func exportPNG(options: ExportOptions) async throws -> URL {
        let pngData = try await exportPNGData(options: options)

        let tempDir = FileManager.default.temporaryDirectory
        // UUID filename: a second-resolution timestamp collided when two
        // exports landed in the same wall-clock second, silently overwriting
        // the first before its caller consumed it.
        let fileName = "diagram-\(UUID().uuidString).png"
        let tempURL = tempDir.appendingPathComponent(fileName)
        try pngData.write(to: tempURL)

        return tempURL
    }

    /// Render the current diagram to PNG data without touching disk.
    ///
    /// Preferred over ``exportPNG(options:)`` when the caller just needs the
    /// bytes — it avoids the temp-file round-trip (and the leak of never
    /// cleaning that file up).
    public func exportPNGData(options: ExportOptions) async throws -> Data {
        let renderer = DiagramImageRenderer(theme: theme)
        renderer.layoutConfig = layoutConfig
        renderer.sourceFormat = state.sourceFormat.formatID

        let image: BMImage?
        switch options.sizing {
        case .auto:
            image = try await renderer.renderImage(from: state.source, scale: options.scale)
        case .fixed(let size):
            image = try await renderer.renderImage(from: state.source, size: size)
        }

        guard let image else {
            throw ExportError.renderFailed
        }

        guard let pngData = _platformPNGData(from: image) else {
            throw ExportError.pngConversionFailed
        }

        return pngData
    }

    /// Export the current diagram as an SVG string.
    ///
    /// - Throws: Rendering errors.
    /// - Returns: The SVG markup string.
    public func exportSVG() async throws -> String {
        try await DiagramEngine.renderSVG(
            source: state.source,
            theme: theme,
            layoutConfig: layoutConfig,
            sourceFormat: state.sourceFormat.formatID
        )
    }

    /// Export the current diagram as an ASCII / Unicode string.
    ///
    /// Mermaid sources render directly; supported imported formats are
    /// normalized through Mermaid export before ASCII rendering.
    public func exportASCII() async throws -> String {
        try await DiagramEngine.renderASCII(
            source: state.source,
            theme: theme,
            sourceFormat: state.sourceFormat.formatID
        ).text
    }

    /// Convert the current source to another format via parse → export.
    ///
    /// Parses through the selected source format, then dispatches to the
    /// target exporter through
    /// `DiagramPipeline.defaultExportRegistry`. All five formats have
    /// registered exporters; an exporter may still emit a `.unsupported`
    /// diagnostic when the parsed document's diagram family is outside
    /// its `supportedDiagramTypes`.
    ///
    /// - Parameter target: Destination format.
    /// - Throws: Parse errors from the source side, or fatal export errors.
    /// - Returns: The exporter's `DiagramExportResult` with `source` and
    ///   `diagnostics`.
    public func exportSource(to target: SourceFormat) async throws -> DiagramExportResult {
        let document = try await DiagramEngine.parse(
            state.source,
            as: state.sourceFormat.formatID
        )
        return try DiagramExportLoader.export(
            document,
            to: target.formatID,
            registry: DiagramPipeline.defaultExportRegistry
        )
    }

    // MARK: - Copy to clipboard (Phase 4)

    /// Copy the diagram source text to the system pasteboard.
    /// - Returns: `true` if the copy succeeded.
    @discardableResult
    public func copySource() -> Bool {
        _writeToPasteboard(state.source)
    }

    /// Copy the config JSON text to the system pasteboard.
    /// - Returns: `true` if the copy succeeded.
    @discardableResult
    public func copyConfig() -> Bool {
        _writeToPasteboard(state.configJSON)
    }

    /// Render and copy the SVG markup to the system pasteboard.
    /// - Throws: Rendering errors.
    public func copySVG() async throws {
        let svg = try await exportSVG()
        _ = _writeToPasteboard(svg)
    }

    /// Render and copy the PNG image to the system pasteboard.
    /// - Parameter options: Sizing and scale parameters.
    /// - Throws: Rendering errors.
    public func copyPNGImage(options: ExportOptions) async throws {
        let renderer = DiagramImageRenderer(theme: theme)
        renderer.layoutConfig = layoutConfig
        renderer.sourceFormat = state.sourceFormat.formatID

        let image: BMImage?
        switch options.sizing {
        case .auto:
            image = try await renderer.renderImage(from: state.source, scale: options.scale)
        case .fixed(let size):
            image = try await renderer.renderImage(from: state.source, size: size)
        }

        guard let image else {
            throw ExportError.renderFailed
        }

        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        #elseif os(iOS)
        UIPasteboard.general.image = image
        #endif
    }

    // MARK: - Pasteboard helpers

    /// Convert a platform image to PNG data.
    private func _platformPNGData(from image: BMImage) -> Data? {
        #if canImport(UIKit)
        return image.pngData()
        #elseif canImport(AppKit)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #endif
    }

    /// Write a string to the system pasteboard.
    /// - Returns: `true` if the write succeeded.
    @discardableResult
    private func _writeToPasteboard(_ string: String) -> Bool {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(string, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = string
        return true
        #endif
    }
}

// Phase 9: Interactive Model — Slice 9C
// Source sync via export protocol.

import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import Foundation

#if canImport(CoreGraphics)
import DiagramKitRenderingCG
#endif

extension DiagramEditor {
    /// Re-export the current document via `preferredExportFormat`.
    ///
    /// Uses `DiagramExportLoader.export(_:to:registry:)` for deterministic
    /// format-ID-based dispatch. Sets `source` to the exported source text
    /// and `lastExportDiagnostics` to any non-fatal diagnostics.
    ///
    /// - Throws: `DiagramExportError` if no exporter is registered for
    ///   `preferredExportFormat`, or if the exporter throws a fatal error.
    public func syncSource() throws {
        let result = try DiagramExportLoader.export(
            document,
            to: preferredExportFormat,
            registry: exportRegistry
        )
        _commitSource(result.source)
        _commitDiagnostics(result.diagnostics)
    }

    /// Internal helper: export without mutating state.
    /// Used during atomic commit to validate before state swap.
    func _export(_ document: DiagramDocument) throws -> DiagramExportResult {
        try DiagramExportLoader.export(
            document,
            to: preferredExportFormat,
            registry: exportRegistry
        )
    }

    // MARK: - Worker hop

    /// Dispatch `work` to a fresh 8 MB worker thread per CLAUDE.md's
    /// no-thread-pool rule. On Apple platforms this forwards to
    /// `DiagramWorkerThread.run` from `DiagramKitRenderingCG`. On Linux,
    /// spins a fresh `Thread` with the stack size from
    /// `DiagramWorkerConfig`.
    static func _runOnWorker<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        #if canImport(CoreGraphics)
        return try await DiagramWorkerThread.run(work)
        #else
        return try await withCheckedThrowingContinuation { continuation in
            let thread = Thread {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            thread.name = "DiagramKit editor worker"
            thread.stackSize = DiagramWorkerConfig.stackSize
            thread.start()
        }
        #endif
    }
}

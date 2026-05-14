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
    /// Hops to a fresh 8 MB worker thread; sets `source` to the exported
    /// source text and `lastExportDiagnostics` to any non-fatal
    /// diagnostics on success.
    ///
    /// - Throws: `DiagramExportError` if no exporter is registered for
    ///   `preferredExportFormat`, or if the exporter throws a fatal error.
    public func syncSource() async throws {
        let result = try await _exportAsync(document)
        _commitSource(result.source)
        _commitDiagnostics(result.diagnostics)
    }

    /// Internal helper: export without mutating state, off MainActor.
    ///
    /// Used by `perform`/`performFlowchart` to validate the round-trip
    /// before state swap. Hops to a fresh worker thread per CLAUDE.md's
    /// no-thread-pool rule.
    func _exportAsync(_ document: DiagramDocument) async throws -> DiagramExportResult {
        let format = preferredExportFormat
        let registry = exportRegistry
        return try await Self._runOnWorker {
            try DiagramExportLoader.export(
                document, to: format, registry: registry
            )
        }
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

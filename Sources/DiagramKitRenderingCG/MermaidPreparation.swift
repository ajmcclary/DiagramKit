// Apple-only — depends on `PreparedDiagram` (RenderingCG) and is the
// canonical async preparer for view-side code that lives in the
// DiagramKitViews target. The synchronous parse/layout/prepare work
// (`MermaidPipeline.prepare`) still lives in the umbrella; the umbrella
// registers that closure via `registerImplementation(_:)` on first use.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel

/// Canonical async wrapper around the umbrella's synchronous prepare
/// pipeline that dispatches onto the 8 MB-stack worker
/// (`MermaidWorkerThread.run`).
///
/// All UI-side preparation paths (`MermaidImageRenderer`, `MermaidLayer`,
/// `MermaidDiagram`) MUST go through this entry point — never call the
/// synchronous pipeline from `@MainActor` code, since flowchart
/// layout's recursion can exceed the cooperative pool's ~512 KB stack
/// budget on nested-subgraph diagrams.
///
/// **Concurrency Contract**: this enum holds a single `_impl` closure
/// that is set exactly once by the umbrella's bootstrap and then read
/// concurrently from any actor. Writes go through `_lock`; reads do
/// too. The closure itself must be `@Sendable`.
public enum MermaidPreparationError: Error, LocalizedError, Sendable {
    case notConfigured

    public var errorDescription: String? {
        """
        MermaidPreparation has no registered implementation. Import DiagramKit and \
        call MermaidRenderer.bootstrap() once at startup, or register a custom \
        implementation with MermaidPreparation.registerImplementation(_:).
        """
    }
}

public enum MermaidPreparation {

    /// Synchronous prepare implementation signature. The umbrella
    /// supplies one of these (closing over `MermaidPipeline.prepare`)
    /// via `registerImplementation(_:)`.
    public typealias SyncImplementation = @Sendable (
        _ source: String,
        _ theme: DiagramTheme,
        _ layoutConfig: LayoutConfig
    ) throws -> PreparedDiagram

    nonisolated(unsafe) private static var _impl: SyncImplementation?
    private static let _lock = NSLock()

    /// Register the synchronous prepare implementation. The umbrella
    /// calls this from `_MermaidPreparerBootstrap.didInstall` so that
    /// any subsequent `prepare(...)` call can dispatch through the
    /// canonical pipeline. Idempotent — calling again replaces the
    /// previous implementation (used by tests).
    public static func registerImplementation(_ impl: @escaping SyncImplementation) {
        _lock.lock()
        defer { _lock.unlock() }
        _impl = impl
    }

    /// Run the registered prepare implementation on the worker thread.
    public static func prepare(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig()
    ) async throws -> PreparedDiagram {
        let impl = _currentImpl
        guard let impl else {
            throw MermaidPreparationError.notConfigured
        }
        return try await MermaidWorkerThread.run {
            try impl(source, theme, layoutConfig)
        }
    }

    private static var _currentImpl: SyncImplementation? {
        _lock.lock()
        defer { _lock.unlock() }
        return _impl
    }
}
#endif

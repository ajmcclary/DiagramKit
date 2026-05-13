#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel

/// Indirection for view-side diagram preparation.
///
/// The view types in `Sources/DiagramKitViews/` call through this
/// wrapper instead of reaching up into the umbrella target. That keeps
/// the view layer below `DiagramKit` while still using the canonical
/// preparation pipeline registered by the umbrella.
///
/// `DiagramViewPreparer` is a `Sendable` value-type wrapper around the
/// async prepare closure. The umbrella registers the canonical
/// implementation (which routes through `_runOnWorker` onto the
/// 8 MB-stack worker thread) via
/// `DiagramViewPreparerEnvironment.configure(_:)`. Tests can substitute
/// a stub preparer to drive view behavior without going through the
/// real pipeline.
public struct DiagramViewPreparer: Sendable {

    public var prepare: @Sendable (
        _ source: String,
        _ theme: DiagramTheme,
        _ config: LayoutConfig
    ) async throws -> PreparedDiagram

    public init(
        prepare: @escaping @Sendable (String, DiagramTheme, LayoutConfig) async throws -> PreparedDiagram
    ) {
        self.prepare = prepare
    }
}

/// Process-wide injection point for the active `DiagramViewPreparer`.
/// The umbrella module sets this on first use; tests can override
/// before constructing any view that depends on it.
public enum DiagramViewPreparerEnvironment {

    // `nonisolated(unsafe)` is acceptable here because configuration is a
    // one-time install during module bootstrap, and the access pattern is
    // read-mostly. The Concurrency Contract: writes happen via
    // `configure(_:)`, intended to be called from a single configuration
    // point at module init; reads happen from any actor.
    nonisolated(unsafe) private static var _shared: DiagramViewPreparer?
    private static let _lock = NSLock()

    /// Returns the configured preparer, or `nil` if the umbrella hasn't
    /// installed one yet. Callers should fall back to direct preparation
    /// (e.g. `DiagramPreparation.prepare`) when this is `nil`.
    public static var current: DiagramViewPreparer? {
        _lock.lock()
        defer { _lock.unlock() }
        return _shared
    }

    /// Install the default or test preparer. Idempotent — calling again
    /// replaces the previous value.
    public static func configure(_ preparer: DiagramViewPreparer) {
        _lock.lock()
        defer { _lock.unlock() }
        _shared = preparer
    }
}

#endif

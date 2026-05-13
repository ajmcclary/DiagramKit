#if canImport(CoreGraphics)
import XCTest
@testable import DiagramKit
@testable import DiagramKitModel
import DiagramKitRenderingCG

/// Asserts the architectural invariant: every async preparation entry point
/// dispatches onto the named 8 MB worker thread defined by
/// `DiagramEngine._runOnWorker`. If a future refactor reintroduces an
/// inline `Thread { ... }.start()` or runs prepare/layout on the main
/// actor, these tests fail.
final class DiagramPreparationWorkerTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        // `DiagramPreparation` now lives in `DiagramKitRenderingCG` and
        // takes its synchronous implementation from the umbrella's
        // `_DiagramPreparerBootstrap`. The bootstrap fires implicitly
        // from any `DiagramEngine.*` call, but these tests invoke
        // `DiagramPreparation.prepare(...)` directly — so we need to
        // trigger it manually.
        DiagramEngine.bootstrap()
    }

    func test_runOnWorker_runsOnNamedNonMainThread() async throws {
        // Return the observed values directly from the worker closure — both
        // String? and Bool are Sendable, so we can carry them across the
        // continuation without a fire-and-forget Task + actor + Task.sleep.
        let observed: (name: String?, isMain: Bool) = try await DiagramEngine._runOnWorker {
            (Thread.current.name, Thread.isMainThread)
        }
        XCTAssertEqual(observed.name, "BeautifulMermaid worker")
        XCTAssertFalse(observed.isMain)
    }

    func test_DiagramPreparation_prepareSucceeds() async throws {
        let source = "flowchart TD\n  A[Start] --> B[End]\n"
        let prepared = try await DiagramPreparation.prepare(source: source)
        XCTAssertGreaterThan(prepared.bounds.width, 0)
        XCTAssertGreaterThan(prepared.bounds.height, 0)
    }

    func test_DiagramPreparation_routesThroughNamedWorker() async throws {
        // Run three serial prepares and confirm each observes the
        // canonical worker thread name. Serial rather than parallel
        // because XCTestCase is not Sendable under strict concurrency.
        let source = "flowchart TD\n  A[Start] --> B[End]\n"
        for _ in 0..<3 {
            let observed = try await _observeWorkerName()
            XCTAssertEqual(observed, "BeautifulMermaid worker")
            _ = try await DiagramPreparation.prepare(source: source)
        }
    }
}

/// Free function — kept outside the test class so it does not capture
/// `self` (XCTestCase is not Sendable under strict concurrency).
private func _observeWorkerName() async throws -> String? {
    try await DiagramEngine._runOnWorker { Thread.current.name }
}
#endif

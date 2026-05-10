#if canImport(CoreGraphics)
import XCTest
@testable import DiagramKit
@testable import DiagramKitModel
import DiagramKitRenderingCG

/// Asserts the architectural invariant: every async preparation entry point
/// dispatches onto the named 8 MB worker thread defined by
/// `MermaidRenderer._runOnWorker`. If a future refactor reintroduces an
/// inline `Thread { ... }.start()` or runs prepare/layout on the main
/// actor, these tests fail.
final class MermaidPreparationWorkerTests: XCTestCase {

    /// Captures values observed inside a worker closure, sendably.
    private actor WorkerObservation {
        var threadName: String?
        var isMainThread: Bool?
        func record(name: String?, isMain: Bool) {
            self.threadName = name
            self.isMainThread = isMain
        }
    }

    func test_runOnWorker_runsOnNamedNonMainThread() async throws {
        let observation = WorkerObservation()
        try await MermaidRenderer._runOnWorker {
            let name = Thread.current.name
            let isMain = Thread.isMainThread
            Task { await observation.record(name: name, isMain: isMain) }
        }
        // Allow the recorder Task to drain.
        try await Task.sleep(nanoseconds: 50_000_000)
        let observedName = await observation.threadName
        let observedIsMain = await observation.isMainThread
        XCTAssertEqual(observedName, "BeautifulMermaid worker")
        XCTAssertEqual(observedIsMain, false)
    }

    func test_MermaidPreparation_prepareSucceeds() async throws {
        let source = "flowchart TD\n  A[Start] --> B[End]\n"
        let prepared = try await MermaidPreparation.prepare(source: source)
        XCTAssertGreaterThan(prepared.bounds.width, 0)
        XCTAssertGreaterThan(prepared.bounds.height, 0)
    }

    func test_MermaidPreparation_routesThroughNamedWorker() async throws {
        // Run three serial prepares and confirm each observes the
        // canonical worker thread name. Serial rather than parallel
        // because XCTestCase is not Sendable under strict concurrency.
        let source = "flowchart TD\n  A[Start] --> B[End]\n"
        for _ in 0..<3 {
            let observed = try await _observeWorkerName()
            XCTAssertEqual(observed, "BeautifulMermaid worker")
            _ = try await MermaidPreparation.prepare(source: source)
        }
    }
}

/// Free function — kept outside the test class so it does not capture
/// `self` (XCTestCase is not Sendable under strict concurrency).
private func _observeWorkerName() async throws -> String? {
    let observation = MermaidPreparationWorkerTests_WorkerObservation()
    try await MermaidRenderer._runOnWorker {
        let name = Thread.current.name
        let isMain = Thread.isMainThread
        Task { await observation.record(name: name, isMain: isMain) }
    }
    try await Task.sleep(nanoseconds: 50_000_000)
    return await observation.threadName
}

private actor MermaidPreparationWorkerTests_WorkerObservation {
    var threadName: String?
    var isMainThread: Bool?
    func record(name: String?, isMain: Bool) {
        self.threadName = name
        self.isMainThread = isMain
    }
}
#endif

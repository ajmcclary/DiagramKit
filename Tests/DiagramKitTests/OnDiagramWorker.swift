@testable import DiagramKit

/// Runs `body` on the pipeline's 8 MB worker thread. swift-testing runs
/// tests on cooperative-pool threads whose stack is far smaller; tests that
/// lay out or render whole corpora call the synchronous `DiagramPipeline`
/// API through this, as the public async API does.
func onDiagramWorker<T: Sendable>(_ body: @escaping @Sendable () throws -> T) async throws -> T {
    try await DiagramEngine._runOnWorker(body)
}

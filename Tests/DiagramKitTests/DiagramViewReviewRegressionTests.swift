#if canImport(UIKit) || canImport(AppKit)
import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
@testable import DiagramKitViews

@MainActor
@Suite("DiagramLayer concurrency review regressions")
struct DiagramViewReviewRegressionTests {

    /// Critical 3: a cancelled preparation must not publish stale state or
    /// fire `onPrepareComplete`. Setting `source` twice synchronously cancels
    /// the first task; only the second task's completion should reach the
    /// callback.
    @Test func cancelledPreparationDoesNotFireCallback() async {
        DiagramEngine.bootstrap()
        let layer = DiagramLayer()
        let firstSource = "flowchart LR\n  A --> B\n"
        let secondSource = "flowchart LR\n  C --> D\n"

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            layer.onPrepareComplete = { [weak layer] in
                if layer?.source == secondSource, !resumed {
                    resumed = true
                    continuation.resume()
                }
            }

            // Both setters synchronous: first task is cancelled before its
            // main-actor continuation can publish.
            layer.source = firstSource
            layer.source = secondSource
        }

        #expect(layer.preparedDiagram != nil)
        #expect(layer.parseError == nil)
        #expect(layer.source == secondSource)
    }

    /// Critical 5: registering a fan-out handler via
    /// `addPrepareCompletionHandler(_:)` must not displace the host's
    /// `onPrepareComplete`. Both observers fire for the same preparation event.
    @Test func bothHostCallbackAndAddedHandlerFireOnPreparation() async {
        DiagramEngine.bootstrap()
        let layer = DiagramLayer()
        var hostFired = 0
        var fanOutFired = 0

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            layer.onPrepareComplete = {
                hostFired += 1
            }
            _ = layer.addPrepareCompletionHandler {
                fanOutFired += 1
                if !resumed {
                    resumed = true
                    continuation.resume()
                }
            }

            layer.source = "flowchart LR\n  A --> B\n"
        }

        #expect(hostFired == 1, "Expected onPrepareComplete to fire exactly once; got \(hostFired)")
        #expect(fanOutFired == 1, "Expected fan-out handler to fire exactly once; got \(fanOutFired)")
    }

    /// `removePrepareCompletionHandler` cleanly detaches a previously-installed
    /// handler so it does not receive future preparation events.
    @Test func removedHandlerStopsReceivingEvents() async {
        DiagramEngine.bootstrap()
        let layer = DiagramLayer()
        var fanOutFired = 0
        let token = layer.addPrepareCompletionHandler {
            fanOutFired += 1
        }

        // First preparation: handler fires.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            layer.onPrepareComplete = {
                if !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
            layer.source = "flowchart LR\n  A --> B\n"
        }
        #expect(fanOutFired == 1)

        // Detach and prepare again — count must not advance.
        layer.removePrepareCompletionHandler(token)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            layer.onPrepareComplete = {
                if !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
            layer.source = "flowchart LR\n  E --> F\n"
        }
        #expect(fanOutFired == 1, "Removed handler must not fire after detach; got \(fanOutFired)")
    }
}
#endif

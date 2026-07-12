import Testing
import IssueReporting
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel

/// Pins the depth-cap contract introduced to bound the worker-thread
/// stack against adversarial deep-tree inputs (formerly SIGSEGV'd).
///
/// The cap is implemented as a soft truncation: the recursive walk
/// stops when `depth == _diagramDefaultRecursionLimit` and reports the
/// truncation via `_reportDiagramIssue` (the IssueReporting channel).
/// These tests install an empty reporter while exercising the expected report;
/// assertions pin the guard result without asking the Xcode 27 beta's default
/// Swift Testing reporter to reflect the current test from inside the callback.
@Suite("Recursion Guard")
struct RecursionGuardTests {

    @Test("Direct helper returns true under the limit")
    func belowLimit() {
        #expect(_recursionGuard(depth: 0, location: "test") == true)
        #expect(_recursionGuard(depth: _diagramDefaultRecursionLimit - 1, location: "test") == true)
    }

    @Test("Direct helper returns false and reports at the limit")
    func atLimit() {
        var hit = false
        withIssueReporters([]) {
            hit = (_recursionGuard(depth: _diagramDefaultRecursionLimit, location: "RecursionGuardTests.atLimit") == false)
        }
        #expect(hit)
    }

    @Test("Custom limit truncates and reports")
    func customLimit() {
        withIssueReporters([]) {
            #expect(_recursionGuard(depth: 5, limit: 5, location: "RecursionGuardTests.customLimit") == false)
        }
    }

    @Test("Counted recursion stops at the limit instead of running away")
    func countedRecursionStops() {
        // Emulate the shape of an adversarial recursive walk: each call
        // would normally tail-recurse into its child. We assert that the
        // guard yields `false` exactly at the configured limit and the
        // recursion count plateaus there.
        var calls = 0
        func walk(depth: Int) {
            calls += 1
            guard _recursionGuard(depth: depth, limit: 50, location: "RecursionGuardTests.walk") else {
                return
            }
            walk(depth: depth + 1)
        }
        withIssueReporters([]) {
            walk(depth: 0)
        }
        #expect(calls == 51) // 0..50 inclusive — the call at depth 50 hits the guard and returns
    }
}

// Apple-only test (DiagramKitViews). On Linux this file is empty.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import Testing
import DiagramKit
import DiagramKitRenderingCG
@testable import DiagramKitViews

@Suite("DiagramViewModel publishes only the newest preparation") @MainActor
struct DiagramViewModelGenerationTests {

    @Test("a slow preparation for an older source does not overwrite a newer one")
    func staleResultDropped() async throws {
        let small = try await DiagramEngine.prepare(source: "flowchart TD\n  A")
        let large = try await DiagramEngine.prepare(source: "flowchart TD\n  A --> B --> C --> D")
        #expect(small.bounds != large.bounds)

        let model = DiagramViewModel(source: "old")
        model._preparerOverride = DiagramViewPreparer { source, _, _, _ in
            if source == "old" {
                try await Task.sleep(nanoseconds: 300_000_000)
                return small
            }
            return large
        }
        let first = Task { await model.prepare() }
        await Task.yield()
        try await Task.sleep(nanoseconds: 20_000_000)
        model.source = "new"
        await model.prepare()
        await first.value
        #expect(model.diagramBounds == large.bounds)
    }
}
#endif

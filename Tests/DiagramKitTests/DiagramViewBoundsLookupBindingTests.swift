#if canImport(UIKit) || canImport(AppKit)
import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
@testable import DiagramKitViews

@MainActor
@Suite("DiagramView bounds-lookup binding")
struct DiagramViewBoundsLookupBindingTests {

    @Test("PreparedDiagram exposes a non-nil lookup with node IDs after a successful prepare")
    func lookupPopulatedAfterSuccessfulPrepare() async {
        DiagramEngine.bootstrap()
        let layer = DiagramLayer()
        let source = "flowchart LR\n  A --> B\n"

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            layer.onPrepareComplete = { [weak layer] in
                if layer?.source == source, !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
            layer.source = source
        }

        let lookup = layer.preparedDiagram?.positioned.lookup
        #expect(lookup != nil)
        #expect(lookup?.allElementIDs.contains("node:A") == true)
        #expect(lookup?.allElementIDs.contains("node:B") == true)
    }

    @Test("PreparedDiagram is nil after a parse error so the lookup binding publishes nil")
    func lookupNilAfterParseError() async {
        DiagramEngine.bootstrap()
        let layer = DiagramLayer()
        let bogus = "not-a-diagram-source\n"

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            layer.onPrepareComplete = { [weak layer] in
                if layer?.source == bogus, !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
            layer.source = bogus
        }

        #expect(layer.preparedDiagram == nil)
        #expect(layer.parseError != nil)
    }

    @Test("DiagramView default initializer (no boundsLookup binding) compiles")
    func defaultInitializerCompiles() {
        // Compile-time check: existing call sites must keep working with the
        // new parameter's default value. Success is a clean build.
        if #available(macOS 26.0, iOS 26.0, macCatalyst 26.0, *) {
            _ = DiagramView(source: "")
        }
    }
}
#endif

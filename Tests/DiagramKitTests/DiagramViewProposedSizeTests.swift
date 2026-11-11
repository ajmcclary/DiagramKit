#if canImport(AppKit) && !canImport(UIKit)
import AppKit
import SwiftUI
import Testing
@testable import DiagramKit
@testable import DiagramKitViews

/// `DiagramView` must take the size SwiftUI gives it. The native view draws
/// the diagram scaled to its own bounds, so a host that frames the view at
/// 50% of the diagram's natural size gets a 50% drawing only if the native
/// view's frame really is that size. It used to keep its natural size (it
/// reported one as `intrinsicContentSize` and resisted compression), so the
/// drawing stayed at 100% and overflowed the frame from its centre.
@MainActor
@Suite("DiagramView proposed size")
struct DiagramViewProposedSizeTests {

    private static let source = "flowchart LR\n  A[Alpha] --> B[Beta] --> C[Gamma]\n"

    @Test("A view framed below its natural size reports that frame")
    func framedBelowNaturalSizeReportsThatFrame() async throws {
        let natural = try await Self.naturalSize()
        let framed = CGSize(
            width: (natural.width * 0.5).rounded(),
            height: (natural.height * 0.5).rounded()
        )

        let host = try await HostedDiagram(source: Self.source, frame: framed)
        defer { host.close() }

        #expect(host.nativeView.diagramBounds.size == natural)
        #expect(host.nativeView.frame.size == framed)
    }

    @Test("A view framed above its natural size reports that frame")
    func framedAboveNaturalSizeReportsThatFrame() async throws {
        let natural = try await Self.naturalSize()
        let framed = CGSize(
            width: (natural.width * 1.5).rounded(),
            height: (natural.height * 1.5).rounded()
        )

        let host = try await HostedDiagram(source: Self.source, frame: framed)
        defer { host.close() }

        #expect(host.nativeView.frame.size == framed)
    }

    @Test("An unframed view at its ideal size reports the diagram's natural size")
    func fixedSizeReportsNaturalSize() async throws {
        let natural = try await Self.naturalSize()

        let host = try await HostedDiagram(source: Self.source, frame: nil)
        defer { host.close() }

        // SwiftUI rounds the frame to whole pixels; the natural size is fractional.
        let size = host.nativeView.frame.size
        #expect(abs(size.width - natural.width) <= 1)
        #expect(abs(size.height - natural.height) <= 1)
    }

    // MARK: - Helpers

    /// The diagram's natural size, measured without any SwiftUI host.
    private static func naturalSize() async throws -> CGSize {
        DiagramEngine.bootstrap()
        let layer = DiagramLayer()
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
        let size = layer.diagramBounds.size
        try #require(size.width > 100 && size.height > 20, "fixture diagram is too small to halve meaningfully")
        return size
    }
}

/// The sizing policy behind `DiagramView.sizeThatFits`, shared by the AppKit
/// and UIKit representables.
@Suite("DiagramView sizing policy")
struct DiagramViewSizingTests {

    private let natural = CGSize(width: 400, height: 100)

    @Test("A fully specified proposal is taken as is, below or above natural size")
    func specifiedProposalIsTaken() {
        #expect(DiagramViewSizing.size(for: ProposedViewSize(width: 200, height: 50), naturalSize: natural)
            == CGSize(width: 200, height: 50))
        #expect(DiagramViewSizing.size(for: ProposedViewSize(width: 800, height: 300), naturalSize: natural)
            == CGSize(width: 800, height: 300))
        #expect(DiagramViewSizing.size(for: .zero, naturalSize: natural) == .zero)
    }

    @Test("An unspecified proposal gets the natural size")
    func unspecifiedProposalGetsNaturalSize() {
        #expect(DiagramViewSizing.size(for: .unspecified, naturalSize: natural) == natural)
    }

    @Test("A width below natural with no height keeps the aspect ratio")
    func narrowWidthScalesTheUnspecifiedHeight() {
        #expect(DiagramViewSizing.size(for: ProposedViewSize(width: 200, height: nil), naturalSize: natural)
            == CGSize(width: 200, height: 50))
        #expect(DiagramViewSizing.size(for: ProposedViewSize(width: nil, height: 25), naturalSize: natural)
            == CGSize(width: 100, height: 25))
    }

    @Test("A width above natural with no height keeps the natural height")
    func wideWidthKeepsTheNaturalHeight() {
        #expect(DiagramViewSizing.size(for: ProposedViewSize(width: 800, height: nil), naturalSize: natural)
            == CGSize(width: 800, height: 100))
        #expect(DiagramViewSizing.size(for: ProposedViewSize(width: nil, height: 300), naturalSize: natural)
            == CGSize(width: 400, height: 300))
    }

    @Test("An unprepared diagram has no natural size and still takes the proposal")
    func unpreparedDiagramTakesTheProposal() {
        #expect(DiagramViewSizing.size(for: ProposedViewSize(width: 300, height: 200), naturalSize: .zero)
            == CGSize(width: 300, height: 200))
        #expect(DiagramViewSizing.size(for: ProposedViewSize(width: 300, height: nil), naturalSize: .zero)
            == CGSize(width: 300, height: 0))
        #expect(DiagramViewSizing.size(for: .unspecified, naturalSize: .zero) == .zero)
    }

    @Test("NaN and negative proposals never reach the view's frame")
    func degenerateProposalsAreSanitised() {
        #expect(DiagramViewSizing.size(for: ProposedViewSize(width: .nan, height: .nan), naturalSize: natural)
            == natural)
        #expect(DiagramViewSizing.size(for: ProposedViewSize(width: -10, height: -10), naturalSize: natural)
            == .zero)
    }
}

/// A `DiagramView` hosted in a real window, laid out after the diagram has
/// been prepared.
@MainActor
private struct HostedDiagram {
    let window: NSWindow
    let nativeView: DiagramNativeView

    /// - Parameter frame: the SwiftUI frame to give the view, or `nil` to host
    ///   it at its ideal size (`fixedSize()`).
    init(source: String, frame: CGSize?) async throws {
        DiagramEngine.bootstrap()

        let diagram = DiagramView(source: source)
        let content: AnyView
        if let frame {
            content = AnyView(diagram.frame(width: frame.width, height: frame.height))
        } else {
            content = AnyView(diagram.fixedSize())
        }
        // A canvas far larger than the diagram, so neither the window nor the
        // hosting view is what limits the diagram's size.
        let root = content.frame(width: 2000, height: 2000)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 2000, height: 2000)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        self.window = window

        let native = try #require(Self.findNativeView(in: hosting), "DiagramView did not create its native view")
        self.nativeView = native

        // Preparation runs off the main actor; wait for it, then let SwiftUI
        // settle the layout it invalidated.
        var attempts = 0
        while native.diagramLayer.preparedDiagram == nil, attempts < 500 {
            try await Task.sleep(for: .milliseconds(10))
            attempts += 1
        }
        try #require(native.diagramLayer.preparedDiagram != nil, "diagram was not prepared in time")
        for _ in 0..<5 {
            await Task.yield()
            hosting.layoutSubtreeIfNeeded()
        }
    }

    func close() {
        window.contentView = nil
        window.close()
    }

    private static func findNativeView(in view: NSView) -> DiagramNativeView? {
        if let native = view as? DiagramNativeView { return native }
        for subview in view.subviews {
            if let native = findNativeView(in: subview) { return native }
        }
        return nil
    }
}
#endif

import Testing
import DiagramKitTestSupport
import Foundation

@Suite("RoundTripFixtureLoader")
struct RoundTripFixtureLoaderTests {

    @Test("Loads .md fixtures from mermaid-flowchart directory")
    func loadsMermaidFlowchartFixtures() throws {
        let loaded = try fixtures(for: "mermaid-flowchart", fromRoot: roundTripResourcesRoot())
        #expect(!loaded.isEmpty, "expected at least 01-basic.md")
        #expect(loaded.contains { $0.path.hasSuffix("01-basic.md") })
    }

    @Test("Sidecar JSON populates additionalAllowedLosses")
    func sidecarJSON() throws {
        // We synthesise a sidecar at runtime to exercise the loader without
        // committing a sidecar-only fixture. Use the temp dir.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("rt-loader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent("foo-flowchart"),
            withIntermediateDirectories: true
        )
        try "graph TD\nA-->B".write(
            to: tmp.appendingPathComponent("foo-flowchart/01-basic.md"),
            atomically: true,
            encoding: .utf8
        )
        try #"{"additionalAllowedLosses":["shapeDowngrade"],"note":"test"}"#.write(
            to: tmp.appendingPathComponent("foo-flowchart/01-basic.json"),
            atomically: true,
            encoding: .utf8
        )
        defer { try? FileManager.default.removeItem(at: tmp) }

        let loaded = try fixtures(for: "foo-flowchart", fromRoot: tmp)
        #expect(loaded.count == 1)
        #expect(loaded[0].additionalAllowedLosses == [.shapeDowngrade])
        #expect(loaded[0].note == "test")
    }
}

/// Resolves the absolute URL of `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`
/// from the location of this test file. Mirrors the projectRoot()-from-#filePath
/// pattern used by CorpusSnapshotTests.
func roundTripResourcesRoot(file: StaticString = #filePath) -> URL {
    URL(fileURLWithPath: "\(file)")
        .deletingLastPathComponent()
        .appendingPathComponent("Resources/roundtrip", isDirectory: true)
}

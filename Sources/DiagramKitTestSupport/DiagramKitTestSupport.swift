/// UNSUPPORTED TOOLING PRODUCT — not part of DiagramKit's supported public
/// API and exempt from semver stability. This product ships the round-trip
/// harness (`RoundTripHarness`, `RoundTripLoss`, `RoundTripDelta`,
/// `DiagramDocumentDiff`), the round-trip fixture loader, and the corpus
/// re-export. It exists so DiagramKit's own test suites (and the workspace's
/// path-dependency app) can share them; the surface may change or be
/// withdrawn in any release without a deprecation cycle. Consumers outside
/// this repository should not take a dependency on it.
///
/// Namespace for shared test fixtures and helpers.
///
/// Kept as an empty `public enum` so the library product `DiagramKitTestSupport`
/// has a stable, importable symbol surface even when the corpus loader and
/// other helpers live in their own files (`CorpusEntry.swift`,
/// `CorpusFile.swift`, etc.). Removing this type would change the
/// `import DiagramKitTestSupport` source compatibility story for downstream
/// test fixtures, so it stays.
public enum DiagramKitTestSupport {}

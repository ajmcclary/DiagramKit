/// Namespace for shared test fixtures and helpers.
///
/// Kept as an empty `public enum` so the library product `DiagramKitTestSupport`
/// has a stable, importable symbol surface even when the corpus loader and
/// other helpers live in their own files (`CorpusEntry.swift`,
/// `CorpusFile.swift`, etc.). Removing this type would change the
/// `import DiagramKitTestSupport` source compatibility story for downstream
/// test fixtures, so it stays.
public enum DiagramKitTestSupport {}

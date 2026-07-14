// The corpus schema (`CorpusEntry`, `CorpusFile`, `ExpectedDiagnostic`,
// `CorpusEntryError`) and the canonical `test-diagrams.json` fixture now live
// in the `DiagramKitCorpus` target — the single source of truth shared by
// DiagramKit's corpus-driven suites and the apps/DiagramStudio playground.
// Re-export it here so existing `import DiagramKitTestSupport` call sites keep
// seeing those types without an extra import.
@_exported import DiagramKitCorpus

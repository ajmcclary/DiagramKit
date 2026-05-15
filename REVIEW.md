# DiagramKit Code Review — Remaining Work

The original six-reviewer code review (architecture/public-API, model, rendering+views, format slices, playground+interactive editor, tests/gates/concurrency) and all Deferred Effort items §1–§7 are closed end-to-end across Phases 1–5 and Sessions 1–16. Cross-cutting Observations #1–#5 are closed. Historical session-by-session detail and the original Critical/Important/Minor tier inventories have been removed from this file; `git log` is authoritative for what landed when.

The items below are the genuine open backlog. None block merge.

---

## Deferred from Session 16 — Playground accessibility pass

1. **Inspector layout bug (product issue).** With the inspector open, the playground's right-side inspector panel covers the preview surface entirely instead of sitting alongside it. Preview-related controls (`preview.fit`, `preview.mode`, etc.) are not visible while the inspector is open. The UI tests work around this by loading the diagram with the inspector closed for preview tests (`editingFlow1`) and opening it only for editor-pane tests (`editingFlow1Inspector`). Underlying layout regression needs a fix in `LiveEditorView` / inspector docking.

2. **Xcode 26.4 / xcodebuild quirk.** Class-level `-only-testing:<class>` filters reproducibly fail with `The bundle identifier for DiagramPlayground couldn't be read. No such file or directory: ".../Debug/DiagramPlayground"` (note the missing `.app` extension). The error fires during pre-test setup, before any test runs. Single test-method runs (`-only-testing:<class>/<method>`) work. Setting `TEST_HOST` explicitly conflicts with `USES_XCTRUNNER` (`bundle.ui-testing` type). Workaround is documented in `Scripts/playground-a11y-check.sh`: enumerate every test by `<class>/<method>`. Worth deeper investigation.

---

## §5 Opportunistic polish backlog

Pick these up when touching the relevant file; not worth a standalone pass.

- **Files over the 500-line warn threshold** (allowlisted, but split candidates):
  - Library: `src_ascii_index.swift`, `DiagramRenderer+Sequence.swift`, `ShapeRenderer.swift`, `DiagramRenderer+Wardley.swift`, `src_sequence_renderer.swift`, `src_er_renderer.swift`, `src_class_renderer.swift`, `src_xychart_renderer.swift`.
  - Playground: `LiveEditorStore.swift`, `SampleDiagrams.swift`, `PreviewCanvas.swift`, `ActionsView.swift`, `DiagramEditorPane.swift`, `NativeCodeEditor.swift`.
- **`DiagramEditor+Mutations.swift`** — near-identical `.flowchart` / `.stateDiagram` blocks in `_deleteElement` and `_setLabel` (~80 dup lines).
- **`LiveEditorToolbar.swift`** — duplicated Cmd-I markup at `:96-105` and `:179-187`; one helper would keep icon/state in sync.
- **`AsciiVisualReportGenerator.swift` / `VisualReportGenerator.swift` / `ExampleImageExporter.swift`** are env-gated but still discovered by `swift test`. Reclassified as design-required (Session 3): XCTest discovery is class-based, not filename-based, so filename renames alone don't clean the listing — needs a separate test target.

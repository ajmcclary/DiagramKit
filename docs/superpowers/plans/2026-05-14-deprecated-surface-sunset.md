# Deprecated Surface Sunset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete every `@available(*, deprecated, renamed:)` shim in the `DiagramKit` umbrella belonging to the Phase 0 (Mermaid→Diagram rename), Session 7 (free-function deprecation), and Session 8 (`MermaidPreparerBootstrap` alias) cohort, after migrating every in-tree caller to the canonical API. End state: zero "Will be removed in the next major version" warnings from in-tree builds.

**Architecture:** Six mechanical phases on `main` (no worktrees, no branches per project standing default). Phases 1–2 migrate test callsites; Phase 4 migrates the sole source-side caller; Phase 5 deletes the legacy test file; Phase 6 deletes the deprecated symbols atomically; Phase 7 syncs docs. Phase 3 collapsed during plan-time grep because zero in-tree callers exist for the String-instance Mermaid* methods.

**Tech Stack:** Swift 6, SwiftPM, swift-testing (some XCTest legacy), swift-snapshot-testing.

**Spec:** `docs/superpowers/specs/2026-05-14-deprecated-surface-sunset-design.md` (commit `040573f`).

---

## Standing Conventions (Project)

- Commit-by-commit on `main`. No worktrees, no branches.
- Targeted `swift test --filter <Suite>` only. Full `swift test` runs are too slow and hit the pre-existing `CorpusSnapshotTests` signal-10.
- Once a test has passed, do not re-run it for confirmation; move on.
- The `CorpusSnapshotTests` signal-10 is pre-existing and NOT a regression of this work.

---

## Canonical Migration Patterns

These five patterns cover every callsite touched in Phases 1, 2, and 4. Apply mechanically.

**Pattern A — async free function, no options:**
```diff
-let svg = try await renderDiagramSVG(source)
+let svg = try await DiagramEngine.renderSVG(source: source)
```

**Pattern B — async free function with empty RenderOptions:**
```diff
-let svg = try await renderDiagramSVG(source, RenderOptions())
+let svg = try await DiagramEngine.renderSVG(source: source)
```

**Pattern C — async free function with stable idPolicy:**
```diff
-let svg = try await renderDiagramSVG(source, RenderOptions(idPolicy: .stable))
+let svg = try await DiagramEngine.renderSVG(source: source, idPolicy: .stable)
```

**Pattern D — sync internal SPI, no options:**
```diff
-let svg = try _renderDiagramSVG(source)
+let svg = try DiagramPipeline.renderSVG(source: source)
```

**Pattern E — sync internal SPI with stable idPolicy:**
```diff
-let svg = try _renderDiagramSVG(source, RenderOptions(idPolicy: .stable))
+let svg = try DiagramPipeline.renderSVG(source: source, idPolicy: .stable)
```

Variants of `renderMermaidSVG` / `renderMermaidSVGAsync` / `renderMermaid` / `renderDiagramSVGAsync` are all renamed-to → `renderDiagramSVG`, so they map to the same Pattern A/B/C target.

---

## File Structure

Files touched across the plan:

**Test files (Phases 1, 2, 5):** 28 files in `Tests/DiagramKitTests/`. Listed per-task below.

**Source files (Phase 4, 6):**
- `Sources/DiagramKit/DiagramImageRenderer.swift` (Phase 4 — line 103-119 `renderSVGSync`)
- `Sources/DiagramKit/MermaidImporter.swift` (Phase 4 — stale comment at line 39)
- `Sources/DiagramKit/src_index.swift` (Phase 6 — delete entire deprecated public surface + `_renderDiagramSVG` + `buildColors`)
- `Sources/DiagramKit/Deprecations.swift` (Phase 6 — delete entire file)
- `Sources/DiagramKit/DiagramEngine.swift` (Phase 6 — delete `*Async` shims and String Mermaid* methods)
- `Sources/DiagramKit/DiagramPipeline.swift` (Phase 6 — delete `renderSVG(_:options:)` orphan)
- `Sources/DiagramKit/DiagramPreparerWiring.swift` (Phase 6 — delete `_MermaidPreparerBootstrap` typealias)

**Doc files (Phase 7):**
- `CLAUDE.md`
- `ARCHITECTURE.md` (scan)
- `REVIEW.md` (Session 12 row)

---

### Task 1: Phase 1a — Async sweep, batch A

**Files:**
- Modify: `Tests/DiagramKitTests/ArchitectureRendererTests.swift` (async callsites only; sync `_renderDiagramSVG` calls migrate in Phase 2)
- Modify: `Tests/DiagramKitTests/BeautifulMermaidSwiftTests.swift`
- Modify: `Tests/DiagramKitTests/BlockSvgTests.swift` (async callsites only)
- Modify: `Tests/DiagramKitTests/ERParserTests+Foundation.swift`
- Modify: `Tests/DiagramKitTests/ERRendererTests.swift`
- Modify: `Tests/DiagramKitTests/EventModelingTests.swift`
- Modify: `Tests/DiagramKitTests/FlowchartELKFallbackTests.swift`

- [ ] **Step 1: Enumerate callsites per file**

For each of the seven files, run:
```bash
grep -nE 'renderDiagramSVG\b|renderDiagramSVGAsync\b|renderMermaidSVG\b|renderMermaidSVGAsync\b|renderMermaid\b' <file>
```
Important: do NOT touch `_renderDiagramSVG` (underscore prefix). Those migrate in Phase 2.

- [ ] **Step 2: Apply Patterns A / B / C to each callsite**

Each match is one of three shapes:
- `try await renderDiagramSVG(X)` → Pattern A
- `try await renderDiagramSVG(X, RenderOptions())` → Pattern B
- `try await renderDiagramSVG(X, RenderOptions(idPolicy: .stable))` → Pattern C

Also rename `renderMermaidSVG` / `renderMermaidSVGAsync` / `renderMermaid` / `renderDiagramSVGAsync` callsites to the same `DiagramEngine.renderSVG(source:)` form (all four map to the same canonical target). The argument label `source:` is required.

For multi-line `"""…"""` literals, the first positional arg becomes `source: """…"""`. Watch indentation — Swift parses the closing `"""` based on its indent.

- [ ] **Step 3: Verify per-suite tests pass**

```bash
swift test --filter "ArchitectureRendererTests|BeautifulMermaidSwiftTests|BlockSvgTests|ERParserTests|ERRendererTests|EventModelingTests|FlowchartELKFallbackTests"
```
Expected: green. Mix of `@Test` and `XCTestCase` is normal.

- [ ] **Step 4: Commit**

```bash
git add Tests/DiagramKitTests/ArchitectureRendererTests.swift \
        Tests/DiagramKitTests/BeautifulMermaidSwiftTests.swift \
        Tests/DiagramKitTests/BlockSvgTests.swift \
        Tests/DiagramKitTests/ERParserTests+Foundation.swift \
        Tests/DiagramKitTests/ERRendererTests.swift \
        Tests/DiagramKitTests/EventModelingTests.swift \
        Tests/DiagramKitTests/FlowchartELKFallbackTests.swift

git commit -m "$(cat <<'EOF'
refactor(tests): migrate async renderDiagramSVG → DiagramEngine (batch 1a)

Seven test files migrate from the deprecated renderDiagramSVG /
renderMermaidSVG free functions to DiagramEngine.renderSVG(source:).
RenderOptions() drops; .stable idPolicy becomes a direct parameter.
Sync _renderDiagramSVG callsites in Architecture/Block migrate in
Phase 2.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Phase 1b — Async sweep, batch B

**Files:**
- Modify: `Tests/DiagramKitTests/FlowchartSecurityTests.swift`
- Modify: `Tests/DiagramKitTests/FlowchartVisualDiffTests.swift`
- Modify: `Tests/DiagramKitTests/IconImageRendererTests.swift`
- Modify: `Tests/DiagramKitTests/IshikawaRendererTests.swift`
- Modify: `Tests/DiagramKitTests/KanbanRendererTests.swift`
- Modify: `Tests/DiagramKitTests/MindmapRendererTests.swift`
- Modify: `Tests/DiagramKitTests/QuadrantSvgTests.swift` (async callsites only)

- [ ] **Step 1: Enumerate callsites per file**

```bash
grep -nE 'renderDiagramSVG\b|renderDiagramSVGAsync\b|renderMermaidSVG\b|renderMermaidSVGAsync\b|renderMermaid\b' \
  Tests/DiagramKitTests/FlowchartSecurityTests.swift \
  Tests/DiagramKitTests/FlowchartVisualDiffTests.swift \
  Tests/DiagramKitTests/IconImageRendererTests.swift \
  Tests/DiagramKitTests/IshikawaRendererTests.swift \
  Tests/DiagramKitTests/KanbanRendererTests.swift \
  Tests/DiagramKitTests/MindmapRendererTests.swift \
  Tests/DiagramKitTests/QuadrantSvgTests.swift
```
Important: do NOT touch `_renderDiagramSVG` (underscore prefix). Those migrate in Phase 2.

- [ ] **Step 2: Apply Patterns A / B / C to each callsite**

Each match is one of three shapes — Pattern A (no options), B (empty `RenderOptions()`), or C (`RenderOptions(idPolicy: .stable)`) — defined at the top of this plan. `renderMermaidSVG` / `renderMermaidSVGAsync` / `renderMermaid` / `renderDiagramSVGAsync` all rename to the same `DiagramEngine.renderSVG(source:)` target.

- [ ] **Step 3: Verify per-suite tests pass**

```bash
swift test --filter "FlowchartSecurityTests|FlowchartVisualDiffTests|IconImageRendererTests|IshikawaRendererTests|KanbanRendererTests|MindmapRendererTests|QuadrantSvgTests"
```

- [ ] **Step 4: Commit**

```bash
git add Tests/DiagramKitTests/FlowchartSecurityTests.swift \
        Tests/DiagramKitTests/FlowchartVisualDiffTests.swift \
        Tests/DiagramKitTests/IconImageRendererTests.swift \
        Tests/DiagramKitTests/IshikawaRendererTests.swift \
        Tests/DiagramKitTests/KanbanRendererTests.swift \
        Tests/DiagramKitTests/MindmapRendererTests.swift \
        Tests/DiagramKitTests/QuadrantSvgTests.swift

git commit -m "$(cat <<'EOF'
refactor(tests): migrate async renderDiagramSVG → DiagramEngine (batch 1b)

Seven test files (FlowchartSecurity, FlowchartVisualDiff,
IconImageRenderer, IshikawaRenderer, KanbanRenderer, MindmapRenderer,
QuadrantSvg) migrate the async deprecation surface to
DiagramEngine.renderSVG(source:). Sync _renderDiagramSVG callsite in
QuadrantSvg migrates in Phase 2.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Note: this task's Step 1 enumerates callsites, Step 2 applies Patterns A/B/C, Step 3 verifies the suite, Step 4 commits. The four-step pattern repeats in Tasks 3 and 4.

---

### Task 3: Phase 1c — Async sweep, batch C

**Files:**
- Modify: `Tests/DiagramKitTests/RadarEndToEndTests.swift`
- Modify: `Tests/DiagramKitTests/RequirementRendererTests.swift`
- Modify: `Tests/DiagramKitTests/SemicolonSeparatorTests.swift`
- Modify: `Tests/DiagramKitTests/TimelineRendererTests.swift` (async callsites only)
- Modify: `Tests/DiagramKitTests/TimelineSvgTests.swift` (async callsites only)
- Modify: `Tests/DiagramKitTests/TreeViewPipelineTests.swift`
- Modify: `Tests/DiagramKitTests/TreeViewSvgTests.swift`

- [ ] **Step 1: Enumerate callsites per file**

```bash
grep -nE 'renderDiagramSVG\b|renderDiagramSVGAsync\b|renderMermaidSVG\b|renderMermaidSVGAsync\b|renderMermaid\b' \
  Tests/DiagramKitTests/RadarEndToEndTests.swift \
  Tests/DiagramKitTests/RequirementRendererTests.swift \
  Tests/DiagramKitTests/SemicolonSeparatorTests.swift \
  Tests/DiagramKitTests/TimelineRendererTests.swift \
  Tests/DiagramKitTests/TimelineSvgTests.swift \
  Tests/DiagramKitTests/TreeViewPipelineTests.swift \
  Tests/DiagramKitTests/TreeViewSvgTests.swift
```
Do NOT touch `_renderDiagramSVG` matches (Phase 2).

- [ ] **Step 2: Apply Patterns A / B / C to each callsite**

Three shapes — Pattern A (no options), B (empty `RenderOptions()`), C (`.stable` idPolicy) — defined at the top of this plan. All `renderMermaid*` variants rename to `DiagramEngine.renderSVG(source:)`.

- [ ] **Step 3: Verify per-suite tests pass**

```bash
swift test --filter "RadarEndToEndTests|RequirementRendererTests|SemicolonSeparatorTests|TimelineRendererTests|TimelineSvgTests|TreeViewPipelineTests|TreeViewSvgTests"
```

- [ ] **Step 4: Commit**

```bash
git add Tests/DiagramKitTests/RadarEndToEndTests.swift \
        Tests/DiagramKitTests/RequirementRendererTests.swift \
        Tests/DiagramKitTests/SemicolonSeparatorTests.swift \
        Tests/DiagramKitTests/TimelineRendererTests.swift \
        Tests/DiagramKitTests/TimelineSvgTests.swift \
        Tests/DiagramKitTests/TreeViewPipelineTests.swift \
        Tests/DiagramKitTests/TreeViewSvgTests.swift

git commit -m "$(cat <<'EOF'
refactor(tests): migrate async renderDiagramSVG → DiagramEngine (batch 1c)

Seven test files (Radar, Requirement, SemicolonSeparator, Timeline×2,
TreeView×2) migrate the async deprecation surface to
DiagramEngine.renderSVG(source:). Sync _renderDiagramSVG callsites in
Timeline×2 migrate in Phase 2.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Phase 1d — Async sweep, batch D

**Files:**
- Modify: `Tests/DiagramKitTests/TreemapEndToEndTests.swift`
- Modify: `Tests/DiagramKitTests/VennEndToEndTests.swift`
- Modify: `Tests/DiagramKitTests/VerificationStepExporterTests.swift`
- Modify: `Tests/DiagramKitTests/WardleyMapEndToEndTests.swift` (async callsites only)
- Modify: `Tests/DiagramKitTests/XYChartCrashRegressionTests.swift`
- Modify: `Tests/DiagramKitTests/XYChartSvgTests.swift`
- Modify: `Tests/DiagramKitTests/ZenUMLSvgTests.swift` (async callsites only)

- [ ] **Step 1: Enumerate callsites per file**

```bash
grep -nE 'renderDiagramSVG\b|renderDiagramSVGAsync\b|renderMermaidSVG\b|renderMermaidSVGAsync\b|renderMermaid\b' \
  Tests/DiagramKitTests/TreemapEndToEndTests.swift \
  Tests/DiagramKitTests/VennEndToEndTests.swift \
  Tests/DiagramKitTests/VerificationStepExporterTests.swift \
  Tests/DiagramKitTests/WardleyMapEndToEndTests.swift \
  Tests/DiagramKitTests/XYChartCrashRegressionTests.swift \
  Tests/DiagramKitTests/XYChartSvgTests.swift \
  Tests/DiagramKitTests/ZenUMLSvgTests.swift
```
Do NOT touch `_renderDiagramSVG` matches (Phase 2).

- [ ] **Step 2: Apply Patterns A / B / C to each callsite**

Three shapes — Pattern A (no options), B (empty `RenderOptions()`), C (`.stable` idPolicy) — defined at the top of this plan. All `renderMermaid*` variants rename to `DiagramEngine.renderSVG(source:)`.

- [ ] **Step 3: Verify per-suite tests pass**

```bash
swift test --filter "TreemapEndToEndTests|VennEndToEndTests|VerificationStepExporterTests|WardleyMapEndToEndTests|XYChartCrashRegressionTests|XYChartSvgTests|ZenUMLSvgTests"
```

- [ ] **Step 4: Confirm Phase 1 complete**

After this commit, every async-deprecation-surface callsite in `Tests/` should be gone:

```bash
grep -rn 'renderDiagramSVG\b\|renderDiagramSVGAsync\b\|renderMermaidSVG\b\|renderMermaidSVGAsync\b\|renderMermaid\b' Tests/ | grep -v '_renderDiagramSVG'
```
Expected: no hits.

- [ ] **Step 5: Commit**

```bash
git add Tests/DiagramKitTests/TreemapEndToEndTests.swift \
        Tests/DiagramKitTests/VennEndToEndTests.swift \
        Tests/DiagramKitTests/VerificationStepExporterTests.swift \
        Tests/DiagramKitTests/WardleyMapEndToEndTests.swift \
        Tests/DiagramKitTests/XYChartCrashRegressionTests.swift \
        Tests/DiagramKitTests/XYChartSvgTests.swift \
        Tests/DiagramKitTests/ZenUMLSvgTests.swift

git commit -m "$(cat <<'EOF'
refactor(tests): migrate async renderDiagramSVG → DiagramEngine (batch 1d)

Seven test files (Treemap, Venn, VerificationStepExporter, WardleyMap,
XYChart×2, ZenUML) migrate the async deprecation surface to
DiagramEngine.renderSVG(source:). Closes Phase 1 — every async free-
function callsite under Tests/ is now retired. Sync _renderDiagramSVG
callsites in Wardley/ZenUML migrate in Phase 2.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Phase 2 — Sync test sweep

**Files (seven files):**
- Modify: `Tests/DiagramKitTests/ArchitectureRendererTests.swift` (sync `_renderDiagramSVG` callsites only)
- Modify: `Tests/DiagramKitTests/BlockSvgTests.swift` (sync only)
- Modify: `Tests/DiagramKitTests/QuadrantSvgTests.swift` (sync only)
- Modify: `Tests/DiagramKitTests/TimelineRendererTests.swift` (sync only)
- Modify: `Tests/DiagramKitTests/TimelineSvgTests.swift` (sync only)
- Modify: `Tests/DiagramKitTests/WardleyMapEndToEndTests.swift` (sync only)
- Modify: `Tests/DiagramKitTests/ZenUMLSvgTests.swift` (sync only)

Note: the spec said "six files"; the precise grep returned seven. Plan reflects reality.

- [ ] **Step 1: Enumerate sync callsites per file**

```bash
grep -nE '_renderDiagramSVG\b' Tests/DiagramKitTests/ArchitectureRendererTests.swift Tests/DiagramKitTests/BlockSvgTests.swift Tests/DiagramKitTests/QuadrantSvgTests.swift Tests/DiagramKitTests/TimelineRendererTests.swift Tests/DiagramKitTests/TimelineSvgTests.swift Tests/DiagramKitTests/WardleyMapEndToEndTests.swift Tests/DiagramKitTests/ZenUMLSvgTests.swift
```

- [ ] **Step 2: Apply Patterns D / E to each callsite**

Each match is one of two shapes:
- `try _renderDiagramSVG(X)` → Pattern D
- `try _renderDiagramSVG(X, RenderOptions(idPolicy: .stable))` → Pattern E

These remain `try` (not `try await`) — `DiagramPipeline.renderSVG(source:)` is sync.

- [ ] **Step 3: Verify per-suite tests pass**

```bash
swift test --filter "ArchitectureRendererTests|BlockSvgTests|QuadrantSvgTests|TimelineRendererTests|TimelineSvgTests|WardleyMapEndToEndTests|ZenUMLSvgTests"
```

- [ ] **Step 4: Confirm Phase 2 complete**

```bash
grep -rn '_renderDiagramSVG\b' Tests/
```
Expected: no hits.

- [ ] **Step 5: Commit**

```bash
git add Tests/DiagramKitTests/ArchitectureRendererTests.swift \
        Tests/DiagramKitTests/BlockSvgTests.swift \
        Tests/DiagramKitTests/QuadrantSvgTests.swift \
        Tests/DiagramKitTests/TimelineRendererTests.swift \
        Tests/DiagramKitTests/TimelineSvgTests.swift \
        Tests/DiagramKitTests/WardleyMapEndToEndTests.swift \
        Tests/DiagramKitTests/ZenUMLSvgTests.swift

git commit -m "$(cat <<'EOF'
refactor(tests): migrate sync _renderDiagramSVG → DiagramPipeline

Seven test files retire the underscored SPI _renderDiagramSVG in
favor of the canonical DiagramPipeline.renderSVG(source:theme:
layoutConfig:idPolicy:). Same sync semantics; .stable idPolicy
routes through the engine's first-class parameter. Closes Phase 2.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Phase 4 — Source-side migration

Phase 3 of the spec collapsed at plan-time: zero in-tree callers exist for the String-instance Mermaid* shims (the earlier-counted 10 callsites were false positives from the unrelated `original_src_ascii_index.renderMermaidASCII` class method). Those shims are deleted in Phase 6 without prior migration.

**Files:**
- Modify: `Sources/DiagramKit/DiagramImageRenderer.swift:103-119` (rewrite `renderSVGSync` to call `DiagramPipeline.renderSVG` directly)
- Modify: `Sources/DiagramKit/MermaidImporter.swift:39` (remove stale comment referencing `MermaidParser.parse`)

- [ ] **Step 1: Rewrite `DiagramImageRenderer.renderSVGSync`**

Replace lines 103-119 of `Sources/DiagramKit/DiagramImageRenderer.swift`:

```diff
-    func renderSVGSync(from source: String, idPolicy: SVGIDPolicy = .unique) throws -> String {
-        let options = RenderOptions(
-            bg: _hex(theme.background),
-            fg: _hex(theme.foreground),
-            line: _hex(theme.effectiveLine()),
-            accent: _hex(theme.effectiveAccent()),
-            muted: _hex(theme.effectiveMuted()),
-            surface: _hex(theme.effectiveSurface()),
-            border: _hex(theme.effectiveBorder()),
-            transparent: false,
-            idPolicy: idPolicy
-        )
-
-        let svg = try _renderDiagramSVG(source, options, layoutConfig: layoutConfig)
-        let resolvedSvg = _resolveSvgCssVariables(svg)
-        return _flattenKnownSvgTokens(resolvedSvg, theme: theme)
-    }
+    func renderSVGSync(from source: String, idPolicy: SVGIDPolicy = .unique) throws -> String {
+        try DiagramPipeline.renderSVG(
+            source: source,
+            theme: theme,
+            layoutConfig: layoutConfig,
+            idPolicy: idPolicy
+        )
+    }
```

Why this is safe: `DiagramPipeline.renderSVG(source:theme:layoutConfig:idPolicy:)` internally constructs `DiagramColors` via `theme.effective*()` (DiagramPipeline.swift:153-161) — semantically identical to the old `buildColors(_:)` round-trip. It also already runs `_resolveSvgCssVariables` and `_flattenKnownSvgTokens` (DiagramPipeline.swift:172-173). The change collapses three layers (`_renderDiagramSVG` + manual post-process) into one canonical call.

The `_hex` helper, `transparent: false`, and the `RenderOptions` allocation are all dead after this change. They go away with the surrounding deletion in Phase 6 (no separate cleanup needed in this commit — `_hex` is still used by other code in this file; do NOT delete it here).

- [ ] **Step 2: Remove stale comment in MermaidImporter**

`Sources/DiagramKit/MermaidImporter.swift:39` currently reads:
```swift
        // Replicate existing MermaidParser.parse() logic.
```
Delete this single line. The function's intent is self-documenting.

- [ ] **Step 3: Verify build + image renderer tests**

```bash
swift build
swift test --filter "DiagramImageRendererTests|IconImageRendererTests"
```
Expected: build clean (modulo deprecation warnings on the surfaces still slated for Phase 6 deletion); tests green.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKit/DiagramImageRenderer.swift \
        Sources/DiagramKit/MermaidImporter.swift

git commit -m "$(cat <<'EOF'
refactor(image): route renderSVGSync through DiagramPipeline.renderSVG

DiagramImageRenderer.renderSVGSync no longer round-trips the theme
through a RenderOptions allocation and the underscored
_renderDiagramSVG SPI; it now calls the canonical
DiagramPipeline.renderSVG(source:theme:layoutConfig:idPolicy:) which
already runs the same buildColors + CSS-variable + token-flatten
chain internally. Semantically identical, structurally simpler.
Drive-by: strip the stale "Replicate existing MermaidParser.parse()
logic" comment from MermaidImporter.swift:39.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Phase 5 — Delete MermaidLegacyAPITests.swift

**Files:**
- Delete: `Tests/DiagramKitTests/MermaidLegacyAPITests.swift`

- [ ] **Step 1: Confirm file purpose is exhausted**

```bash
cat Tests/DiagramKitTests/MermaidLegacyAPITests.swift
```
Expected: the file references `MermaidParser`, `MermaidRenderer`, `MermaidPipeline`, `MermaidImageRenderer`, or `MermaidStructuralError` — i.e., only the deprecation surface being deleted in Phase 6. No coverage of canonical types.

- [ ] **Step 2: Delete the file**

```bash
git rm Tests/DiagramKitTests/MermaidLegacyAPITests.swift
```

- [ ] **Step 3: Verify build still compiles**

```bash
swift build --build-tests
```
Expected: clean build. (No filtered test run needed — the suite no longer exists.)

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
test(legacy): delete MermaidLegacyAPITests

The file's sole purpose was exercising the @available(*, deprecated)
Mermaid* aliases (MermaidParser, MermaidRenderer, MermaidPipeline,
MermaidImageRenderer, MermaidStructuralError) — the entire cohort
goes away in Phase 6. The canonical Diagram* types have dedicated
test coverage already.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Phase 6 — Atomic deletion of deprecated surface

**Files:**
- Modify (or delete): `Sources/DiagramKit/src_index.swift`
- Delete: `Sources/DiagramKit/Deprecations.swift`
- Modify: `Sources/DiagramKit/DiagramEngine.swift` (delete `*Async` static shims + String Mermaid* instance methods)
- Modify: `Sources/DiagramKit/DiagramPipeline.swift` (delete `renderSVG(_:options:)` orphan at line 210)
- Modify: `Sources/DiagramKit/DiagramPreparerWiring.swift` (delete `_MermaidPreparerBootstrap` typealias at lines 60-64)

This is the load-bearing commit. Six file edits in one logical change. Verify build and snapshot canary BEFORE committing.

- [ ] **Step 1: Edit `src_index.swift`**

Delete the entire public surface plus the internal `_renderDiagramSVG` SPI. Remove:
- `renderDiagramSVG(_:_:)` (lines 76-84)
- `renderDiagramSVGAsync(_:_:)` (lines 86-94)
- `renderMermaidSVG(_:_:)` (lines 98-104)
- `renderMermaidSVGAsync(_:_:)` (lines 106-112)
- `renderMermaid(_:_:)` (lines 114-120)
- `_renderDiagramSVG(_:_:layoutConfig:)` (lines 43-66)
- `buildColors(_:)` private helper (lines 24-34)
- `_IndexDefaults` enum (lines 11-14, only used by `buildColors`)

What remains: the file header comment + `original_src_index` empty class (lines 122-124).

Decision point: if the surviving content is **only** `original_src_index` (a Phase-0 placeholder shell with no callers anywhere), delete the entire file:

```bash
grep -rn '\boriginal_src_index\b' Sources/ Tests/ Examples/
```

If the grep returns nothing outside `src_index.swift` itself, prefer `git rm Sources/DiagramKit/src_index.swift`. Otherwise keep the file but trim it to the minimum.

- [ ] **Step 2: Delete `Deprecations.swift`**

```bash
git rm Sources/DiagramKit/Deprecations.swift
```

- [ ] **Step 3: Edit `DiagramEngine.swift`**

Delete the following methods (line numbers approximate; locate by name):
- `static func renderImageAsync(source:theme:scale:)` (line ~200)
- `static func renderSVGAsync(source:theme:)` (line ~211)
- `static func renderASCIIAsync(source:theme:)` (line ~218)
- `static func prepareAsync(source:theme:layoutConfig:)` (line ~229)
- String-instance method `parseMermaid()` (line ~244)
- String-instance method `renderMermaidImage(theme:scale:)` (line ~259)
- String-instance method `renderMermaidSVG(theme:layoutConfig:)` (line ~280)
- String-instance method `renderMermaidASCII(theme:)` (line ~294)

Keep `renderImage`, `renderSVG`, `renderASCII`, `prepare`, `parseDiagram`, `renderDiagramImage`, `renderDiagramSVG`, `renderDiagramASCII` (the canonical surfaces).

After deletion, the `extension DiagramEngine { … }` block at line ~196 may become empty; if so, delete the empty extension. The surviving `extension String { … }` block at the bottom of the file may also collapse — delete if empty.

- [ ] **Step 4: Edit `DiagramPipeline.swift`**

Delete the orphaned `renderSVG(_:options:)` overload at lines 210-217:

```diff
-    public static func renderSVG(
-        _ text: String,
-        options: RenderOptions = RenderOptions()
-    ) throws -> String {
-        try runPipeline(operation: "DiagramPipeline.renderSVG(options:)") {
-            try _renderDiagramSVG(text, options)
-        }
-    }
-
```

- [ ] **Step 5: Edit `DiagramPreparerWiring.swift`**

Delete lines 60-64:
```diff
-
-// MARK: - Phase 0 backward-compat deprecated alias
-
-@available(*, deprecated, renamed: "_DiagramPreparerBootstrap", message: "Will be removed in the next major version.")
-typealias _MermaidPreparerBootstrap = _DiagramPreparerBootstrap
```

The `#endif` on line 64 belongs to the surrounding `#if canImport(...)` and must survive.

- [ ] **Step 6: Build**

```bash
swift build
```
Expected: clean build, zero deprecation warnings from in-tree code.

If `swift build` fails with "no such method `_renderDiagramSVG`" anywhere, you missed a Phase 1/2/4 callsite. Locate via:
```bash
grep -rn '_renderDiagramSVG\b' Sources/ Tests/
```

- [ ] **Step 7: Acceptance grep**

```bash
grep -rn '@available.*deprecated.*Will be removed in the next major version' Sources/DiagramKit/
```
Expected: no hits.

```bash
grep -rn '\bMermaidParser\b\|\brenderMermaid\b\|\brenderDiagramSVG(' Sources/ Tests/ Examples/
```
Expected: no hits.

- [ ] **Step 8: Snapshot canary**

```bash
SNAPSHOT_DIAGRAM_IDS=block-1-simple,c4-1-system swift test --filter "CorpusSnapshotTests/svgSnapshot"
```
Expected: green, no snapshot diffs requiring rebaseline.

- [ ] **Step 9: Discipline gates**

```bash
Scripts/check-sendable-annotations.sh
Scripts/check-file-sizes.sh
Scripts/strict-concurrency-check.sh
```
Expected: green / only pre-existing yellow warnings.

- [ ] **Step 10: Commit**

```bash
git add -A  # use -A here because this commit includes deletions across multiple files

git commit -m "$(cat <<'EOF'
refactor(api)!: sunset Phase-0 / Session-7 deprecation surface

BREAKING CHANGE: delete the entire @available(*, deprecated)
Mermaid-prefixed API cohort along with the Session-7 free-function
deprecations.

Removed:
- Free functions: renderDiagramSVG, renderDiagramSVGAsync,
  renderMermaidSVG, renderMermaidSVGAsync, renderMermaid (src_index.swift)
- Internal SPI: _renderDiagramSVG and buildColors helper
- Typealiases (Deprecations.swift, entire file): MermaidStructuralError,
  MermaidRenderer, MermaidPipeline, MermaidImageRenderer
- Enum: MermaidParser (with .parse) — use MermaidImporter().parse(_:).document
- DiagramEngine *Async statics: renderImageAsync, renderSVGAsync,
  renderASCIIAsync, prepareAsync
- String instance methods: parseMermaid, renderMermaidImage,
  renderMermaidSVG, renderMermaidASCII
- Orphaned options overload: DiagramPipeline.renderSVG(_:options:)
- Internal alias: _MermaidPreparerBootstrap

All in-tree callers were migrated in Phases 1-4. Snapshot canary on
block-1-simple + c4-1-system passes without rebaselining.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Phase 7 — Docs sync

**Files:**
- Modify: `CLAUDE.md` (Public Surface section + Testing And Snapshots test source count)
- Modify: `ARCHITECTURE.md` (scan for stale references)
- Modify: `REVIEW.md` (add Session 12 Resolution Status row)

- [ ] **Step 1: Update `CLAUDE.md` Public Surface section**

Find and delete the sentence:
> Mermaid-prefixed public aliases carry `@available(*, deprecated, renamed:message:)` annotations and will be removed in the next major version. Internal/SPI aliases were removed in Phase 10.

This sentence lives under the "Public Surface" bullet list. After deletion, verify the surrounding bullets read coherently.

- [ ] **Step 2: Sync test source count in `CLAUDE.md`**

Find:
> Current test source count: 245 Swift files under `Tests/DiagramKitTests`.

Change `245` → `244` (the `MermaidLegacyAPITests.swift` deletion is -1).

- [ ] **Step 3: Scan `ARCHITECTURE.md` for stale references**

```bash
grep -n 'MermaidParser\|MermaidRenderer\|MermaidPipeline\|MermaidImageRenderer\|MermaidStructuralError\|renderMermaid\|renderDiagramSVG(' ARCHITECTURE.md
```
Update or remove any matches. If none, no change needed.

- [ ] **Step 4: Add Session 12 row to `REVIEW.md`**

Add a new `## Resolution Status — Session 12 (YYYY-MM-DD)` section above the `## Deferred Effort — Recommendations` heading. Use the same table format as Sessions 1–11. Reference the commits from Phases 1–6 by their short SHA. Match the prose style of the existing Session N rows (terse, file:line-grounded).

Note: this row closes Cross-cutting Observation #3 from the original review. Cite it.

- [ ] **Step 5: Verify docs build (light check)**

```bash
grep -rn '@available.*deprecated.*next major' CLAUDE.md ARCHITECTURE.md
```
Expected: no hits.

```bash
ls Tests/DiagramKitTests/*.swift | wc -l
```
Expected: 244 (matches the synced count in CLAUDE.md).

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md ARCHITECTURE.md REVIEW.md

git commit -m "$(cat <<'EOF'
docs(claude,architecture,review): sync after Phase-0 deprecation sunset

CLAUDE.md: drop the "Mermaid-prefixed public aliases carry @available"
sentence from Public Surface; sync test source count 245 → 244 (the
MermaidLegacyAPITests deletion). ARCHITECTURE.md: scan for and remove
any residual Mermaid* references. REVIEW.md: Session 12 closes
Cross-cutting Observation #3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Checklist

After all tasks complete, verify:

- [ ] `grep -rn '@available.*deprecated.*Will be removed in the next major version' Sources/DiagramKit/` returns no hits.
- [ ] `grep -rn '\bMermaidParser\b\|\brenderMermaid\b' Sources/ Tests/ Examples/` returns no hits.
- [ ] `grep -rn '_renderDiagramSVG\b' Sources/ Tests/` returns no hits.
- [ ] `grep -rn 'renderDiagramSVG(' Sources/ Tests/ Examples/` returns no hits (free-function form; the canonical `DiagramEngine.renderSVG(source:)` and `DiagramPipeline.renderSVG(source:)` calls use the `source:` label so they don't match this pattern).
- [ ] `ls Tests/DiagramKitTests/*.swift | wc -l` returns 244.
- [ ] `Scripts/check-sendable-annotations.sh` green.
- [ ] `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings.
- [ ] `Scripts/strict-concurrency-check.sh` first-party clean.
- [ ] CLAUDE.md and REVIEW.md updated.
- [ ] Final commit count: 4 (Phase 1) + 1 (Phase 2) + 1 (Phase 4) + 1 (Phase 5) + 1 (Phase 6) + 1 (Phase 7) = 9 commits.

## Risk Mitigations Already Built In

- **Risk 1 (DiagramImageRenderer color routing):** verified pre-flight. The `renderSVGSync` method round-tripped `theme.effective*()` through `RenderOptions`; `DiagramPipeline.renderSVG(source:theme:layoutConfig:idPolicy:)` derives colors from the same `theme.effective*()` calls internally. Migration is a semantic no-op.
- **Risk 2 (.stable idPolicy):** the engine and pipeline APIs both expose `idPolicy:` as a first-class parameter. Sessions 4 and 8 already exercised this surface; no new risk.
- **Risk 3 (snapshot drift):** Phase 6 canary on `block-1-simple` + `c4-1-system` is the gate. If either diffs, halt and investigate before committing.
- **Risk 4 (test count drift):** Phase 7 syncs CLAUDE.md.
- **Risk 5 (argument-label hygiene with `"""…"""` literals):** Phase 1 batches are 7 files each, small enough to review the diff per file before committing.

# DiagramKit — Import Analysis & Direct Path

> **Status (post-Stage 4):** Stages 1 (module split & rename), 2 (Linux portability), 3 (governance scripts), and 4 (docs) are complete on `main`. The package ships six layered SwiftPM targets, builds on `swift:6.3.1-noble` for the Linux-portable subset, applies `strictConcurrencySettings` per target, runs four governance gates (`check-file-sizes.sh`, `check-sendable-annotations.sh`, `strict-concurrency-check.sh`, `bootstrap-smoke-check.sh`) with grandfathered allowlists, and now carries a full doc set (`README.md`, `ARCHITECTURE.md`, `BASELINES.md`, `CONTRIBUTING.md`, `ATTRIBUTION.md`, refreshed `THIRD_PARTY_LICENSES.md`). Stages 5 (examples app) and 6 (promotion docs) are open. The promotion-gate question — "what is the second consumer?" — is still unanswered and gates the merge.

## Executive read

`mermaid-swift` is **substantively complete as a Mermaid implementation** (28 diagram types, parser + layout + three render backends — CG, SVG, ASCII — plus a SwiftUI wrapper, ~84k LOC, ~144 test files, ~914 snapshot baselines, fonts bundled OFL). It already mirrors several MusicToolkit conventions: Swift 6.3 / Swift 6 language mode, `swift-snapshot-testing` pinned to your `fix-swift-6.3-attachable` fork, OFL font registration via `CTFontManagerRegisterFontsForURL` (the `THIRD_PARTY_LICENSES.md` even cites `MusicToolkit` as the precedent).

After Stages 1–2 it is **shaped like a layered DiagramKit**: a six-target SPM package (Common → Model → RenderingCG / TestSupport / Views → DiagramKit umbrella) with strict-direction imports, Apple-only edges gated via `condition: .when(platforms:)`, and a Linux portability harness. The remaining gap is **governance and docs**, not capability or shape.

## Diff vs MusicToolkit conventions

| Dimension | MusicToolkit | mermaid-swift today | Status |
|---|---|---|---|
| Library products | 22 layered targets | 6 layered targets (Common, Model, RenderingCG, Views-stub, TestSupport, umbrella) | ✅ Stage 1 |
| Source dir naming | `Sources/<TargetName>/` | `Sources/DiagramKit*/` (renamed from `BeautifulMermaidSwift/`) | ✅ Stage 1 |
| Linux platform | Engine-portable, Apple-only rendering carved out via `condition: .when(platforms:)` on dep edges + `#if canImport(CoreGraphics)` in source | Same pattern: Common/TestSupport full-Linux; Model partial-Linux (UIKit/AppKit/CoreText files compile to empty); RenderingCG/Views Apple-only via dep-edge conditions; `Scripts/linux-check.sh` + `Dockerfile.linux-check` verify against `swift:6.3.1-noble` | ✅ Stage 2 |
| Linux verification | `Dockerfile.linux-check` against `swift:6.3.1-noble` | Present at repo root | ✅ Stage 2 |
| Crypto on Linux | `swift-crypto` Linux-conditional dep for CryptoKit-equivalent API | Same: `swift-crypto` gated `condition: .when(platforms: [.linux])` for `DiagramKitCommon.StableID.derive(...)` | ✅ Stage 2 |
| Concurrency | `swiftSettings: strictConcurrencySettings` (`StrictConcurrency` + `InferSendableFromCaptures`) per target | Variant: top-level `let strictConcurrencySettings: [SwiftSetting]` applied to all 8 targets, but `InferSendableFromCaptures` was dropped (already default in Swift 6, emitted per-file "already enabled" warnings). Only `StrictConcurrency` ships. | ✅ Stage 3 |
| Sendable governance | `.sendable-allowlist.txt` + `Scripts/check-sendable-annotations.sh` with sunset dates | Same: 14 yellow entries with sunset `2027-06-30`; gate enforces banner-or-allowlist | ✅ Stage 3 |
| File-size gate | 500/1000-line gate via `Scripts/check-file-sizes.sh` + allowlist | Same: 11 JS-ported parser/layout/renderer files grandfathered in `Scripts/check-file-sizes-allowlist.txt` | ✅ Stage 3 |
| Bootstrap phases | Each module exposes `<Module>Bootstrap.phase: Int` | N/A | ❌ Stage 3 (deferred to Stage 6 monorepo promotion) |
| Docs | `README.md`, `ARCHITECTURE.md`, `BASELINES.md`, `ATTRIBUTION.md`, `THIRD_PARTY_LICENSES.md`, `CONTRIBUTING.md`, `CLAUDE.md` | Same: `README.md`, `ARCHITECTURE.md`, `BASELINES.md`, `CONTRIBUTING.md`, `ATTRIBUTION.md` authored; `THIRD_PARTY_LICENSES.md` refreshed (paths and Swift-library list updated, dangling `FOLLOWUPS.md` link removed); `CLAUDE.md` + `AGENTS.md` already current | ✅ Stage 4 |
| Examples app | No in-package executable; consumers live in `products/` | `Examples/MermaidPlayground/` SPM executable + Xcode project still in tree | ❌ Stage 5 |

## Direct path — six stages

Stages 1 and 2 have shipped. What's left is governance, docs, the examples-app decision, and the promotion-docs roll-up. Estimates assume the parser/layout/render code itself is left untouched.

**Stage 1 — Module split & rename.** ✅ **Done** (commits `e15653c` … `6c53015` plus follow-ups through `927db95`).

The actual split is more conservative than originally proposed — 6 targets, not 11. Parse / Layout / RenderingSVG / RenderingASCII are **not separate targets**; they all live inside `DiagramKitModel` (~197 files: `src_<type>_parser.swift`, `src_<type>_layout.swift`, `src_<type>_renderer.swift`, `src_ascii_*.swift`, plus the source-preprocessing quartet, `Types.swift`, `RenderConfig.swift`, `PositionedPayloads.swift`, `CrossPlatform.swift`, and 28 `FrontmatterBinding+<Type>.swift` adapters). A backend-agnostic `DiagramKitRendering` contract target was not introduced.

The shipped layout:

- `DiagramKitCommon` (Linux + Apple) — `SVG`, `IssueReportingSupport`, `StableID` (CryptoKit / swift-crypto), text metrics, theme, font-awesome / HTML-entity tables, multiline utils, styles. **No CG/CT/UI deps.**
- `DiagramKitModel` (Linux + Apple, partial) — parsers, layouts, SVG/ASCII renderers, frontmatter binding, types, payloads, `RenderConfig` / `RenderOptions` / `RenderTokens`. UIKit/AppKit/CoreText files compile to empty on Linux; CTLine-bound layouts (ishikawa / treeView / eventModeling) are Linux-unreachable for now.
- `DiagramKitRenderingCG` (Apple-only) — `Render/` migrated here as flat per-type extensions (`DiagramRenderer+<Type>.swift`), plus `EdgeRenderer`, `LabelRenderer`, `ShapeRenderer`, `ArrowRenderer`, `CGPathRenderer`, `PreparedDiagram`, `FontRegistry` (`BeautifulMermaidFontRegistry`), `Version` (reads `Resources/VERSION`). Ships bundled `Resources/Fonts/`.
- `DiagramKitTestSupport` (Linux + Apple) — currently a thin file. Test corpus stayed in `Examples/MermaidPlayground/Resources/test-diagrams.json` (Stage 5 may move it).
- `DiagramKitViews` (Apple-only) — **placeholder stub.** Actual SwiftUI/UIKit views (`MermaidView`, `MermaidDiagramView`, `MermaidLayer`, `MermaidDiagram`) still live inside `Sources/DiagramKit/Views/` because they depend on `MermaidPipeline`. A future refactor may extract them via a closure-based Preparer protocol.
- `DiagramKit` (umbrella) — public API surface (`MermaidRenderer`, `MermaidImageRenderer`, `MermaidPipeline`, `Parser.swift`, `Layout.swift`) plus `Views/`. Apple-only edges to RenderingCG/Views are gated via `condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])`.

The `MermaidRenderer` namespace was kept as-is (no rename to `DiagramKit.Mermaid.Renderer`). If a second format (Graphviz, PlantUML, D2) is added later, that's a real API decision worth revisiting.

**Stage 2 — Linux portability.** ✅ **Done** (commits `a62e88c` … `1d0312c`). All four Linux-portable targets build green on `swift:6.3.1-noble`:

| Target | Linux | Notes |
|---|---|---|
| `DiagramKitCommon` | full | No CG/CT/UI deps. |
| `DiagramKitModel` | partial | UIKit/AppKit/CoreText files compile to empty on Linux. SVG/ASCII paths that don't measure text work; CTLine-bound layouts (ishikawa, treeView, eventModeling) throw `MermaidStructuralError.payloadMismatch`. |
| `DiagramKitTestSupport` | full | No CG/CT/UI deps. |
| `DiagramKit` (umbrella) | partial | `parse(_:)` and `layout(_:config:)` portable. `renderImage`, `renderSVG`, `renderASCII`, `render(in: CGContext)`, `Views/*` are Apple-only. |
| `DiagramKitRenderingCG` | none | Apple-only via `condition: .when(platforms: [Apple])` + `#if canImport(CoreGraphics)`. |
| `DiagramKitViews` | none | Apple-only. |
| `DiagramKitTests` | none | Test target depends on RenderingCG; left Apple-only for Stage 2. |

The pattern matches MusicToolkit:

- `Package.swift` edges that traverse RenderingCG/Views are guarded by `condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS, .macCatalyst])`.
- Source-level: `#if canImport(CoreGraphics)` for CG, `#if canImport(CoreText)` for text measurement, `#if canImport(UIKit) || canImport(AppKit)` for native UI types and `BMColor`/`BMFont`/`BMImage`.
- `BMColor` / `BMFont` / `BMImage` / `BMView` / `BMBezierPath` typealiases in `CrossPlatform.swift` are intentionally undefined on Linux. Any callsite using them is itself gated.

**Stage 2.5 — deferred:** a portable text-measurement shim (replacement for `CTLineGetBoundsWithOptions` on Linux) so `ishikawa` / `treeView` / `eventModeling` layouts can run without an Apple runtime. Not a blocker for the import; tracked as a known deferral in `CLAUDE.md`. The `_runOnWorker` 8 MB-stack `Thread` pattern verified fine on Linux Foundation (no fallback needed in practice).

**Stage 3 — Discipline.** ✅ **Done** (commits `bf64397` … `31c36b2`, plus follow-ups). A `strictConcurrencySettings` constant (only the `StrictConcurrency` upcoming feature — `InferSendableFromCaptures` was dropped as a follow-up because it's already default in Swift 6 and emitted a per-file "already enabled" warning) is applied to all 8 targets in `Package.swift`. The four governance scripts ship under `Scripts/`: `check-file-sizes.sh` (500 warn / 1000 error, with `Scripts/check-file-sizes-allowlist.txt` grandfathering 11 JS-ported parser/layout/renderer files); `check-sendable-annotations.sh` paired with `.sendable-allowlist.txt` (14 yellow entries, sunset `2027-06-30`); `strict-concurrency-check.sh` (passes clean on first run — Swift 6 language mode was already doing the heavy lifting); and `bootstrap-smoke-check.sh` orchestrating all of the above plus `swift test`, `linux-check.sh`, and a multiplatform `xcodebuild` sweep. `<Module>Bootstrap.phase: Int` markers are intentionally **deferred** to Stage 6: per the original guidance, those are relevant once DiagramKit lands in the monorepo with a confirmed second consumer, not before. Known caveat: `swift test` invoked by `bootstrap-smoke-check.sh` hits the pre-existing `CorpusSnapshotTests` signal-10 hang on `main`; that's an upstream test-runner / `swift-snapshot-testing` interaction, not a Stage 3 regression.

**Stage 4 — Docs.** ✅ **Done** (this docs commit). Authored:
- `README.md` — public surface, install snippet, package topology, quick-start examples for all four render paths (image / SVG / ASCII / SwiftUI), Linux-portability table, smoke-check pointers.
- `ARCHITECTURE.md` — layered target map (ASCII layer diagram + per-target table), the three-stage pipeline (parse → layout → render), the **worker-thread invariant** with the explicit "do not reintroduce a thread pool" warning citing the reverted commit, the dual-renderer drift hazard, layer-import rules, concurrency model, and the discipline-gate orchestration.
- `BASELINES.md` — captured 2026-05-10: 53.4s clean build / 4.0s incremental, 144 test files, 914 snapshot baselines (396 SVG / 346 image / 172 ASCII), 396-diagram corpus, file-size landscape (11 allowlisted ≥1000-line files plus 56 warnings in the 500–1000 band), the four discipline gates' status, plus refresh commands. Documents the corpus signal-10 hang and other known pre-existing test failures as caveats, not regressions.
- `CONTRIBUTING.md` — file-size thresholds, the green/yellow/red `@unchecked Sendable` policy with banner example, layer-import rules, "adding a new diagram type" 9-step checklist (parser → types → layout → SVG renderer → CG renderer → ASCII renderer → frontmatter binding → corpus fixtures → snapshot baselines), snapshot-test workflow, PR checklist.
- `ATTRIBUTION.md` — upstream `mermaid-js` lineage (MIT, Knut Sveidqvist & contributors) prominently cited as the source of the parsers/layouts/SVG renderers; bundled fonts (Noto Sans + Noto Sans Mono under SIL OFL) with origin/license/SPDX/bundled-status; Swift libraries (`swift-custom-dump`, `xctest-dynamic-overlay`, `swift-crypto`, `swift-snapshot-testing`) with the fork-pinning rationale; "how to update this file" checklist.
- Refreshed `THIRD_PARTY_LICENSES.md` — fixed every `Sources/BeautifulMermaidSwift/...` path to `Sources/DiagramKitRenderingCG/...`, removed the dangling link to the deleted `FOLLOWUPS.md`, added the missing `swift-crypto` dependency, added a top-of-file pointer to the new `ATTRIBUTION.md`.

`CLAUDE.md` was already current post-Stage 3 (the "Discipline gates" section was added there). `AGENTS.md` is unchanged.

**Stage 5 — Examples app handling.** ❌ **Open.** `Examples/MermaidPlayground/` (SwiftUI sample app + Xcode project) is still in the tree. Either drop it (cleaner, matches monorepo convention "products own apps") or keep as SPM executable target only and remove the Xcode project. Recommendation unchanged: drop entirely; move the 396-entry `test-diagrams.json` corpus to `DiagramKitTestSupport/Resources/`. `PlaygroundExampleCatalogTests` will need a corresponding repoint.

**Stage 6 — Promotion docs.** ❌ **Open.** Update `/Users/ajmcclary/Workspace/CLAUDE.md` package-count line, add a row to `packages/CLAUDE.md` table, update `docs/architecture/packages-roadmap.md` with DiagramKit's incubating status and target consumers. Same provenance as MusicToolkit.

## The promotion gate — answer this before merging

Your monorepo's `packages/` rule is **≥2 independent consumers** (root `CLAUDE.md` line 20). MusicToolkit is currently the only exception, "pending Q3 2026 governance confirmation." Adding DiagramKit as a second pending exception is a precedent decision.

The honest question: **what are the two consumers?** Possibilities (unchanged from original analysis):

1. **Sonography** — embed Mermaid for in-app help/tutorial diagrams or pedagogy notation overlays.
2. **Bridge or PixelLift** — same use case, lower fit.
3. **A new `services/diagram-engine/` Swift-on-Linux sidecar** mirroring `notation-engine` — server-side parse + SVG render of Mermaid for non-Swift clients (web, future agents). With Stage 2 done, this is now mechanically achievable for the SVG/ASCII paths (CTLine-bound layouts excepted until Stage 2.5).
4. **A new product** that's primarily a diagram tool.

The Stage 2 work landed precisely so option (3) is on the table. If the answer is "(1) plus (3)," the layered Linux-portable shape pays for itself and the symmetry with MusicToolkit / notation-engine is exact. If the answer is just (1), the Stage 2 work is still defensible (it forced cleaner module boundaries) but the import could collapse to a single Apple-only umbrella with a much smaller footprint in the monorepo.

## My recommendation

The investment in Stages 1–2 is sunk and the result is high-quality: layered targets, Linux-verified, no API churn, snapshot tests still passing (~914 baselines across SVG / image / ASCII). The honest blocker remains the same as before: **pick the second consumer.** That decision shapes Stages 3–6:

- If the answer involves a Linux server (option 3), Stages 3–5 are worth the full MusicToolkit treatment — file-size gates, sendable allowlist, `Dockerfile.linux-check` already exists, Examples app gets dropped, corpus moves to TestSupport.
- If the answer is Apple-clients-only (option 1 alone), Stage 3 can be lighter (skip Linux-specific scripts), Stage 5 is optional (the playground is a useful dogfooding surface), and Stage 4 still wants `README.md` + `ARCHITECTURE.md` at minimum.

Either way, Stages 1–2 were the right move first — they were prerequisite to either path. Confirm the consumer story and I'll write the implementation plan for whichever Stage 3–6 shape applies.

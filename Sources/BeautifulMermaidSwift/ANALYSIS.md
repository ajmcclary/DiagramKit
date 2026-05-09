# DiagramKit — Import Analysis & Direct Path

## Executive read

`mermaid-swift` is **substantively complete as a Mermaid implementation** (28 diagram types, parser + layout + three render backends — CG, SVG, ASCII — plus a SwiftUI wrapper, ~84k LOC, ~144 test files, ~726 snapshot baselines, fonts bundled OFL). It already mirrors several MusicToolkit conventions: Swift 6.3 / Swift 6 language mode, `swift-snapshot-testing` pinned to your `fix-swift-6.3-attachable` fork, OFL font registration via `CTFontManagerRegisterFontsForURL` (the `THIRD_PARTY_LICENSES.md` even cites `MusicToolkit` as the precedent).

But it is shaped as a **single library** (`BeautifulMermaid`, source at `Sources/BeautifulMermaidSwift/`) with **zero Linux portability** and no in-monorepo discipline (no layered targets, no strict-concurrency settings, no Linux check, no `BASELINES.md`, no `.sendable-allowlist.txt`, no `Scripts/` gates, no `README.md`, no `ARCHITECTURE.md`). It is not yet "DiagramKit." It is one consolidated SPM target with great functionality.

The honest gap is **shape and governance**, not capability.

## Diff vs MusicToolkit conventions

| Dimension | MusicToolkit | mermaid-swift today |
|---|---|---|
| Library products | 22 layered targets | 1 monolith |
| Linux platform | Engine-portable, Apple-only rendering carved out via `condition: .when(platforms:)` on dep edges + `#if canImport(CoreGraphics)` in source | None declared; 67 files `import CoreGraphics` unconditionally, including SVG/ASCII renderers (only for `CGPoint`/`CGRect`/`CGFloat` math) |
| Concurrency | `swiftSettings: strictConcurrencySettings` (`StrictConcurrency` + `InferSendableFromCaptures`) per target | Not enabled (Swift 6 mode only) |
| Sendable governance | `.sendable-allowlist.txt` + `Scripts/check-sendable-annotations.sh` with sunset dates | None |
| File-size gate | 500/1000-line gate via `Scripts/check-file-sizes.sh` + allowlist | None — `Types.swift` is 761, `DiagramDescriptor.swift` 776, `SourcePreprocessing.swift` 370 |
| Linux verification | `Dockerfile.linux-check` against `swift:6.3.1-noble` | None |
| Bootstrap phases | Each module exposes `<Module>Bootstrap.phase: Int` | N/A (single target) |
| Docs | `README.md`, `ARCHITECTURE.md`, `BASELINES.md`, `ATTRIBUTION.md`, `THIRD_PARTY_LICENSES.md`, `CONTRIBUTING.md`, `CLAUDE.md` | `CLAUDE.md` + `AGENTS.md` + `THIRD_PARTY_LICENSES.md` only; `README.md` missing; `FOLLOWUPS.md` referenced but absent |
| Source dir naming | `Sources/<TargetName>/` | `Sources/BeautifulMermaidSwift/` (mismatched) |
| Examples app | No in-package executable; consumers live in `products/` | `Examples/MermaidPlayground/` SPM executable + Xcode project |

## Direct path — six stages

I'd land this in stages so each is verifiable on its own. Estimates assume the parser/layout/render code itself is left untouched.

**Stage 1 — Module split & rename (largest single change).** Carve the monolith into roughly:

- `DiagramKitCommon` — utilities, `IssueReportingSupport`
- `DiagramKitModel` — `Types.swift`, `DiagramDescriptor`, `MermaidGraph`, `PositionedGraph`, `Theme`, errors (Linux-portable)
- `DiagramKitParse` — `Mermaid/src_*_parser.swift`, `SourcePreprocessing`, `MermaidSourceNormalizer`, `InitDirectiveParser`, `FrontmatterDocumentParser` (Linux-portable target)
- `DiagramKitLayout` — `Layout.swift`, `Mermaid/src_*_layout.swift`, `ElkModels`, `FlowNodeSizer`, `EdgePathMidpoint`, `EdgeShapeClipper` (Linux-portable target)
- `DiagramKitRendering` — backend-agnostic canvas contracts (mirror of MusicToolkit's `Rendering` target — declares the surface, no CG dependency)
- `DiagramKitRenderingSVG` — `Mermaid/src_*_renderer.swift` (Linux-portable target — strip `import CoreGraphics`, keep just `Foundation`)
- `DiagramKitRenderingASCII` — `Mermaid/src_ascii_*` 24-file family (Linux-portable target)
- `DiagramKitRenderingCG` — `Render/` (43 files), `ImageRenderer`, `CrossPlatform.swift`, font registry — Apple-only via `condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS])`
- `DiagramKitViews` — `Views/` (4 files, OS 26+ gated) — Apple-only
- `DiagramKitTestSupport` — fixture builders + the 396-entry `test-diagrams.json` corpus (Linux-portable)
- `DiagramKit` — umbrella library re-exporting Common/Model/Parse/Layout/RenderingSVG/RenderingASCII (matches MusicToolkit's umbrella pattern)

Rename `MermaidRenderer` → `Diagram.Mermaid.Renderer` (or keep `MermaidRenderer` and namespace inside `DiagramKit`). Picking a `DiagramKit.Mermaid` namespace leaves room for additional formats later (Graphviz, PlantUML, D2) without an API break.

**Stage 2 — Linux portability.** Add `.linux` to platforms (or rather, leave it implicit and just verify), strip `import CoreGraphics` from the SVG/ASCII parsers and renderers (replace with `import Foundation` — `CGPoint`/`CGRect`/`CGFloat` are exposed on Linux Foundation). Mark the CG/Views dep edges `condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS])`. Verify the `_runOnWorker` 8MB-stack `Thread` pattern works on Linux Foundation (`Thread.init(stackSize:)` is platform-conditional — may need a fallback path).

**Stage 3 — Discipline.** Adopt MusicToolkit's `strictConcurrencySettings` constant; copy `Scripts/check-file-sizes.sh` + allowlist (start with current outliers grandfathered with sunset dates), `check-sendable-annotations.sh`, `strict-concurrency-check.sh`, `bootstrap-smoke-check.sh`, `Dockerfile.linux-check`. Write `.sendable-allowlist.txt`.

**Stage 4 — Docs.** Author `README.md` (public surface + module map), `ARCHITECTURE.md` (layer diagram, three-stage pipeline, the worker-thread invariant from existing `CLAUDE.md`), `BASELINES.md` (clean-build time, test count, snapshot count after split), `CONTRIBUTING.md`, refresh `ATTRIBUTION.md` and `THIRD_PARTY_LICENSES.md`. Existing `CLAUDE.md` is already strong — port it.

**Stage 5 — Examples app handling.** Either drop `Examples/MermaidPlayground/` from the imported tree (cleaner) or keep it as an SPM executable target only and remove the Xcode project (Workspace pattern is "products own apps"). My recommendation: drop entirely; the 396-entry `test-diagrams.json` corpus is the authoritative example surface and belongs in `DiagramKitTestSupport/Resources/`.

**Stage 6 — Promotion docs.** Update `/Users/ajmcclary/Workspace/CLAUDE.md` package count line, add a row to `packages/CLAUDE.md` table, update `docs/architecture/packages-roadmap.md` with DiagramKit's incubating status and target consumers. Same provenance as MusicToolkit.

## The promotion gate — answer this before merging

Your monorepo's `packages/` rule is **≥2 independent consumers** (root `CLAUDE.md` line 20). MusicToolkit is currently the only exception, "pending Q3 2026 governance confirmation." Adding DiagramKit as a second pending exception is a precedent decision.

The honest question: **what are the two consumers?** Possibilities:

1. **Sonography** — embed Mermaid for in-app help/tutorial diagrams or pedagogy notation overlays.
2. **Bridge or PixelLift** — same use case, lower fit.
3. **A new `services/diagram-engine/` Swift-on-Linux sidecar** mirroring `notation-engine` — server-side parse + SVG render of Mermaid for non-Swift clients (web, future agents). This is the cleanest second consumer and is the entire reason Stage 2's Linux portability matters.
4. **A new product** that's primarily a diagram tool.

If the answer is "(1) plus (3)," the Linux-portable split pays for itself and the symmetry with MusicToolkit / notation-engine is exact. If the answer is just (1), the import is still doable but it lands as a single Apple-only umbrella and Stage 2 becomes optional — a much smaller diff.

## My recommendation

Worth importing — the code is high-quality, you already authored it, the precedents (font bundling, snapshot fork pin) are aligned, and the 28-format coverage is genuinely useful. **But pick the second consumer first.** That decision determines whether you need the full 6-stage split or a much smaller "rename + adopt discipline" import. Let me know the consumer story and I'll write the actual implementation plan against the chosen path.

# Follow-ups

Items intentionally deferred from the May 2026 remediation. Tracked here so the deferral is visible, not forgotten. Approximate severity in `[brackets]`.

## High-leverage (do once snapshot baselines are reviewed)

### CG/SVG render-path divergence audit `[medium]`

Every diagram type has two renderers — a CG renderer at `Sources/BeautifulMermaidSwift/Render/DiagramRenderer+<Type>.swift` and a legacy SVG renderer at `Sources/BeautifulMermaidSwift/Mermaid/src_<type>_renderer.swift`. Text measurement, color resolution, and geometry are computed independently in each path. Now that snapshots are committed, diff every (svg, png) pair for the same `diagram.id` and pick a canonical path per diagram type. Long-term: deprecate one path entirely.

Concrete CG-side gaps surfaced while fixing duplicate `case` warnings in `Sources/BeautifulMermaidSwift/Render/ShapeRenderer.swift`:

- `horizontal-cylinder` and `data-store`: `shapePath(for:in:)` now returns the correct body rect (X-shrink for horizontal-cylinder, Y-shrink for data-store, matching SVG `_renderHorizontalCylinder` / `_renderDataStore`), but `drawShapeDetails(_:in:context:theme:inlineStyles:)` has **no case** for either. Result: only the inner body rect is drawn — no end-cap ellipses for horizontal-cylinder, no top-ellipse / curved-bottom for data-store. Add corresponding cases to `drawShapeDetails` to match the SVG canonical.

### Renderer consolidation — pick CG-only or SVG-only `[medium]`

Architectural decision blocked by the audit above. CG-only is faster and pixel-perfect on Apple platforms; SVG-only is portable and easier to debug. Supporting both forever doubles maintenance.

### Triage rendering bugs surfaced by baselines `[high]`

`SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests` recorded:

- **393** SVG snapshots out of 396 corpus diagrams (~99% success)
- **172** ASCII snapshots (~43% success — many diagram types don't have an ASCII path)
- **161** Image snapshots (~41% success — `try #require` failed for the rest, meaning `renderImage` returned `nil`, typically because layout produced 0×0 bounds)

Walk the missing-image cases: they're the concrete "rendering is incorrect" punch list. For each:

1. Inspect the SVG snapshot — does it look right?
2. Check why `renderImage` returned nil (layout produced empty bounds? `_renderPrepared` rejected the size?).
3. Either fix the layout, or skip with `@Test(.disabled("rendering bug — see issue #N"))` and file the issue.

## Code-quality cleanup

### RenderConfig magic-number sweep `[low]`

~25 hardcoded numbers identified across `DiagramRenderer+Pie.swift` (`pieCx=225`), `DiagramRenderer+GitGraph.swift` (bullet radii), `DiagramRenderer+Class.swift` (header offsets), etc. Route them through `RenderConfig` so layouts are parameterizable without code changes.

### `SourcePreprocessing.swift` split `[low]`

File is 2,637 lines after the YAML-parser dedup (down from 3,572). Split into stage-shaped files: `Frontmatter.swift`, `LineJoining.swift`, `CommentStripping.swift`, `StatementSplitting.swift`. Currently untestable as units because all functions are private nested helpers sharing closure state.

### Full swift-testing migration `[low]`

`CorpusSnapshotTests.swift` and a few others use `@Test`/`@Suite`. The remaining ~140 test files use XCTest. Migrating gives parallel execution by default, parameterized tests as first-class, and `#expect`/`#require` failure messages. Bulk find-replace plus per-file review.

### BlockSecurityTests `[low]`

`FlowchartSecurityTests.swift` exists. Equivalent fuzz-style tests don't exist for `block`, `architecture`, `treemap`, `kanban`. Block diagrams accept arbitrary user-supplied labels and should have the same XSS-vector / oversize-input coverage.

### Examples target exclusion audit `[trivial]`

`Package.swift:39-42` excludes `Info.plist` and `Scripts` from the playground target. Confirm the exclusions still match what's actually in `Examples/MermaidPlayground/Scripts/` and aren't accidentally bundling dev-only files (e.g. `GenerateAppIcon.swift`) into the shipped playground.

## Non-issues (decided, archived for posterity)

- **Worker thread pool (Phase 2.2 in original plan):** attempted in commit `ff2622b` and reverted. The per-call `Thread` spawn at 8 MB stack is the right trade-off at the steady-state rate this library is used. See doc-comment on `MermaidRenderer._runOnWorker` for full rationale. **Do not revisit unless profiling shows thread spawn dominates.**
- **`MermaidPipeline` actor → enum (Phase 2.1):** done in commit `d46f67d`. No further action.
- **Deployment-target drop (Phase 0.3):** done. iOS 17 / macOS 14 / Catalyst 17 / visionOS 1.

## Upstream dependencies to watch

### swift-snapshot-testing #1090

`Package.swift:18-30` pins to the fork at `https://github.com/ajmcclary/swift-snapshot-testing`, branch `fix-swift-6.3-attachable`, while [pointfreeco/swift-snapshot-testing#1090](https://github.com/pointfreeco/swift-snapshot-testing/pull/1090) is awaiting upstream merge. When that PR ships in a tagged release (likely 1.19.3 or later), unwind:

1. Edit `Package.swift` to revert the dependency to `.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "<release>")`.
2. Drop the multi-line `// TEMP:` comment block above the dependency.
3. Run `swift package resolve` and `swift test --filter CorpusSnapshotTests` to confirm the upstream library passes.

The Swift Testing `Attachable` cross-import-overlay break is a Swift 6.3-specific issue; on older toolchains the fork is a no-op.

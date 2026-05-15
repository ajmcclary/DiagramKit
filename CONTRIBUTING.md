# Contributing to DiagramKit

This package follows the conventions of the sibling `MusicToolkit` package: layered SPM targets, Linux-portable foundation, governance gates run locally before merging.

For invariants Claude / contributors must respect, see [CLAUDE.md](CLAUDE.md). For the full architectural picture, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Before you start

```bash
swift package resolve     # after editing Package.swift dependencies
swift build               # ~50s clean, ~4s incremental
swift test --filter <NameOrPattern>   # narrow run while iterating
```

If you're touching public API or a renderer, also run:

```bash
./Scripts/bootstrap-smoke-check.sh    # the local "is this branch healthy?" gate
```

## Continuous integration

`.github/workflows/ci.yml` runs every PR through a macOS runner:

- `swift package dump-package`
- `swift build --build-tests`
- `swift test`
- `Scripts/check-file-sizes.sh`
- `Scripts/check-sendable-annotations.sh`
- `Scripts/strict-concurrency-check.sh`
- `Scripts/linux-check.sh` (with `SKIP_LINUX_CHECK=1` — GitHub's macOS runners don't ship Docker or Podman; the actual container build runs locally via `bootstrap-smoke-check.sh`).

The local merge gate is the authoritative health check: it adds the Xcode multi-platform builds and a real `linux-check.sh` against your locally-installed runtime. CI is the second line of defense, not a replacement.

## File-size guidelines

| Threshold | Behaviour |
|---|---|
| ≤ 500 lines | preferred |
| 500–1000 lines | warns (`Scripts/check-file-sizes.sh` prints `WARNING:`); still passes |
| > 1000 lines | errors unless allowlisted in `Scripts/check-file-sizes-allowlist.txt` |

The 11 currently-allowlisted files are JS-port parsers/layouts/renderers in `DiagramKitModel` that mirror upstream `mermaid-js` source files line-for-line. Splitting them would diverge from upstream and create maintenance churn. **Don't add new allowlist entries without a comment block explaining why** — file size is a code smell signal, and the allowlist is for genuine exceptions.

When you find yourself wanting to add to the allowlist:

1. Confirm the file is genuinely unsplittable for upstream-parity reasons.
2. Update the comment header in `Scripts/check-file-sizes-allowlist.txt` if your justification is novel.
3. Add the path on its own line (no inline comments).

## Sendable / concurrency policy

`Package.swift` applies `strictConcurrencySettings` (the `StrictConcurrency` upcoming feature) per target. `InferSendableFromCaptures` is omitted because it is already default in Swift 6 mode — re-enabling it via `.enableUpcomingFeature` emits one warning per source file. `swift build` should be warning-free under `-strict-concurrency=complete -warnings-as-errors` — the gate at `Scripts/strict-concurrency-check.sh` enforces this for first-party paths matching `Sources/DiagramKit*/`.

For `@unchecked Sendable`, the policy is **green > yellow > red**:

- **Green (preferred):** add a "Concurrency Contract" banner explaining the invariant — single-pass / construction-then-freeze / queue-confinement / setup-then-share / etc. The banner must appear in the first 50 lines of the file or within 10 lines of the annotation. The gate at `Scripts/check-sendable-annotations.sh` searches for the banner pattern.
- **Yellow:** add a `file:line:yellow:YYYY-MM-DD` entry to `.sendable-allowlist.txt` with a sunset date you intend to hit. Existing yellow entries (14 of them, all grandfathered when Stage 3 landed) sunset on `2027-06-30`.
- **Red:** entry-format `file:line:red:` — the gate fails immediately. Use only as a self-imposed deadline, never as a permanent state.

Banner example:

```swift
// MARK: Concurrency Contract
// `Foo` is constructed once on the parser thread and frozen before any
// renderer reads it. All renderers see a stable snapshot — single-pass,
// construction-then-freeze.
public final class Foo: @unchecked Sendable { … }
```

## Layer-import rules

A file's home target is determined by its dependencies. When in doubt:

- Touches `CoreGraphics` → `DiagramKitRenderingCG`.
- Touches `UIKit`/`AppKit` only via the `BMColor`/`BMFont`/`BMImage` shims in `Sources/DiagramKitModel/CrossPlatform.swift` → `DiagramKitModel` under a `#if canImport(UIKit) || canImport(AppKit)` gate.
- Touches `CoreText` → either `DiagramKitModel` under `#if canImport(CoreText)` (text measurement) or `DiagramKitRenderingCG` (rendering).
- No platform deps at all → `DiagramKitCommon` (preferred for portable utilities).

Files in `DiagramKitModel` cannot `import DiagramKitRenderingCG`. Files in `DiagramKitRenderingCG` import `DiagramKitModel` + `DiagramKitCommon`. The umbrella `DiagramKit` re-exports the layer below it.

## Adding a new diagram type

When porting a new mermaid diagram family from upstream `mermaid-js`:

1. **Parser** — `Sources/DiagramKitModel/src_<type>_parser.swift`. Follow the cascading `firstLine.hasPrefix(...)` discipline in [Parser.swift](Sources/DiagramKit/Parser.swift) — narrower prefixes before broader ones.
2. **Types** — `Sources/DiagramKitModel/src_<type>_types.swift` (only if the family has substantial domain types beyond what `Types.swift` covers).
3. **Layout** — `Sources/DiagramKitModel/src_<type>_layout.swift`. Returns a `PositionedContent.<type>(...)` case — extend the enum in `Sources/DiagramKitModel/PositionedPayloads.swift`.
4. **SVG renderer** — `Sources/DiagramKitModel/src_<type>_renderer.swift` (or `_svg.swift`).
5. **CG renderer** — `Sources/DiagramKitRenderingCG/DiagramRenderer+<Type>.swift`. **Both renderers must move together** — see "Drift hazard" in [ARCHITECTURE.md](ARCHITECTURE.md). Sharing geometry helpers is a long-standing follow-up; in the meantime, snapshot tests are the only guardrail.
6. **ASCII renderer** — `Sources/DiagramKitModel/src_ascii_<type>.swift` (optional but encouraged for parity).
7. **Frontmatter binding** — `Sources/DiagramKitModel/FrontmatterBinding+<Type>.swift`. Defines how YAML frontmatter and `%%{init: …}%%` directives map to the per-diagram `RenderConfig` slice.
8. **Corpus fixtures** — add 2–4 representative diagrams to `Examples/DiagramPlayground/Resources/test-diagrams.json` and re-run `PlaygroundExampleCatalogTests`.
9. **Snapshot baselines** — `SNAPSHOT_TESTING_RECORD=true swift test --filter "CorpusSnapshotTests/.*<type>-"` to generate SVG / image / ASCII baselines. Inspect each visually before committing.
10. **Diagnostics** — emit via the typed factories (`DiagramDiagnostic.lossyTransform` / `.featureDropped` / `.informational`); pick a `DiagnosticCategory` per the decision tree in [docs/diagnostic-severity-discipline.md](docs/diagnostic-severity-discipline.md). Silent drops require a `// SILENT-DROP(...)` marker with a `Pinned by:` line.

## Snapshot tests

```bash
# Re-record (after intentional visual change)
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests
SNAPSHOT_TESTING_RECORD=true swift test --filter "CorpusSnapshotTests/svgSnapshot.*<family>-"

# Verify against committed baselines
swift test --filter CorpusSnapshotTests
swift test --filter "CorpusSnapshotTests/svgSnapshot.*<family>-"
```

Baselines live under `Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests/`. The full-corpus run hits a known signal-10 hang on `main` — verify in chunks until the harness issue is resolved (see [BASELINES.md](BASELINES.md)).

## Pull-request checklist

Before opening a PR:

- [ ] `./Scripts/bootstrap-smoke-check.sh` exits 0 (modulo the documented `swift test` corpus-hang caveat and any platform runtimes not installed locally).
- [ ] No new `@unchecked Sendable` without either a green banner or a yellow allowlist entry.
- [ ] No new file > 1000 lines without an allowlist entry justified in the file-size gate's comment header.
- [ ] If you changed any renderer, both the SVG and CG paths are updated and snapshot baselines are re-recorded for both.
- [ ] If you added a public API, [README.md](README.md) and [ARCHITECTURE.md](ARCHITECTURE.md) reflect it.
- [ ] If your change shifts clean-build time by ≥ 20% or changes snapshot counts, [BASELINES.md](BASELINES.md) is refreshed.

## Deprecation policy

Public API renames follow a two-release-cycle deprecation window:

- **Tier 1 (public API):** deprecated aliases carry `@available(*, deprecated, renamed: "NewName", message: "Will be removed in the next major version.")`. The `renamed:` parameter preserves compiler fix-its. These are removed after two major releases.
- **Tier 2 (internal/SPI):** removed immediately with no deprecation cycle. No downstream consumer should reference internal typealiases or underscore-prefixed symbols.
- **New deprecations:** use the two-attribute form (`renamed:` + `message:`) for all public-facing aliases. The `message:` field documents the removal timeline.

Deprecated Mermaid-prefixed compatibility aliases (`MermaidRenderer`, `MermaidPipeline`, `MermaidImageRenderer`, `MermaidGraph`, `BeautifulMermaidError`, `MermaidStructuralError`, `MermaidView`, `MermaidDiagramView`, `MermaidLayer`, `MermaidDiagram`) remain available through the next major version with compiler fix-its pointing to their Diagram-prefixed canonical names.

## Style notes

- `async throws` is the public default. `@MainActor` is reserved for methods that produce or consume native UI types (`BMImage`, `CGContext`).
- Errors flow through `_withDiagramIssueReporting(operation:)` at every public boundary.
- Underscore-prefixed top-level names are SPI; public typealiases drop the underscore.
- Don't hardcode font names (`"Menlo"`, `"Trebuchet MS"`, etc.) in renderers — route through `RenderConfig.*` so the bundled-font determinism story holds.
- Prefer pattern-matching the typed payload enums (`DiagramPayload`, `PositionedContent`) over `as?` casts.

## Where to ask

- Architectural questions / unclear invariants: open a discussion referencing the relevant section of [ARCHITECTURE.md](ARCHITECTURE.md) or [CLAUDE.md](CLAUDE.md).
- "Should this go in Common, Model, or RenderingCG?": see the layer-import rules above; if still unsure, ask in the PR.
- Stage-plan questions (what's open, what's deferred): [ANALYSIS.md](ANALYSIS.md).

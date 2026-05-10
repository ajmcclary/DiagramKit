# Baselines

Captured **2026-05-10** as part of Stage 4 (Docs). These numbers are the reference state at the moment Stages 1–3 (module split, Linux portability, governance gates) shipped; refresh after any subsequent stage completion or significant refactor.

## Hardware & toolchain

| Field | Value |
|---|---|
| OS | Darwin 25.5.0 (macOS 15 Sonoma family) |
| Architecture | Apple silicon (`arm64`) |
| Swift | 6.3 |
| SwiftPM tools-version | 6.3 |
| Language mode | Swift 6 (`swiftLanguageModes: [.v6]`) |
| Strict concurrency | Per-target `StrictConcurrency` upcoming feature (`InferSendableFromCaptures` omitted — it's already default in Swift 6 and would emit per-file warnings) |

## Build performance

| Metric | Value | Command |
|---|---|---|
| Clean build, all targets | **53.4s** wall (≈ 116s user, 9s sys; 232% CPU) | `swift package clean && swift build` |
| Incremental build, no source changes | **4.0s** wall | `swift build` (after the clean build above) |
| `swift package dump-package` | < 1s | `swift package dump-package > /dev/null` |
| Library targets | 6 | `DiagramKitCommon`, `DiagramKitModel`, `DiagramKitRenderingCG`, `DiagramKitViews`, `DiagramKitTestSupport`, `DiagramKit` |
| Executable targets | 1 | `MermaidPlayground` |
| Test targets | 1 | `DiagramKitTests` |

The clean build runs ≈ 320 compile/link steps. Most of the wall-clock time goes to `DiagramKitModel` (the largest target by source LOC).

## Source size

| Metric | Value |
|---|---|
| Total source LOC (`find Sources -name '*.swift' \| xargs wc -l`) | **84,560** |
| Total source files | ~470 |
| Largest 11 files (>1000 lines, allowlisted) | see "File-size landscape" below |

## Test suite

| Metric | Value |
|---|---|
| Test files (XCTest + swift-testing, mixed) | **144** |
| Snapshot baselines (total) | **914** |
| └ SVG | 396 (full corpus) |
| └ Image (CG) | 346 (gap is the rendering-bug punch list — `IMAGE_BASELINES_GAP.md` style follow-up) |
| └ ASCII | 172 |
| Test corpus diagrams | **396** across 28 families (`Examples/MermaidPlayground/Resources/test-diagrams.json`) |

> **Known caveat — the corpus signal-10 hang:** running the full `CorpusSnapshotTests` parameterized suite in one go hangs / segfaults with `unexpected signal code 10` on `main` as of 2026-05-09. **The snapshots themselves are green** — running smaller filtered groups (one diagram family at a time, e.g. `--filter "CorpusSnapshotTests/svgSnapshot.*flow-"`) all pass. The full-run hang is a `swift-testing` × `swift-snapshot-testing` interaction over the 396-entry parameterized `@Test`, not a snapshot failure or refactor regression. For routine smoke checks, `--filter PlaygroundExampleCatalogTests` plus a representative renderer XCTest (e.g. `SequenceSvgTests`) is sufficient.

> **Other pre-existing test failures on `main`:** `RadarSvgTests` "SVG XML-escapes special characters" (1 issue), `RadarParserTests` "End-to-end parsing applies init directive radar config and theme" (2 issues). Treat as known baseline failures, not regressions.

## CI gate status

All four discipline gates exit 0 on `main` post-Stage 3:

| Gate | Status | Notes |
|---|---|---|
| `Scripts/check-file-sizes.sh` | ✅ exit 0 | 0 ERRORs, 56 WARNINGs (files in the 500–1000 range; not blocking). 11 files ≥ 1000 are allowlisted in `Scripts/check-file-sizes-allowlist.txt`. |
| `Scripts/check-sendable-annotations.sh` | ✅ exit 0 | 14 yellow entries in `.sendable-allowlist.txt`, sunset `2027-06-30`. No green-banner sites yet. |
| `Scripts/strict-concurrency-check.sh` | ✅ exit 0 | First-party diagnostics matching `Sources/DiagramKit*/` are clean under `-strict-concurrency=complete -warnings-as-errors`. |
| `Scripts/linux-check.sh` | ✅ exit 0 (when Docker/Podman is running) | Builds `DiagramKitCommon`, `DiagramKitModel`, `DiagramKitTestSupport`, and the `DiagramKit` umbrella's portable subset on `swift:6.3.1-noble`. |

`Scripts/bootstrap-smoke-check.sh` orchestrates the above plus `swift test` and a multiplatform `xcodebuild` sweep (iOS / visionOS / tvOS via the `DiagramKit-Package` auto-scheme). The smoke check exits 0 modulo the `swift test` corpus-hang caveat above and any platform runtimes not installed in Xcode (which the script skips, not fails).

## File-size landscape

The file-size gate uses 500-line warn / 1000-line error thresholds, matching the sibling `MusicToolkit` package.

### Allowlisted (≥ 1000 lines)

All entries below are in `DiagramKitModel` and mirror upstream `mermaid-js` source files line-for-line (per-diagram parsers / layouts / renderers / ASCII drawers). Splitting them would diverge from upstream and create maintenance churn. Listed in `Scripts/check-file-sizes-allowlist.txt`:

| File | Lines |
|---|---:|
| `Sources/DiagramKitModel/src_class_parser.swift` | 1593 |
| `Sources/DiagramKitModel/src_layout.swift` | 1539 |
| `Sources/DiagramKitModel/src_zenuml_parser.swift` | 1485 |
| `Sources/DiagramKitModel/src_er_parser.swift` | 1425 |
| `Sources/DiagramKitModel/src_renderer.swift` | 1358 |
| `Sources/DiagramKitModel/src_parser.swift` | 1276 |
| `Sources/DiagramKitModel/src_ascii_draw.swift` | 1108 |
| `Sources/DiagramKitModel/src_wardley_parser.swift` | 1040 |
| `Sources/DiagramKitModel/src_xychart_parser.swift` | 1026 |
| `Sources/DiagramKitModel/src_venn_layout.swift` | 1025 |
| `Sources/DiagramKitModel/src_sequence_types.swift` | 1010 |

### Warning band (500–1000 lines)

56 files print `WARNING:` from the gate. Notable ones (top 10):

| File | Lines |
|---|---:|
| `Tests/DiagramKitTests/RadarParserTests.swift` | 889 |
| `Sources/DiagramKitModel/src_gantt_parser.swift` | 873 |
| `Sources/DiagramKit/DiagramDescriptor.swift` | 851 |
| `Sources/DiagramKitModel/src_requirement_parser.swift` | 816 |
| `Sources/DiagramKitModel/src_sequence_parser.swift` | 803 |
| `Sources/DiagramKitModel/src_gitgraph_parser.swift` | 788 |
| `Tests/DiagramKitTests/ERParserTests+Foundation.swift` | 774 |
| `Sources/DiagramKitModel/src_kanban_parser.swift` | 772 |
| `Sources/DiagramKit/src_ascii_index.swift` | 765 |
| `Sources/DiagramKitModel/Types.swift` | 763 |

These warn but do not fail the gate. Most are JS-port parsers; `DiagramDescriptor.swift` and `Types.swift` are candidates for incremental decomposition but not blocking.

## How to refresh these baselines

```bash
# Hardware / toolchain
sw_vers
swift --version

# Build performance
swift package clean && time swift build      # clean wall-clock
time swift build                              # incremental wall-clock

# Source size
find Sources -name '*.swift' | xargs wc -l | tail -1

# Test counts
find Tests -name '*.swift' | wc -l
find Tests/DiagramKitTests/__Snapshots__ -type f | wc -l
find Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests -name 'svgSnapshot*'   | wc -l
find Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests -name 'imageSnapshot*' | wc -l
find Tests/DiagramKitTests/__Snapshots__/CorpusSnapshotTests -name 'asciiSnapshot*' | wc -l

# Corpus diagram count
python3 -c "import json; print(len(json.load(open('Examples/MermaidPlayground/Resources/test-diagrams.json'))['diagrams']))"

# Gate status
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
Scripts/linux-check.sh    # requires Docker or Podman

# File-size landscape
find Sources Tests -name '*.swift' -exec wc -l {} \; | sort -rn | head -25
```

Update this document when:

- A new stage of the [ANALYSIS.md](ANALYSIS.md) plan completes.
- The clean-build wall-clock changes by ≥ 20% (signals a meaningful target shape change).
- Snapshot-baseline counts change (e.g. new diagram family lands or the image gap closes).
- A discipline gate's exit status changes (any of the four above starts failing on `main`).

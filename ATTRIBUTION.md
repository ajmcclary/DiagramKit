# Attribution

DiagramKit is a Swift port and adaptation of [mermaid-js](https://mermaid.js.org/) and bundles assets and dependencies from several upstream projects. This file lists each with its copyright, license, and the role it plays in DiagramKit.

For a shorter, asset-focused listing of the bundled fonts (with paths and license-text references), see [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md).

## Upstream lineage — `mermaid-js`

DiagramKit's parsers, layouts, and SVG renderers are a Swift port of the reference [`mermaid-js`](https://github.com/mermaid-js/mermaid) implementation:

- **Project:** Mermaid (`mermaid-js/mermaid`)
- **Origin:** <https://github.com/mermaid-js/mermaid>
- **License:** MIT
- **Copyright:** Copyright © 2014–present Knut Sveidqvist and the Mermaid contributors
- **License text:** <https://github.com/mermaid-js/mermaid/blob/develop/LICENSE>

The port preserves upstream's per-diagram-type architecture (one parser, one layout, one renderer per family) and many of its file-naming conventions. Files prefixed `src_<type>_*.swift` in `Sources/DiagramKitModel/` and `Sources/DiagramKit/` correspond directly to upstream's `packages/mermaid/src/diagrams/<type>/` modules. Diagram syntax, frontmatter conventions, `%%{init: …}%%` directives, and theme tokens follow upstream Mermaid's published behaviour.

Where the Swift port diverges from upstream, the divergence is documented in [ARCHITECTURE.md](ARCHITECTURE.md) (notably: the dual CG/SVG renderer paths, the Apple-only image renderer, the worker-thread invariant, and the layered-target separation). Where it tracks upstream, file-level changes follow upstream as closely as practical so future merges remain feasible.

The upstream MIT licence is reproduced inline at the URL above. The MIT licence permits redistribution, modification, and commercial use, subject to inclusion of the copyright notice and license text — both of which this attribution provides via reference.

## Bundled fonts

Fonts are shipped as SwiftPM resources under [Sources/DiagramKitRenderingCG/Resources/Fonts/](Sources/DiagramKitRenderingCG/Resources/Fonts/) and registered process-wide on first use by `DiagramFontRegistry` ([Sources/DiagramKitRenderingCG/FontRegistry.swift](Sources/DiagramKitRenderingCG/FontRegistry.swift)).

### Noto Sans

- **License:** SIL Open Font License, Version 1.1
- **Copyright:** Copyright © 2015–2024 Google Inc.
- **Reserved Font Name:** "Noto Sans"
- **Origin:** <https://fonts.google.com/noto/specimen/Noto+Sans>
- **SPDX Identifier:** OFL-1.1
- **Bundled:** ✅
- **Files:** `noto-sans/NotoSans-Regular.otf`, `NotoSans-Bold.otf`, `NotoSans-Italic.otf`, `NotoSans-BoldItalic.otf`
- **License text:** [Sources/DiagramKitRenderingCG/Resources/Fonts/OFL.txt](Sources/DiagramKitRenderingCG/Resources/Fonts/OFL.txt)

Noto Sans is DiagramKit's default proportional font, used for diagram labels, edge text, and most node content. It is referenced via `RenderConfig.defaultProportionalFontFamily = "Noto Sans"` and resolved via `CTFontManagerRegisterFontsForURL` at first render.

### Noto Sans Mono

- **License:** SIL Open Font License, Version 1.1
- **Copyright:** Copyright © 2022 The Noto Project Authors
- **Reserved Font Name:** "Noto Sans Mono"
- **Origin:** <https://fonts.google.com/noto/specimen/Noto+Sans+Mono>
- **SPDX Identifier:** OFL-1.1
- **Bundled:** ✅
- **Files:** `noto-sans-mono/NotoSansMono-Regular.ttf`, `NotoSansMono-Bold.ttf`
- **License text:** [Sources/DiagramKitRenderingCG/Resources/Fonts/OFL.txt](Sources/DiagramKitRenderingCG/Resources/Fonts/OFL.txt)

Noto Sans Mono is DiagramKit's default monospace font, used for code-like labels (commit hashes in git graphs, axis tick labels, packet-diagram bit indices, etc.). It is referenced via `RenderConfig.defaultFontFamily = "Noto Sans Mono"`.

### Why bundle fonts at all?

Snapshot-image determinism depends on every host machine resolving identical glyph outlines for a given (family, size, weight, italic) tuple. Apple's system fonts (San Francisco, Menlo, etc.) drift across major OS updates: the same `UIFont.systemFont(ofSize: 14)` produces subtly different glyph paths between macOS 14 and macOS 15, breaking snapshot tests with no underlying code change. Bundling Noto Sans / Noto Sans Mono and registering them at process load gives `BMFont(name: "Noto Sans", …)` lookups a stable resolution across hosts, OS versions, and CI runners. This pattern mirrors the convention established in the sibling `MusicToolkit` package.

## Third-party Swift libraries

These dependencies are declared in [Package.swift](Package.swift) and resolved by SwiftPM. They are **not** redistributed as bundled resources; their licences live in their respective repositories.

### `swift-custom-dump`

- **Origin:** <https://github.com/pointfreeco/swift-custom-dump>
- **License:** MIT
- **Copyright:** Copyright © 2021 Point-Free, Inc.
- **SPDX Identifier:** MIT
- **Used by:** `DiagramKitTests` for diagnostic dumps in test failures.

### `xctest-dynamic-overlay` (provides `IssueReporting`)

- **Origin:** <https://github.com/pointfreeco/xctest-dynamic-overlay>
- **License:** MIT
- **Copyright:** Copyright © 2022 Point-Free, Inc.
- **SPDX Identifier:** MIT
- **Used by:** `DiagramKitCommon` and `DiagramKit` for `_reportDiagramIssue(...)` and `_withDiagramIssueReporting(operation:)` — test-time issue surfaces that no-op in production.

### `swift-crypto`

- **Origin:** <https://github.com/apple/swift-crypto>
- **License:** Apache-2.0
- **Copyright:** Copyright © 2019 Apple Inc.
- **SPDX Identifier:** Apache-2.0
- **Used by:** `DiagramKitCommon.StableID.derive(...)` on Linux only (Apple platforms use system `CryptoKit` directly via `import CryptoKit`). The dependency is gated `condition: .when(platforms: [.linux])` in `Package.swift`.

### `swift-snapshot-testing`

- **Origin:** <https://github.com/pointfreeco/swift-snapshot-testing> (currently pinned to the fork at <https://github.com/ajmcclary/swift-snapshot-testing> branch `fix-swift-6.3-attachable`)
- **License:** MIT
- **Copyright:** Copyright © 2019 Point-Free, Inc.
- **SPDX Identifier:** MIT
- **Used by:** `DiagramKitTests` for SVG / image / ASCII baselines.
- **Note on the fork:** the fork carries [pointfreeco/swift-snapshot-testing#1090](https://github.com/pointfreeco/swift-snapshot-testing/pull/1090), which fixes a Swift 6.3 `Attachable` cross-import-overlay break (`Data: Attachable` and `NSImage: AttachableAsImage` live in `_Testing_Foundation` / `_Testing_AppKit` overlays that SwiftPM only enables for test targets). Once #1090 ships in a tagged upstream release (likely 1.19.3+), `Package.swift` will switch back to the upstream `pointfreeco/swift-snapshot-testing`.

## Inspirational / convention sources

- **Sibling `MusicToolkit` package** — DiagramKit's layered-target shape, governance scripts, and bundled-font / `@unchecked Sendable` policies are direct ports from MusicToolkit. The relationship is documented in [ANALYSIS.md](ANALYSIS.md) ("Diff vs MusicToolkit conventions").

## License texts

- Bundled fonts (Noto Sans + Noto Sans Mono): [Sources/DiagramKitRenderingCG/Resources/Fonts/OFL.txt](Sources/DiagramKitRenderingCG/Resources/Fonts/OFL.txt) (SIL OFL 1.1).
- Upstream `mermaid-js` MIT licence: <https://github.com/mermaid-js/mermaid/blob/develop/LICENSE>.
- Swift libraries (MIT / Apache-2.0): see each repository linked above.

## How to update this file

When adding a new third-party dependency or bundled asset:

1. Add the SwiftPM declaration to `Package.swift`.
2. Add a subsection here with: License, Copyright, Origin URL, SPDX Identifier, Bundled (✅/❌), and a one-line "Used by" note.
3. If the asset is bundled (✅), add the same entry to [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) with file paths and the license-text reference.
4. If the licence requires reproduction in distributed binaries (some licences do), confirm `Resources/` ships the licence text alongside the asset.

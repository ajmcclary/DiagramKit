# Third-Party Licenses

DiagramKit bundles a small number of third-party assets as SwiftPM package resources. Each is reproduced here with its copyright notice and license. The full license text lives alongside the assets it covers, as noted in each section.

For the full attribution story — including upstream `mermaid-js` lineage and the Swift libraries DiagramKit depends on at the package level — see [ATTRIBUTION.md](ATTRIBUTION.md).

## Bundled fonts

Fonts are shipped under [Sources/DiagramKitRenderingCG/Resources/Fonts/](Sources/DiagramKitRenderingCG/Resources/Fonts/) and registered at runtime by `BeautifulMermaidFontRegistry` ([Sources/DiagramKitRenderingCG/FontRegistry.swift](Sources/DiagramKitRenderingCG/FontRegistry.swift)).

### Noto Sans

- **Origin:** Google Inc. — <https://fonts.google.com/noto/specimen/Noto+Sans>
- **Files:**
  - `noto-sans/NotoSans-Regular.otf`
  - `noto-sans/NotoSans-Bold.otf`
  - `noto-sans/NotoSans-Italic.otf`
  - `noto-sans/NotoSans-BoldItalic.otf`
- **License:** SIL Open Font License, Version 1.1
- **Copyright:** Copyright © 2015–2024 Google Inc.
- **Reserved Font Name:** "Noto Sans"
- **License text:** [Sources/DiagramKitRenderingCG/Resources/Fonts/OFL.txt](Sources/DiagramKitRenderingCG/Resources/Fonts/OFL.txt)

Noto Sans is DiagramKit's default proportional font, used for diagram labels, edge text, and most node content. It is referenced via `RenderConfig.defaultProportionalFontFamily = "Noto Sans"` and resolved by `CTFontManagerRegisterFontsForURL` at first render.

### Noto Sans Mono

- **Origin:** Google Inc. — <https://fonts.google.com/noto/specimen/Noto+Sans+Mono>
- **Files:**
  - `noto-sans-mono/NotoSansMono-Regular.ttf`
  - `noto-sans-mono/NotoSansMono-Bold.ttf`
- **License:** SIL Open Font License, Version 1.1
- **Copyright:** Copyright © 2022 The Noto Project Authors
- **Reserved Font Name:** "Noto Sans Mono"
- **License text:** [Sources/DiagramKitRenderingCG/Resources/Fonts/OFL.txt](Sources/DiagramKitRenderingCG/Resources/Fonts/OFL.txt)

Noto Sans Mono is DiagramKit's default monospace font, used for code-like labels (commit hashes in git graphs, axis tick labels, packet-diagram bit indices, etc.). It is referenced via `RenderConfig.defaultFontFamily = "Noto Sans Mono"`.

## Why bundle fonts at all?

Snapshot-image determinism depends on every host machine resolving identical glyph outlines for a given (family, size, weight, italic) tuple. Apple's system fonts (San Francisco, Menlo, etc.) drift across major OS updates: the same `UIFont.systemFont(ofSize: 14)` produces subtly different glyph paths between macOS 14 and macOS 15, breaking snapshot tests with no underlying code change. Bundling Noto Sans / Noto Sans Mono and registering them at process load gives `BMFont(name: "Noto Sans", …)` lookups a stable resolution across hosts, OS versions, and CI runners.

This pattern mirrors the convention established in the sibling `MusicToolkit` package.

## Other dependencies

Swift package dependencies are declared in [Package.swift](Package.swift). Their licenses live in their respective repositories:

- [swift-custom-dump](https://github.com/pointfreeco/swift-custom-dump) — MIT
- [xctest-dynamic-overlay](https://github.com/pointfreeco/xctest-dynamic-overlay) — MIT (provides `IssueReporting`)
- [swift-crypto](https://github.com/apple/swift-crypto) — Apache-2.0 (Linux-only conditional dependency for `DiagramKitCommon.StableID.derive(...)`; Apple platforms use system `CryptoKit` directly)
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) — MIT (currently pinned to the fork at [ajmcclary/swift-snapshot-testing](https://github.com/ajmcclary/swift-snapshot-testing) branch `fix-swift-6.3-attachable`, carrying [pointfreeco/swift-snapshot-testing#1090](https://github.com/pointfreeco/swift-snapshot-testing/pull/1090) until it lands in a tagged upstream release)

These are SwiftPM-managed and not redistributed as resources.

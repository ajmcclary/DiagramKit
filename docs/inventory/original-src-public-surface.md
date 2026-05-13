# Public `original_src_*` surface inventory (Phase 6)

Premise check (2026-05-13):
- `rg --no-filename -o '^open class (original_src_[a-z_]+)' Sources | sort -u` → **47** classes.
- `rg -n '^public final class original_src_' Sources` → **2** classes (`original_src_index`, `original_src_ascii_index`).
- Total public/open `original_src_*` declarations: **49**.
- `rg -n 'original_src_' Sources | wc -l` → **569** references.

Classification dimensions:
- `cross` = number of source files in *other* SwiftPM targets that reference the symbol.
- `tests/ex` = number of files in `Tests/` or `Examples/` that reference the symbol.
- Decision: `internal` (drop `public`/`open`), `spi` (`@_spi(PortCompatibility) + @available(...,deprecated)`), or `keep-public` (no change yet — rename + deprecated alias deferred to future major-version work).

## Decision table

| # | Symbol | Defined in | cross | tests/ex | Decision | Rationale |
|---|---|---|---:|---:|---|---|
| 1 | `original_src_ascii_ansi` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 2 | `original_src_ascii_canvas` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 3 | `original_src_ascii_class_diagram` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 4 | `original_src_ascii_converter` | DiagramKitModel | 1 | 0 | keep-public | One cross-target reference (`DiagramKit/src_ascii_index.swift`). |
| 5 | `original_src_ascii_draw` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 6 | `original_src_ascii_edge_bundling` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 7 | `original_src_ascii_edge_routing` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 8 | `original_src_ascii_er_diagram` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 9 | `original_src_ascii_grid` | DiagramKitModel | 1 | 0 | keep-public | One cross-target reference. |
| 10 | `original_src_ascii_index` | DiagramKit | 0 | 7 | keep-public | Test entry point (`renderMermaidASCII`, `detectDiagramType`). |
| 11 | `original_src_ascii_multiline_utils` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 12 | `original_src_ascii_pathfinder` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 13 | `original_src_ascii_sequence` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 14 | `original_src_ascii_shapes_circle` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 15 | `original_src_ascii_shapes_corners` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 16 | `original_src_ascii_shapes_diamond` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 17 | `original_src_ascii_shapes_hexagon` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 18 | `original_src_ascii_shapes_index` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 19 | `original_src_ascii_shapes_rectangle` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 20 | `original_src_ascii_shapes_rounded` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 21 | `original_src_ascii_shapes_special` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 22 | `original_src_ascii_shapes_stadium` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 23 | `original_src_ascii_shapes_state` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 24 | `original_src_ascii_shapes_types` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 25 | `original_src_ascii_types` | DiagramKitModel | 2 | 0 | keep-public | Two cross-target references (`DiagramKit/AsciiRenderRegistry.swift`); top-level aliases in `AsciiTopLevelAliases.swift` re-export its types into the public surface. |
| 26 | `original_src_ascii_validate` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 27 | `original_src_class_layout` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 28 | `original_src_class_parser` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 29 | `original_src_class_renderer` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 30 | `original_src_class_types` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 31 | `original_src_er_config` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 32 | `original_src_er_layout` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 33 | `original_src_er_parser` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 34 | `original_src_er_renderer` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 35 | `original_src_er_types` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 36 | `original_src_index` | DiagramKit | 0 | 0 | internal | Empty wrapper (`public init() {}`). |
| 37 | `original_src_layout` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 38 | `original_src_multiline_utils` | DiagramKitCommon | 12 | 0 | keep-public | Cross-target consumers in DiagramKitModel; format-neutral rename deferred. |
| 39 | `original_src_parser` | DiagramKitModel | 0 | 0 | internal | One-method wrapper around `_parseMermaidEntry`. |
| 40 | `original_src_renderer` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 41 | `original_src_sequence_layout` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 42 | `original_src_sequence_parser` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 43 | `original_src_sequence_renderer` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 44 | `original_src_sequence_types` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 45 | `original_src_shape_clipping` | DiagramKitModel | 0 | 0 | internal | Only `DiagramKitModel` references the class name. |
| 46 | `original_src_styles` | DiagramKitCommon | 14 | 0 | keep-public | Cross-target consumers; format-neutral rename deferred. |
| 47 | `original_src_text_metrics` | DiagramKitCommon | 14 | 0 | keep-public | Cross-target consumers; format-neutral rename deferred. |
| 48 | `original_src_theme` | DiagramKitCommon | 5 | 0 | keep-public | Cross-target consumers; format-neutral rename deferred. |
| 49 | `original_src_types` | DiagramKitModel | 13 | 13 | keep-public | Tests + cross-target consumers (`MermaidGraph`, `MermaidNode`, `MermaidEdge`, `Direction`, `NodeShape`, etc.); format-neutral rename deferred. |

## Summary

- **internal** (drop `public`/`open`): **40** classes.
- **keep-public** (kept as-is until a future major-version rename): **9** classes.
- **spi**: 0 — `@_spi(PortCompatibility)` would still require every cross-target consumer to add `@_spi(PortCompatibility) import …`, which is broader churn than this phase warrants. The `keep-public` set captures the same "intentional but legacy" intent without forcing the SPI flag through every importer.

## Notes

- Demotion to `internal` retains the class symbol within its defining module, so private callers continue to compile. Static methods inside lose `public`, but no external module references them (verified via `rg`).
- The 9 `keep-public` rows do **not** receive new `@available(*, deprecated, …)` annotations in this phase. Adding deprecation broadcasts a warning at every call site (~30+ in `Sources`, ~25 in `Tests`) without a concrete replacement to point at. A future format-neutral rename (e.g. `MermaidTypes`, `LegacyTextMetrics`) is the right time to land the deprecation.
- This file is **transient** — deleted at the end of Phase 6 per the plan.

# DiagramFormatID Symmetric Importer Dispatch — Design

Author: Claude (Opus 4.7)
Date: 2026-05-14
Status: Draft for review

## Problem

The import and export sides of the toolkit disagree on identity. `DiagramExporter` carries a typed `formatID: DiagramFormatID`; `ExporterRegistry` keys exporters by that ID; `DiagramExportLoader.export(_:to:registry:)` selects by ID. `DiagramSourceImporter` carries only `name: String`, `ImporterRegistry` is an ordered probe array, and `DiagramLoader.parse(_:registry:)` dispatches by first-match-wins `supports(source:)`.

The asymmetry is documented today on the `DiagramSourceImporter` protocol header (`Sources/DiagramKitImport/DiagramSourceImporter.swift:8-15`), but the justification ("exporters use the closed `DiagramFormatID` enum") is mildly wrong — `DiagramFormatID` is a `RawRepresentable(rawValue: String)` struct, open by construction. The asymmetry costs three things concretely:

1. **Type-safe round-trip routing is awkward.** Round-trip tests want one key on both sides. Today they hand-map `"Mermaid"` → `.mermaid` at use site.
2. **The public protocols are incoherent.** Two protocols, one job (identify a format), two different shapes. The protocol-header doc tries to justify the gap and gets the justification wrong.
3. **Third-party format registration is forced through display-name comparisons.** A custom format importer paired with a custom format exporter has no shared dispatch key — the importer is found by probe; the exporter is found by ID.

`CorpusEntry.expectedImporters` (the routing-test field at `Sources/DiagramKitTestSupport/CorpusEntry.swift:20`) is `[String: String]?`. Keys are format identifiers ("mermaid", "d2"), values are importer display names ("Mermaid", "D2"). It exists precisely because there's no typed routing — and the type would be tautological if there were.

## Goal

Make `DiagramFormatID` the shared dispatch key for both importers and exporters, preserve probe-based content-driven importer detection as the primary path, and migrate the corpus to the new typed shape in one atomic commit.

- `DiagramFormatID` moves from `DiagramKitExport` to `DiagramKitCommon`, where both `DiagramKitImport` and `DiagramKitExport` already depend.
- `DiagramSourceImporter` gains `var formatID: DiagramFormatID { get }`; `name: String` stays as the human-readable display label, mirroring `DiagramExporter`.
- `ImporterRegistry` gains `importer(for formatID: DiagramFormatID)`; `DiagramLoader` gains `parse(_ source: String, as formatID: DiagramFormatID, registry: ImporterRegistry)`. The existing probe-based `parse(_:registry:)` is unchanged.
- `CorpusEntry.expectedImporters` migrates to `[DiagramFormatID: DiagramFormatID]?`. The 27 corpus JSON entries' values flip from display-name form (`"Mermaid"`) to `formatID` rawValue form (`"mermaid"`). Test sites comparing `entry.expectedImporters?["…"] == "…"` rewrite to typed equality.
- `DiagramExportLoader.export(_:using exporterName:registry:)` (the name-based convenience at `Sources/DiagramKitExport/DiagramExportLoader.swift:61-85`) gains `@available(*, deprecated, renamed: "export(_:to:registry:)")`.

## Non-goals

- Closing `DiagramFormatID` into an enum. The type is `RawRepresentable(rawValue: String)` and stays open — third-party formats may construct `DiagramFormatID(rawValue: "asciiart")` and register importers/exporters under that key.
- Removing probe-based dispatch. First-match-wins on `supports(source:)` remains the primary path. The new by-ID path is opt-in for callers that have already asserted the format.
- Changing `ImporterRegistry` ordering rules or the fallback contract. `_validateFallbackContract` (at most one `isFallback`, ordered last) is unchanged.
- Adding a `DiagramExportLoader.export(_:registry:)` probe path. Exports are caller-driven by definition — there is no source buffer to probe.
- Validating `DiagramFormatID` rawValues at `CorpusEntry` decode time against a closed allowlist. The type is open; drift surfaces at the first registry-lookup miss.

## Architecture

```
DiagramKitCommon
├── DiagramFormatID                   ← moved from DiagramKitExport
└── … existing
    │
    ├── DiagramKitImport
    │   ├── DiagramSourceImporter
    │   │   ├── name: String          (unchanged — display label)
    │   │   └── formatID: DiagramFormatID  (NEW — dispatch key)
    │   ├── ImporterRegistry
    │   │   ├── importer(for source: String)         (existing — probe)
    │   │   └── importer(for formatID: DiagramFormatID)  (NEW — typed lookup)
    │   └── DiagramLoader
    │       ├── parse(_:registry:)                   (existing — probe)
    │       └── parse(_:as:registry:)                (NEW — typed dispatch)
    │
    └── DiagramKitExport
        ├── DiagramExporter           (no change to public API)
        ├── ExporterRegistry
        └── DiagramExportLoader
            ├── export(_:to:registry:)                  (existing — preferred)
            └── export(_:using:registry:) [deprecated]  (display-name lookup)
```

Both `DiagramKitImport` and `DiagramKitExport` already declare `.target(name: …, dependencies: [.target(name: "DiagramKitCommon")])` in `Package.swift`. The `DiagramFormatID` move is purely additive at the dependency graph level — no new edge required. `ARCHITECTURE.md` "imports flow only downward" rule preserved.

## Components

### A. `DiagramFormatID` — module move, no shape change

Body unchanged: `RawRepresentable(rawValue: String) + Sendable + Hashable + CustomStringConvertible` with five canonical constants (`.mermaid`, `.d2`, `.graphviz`, `.structurizr`, `.plantuml`). Lands at:

```
Sources/DiagramKitCommon/DiagramFormatID.swift     ← NEW location
Sources/DiagramKitExport/DiagramFormatID.swift     ← deleted
```

`DiagramKitExport` already imports `DiagramKitCommon`, so existing `DiagramFormatID.mermaid` references inside the export module resolve transparently. No `@_exported` wrapper required.

### B. `DiagramSourceImporter` protocol addition

```swift
public protocol DiagramSourceImporter: Sendable {
    /// Human-readable name (e.g. "Mermaid", "D2", "DOT").
    /// Display label only — not used for routing.
    var name: String { get }

    /// Canonical format identifier. Used by `ImporterRegistry.importer(for:)`
    /// and `DiagramLoader.parse(_:as:registry:)` for typed dispatch.
    var formatID: DiagramFormatID { get }

    var supportedDiagramTypes: Set<DiagramType> { get }
    var isFallback: Bool { get }
    func supports(source: String) -> Bool
    func parse(_ source: String) throws -> DiagramImportResult
}
```

No default `formatID` implementation. Every conformer declares its own, mirroring `DiagramExporter`'s current shape. The protocol-header "Identity model" section is rewritten:

> Importers carry both a `name: String` display label and a `formatID: DiagramFormatID` dispatch key. The name is for UI / diagnostics; the formatID is for typed registry lookup and round-trip pairing with the matching exporter. Probe-based first-match-wins selection on `supports(source:)` remains the primary dispatch path for content-driven detection.

### C. Per-importer `formatID` declarations

| File | Importer | formatID |
| --- | --- | --- |
| `Sources/DiagramKit/MermaidImporter.swift` | `MermaidImporter` | `.mermaid` |
| `Sources/DiagramKitD2/D2Importer.swift` | `D2Importer` | `.d2` |
| `Sources/DiagramKitGraphviz/GraphvizImporter.swift` | `GraphvizImporter` | `.graphviz` |
| `Sources/DiagramKitStructurizr/StructurizrImporter.swift` | `StructurizrImporter` | `.structurizr` |
| `Sources/DiagramKitPlantUML/PlantUMLImporter.swift` | `PlantUMLImporter` | `.plantuml` |

One line each: `public let formatID = DiagramFormatID.<id>`.

### D. `ImporterRegistry.importer(for formatID:)`

```swift
extension ImporterRegistry {
    /// The first importer in this registry whose `formatID` matches, or
    /// `nil` if none declares this format. Orthogonal to probe-based
    /// dispatch — does not call `supports(source:)`.
    public func importer(for formatID: DiagramFormatID) -> (any DiagramSourceImporter)? {
        importers.first { $0.formatID == formatID }
    }
}
```

Linear scan over `importers` (typical N ≤ 6). No side index.

### E. `DiagramLoader.parse(_:as:registry:)`

```swift
extension DiagramLoader {
    /// Parse `source` using the importer registered for `formatID`.
    /// Bypasses probing — the caller has asserted the format. If no
    /// importer in the registry declares this format, throws
    /// `DiagramError.unrecognizedFormat`.
    public static func parse(
        _ source: String,
        as formatID: DiagramFormatID,
        registry: ImporterRegistry
    ) throws -> DiagramImportResult {
        guard let importer = registry.importer(for: formatID) else {
            throw DiagramError.unrecognizedFormat(
                "no importer registered for format '\(formatID.rawValue)' in registry"
            )
        }
        return try importer.parse(source)
    }

    /// Shorthand returning only the `DiagramDocument`, discarding diagnostics.
    public static func parseDocument(
        _ source: String,
        as formatID: DiagramFormatID,
        registry: ImporterRegistry
    ) throws -> DiagramDocument {
        try parse(source, as: formatID, registry: registry).document
    }
}
```

The typed path does **not** call `supports(source:)`. The caller has asserted the format; probe-bypass is the point. If the source turns out malformed, the importer's `parse(_:)` surfaces the failure normally.

### F. `CorpusEntry.expectedImporters` migration

```swift
public struct CorpusEntry: Codable, Identifiable, Sendable {
    // … unchanged fields …

    /// Format identifier to expected importer formatID, for routing tests.
    /// Keys are the source formats present in `sources`; values are the
    /// formatID the registry should select.
    public let expectedImporters: [DiagramFormatID: DiagramFormatID]?

    // … unchanged fields …
}
```

Decoder reads JSON `[String: String]`, normalizes keys (lowercase / trim) the same way the field does today, then maps both key and value through `DiagramFormatID(rawValue:)`:

```swift
expectedImporters = try Self.decodeFormatIDMap(
    container.decodeIfPresent([String: String].self, forKey: .expectedImporters)
)
```

Helper:

```swift
private static func decodeFormatIDMap(
    _ values: [String: String]?
) throws -> [DiagramFormatID: DiagramFormatID]? {
    guard let values else { return nil }
    var result: [DiagramFormatID: DiagramFormatID] = [:]
    for (key, value) in values {
        let normalizedKey = normalizedFormat(key)
        let formatKey = DiagramFormatID(rawValue: normalizedKey)
        let formatValue = DiagramFormatID(rawValue: normalizedFormat(value))
        if result[formatKey] != nil {
            throw CorpusEntryError.duplicateFormatKey(key: normalizedKey)
        }
        result[formatKey] = formatValue
    }
    return result
}
```

Encoder writes back `[String: String]` (sorted by formatID rawValue for determinism):

```swift
if let typed = expectedImporters {
    let stringified = Dictionary(
        uniqueKeysWithValues: typed.map { ($0.key.rawValue, $0.value.rawValue) }
    )
    try container.encode(stringified, forKey: .expectedImporters)
}
```

The 26 corpus JSON entries' values flip from `"Mermaid"` → `"mermaid"`, `"D2"` → `"d2"`, `"Graphviz"` → `"graphviz"`, `"PlantUML"` → `"plantuml"`, `"Structurizr"` → `"structurizr"`. Keys are already lowercase; no key changes.

### G. `DiagramExportLoader.export(_:using:registry:)` deprecation

```swift
@available(*, deprecated, renamed: "export(_:to:registry:)",
           message: "Use formatID-based dispatch instead of display-name lookup.")
public static func export(
    _ document: DiagramDocument,
    using exporterName: String,
    registry: ExporterRegistry
) throws -> DiagramExportResult {
    // body unchanged
}
```

Existing semantics (throws `DiagramExportError` on unknown name; `.unsupported` diagnostic on type mismatch) are preserved verbatim. Only the `@available` annotation is added. No deletion in this spec.

## Data flow

### Probe (existing, unchanged)
```
caller → DiagramLoader.parse(source, registry: …)
       → registry.importer(for: source)         [iterate; first supports(source:) → true wins]
       → importer.parse(source)
       → DiagramImportResult
```

### Typed by-ID (new)
```
caller → DiagramLoader.parse(source, as: .d2, registry: …)
       → registry.importer(for: .d2)            [linear scan for formatID == .d2]
       → importer.parse(source)                 [no probe — format asserted]
       → DiagramImportResult
```

### Export (existing, unchanged)
```
caller → DiagramExportLoader.export(document, to: .d2, registry: …)
       → registry.exporter(named: .d2)
       → exporter.export(document)
       → DiagramExportResult
```

### Round-trip pairing (new capability)
```swift
let formatID: DiagramFormatID = .d2
let imported = try DiagramLoader.parse(source, as: formatID, registry: importerRegistry)
let exported = try DiagramExportLoader.export(imported.document, to: formatID, registry: exporterRegistry)
```

### Corpus routing (post-migration)
```swift
let entry = try CorpusEntry.decode(json)
let expected = entry.expectedImporters?[.d2]                  // → DiagramFormatID.d2
let resolved = registry.importer(for: .d2)?.formatID          // → DiagramFormatID.d2
#expect(expected == resolved)
```

## Error handling

### `DiagramLoader.parse(_:as:registry:)` — unknown formatID
Throws `DiagramError.unrecognizedFormat("no importer registered for format '\(formatID.rawValue)' in registry")`. Same error type the probe path already uses; only the message text distinguishes the two miss modes.

### `CorpusEntry` decode — unknown rawValue in JSON
`DiagramFormatID(rawValue:)` is the open RawRepresentable init. A JSON value like `"d2x"` decodes into `DiagramFormatID(rawValue: "d2x")` — drift surfaces at the first registry-lookup miss, not at decode. This is consistent with `DiagramFormatID`'s open semantics; closed-allowlist decode validation would re-impose closedness that the type itself doesn't have.

### `DiagramExportLoader.export(_:using exporterName:)` — deprecation
Runtime behavior unchanged. Throws `DiagramExportError("No exporter named '\(exporterName)' in registry")` on unknown name; emits `.unsupported` diagnostic on type mismatch. Only difference is the `@available(*, deprecated)` warning at the call site.

### Fallback contract
`ImporterRegistry._validateFallbackContract` keys on `isFallback`, not `formatID`. A registry may legally contain multiple importers with the same `formatID` (unusual but not invalid); by-ID lookup returns the first match. Multi-importer-per-formatID is not a tested scenario in this spec — it's the residual freedom of the open `formatID` type.

## Testing

### New: `Tests/DiagramKitTests/DiagramFormatIDLocationTests.swift`
A single `@Test` that imports `DiagramKitImport`, `DiagramKitExport`, and `DiagramKitCommon`, asserting `DiagramFormatID.mermaid` resolves to the same type from each. Compile-time sanity check that the move landed without `@_exported` gymnastics.

### New: `Tests/DiagramKitTests/DiagramSourceImporterFormatIDTests.swift`
- Five per-importer assertions:
  - `MermaidImporter().formatID == .mermaid`
  - `D2Importer().formatID == .d2`
  - `GraphvizImporter().formatID == .graphviz`
  - `StructurizrImporter().formatID == .structurizr`
  - `PlantUMLImporter().formatID == .plantuml`
- Protocol-level sweep: every importer in `DiagramPipeline.defaultRegistry` returns a non-empty `formatID.rawValue`.

### New: `Tests/DiagramKitTests/ImporterRegistryByIDTests.swift`
- `DiagramPipeline.defaultRegistry.importer(for: .d2)` returns a `D2Importer`-shaped match.
- `defaultRegistry.importer(for: DiagramFormatID(rawValue: "asciiart"))` returns `nil`.
- Multi-importer scenario: registry `[D2Importer(), MermaidImporter()]` → `importer(for: .mermaid)` finds Mermaid.
- Empty registry: `ImporterRegistry.empty.importer(for: .mermaid) == nil`.
- `prepending(D2Importer())` / `appending(MermaidImporter())` still resolve by-ID after composition.

### New: `Tests/DiagramKitTests/DiagramLoaderByIDTests.swift`
- `parse(mermaidSource, as: .mermaid, registry: default)` succeeds and returns the same document the probe path produces.
- `parse(d2Source, as: .d2, registry: default)` succeeds on D2 source.
- `parse(mermaidSource, as: .d2, registry: default)` — typed path bypasses `supports(source:)`; verify the resulting behavior (parser-throw or `.unsupported` diagnostic). Pin whichever happens as the documented contract.
- `parse(source, as: .d2, registry: registryWithoutD2)` throws `DiagramError.unrecognizedFormat`.
- `parseDocument(_:as:registry:)` convenience returns the same `DiagramDocument` as `parse(_:as:registry:).document`.

### New: `Tests/DiagramKitTests/CorpusEntryFormatIDTests.swift`
- Decode JSON with `"expectedImporters": { "mermaid": "mermaid", "d2": "d2" }`; `#expect(entry.expectedImporters?[.mermaid] == .mermaid)`.
- Encode a `CorpusEntry` with typed `expectedImporters` and assert JSON output uses string keys/values, sorted by formatID rawValue.
- Decode JSON value with unknown rawValue (`"d2x"`); assert it lands as `DiagramFormatID(rawValue: "d2x")`.
- Round-trip: decode → encode → decode produces the same typed dictionary.
- Duplicate key (case-only collision after normalization) throws `CorpusEntryError.duplicateFormatKey`.

### Existing-test sweep
- `Tests/DiagramKitTests/ImporterRegistryTests.swift`: add cases for `importer(for: DiagramFormatID)` on default registry, after `prepending` / `appending`, and on `.empty`.
- `Tests/DiagramKitTests/StructurizrCorpusFixtureTests.swift`: rewrite `entry.expectedImporters?["structurizr"] == "Structurizr"` → `entry.expectedImporters?[.structurizr] == .structurizr` (2 sites). Inline JSON literals flip `"Structurizr"` → `"structurizr"` (6 inline blocks).
- `Tests/DiagramKitTests/DOTCorpusFixtureTests.swift`: same pattern (1 expect site, 4 inline JSON blocks).
- `Tests/DiagramKitTests/D2CorpusFixtureTests.swift`: same pattern (1 expect site, 4 inline JSON blocks).
- `Tests/DiagramKitTests/CorpusMultiFormatTests.swift`: 4 expect sites + 2 inline JSON blocks.

Total existing-test sweep: 8 expect-site rewrites + 16 inline-JSON-literal edits across 4 files.
- `Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift`: confirm by-ID assertions still work (the existing tests are probe-driven; this sweep verifies no regression).
- `Tests/DiagramKitTests/Export/DiagramExportInfrastructureTests.swift`: existing `DiagramFormatID` rawValue equality tests pass unchanged after the module move (public API of the type is unchanged).
- `Tests/DiagramKitTests/Export/ExporterRegistryTests.swift`: confirm no regression.

### Corpus JSON sweep
- `Examples/DiagramPlayground/Resources/test-diagrams.json`: 27 `expectedImporters` blocks. Value replacements (54 total):
  - `"Mermaid"` → `"mermaid"` (27 occurrences — every entry maps mermaid → Mermaid)
  - `"D2"` → `"d2"` (6 occurrences)
  - `"Graphviz"` → `"graphviz"` (9 occurrences)
  - `"PlantUML"` → `"plantuml"` (6 occurrences)
  - `"Structurizr"` → `"structurizr"` (6 occurrences)
- Keys (`"mermaid"`, `"d2"`, etc.) already lowercase; no key changes.

### Discipline gates
- `Scripts/check-sendable-annotations.sh`: `DiagramFormatID` already `Sendable`; no change.
- `Scripts/check-file-sizes.sh`: all additions small; nothing crosses 500-line thresholds.
- `Scripts/strict-concurrency-check.sh`: no new actor isolation; must stay green.
- `Scripts/linux-check.sh`: `DiagramKitCommon` is Linux-portable; `DiagramFormatID` is a value type. No platform-gated paths required.

### No snapshot rebaselining
None of these changes touch renderers, layouts, or any geometry-producing path. Snapshot baselines remain valid.

## Implementation order

Suggested commit-by-commit on `main` per the project standing default. Each commit ships green tests for its own scope; later commits assume earlier landings.

1. **`DiagramFormatID` move to `DiagramKitCommon`** — delete `Sources/DiagramKitExport/DiagramFormatID.swift`, create `Sources/DiagramKitCommon/DiagramFormatID.swift`. No public API change. `DiagramKitExport` continues to compile transparently via its existing `DiagramKitCommon` import. Verify: existing `DiagramExportInfrastructureTests.swift` passes unchanged. New `DiagramFormatIDLocationTests` lands here.

2. **`DiagramSourceImporter.formatID` protocol field + per-importer declarations** — add the protocol requirement; declare `.mermaid`/`.d2`/`.graphviz`/`.structurizr`/`.plantuml` on the five built-in importers; rewrite the protocol-header "Identity model" section. Verify: new `DiagramSourceImporterFormatIDTests` lands here.

3. **`ImporterRegistry.importer(for formatID:)` + `DiagramLoader.parse(_:as:registry:)`** — add the typed lookup and dispatch entry points. Verify: new `ImporterRegistryByIDTests`, `DiagramLoaderByIDTests` land here.

4. **`CorpusEntry.expectedImporters` typed migration + JSON sweep** — change the type, add the decode/encode helpers, flip the 54 JSON value occurrences across 27 corpus entries, rewrite the 8 existing test expectations and 16 inline JSON literal blocks across `StructurizrCorpusFixtureTests` / `DOTCorpusFixtureTests` / `D2CorpusFixtureTests` / `CorpusMultiFormatTests`. Verify: new `CorpusEntryFormatIDTests` lands here; full corpus-fixture suite passes.

5. **`DiagramExportLoader.export(_:using:)` deprecation** — add the `@available(*, deprecated, renamed:)` annotation. Run a targeted build to catch deprecation warnings in tests; rewrite any call sites accordingly or accept the warning per `Scripts/strict-concurrency-check.sh` policy. Verify: green build, deprecation surfaces only in test sites that haven't migrated yet (or zero sites if the sweep is complete).

6. **`CLAUDE.md` sync** — bump `Tests/DiagramKitTests` test source count to reflect the new test files. Pure doc commit.

Six commits. None requires snapshot rebaselining. Each is small and reviewable in isolation.

## Risks and rollback

- **CorpusEntry decode strictness.** The migration assumes every existing `expectedImporters` JSON value normalizes cleanly through `DiagramFormatID(rawValue:)`. The corpus is internal; manual review of all 27 entries during the commit-4 sweep catches any odd entries. Rollback path: revert the typed migration, keep the rest of the work (commits 1–3 are independent of commit 4).
- **Deprecation noise.** Adding `@available(*, deprecated)` to `DiagramExportLoader.export(_:using:)` may surface call sites we haven't catalogued. Mitigation: the sweep in commit 5 includes a targeted build to enumerate warnings before declaring done.
- **`DiagramFormatID` module-move source compatibility.** Public API of the type is unchanged; only its declaring module shifts from `DiagramKitExport` to `DiagramKitCommon`. Consumers that import `DiagramKitExport` still see the type transparently; consumers that previously imported `DiagramKitImport` for some other reason can now see `DiagramFormatID` directly. No source-level breakage expected. If a consumer used `DiagramKitExport.DiagramFormatID` as a fully-qualified name, that breaks — but the codebase doesn't do this, and the search across `Sources/` and `Tests/` shows no fully-qualified references.

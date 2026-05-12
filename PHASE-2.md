# Phase 2: Multi-Format Corpus Foundation — Full Plan

Goal: make the corpus capable of hosting multiple source formats before the
second importer lands.

Status: planned.

---

## Architecture Overview

The goal is to make the corpus (`test-diagrams.json` + all consumers) capable of
hosting multiple source formats without changing current Mermaid behavior. The
work splits into five work streams:

1. JSON schema evolution (backward-compatible)
2. Shared type (`CorpusEntry` in `DiagramKitTestSupport`)
3. Test-side consumer updates (`CorpusSnapshotTests`)
4. Playground-side consumer updates (`SampleDiagrams.swift`)
5. New verification tests (`CorpusMultiFormatTests`)

Multi-format examples live as **inline JSON fixtures** in
`CorpusMultiFormatTests`. The real `test-diagrams.json` stays purely Mermaid for
Phase 2. Phase 3 will add real multi-format entries once d2 baselines exist.

---

## Work Stream 1: JSON Schema Extension

**File**: `Examples/MermaidPlayground/Resources/test-diagrams.json`

No changes to the real corpus in Phase 2. All 396 entries stay exactly as they
are. The multi-format schema is exercised through inline JSON strings in
`CorpusMultiFormatTests`.

### Old schema (unchanged — all 396 entries keep this shape)

```json
{
  "id": "flow-1-simple",
  "category": "flowchart",
  "name": "Simple Flow",
  "source": "graph TD\n  A[Start] --> B[Process] --> C[End]"
}
```

### New fields (all optional, available for future entries)

| Field | Type | Purpose |
|---|---|---|
| `sources` | `[String: String]?` | Format → source map. When present, `source` must equal `sources["mermaid"]`. |
| `expectedImporters` | `[String: String]?` | Format → importer name. Per-format expectation for routing tests. |
| `expectedDiagnostics` | `[ExpectedDiagnostic]?` | Non-fatal diagnostics the importer should emit (for sparse-matrix coverage). |
| `unsupportedNote` | `String?` | Human note explaining why a format is unsupported for this diagram. |
| `skipSnapshots` | `[String]?` | List of format names to skip in snapshot tests. |

### `ExpectedDiagnostic` shape

```json
{
  "severity": "unsupported",
  "messageContains": "layers"
}
```

### Backward compat invariant

When only `source` exists (all 396 entries), it is treated as equivalent to
`sources: { "mermaid": "<source>" }`. The `source` field remains the primary
key for Mermaid-only entries.

### Validation invariant

When both `source` and `sources["mermaid"]` are present, they **must** be
identical. A decoding-time assertion or post-decode validation test enforces
this. Divergent values would create ambiguity about which string is the
canonical Mermaid source.

### Test-only inline fixtures

These live as string literals in `CorpusMultiFormatTests`, not in the real
corpus file:

**Fixture A — Mermaid-primary with d2 equivalent:**

```json
{
  "id": "multi-format-flow-simple",
  "category": "flowchart",
  "name": "Multi-Format: Simple Flow",
  "source": "graph TD\n  A[Start] --> B[End]",
  "sources": {
    "mermaid": "graph TD\n  A[Start] --> B[End]",
    "d2": "A -> B"
  },
  "expectedImporters": {
    "mermaid": "Mermaid"
  },
  "unsupportedNote": null,
  "skipSnapshots": ["d2"]
}
```

**Fixture B — d2-primary with Mermaid equivalent:**

```json
{
  "id": "multi-format-d2-flow",
  "category": "flowchart",
  "name": "Multi-Format: D2 Flow",
  "source": "graph LR\n  A --> B",
  "sources": {
    "mermaid": "graph LR\n  A --> B",
    "d2": "A -> B"
  },
  "expectedImporters": {
    "mermaid": "Mermaid",
    "d2": "D2"
  },
  "unsupportedNote": null,
  "skipSnapshots": ["d2"]
}
```

> `expectedImporters.d2` won't be asserted until Phase 3 lands the d2 importer.
> In Phase 2 it serves as a decoding test. `skipSnapshots: ["d2"]` is
> pre-emptive — Phase 2 only snapshots Mermaid, and the d2 source cannot render
> through the Mermaid importer.

---

## Work Stream 2: Shared Type — `CorpusEntry`

**File**: `Sources/DiagramKitTestSupport/CorpusEntry.swift` (new)

`CorpusEntry` is the canonical decoding type for test targets. The playground
(`MermaidPlayground`) cannot depend on `DiagramKitTestSupport`, so it
duplicates the decoding in a local `TestDiagram` struct that decodes the same
JSON schema. This is accepted duplication — the JSON file is the single source
of truth.

```swift
/// A single entry in the diagram corpus (test-diagrams.json).
/// Decodes both the legacy single-format schema and the new multi-format schema.
public struct CorpusEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let category: String
    public let name: String

    /// The primary Mermaid source. Always populated — either from the
    /// top-level `source` field (legacy) or from `sources["mermaid"]`.
    /// When both exist they must be identical (enforced by post-decode validation).
    public let source: String

    /// Format → source map. When present, keys name importers
    /// (e.g. "mermaid", "d2", "graphviz").
    public let sources: [String: String]?

    /// Format → expected importer name for routing tests.
    public let expectedImporters: [String: String]?

    /// Expected non-fatal diagnostics.
    public let expectedDiagnostics: [ExpectedDiagnostic]?

    /// Human note for unsupported features.
    public let unsupportedNote: String?

    /// Format names to skip in snapshot tests.
    public let skipSnapshots: [String]?

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, category, name, source
        case sources
        case expectedImporters
        case expectedDiagnostics
        case unsupportedNote
        case skipSnapshots
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        name = try container.decode(String.self, forKey: .name)
        sources = try container.decodeIfPresent([String: String].self, forKey: .sources)
        expectedImporters = try container.decodeIfPresent([String: String].self, forKey: .expectedImporters)
        expectedDiagnostics = try container.decodeIfPresent(
            [ExpectedDiagnostic].self, forKey: .expectedDiagnostics
        )
        unsupportedNote = try container.decodeIfPresent(String.self, forKey: .unsupportedNote)
        skipSnapshots = try container.decodeIfPresent([String].self, forKey: .skipSnapshots)

        // Derive `source`: prefer `sources["mermaid"]`, fall back to `source`.
        if let mermaidSource = sources?["mermaid"] {
            source = mermaidSource
        } else {
            source = try container.decode(String.self, forKey: .source)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(category, forKey: .category)
        try container.encode(name, forKey: .name)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(sources, forKey: .sources)
        try container.encodeIfPresent(expectedImporters, forKey: .expectedImporters)
        try container.encodeIfPresent(expectedDiagnostics, forKey: .expectedDiagnostics)
        try container.encodeIfPresent(unsupportedNote, forKey: .unsupportedNote)
        try container.encodeIfPresent(skipSnapshots, forKey: .skipSnapshots)
    }

    /// Post-decode validation: when both `source` and `sources["mermaid"]`
    /// are present, they must be identical.
    public func validate() throws {
        if let mermaidSource = sources?["mermaid"], mermaidSource != source {
            throw CorpusEntryError.sourceMermaidMismatch(id: id)
        }
    }

    // MARK: - Helpers

    /// Source text for a given format name.
    /// Special-cases "mermaid" to fall back to the legacy `source` property
    /// when `sources` is nil, preserving the invariant that Mermaid source
    /// is always available.
    public func source(for format: String) -> String? {
        let key = format.lowercased()
        if key == "mermaid" {
            return sources?[key] ?? source
        }
        return sources?[key]
    }

    /// All format names present in sources.
    public var availableFormats: [String] {
        sources?.keys.sorted() ?? ["mermaid"]
    }

    /// Whether this entry carries a source for the given format.
    public func hasSource(for format: String) -> Bool {
        source(for: format) != nil
    }

    /// Whether snapshots should be skipped for the given format.
    public func shouldSkipSnapshot(for format: String) -> Bool {
        skipSnapshots?.contains(format.lowercased()) ?? false
    }
}

public enum CorpusEntryError: Error, CustomStringConvertible {
    case sourceMermaidMismatch(id: String)

    public var description: String {
        switch self {
        case .sourceMermaidMismatch(let id):
            return "Entry \"\(id)\": top-level `source` differs from `sources[\"mermaid\"]`"
        }
    }
}

/// Expected diagnostic shape in the fixture.
public struct ExpectedDiagnostic: Codable, Sendable, Equatable {
    public let severity: String
    public let messageContains: String?
}
```

### Container

```swift
/// Top-level container for test-diagrams.json.
public struct CorpusFile: Codable, Sendable {
    public let version: String?
    public let description: String?
    public let diagrams: [CorpusEntry]
}
```

> `CorpusFile` decodes the JSON file including optional `version` and
> `description` fields and ignores the `metadata` block at the end.

---

## Work Stream 3: `CorpusSnapshotTests` Updates

**File**: `Tests/DiagramKitTests/CorpusSnapshotTests.swift`

Replace the private `DiagramEntry`/`DiagramFile` structs with imports from
`DiagramKitTestSupport`:

```swift
import DiagramKitTestSupport
```

- Remove the local `DiagramEntry` and `DiagramFile` structs.
- Use `CorpusEntry` and `CorpusFile` directly.
- Update `loadDiagrams()` to decode `CorpusFile` and call `entry.validate()`
  on each entry.
- The three test methods (`svgSnapshot`, `imageSnapshot`, `asciiSnapshot`)
  continue using `diagram.source` — which now derives from `sources["mermaid"]`
  when the new schema is present.
- Snapshot names remain `diagram.id` — unchanged. All 396 existing baselines
  match.

### `Package.swift` dependency

`DiagramKitTests` does not currently depend on `DiagramKitTestSupport`. Add it:

```swift
.testTarget(
    name: "DiagramKitTests",
    dependencies: [
        "DiagramKit",
        "DiagramKitCommon",
        "DiagramKitModel",
        "DiagramKitTestSupport",   // NEW
        "MermaidPlayground",
        .target(name: "DiagramKitRenderingCG", condition: ...),
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
    ],
    ...
)
```

---

## Work Stream 4: Playground Consumer Updates

**File**: `Examples/MermaidPlayground/Models/SampleDiagrams.swift`

Since the playground can't depend on `DiagramKitTestSupport`, the `TestDiagram`
struct gets its own backward-compatible decoding. Fields and logic match
`CorpusEntry` to minimize divergence.

### Changes to `TestDiagram`

Add optional multi-format fields with an explicit custom decoder:

```swift
public struct TestDiagram: Codable, Identifiable, Sendable {
    public let id: String
    public let category: String
    public let name: String
    public let source: String
    public var options: [String: Bool]? = nil

    // Multi-format fields (all optional, nil on legacy entries)
    public let sources: [String: String]?
    public let expectedImporters: [String: String]?
    public let expectedDiagnostics: [TestExpectedDiagnostic]?
    public let unsupportedNote: String?
    public let skipSnapshots: [String]?

    enum CodingKeys: String, CodingKey {
        case id, category, name, source, options
        case sources, expectedImporters, expectedDiagnostics
        case unsupportedNote, skipSnapshots
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        name = try container.decode(String.self, forKey: .name)
        options = try container.decodeIfPresent([String: Bool].self, forKey: .options)
        sources = try container.decodeIfPresent([String: String].self, forKey: .sources)
        expectedImporters = try container.decodeIfPresent([String: String].self, forKey: .expectedImporters)
        expectedDiagnostics = try container.decodeIfPresent(
            [TestExpectedDiagnostic].self, forKey: .expectedDiagnostics
        )
        unsupportedNote = try container.decodeIfPresent(String.self, forKey: .unsupportedNote)
        skipSnapshots = try container.decodeIfPresent([String].self, forKey: .skipSnapshots)

        // Derive `source`: prefer `sources["mermaid"]`, fall back to `source`.
        if let mermaidSource = sources?["mermaid"] {
            source = mermaidSource
        } else {
            source = try container.decode(String.self, forKey: .source)
        }
    }

    /// Source text for a given format name.
    /// Special-cases "mermaid" to fall back to the legacy `source` property.
    public func source(for format: String) -> String? {
        let key = format.lowercased()
        if key == "mermaid" {
            return sources?[key] ?? source
        }
        return sources?[key]
    }
}

public struct TestExpectedDiagnostic: Codable, Sendable {
    public let severity: String
    public let messageContains: String?
}
```

### Changes to `TestDiagrams`

- `TestDiagramsFile` stays the same — it decodes `diagrams: [TestDiagram]`. The
  new fields decode or become `nil` on old entries.
- `TestDiagrams.all` continues to return `[TestDiagram]` with `source`
  populated.
- The playground UI (`SampleDiagramPanel`) uses `diagram.source` only — zero
  changes needed.
- The embedded fallback array stays as-is — old-schema entries only.

---

## Work Stream 5: New Tests

**File**: `Tests/DiagramKitTests/CorpusMultiFormatTests.swift` (new)

Test fixtures are inline JSON string literals — the real `test-diagrams.json`
is not modified.

### 1. `MultiFormatDecodingTests` — Decode tests

- `testOldSchemaDecodes` — An inline fixture with only `source` decodes;
  `source` is populated, `sources` is `nil`.
- `testNewSchemaDecodes` — An inline fixture with `sources` decodes;
  `sources["mermaid"]` is populated.
- `testSourceDerivationFromSources` — When `sources["mermaid"]` exists,
  `source` equals it.
- `testSourceFallback` — When only `source` exists (no `sources`), `source`
  is that value.
- `testSourceWithoutMermaidKeyFallsBack` — When `sources` exists but lacks
  a `"mermaid"` key, `source` decodes from the top-level `source` field.

### 2. `MultiFormatFixtureMetadataTests` — Metadata tests

- `testExpectedImportersAvailable` — A fixture with `expectedImporters` has
  them populated.
- `testExpectedDiagnosticsAvailable` — A fixture with `expectedDiagnostics`
  has them populated.
- `testAvailableFormats` — A fixture with `sources` reports correct
  `availableFormats`.
- `testHasSourceForFormat` — `hasSource(for:)` returns correct bool.
- `testMermaidSourceAlwaysAvailable` — `source(for: "mermaid")` returns a
  value even when `sources` is `nil` (legacy fallback).

### 3. `MultiFormatBackwardCompatibilityTests` — Integration tests

- `testAll396MermaidEntriesDecode` — Load the full real corpus, verify count
  ≥ 396, every entry has a non-empty `source`, all entries pass `validate()`.
- `testRealCorpusHasNoSourcesField` — Assert that no existing entry in the
  real corpus has a `sources` field (the 396 are pure Mermaid).
- `testMermaidSnapshotsUnchanged` — Spot-check ~5 real entries: render SVG via
  `DiagramEngine.renderSVG(source: entry.source)` and verify they produce
  non-empty output (not a full snapshot compare — that's
  `CorpusSnapshotTests`'s job).
- `testSecondFormatDoesNotChangeMermaidSource` — For the inline multi-format
  fixture, verify `source` stays the Mermaid string, not the d2 string.

### 4. `MultiFormatValidationTests` — Validation tests

- `testSourceMermaidMismatchThrows` — An inline fixture where `source` and
  `sources["mermaid"]` differ throws `CorpusEntryError.sourceMermaidMismatch`
  during `validate()`.
- `testSourceMermaidMatchPasses` — When `source` and `sources["mermaid"]`
  are identical, `validate()` succeeds.
- `testValidateDoesNotThrowOnLegacyEntries` — Legacy entries (no `sources`)
  pass `validate()`.

### 5. `MultiFormatSparseMatrixTests` — Sparse matrix tests

- `testAvailableFormatsIsOnlyMermaidOnLegacy` — A legacy entry reports
  `availableFormats` as `["mermaid"]`.
- `testMermaidIsAlwaysPresentInSources` — When `sources` exists and is
  non-empty, `"mermaid"` is always a key.
- `testSkipSnapshotsIsPerFormat` — `shouldSkipSnapshot(for:)` returns correct
  per-format results.

---

## File Change Summary

| File | Action |
|---|---|
| `Package.swift` | Add `DiagramKitTestSupport` as a dependency of `DiagramKitTests` |
| `Sources/DiagramKitTestSupport/CorpusEntry.swift` | **New** — canonical `CorpusEntry`, `ExpectedDiagnostic`, `CorpusFile`, `CorpusEntryError` |
| `Tests/DiagramKitTests/CorpusSnapshotTests.swift` | Replace local types with `DiagramKitTestSupport.CorpusEntry`; call `validate()` |
| `Examples/MermaidPlayground/Models/SampleDiagrams.swift` | Add optional multi-format fields + custom decoder to `TestDiagram`; add `TestExpectedDiagnostic` |
| `Tests/DiagramKitTests/CorpusMultiFormatTests.swift` | **New** — 5 test suites with inline JSON fixtures |
| `PHASES.md` | Update Phase 2 status to track progress |

### Files intentionally NOT changed

- `Examples/MermaidPlayground/Resources/test-diagrams.json` — untouched
- `SampleDiagramPanel.swift` — uses `diagram.source` only
- `DiagramKitImport` types — already designed for multi-format
- Any rendering or layout code
- Snapshot baselines — names and content preserved

---

## Execution Order

1. Create `CorpusEntry.swift` in `DiagramKitTestSupport`
2. Add `DiagramKitTestSupport` dependency to `DiagramKitTests` in `Package.swift`
3. Update `CorpusSnapshotTests.swift` to use `CorpusEntry`
4. Update `SampleDiagrams.swift` with backward-compat fields and custom decoder
5. Create `CorpusMultiFormatTests.swift` with full test coverage
6. Build + test — verify all 396 entries still decode and render
7. Update `PHASES.md` to mark Phase 2 progress

## Verification Gates

```bash
swift package dump-package
swift build --build-tests
swift test --filter CorpusSnapshotTests              # all 396 entries, no new baselines needed
swift test --filter CorpusMultiFormatTests           # 5 suites, inline fixtures only
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
git diff --check
```

No re-recording of snapshots needed — the real corpus is unchanged and this is
a pure schema/test-infrastructure extension.

---

## Design Decisions

1. **Multi-format fixtures are inline, not in the real corpus.**
   Adding new entries to `test-diagrams.json` would require new snapshot
   baselines (SVG + image + ASCII) or filtering logic in snapshot tests.
   Keeping them inline avoids both problems and keeps the corpus cleanly
   Mermaid-only until Phase 3 adds real d2 sources with proper baselines.

2. **`source` remains the primary field.** All existing consumers
   (`CorpusSnapshotTests`, `SampleDiagramPanel`) use `entry.source`. By deriving
   `source` from `sources["mermaid"]` when both exist, no consumer code changes.
   This is the single most important invariant for backward compatibility.

3. **`source(for:)` special-cases Mermaid.** When `sources` is `nil` (legacy
   entries), `source(for: "mermaid")` falls back to the top-level `source`
   property. This preserves the invariant that Mermaid source is always
   retrievable regardless of which schema variant is in use.

4. **No new SPM target for the corpus type.** `CorpusEntry` lives in
   `DiagramKitTestSupport` because it's test infrastructure. The playground
   duplicates the decoding (same JSON schema, local `TestDiagram` struct)
   because `MermaidPlayground` cannot depend on a test-only library target.
   This is accepted duplication — the JSON file is the single source of truth.

5. **Metadata is per-format, not top-level.** `expectedImporters` is a map
   from format name to importer name, not a single top-level string. A
   multi-format entry has multiple sources, and importer expectations are
   format-specific. `skipSnapshots` is similarly a list of format names.

6. **`validate()` enforces source/Mermaid consistency.** When both
   `source` and `sources["mermaid"]` are present, they must be identical.
   A decoding-time validation method catches mismatches rather than silently
   preferring one over the other.

7. **`sources` keys are importer names** (e.g. `"mermaid"`, `"d2"`,
   `"graphviz"`), not target names or enum cases. This keeps the fixture
   human-readable and decoupled from Swift module layout. An importer's
   `DiagramSourceImporter.name` property matches the fixture key.

8. **No format-should/shouldn't enforcement in Phase 2.** The
   `supportedDiagramTypes` set on each `DiagramSourceImporter` is the
   authoritative sparse-matrix definition. The fixture's `sources` map only
   carries what's actually been authored. Validation that "d2 doesn't have a
   sequence source because d2 doesn't support sequence" lives in
   `MultiFormatSparseMatrixTests`, not in the type system.

9. **Snapshot names stay `diagram.id`.** When a fixture has both Mermaid and
   d2 sources, the Mermaid path renders with snapshot name `diagram.id` (same
   as today). When Phase 3 adds d2 snapshot testing, d2 snapshots will use
   `diagram.id + "-d2"` (or similar suffix). The naming convention is
   `{id}` for Mermaid, `{id}-{format}` for non-Mermaid formats. This keeps
   existing 396 SVG + 396 image + 174 ASCII baselines matched exactly.

10. **`CorpusFile` ignores `metadata`.** The JSON has a trailing `metadata`
    object with counts. We decode only `diagrams` and skip `metadata` via
    standard `Codable` omission (keys not in `CodingKeys` are ignored). This
    avoids coupling the Swift type to a metadata shape that may change.

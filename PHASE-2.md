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
2. Shared type unification (`CorpusEntry` in `DiagramKitTestSupport`)
3. Test-side consumer updates (`CorpusSnapshotTests`)
4. Playground-side consumer updates (`SampleDiagrams.swift`)
5. New verification tests (`CorpusMultiFormatTests`)

---

## Work Stream 1: JSON Schema Extension

**File**: `Examples/MermaidPlayground/Resources/test-diagrams.json`

Each entry gains optional fields. All 396 existing entries stay unchanged. Two
new multi-format entries are added for testing.

### Old schema (unchanged — all 396 entries keep this shape)

```json
{
  "id": "flow-1-simple",
  "category": "flowchart",
  "name": "Simple Flow",
  "source": "graph TD\n  A[Start] --> B[Process] --> C[End]"
}
```

### New fields (all optional, added to a handful of test-only entries)

| Field | Type | Purpose |
|---|---|---|
| `sources` | `[String: String]?` | Format → source map. When present, `source` is derived from `sources["mermaid"]`. |
| `expectedImporter` | `String?` | The `DiagramSourceImporter.name` expected to claim this entry (for routing tests). |
| `expectedDiagnostics` | `[ExpectedDiagnostic]?` | Non-fatal diagnostics the importer should emit (for sparse-matrix coverage). |
| `unsupportedNote` | `String?` | Human note explaining why a format is unsupported for this diagram. |
| `skipSnapshot` | `Bool?` | When `true`, this entry is skipped in snapshot tests for the relevant format. |

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

### New multi-format test entries (appended to `diagrams` array)

**Entry 1 — Mermaid-primary with d2 equivalent:**

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
  "expectedImporter": "Mermaid",
  "unsupportedNote": null,
  "skipSnapshot": false
}
```

**Entry 2 — d2-primary with Mermaid equivalent:**

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
  "expectedImporter": "d2",
  "unsupportedNote": null,
  "skipSnapshot": false
}
```

> `expectedImporter: "d2"` won't pass until Phase 3 lands the d2 importer, but
> the fixture is ready now. In Phase 2 it serves as a decoding test.

---

## Work Stream 2: Shared Type — `CorpusEntry`

**File**: `Sources/DiagramKitTestSupport/CorpusEntry.swift` (new)

A single canonical type that replaces the duplicated `DiagramEntry`/`TestDiagram`
decoding logic. Both `CorpusSnapshotTests` and `SampleDiagrams.swift` decode the
same JSON schema.

```swift
/// A single entry in the diagram corpus (test-diagrams.json).
/// Decodes both the legacy single-format schema and the new multi-format schema.
public struct CorpusEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let category: String
    public let name: String

    /// The primary Mermaid source. Always populated — either from the
    /// top-level `source` field (legacy) or from `sources["mermaid"]`.
    public let source: String

    /// Format → source map. When present, keys name importers
    /// (e.g. "mermaid", "d2", "graphviz").
    public let sources: [String: String]?

    /// Expected importer name for routing tests.
    public let expectedImporter: String?

    /// Expected non-fatal diagnostics.
    public let expectedDiagnostics: [ExpectedDiagnostic]?

    /// Human note for unsupported features.
    public let unsupportedNote: String?

    /// Skip snapshot rendering for this entry.
    public let skipSnapshot: Bool?

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, category, name, source
        case sources
        case expectedImporter
        case expectedDiagnostics
        case unsupportedNote
        case skipSnapshot
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(String.self, forKey: .category)
        name = try container.decode(String.self, forKey: .name)
        sources = try container.decodeIfPresent([String: String].self, forKey: .sources)
        expectedImporter = try container.decodeIfPresent(String.self, forKey: .expectedImporter)
        expectedDiagnostics = try container.decodeIfPresent(
            [ExpectedDiagnostic].self, forKey: .expectedDiagnostics
        )
        unsupportedNote = try container.decodeIfPresent(String.self, forKey: .unsupportedNote)
        skipSnapshot = try container.decodeIfPresent(Bool.self, forKey: .skipSnapshot)

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
        try container.encodeIfPresent(expectedImporter, forKey: .expectedImporter)
        try container.encodeIfPresent(expectedDiagnostics, forKey: .expectedDiagnostics)
        try container.encodeIfPresent(unsupportedNote, forKey: .unsupportedNote)
        try container.encodeIfPresent(skipSnapshot, forKey: .skipSnapshot)
    }

    // MARK: - Helpers

    /// Source text for a given importer name.
    public func source(for importerName: String) -> String? {
        sources?[importerName.lowercased()]
    }

    /// All importer names present in sources.
    public var availableFormats: [String] {
        sources?.keys.sorted() ?? ["mermaid"]
    }

    /// Whether this entry carries a source for the given format.
    public func hasSource(for format: String) -> Bool {
        source(for: format) != nil
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
- Update `loadDiagrams()` to decode `CorpusFile`.
- The three test methods (`svgSnapshot`, `imageSnapshot`, `asciiSnapshot`)
  continue using `diagram.source` — which now derives from `sources["mermaid"]`
  when the new schema is present.
- Snapshot names remain `diagram.id` — unchanged. All 396 existing baselines
  match.

---

## Work Stream 4: Playground Consumer Updates

**File**: `Examples/MermaidPlayground/Models/SampleDiagrams.swift`

Since the playground can't depend on `DiagramKitTestSupport`, the `TestDiagram`
struct gets its own backward-compatible decoding. But fields and logic match
`CorpusEntry` to minimize divergence.

### Changes to `TestDiagram`

Add optional multi-format fields:

```swift
public struct TestDiagram: Codable, Identifiable, Sendable {
    public let id: String
    public let category: String
    public let name: String
    public let source: String
    public var options: [String: Bool]? = nil
    public let sources: [String: String]?
    public let expectedImporter: String?
    public let expectedDiagnostics: [TestExpectedDiagnostic]?
    public let unsupportedNote: String?
    public let skipSnapshot: Bool?
    // ... same Codable derivation logic as CorpusEntry
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

### 1. `MultiFormatDecodingTests` — Decode tests

- `testOldSchemaDecodes` — A fixture with only `source` decodes; `source` is
  populated, `sources` is `nil`.
- `testNewSchemaDecodes` — A fixture with `sources` decodes;
  `sources["mermaid"]` is populated.
- `testSourceDerivationFromSources` — When `sources["mermaid"]` exists,
  `source` equals it.
- `testSourceFallback` — When only `source` exists (no `sources`), `source`
  is that value.

### 2. `MultiFormatFixtureMetadataTests` — Metadata tests

- `testExpectedImporterAvailable` — A fixture with `expectedImporter` has it
  populated.
- `testExpectedDiagnosticsAvailable` — A fixture with `expectedDiagnostics`
  has them populated.
- `testAvailableFormats` — A fixture with `sources` reports correct
  `availableFormats`.
- `testHasSourceForFormat` — `hasSource(for:)` returns correct bool.

### 3. `MultiFormatBackwardCompatibilityTests` — Integration tests

- `testAll396MermaidEntriesDecode` — Load the full corpus, verify count ≥ 396,
  every entry has a non-empty `source`.
- `testMermaidSnapshotsUnchanged` — Spot-check ~5 entries: render SVG via
  `DiagramEngine.renderSVG(source: entry.source)` and verify they don't crash
  (not a full snapshot compare — that's `CorpusSnapshotTests`'s job).
- `testSecondFormatDoesNotChangeMermaidSource` — For the multi-format entry,
  verify `source` stays the Mermaid string, not the d2 string.

### 4. `MultiFormatSparseMatrixTests` — Sparse matrix tests

- `testNoFormatForcedOnAllEntries` — For the new multi-format entries, verify
  `sources` only contains relevant formats (e.g., no DOT source on a sequence
  diagram).
- `testMermaidIsAlwaysPresent` — When `sources` exists, `sources["mermaid"]`
  is always present.

---

## File Change Summary

| File | Action |
|---|---|
| `Examples/MermaidPlayground/Resources/test-diagrams.json` | Add 2 multi-format entries; keep all 396 unchanged |
| `Sources/DiagramKitTestSupport/CorpusEntry.swift` | **New** — canonical `CorpusEntry`, `ExpectedDiagnostic`, `CorpusFile` |
| `Tests/DiagramKitTests/CorpusSnapshotTests.swift` | Replace local types with `DiagramKitTestSupport` imports; use `CorpusEntry` |
| `Examples/MermaidPlayground/Models/SampleDiagrams.swift` | Add optional multi-format fields to `TestDiagram`; backward-compat decoding |
| `Tests/DiagramKitTests/CorpusMultiFormatTests.swift` | **New** — 4 test suites |
| `PHASES.md` | Update Phase 2 status from "planned" to track progress |

### Zero changes to

- `SampleDiagramPanel.swift` (uses `diagram.source` only)
- `DiagramKitImport` types (already designed for multi-format)
- Any rendering or layout code
- Snapshot baselines (names and content preserved)

---

## Execution Order

1. Create `CorpusEntry.swift` in `DiagramKitTestSupport`
2. Update `test-diagrams.json` with 2 multi-format entries
3. Update `CorpusSnapshotTests.swift` to use `CorpusEntry`
4. Update `SampleDiagrams.swift` with backward-compat fields
5. Create `CorpusMultiFormatTests.swift` with full test coverage
6. Build + test — verify all 396 entries still decode and render
7. Update `PHASES.md` to mark Phase 2 progress

## Verification Gates

```bash
swift build --build-tests
swift test --filter CorpusSnapshotTests              # all 396+2 entries
swift test --filter MultiFormatDecodingTests
swift test --filter MultiFormatFixtureMetadataTests
swift test --filter MultiFormatBackwardCompatibilityTests
swift test --filter MultiFormatSparseMatrixTests
Scripts/check-file-sizes.sh
```

No re-recording of snapshots needed — this is a pure schema extension, no
rendering changes.

---

## Design Decisions

1. **`source` remains the primary field.** All existing consumers
   (`CorpusSnapshotTests`, `SampleDiagramPanel`) use `entry.source`. By deriving
   `source` from `sources["mermaid"]` when both exist, no consumer code changes.
   This is the single most important invariant for backward compatibility.

2. **No new SPM target for the corpus type.** `CorpusEntry` lives in
   `DiagramKitTestSupport` because it's test infrastructure. The playground
   duplicates the decoding (same JSON schema, local `TestDiagram` struct)
   because the playground can't depend on a test target. This is accepted
   duplication — the JSON file is the single source of truth.

3. **`sources` keys are importer names** (e.g. `"mermaid"`, `"d2"`,
   `"graphviz"`), not target names or enum cases. This keeps the fixture
   human-readable and decoupled from Swift module layout. An importer's
   `DiagramSourceImporter.name` property matches the fixture key.

4. **No format-should/shouldn't enforcement in Phase 2.** The
   `supportedDiagramTypes` set on each `DiagramSourceImporter` is the
   authoritative sparse-matrix definition. The fixture's `sources` map only
   carries what's actually been authored. Validation that "d2 doesn't have a
   sequence source because d2 doesn't support sequence" lives in
   `MultiFormatSparseMatrixTests`, not in the type system.

5. **Snapshot names stay `diagram.id`.** When a fixture has both Mermaid and
   d2 sources, the Mermaid path renders with snapshot name `diagram.id` (same
   as today). When Phase 3 adds d2 snapshot testing, d2 snapshots will use
   `diagram.id + "-d2"` (or similar suffix). The naming convention is
   `{id}` for Mermaid, `{id}-{format}` for non-Mermaid formats. This keeps
   existing 396 SVG + 396 image + 174 ASCII baselines matched exactly.

6. **`CorpusFile` ignores `metadata`.** The JSON has a trailing `metadata`
   object with counts. We decode only `diagrams` and skip `metadata` via
   standard `Codable` omission (keys not in `CodingKeys` are ignored). This
   avoids coupling the Swift type to a metadata shape that may change.

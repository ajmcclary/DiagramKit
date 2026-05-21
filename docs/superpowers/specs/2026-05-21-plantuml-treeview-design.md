# Wave H — PlantUML treeView (WBS + JSON + YAML)

Status: draft (design only — implementation plan to follow).
Closes: gap row `treeView × PlantUML` (`—` → `✓`) in
[`COVERAGE.md`](../../../COVERAGE.md).

## Summary

Add three PlantUML upstream-dialect import probes — `@startwbs`, `@startjson`,
`@startyaml` — all landing on the canonical `TreeViewDiagram` payload, plus a
new `PlantUMLTreeViewExporter` that emits `@startwbs` as the single canonical
encoding. Flips the `treeView × PlantUML` matrix cell from `—` to `✓` for both
import and export, raising PlantUML's coverage from 9/28 to 10/28 in both
matrices.

Round-trip discipline applies: every importer/exporter pair gets same-format
fixtures, and the three cross-format intersections (`mermaid`, `d2`, `dot` ↔
`plantuml`) gain new directed pairs against the existing treeView coverage.

### Behavior change (called out)

`@startwbs` currently dispatches to `PlantUMLMindmapParser` and produces a
`MindmapDiagram` payload. This spec **retargets** `@startwbs` to a new
`PlantUMLWBSParser` → `TreeViewDiagram`. Justification: WBS is structurally a
rectangular hierarchical breakdown that matches `TreeViewNode`'s file/directory
semantics (leaf ⇒ `.file`, branch ⇒ `.directory`) better than `MindmapNode`'s
radial layout / shape variety.

Migration cost: one test file
(`Tests/DiagramKitTests/PlantUMLMindmapImporterTests.swift` — split WBS cases
into a new `PlantUMLWBSImporterTests.swift`), dispatch update in
`PlantUMLImporter.swift`, probe update in `PlantUMLFamilyProbe.swift`. No
corpus entries currently use `@startwbs`.

## Out of scope

- No new canonical payload surface. `TreeViewDiagram` / `TreeViewNode` are
  reused as-is. No model-layer expansion.
- No preservation of WBS-specific shape variants (`<<arrow>>`,
  `<<separator>>`, `<<box>>`) or color suffixes (`#LightBlue`). These are
  lossy-dropped on import with `.featureDropped(.slotUnsupported, …)`
  diagnostics. A future spec can add markers / model surface if user need
  emerges.
- No support for YAML anchors, aliases, tags, multi-document streams, flow
  style, or block scalars. Each triggers `.featureDropped(.slotUnsupported,
  …)` and is skipped during parse.
- No JSON-schema validation.
- No per-call encoding selector on the exporter (no `.json` / `.yaml` knob).
  JSON and YAML are import-only entry points that converge to WBS on export.
- PlantUML's existing `@startmindmap` dialect is untouched. WBS is migrated
  out of the mindmap parser; the mindmap parser stays as-is for
  `@startmindmap` sources.

## File layout

Three new sibling directories under `Sources/DiagramKitPlantUML/`, mirroring
the established per-dialect pattern (Mindmap, Activity, Sequence, etc.):

```text
Sources/DiagramKitPlantUML/
├── WBS/
│   ├── PlantUMLWBSParser.swift       # @startwbs body → PlantUMLWBSTree AST
│   ├── PlantUMLWBSMapper.swift       # AST → TreeViewDiagram + diagnostics
│   └── PlantUMLWBSAST.swift          # PlantUMLWBSNode + shape/color slots
├── JSON/
│   ├── PlantUMLJSONParser.swift      # @startjson body → parsed JSON value
│   └── PlantUMLJSONMapper.swift      # parsed value → TreeViewDiagram + diagnostics
├── YAML/
│   ├── PlantUMLYAMLParser.swift      # @startyaml body → YAMLValue AST
│   └── PlantUMLYAMLMapper.swift      # AST → TreeViewDiagram + diagnostics
└── Exporter/
    └── PlantUMLTreeViewExporter.swift  # TreeViewDiagram → @startwbs + markers
```

Updates to existing files:
- `PlantUMLProbe.swift` — extend `extractPlantUMLBody`'s regex to include
  `json` and `yaml` start kinds.
- `PlantUMLFamilyProbe.swift` — drop `|| startKind == "wbs"` from
  `isPlantUMLMindmap`; add `isPlantUMLWBS`, `isPlantUMLJSON`, `isPlantUMLYAML`.
- `PlantUMLImporter.swift` — three new dispatch branches at top of cascade
  (JSON, YAML, WBS, in that order); add `.treeView` to
  `supportedDiagramTypes`.
- `PlantUMLRecoveryMarker.swift` — three new `Kind` cases and matching
  parse/emit helpers (see [Recovery markers](#recovery-markers)).
- `Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift` — add
  `case .treeView(let diagram):` dispatch to `PlantUMLTreeViewExporter`.

No changes to `DiagramKitCommon`, `DiagramKitModel`, or any other slice. No
new public API beyond what falls out of importer/exporter registry
conformance.

## Outer probe + family dispatch

### Outer probe (`PlantUMLProbe.swift`)

Extend the regex from

```swift
"@start(uml|mindmap|gantt|wbs)(.*?)@end(uml|mindmap|gantt|wbs)"
```

to

```swift
"@start(uml|mindmap|gantt|wbs|json|yaml)(.*?)@end(uml|mindmap|gantt|wbs|json|yaml)"
```

The `startKind == endKind` invariant is preserved. Sources opening with
`@startjson` or `@startyaml` now satisfy `isPlantUMLSource(_:)` and reach the
family router.

### Family routing order (`PlantUMLImporter.swift`)

Insert three new top-of-cascade branches above Gantt. `startKind` is the
narrowest possible signal, so these short-circuit before any body-content
probes:

```text
 1. JSON     (`@startjson`)         ← NEW
 2. YAML     (`@startyaml`)         ← NEW
 3. WBS      (`@startwbs`)          ← NEW (split out of Mindmap)
 4. Gantt    (`@startgantt`)
 5. Mindmap  (`@startmindmap` only — no longer claims `wbs`)
 6. C4       (C4-specific keywords)
 …rest unchanged.
```

Each new branch is a single `startKind == "json"` / `"yaml"` / `"wbs"` test.
Body content is irrelevant for routing.

### Family probes (`PlantUMLFamilyProbe.swift`)

- Modify `isPlantUMLMindmap(startKind:_:)` to accept only `startKind ==
  "mindmap"`.
- Add `isPlantUMLWBS(startKind:_:)`, `isPlantUMLJSON(startKind:_:)`,
  `isPlantUMLYAML(startKind:_:)` — each a single-line check on `startKind`.

### `supportedDiagramTypes` set

Add `.treeView` to `PlantUMLImporter.supportedDiagramTypes`. `.mindmap` stays
in the set.

## Payload mapping

All three dialects produce a `TreeViewDiagram` whose `root` is the topmost
node. `TreeViewNode.level` is 0 for the root and increments with depth.
`TreeViewNodeType` is derived structurally: any node that accumulates
children during parse ⇒ `.directory`; any leaf ⇒ `.file`. `TreeViewNode.id`
is assigned in **DFS pre-order during parse** — this is a structural
invariant relied on by recovery-marker keying.

### WBS

Standard PlantUML mindmap-style indent syntax (`*`, `**`, `***`, …;
alternates `+`, `-`). The first marker run is the depth; the label is the
remainder of the line after the marker run and one space.

- `name` ← line label after stripping leading marker run, one space, any
  `<<shape>>` token, and any color suffix (`#name` / `#hexvalue`).
- `level` ← marker-run length minus 1 (so `*` ⇒ 0 = root).
- `nodeType` ← `.directory` if the node accumulates children during parse;
  otherwise `.file`.
- WBS `title …` lines → `TreeViewDiagram.diagramTitle`.
- WBS `caption`, `legend`, `header`, `footer` blocks: out of scope; emit
  `.featureDropped(.slotUnsupported, …)`.
- `<<shape>>` token and color suffix: extracted by regex on each node line,
  dropped from `name`, and surfaced via `.featureDropped(.slotUnsupported,
  …)` diagnostics. **No marker preservation.**

### JSON

Parse via `Foundation.JSONSerialization` (Linux-portable). Mapping rules on
the resulting `Any` tree:

| JSON value | TreeViewNode |
|------------|--------------|
| Object `{"k": v, …}` | `.directory`; each key `k` is a child with `name = k` and subtree from `v` |
| Array `[v0, v1, …]` | `.directory`; each element is a child with synthesized `name = "[i]"` |
| String, Number, Bool, Null | `.file`; `description` holds the JSON literal (`"hello"`, `42`, `true`, `null`) |

If the root JSON document itself is a primitive (e.g. `42`), synthesize a
single-leaf tree with `name = "(root)"`. This is the unambiguous canonical
encoding and is documented in the mapper's doc-comment.

### YAML

Hand-rolled minimal indent scanner (NSRegularExpression-driven; no
third-party dependency — Foundation has no `YAMLSerialization` on Linux).
**Supported subset**: scalars (quoted + plain), block mappings (`key:
value`), block sequences (`- item`), nested combinations, line comments
(`#`). Value mapping mirrors JSON exactly (mappings ⇒ `.directory` with
string keys, sequences ⇒ `.directory` with `[i]` keys, scalars ⇒ `.file`
leaves with the literal in `description`).

**Unsupported subset** (each triggers `.featureDropped(.slotUnsupported, …)`
naming the feature, then continues parsing the remainder where recoverable):

- Anchors (`&name`) and aliases (`*name`)
- Tags (`!!str`, `!Person`, etc.)
- Multi-document streams (additional `---` markers after the first document)
- Flow style (`{a: b}`, `[a, b]` inline collections)
- Block scalars (`|`, `>`)

Parse errors (invalid indent, unterminated scalar) raise
`DiagramError.malformedSource(message:)`.

### Diagnostics surface (shared)

- Empty bodies, missing closing tag, structural parse errors →
  `DiagramError.malformedSource(message:)`.
- Per-node unrepresentable features → `.featureDropped(.slotUnsupported,
  …)`.
- Multiple roots / skipped indent levels → `.informational(.parserRecovery,
  …)`.

## Recovery markers

Three new `PlantUMLRecoveryMarker.Kind` cases:

```swift
case treeViewNodeDescription(nodeId: Int, base64Body: String)
case treeViewNodeIcon(nodeId: Int, iconId: String)
case treeViewNodeCssClass(nodeId: Int, cssClass: String)
```

**Wire format.** Standard `' diagramkit:` line-comment shape:

```
' diagramkit:treeview-node-description=<nodeId>,b64:<base64>
' diagramkit:treeview-node-icon=<nodeId>,<iconId>
' diagramkit:treeview-node-cssclass=<nodeId>,<cssClass>
```

The description payload uses `b64:` to safely carry `;`, `:`, newlines, and
control characters (matching the existing `deploymentNote` /
`deploymentLegend` pattern). Icon and cssClass payloads use the standard
`sanitize(...)` helper since they are identifier-safe strings.

**Marker keying.** `nodeId` is `TreeViewNode.id`, assigned in DFS pre-order
during parse. All three new mappers (WBS / JSON / YAML) follow the same
pre-order convention so cross-format imports produce matching id sequences.
This invariant is documented in each mapper file's doc-comment.

**Application order.** `PlantUMLImporter` runs the existing
`PlantUMLRecoveryMarker.scanner.scan(source:)` after parse + map for any
`@startwbs` body. Description / icon / cssClass markers apply to nodes by
DFS pre-order id. Markers referencing unknown ids are silently dropped
(matches existing `applyActivityOriginalIdMarkers` behavior).

## `PlantUMLTreeViewExporter`

Single canonical output shape:

```
@startwbs
title <diagramTitle if set>
' diagramkit:treeview-node-description=42,b64:NDI=
' diagramkit:treeview-node-icon=3,folder
* (root)
** child1
*** leaf1
** child2
@endwbs
```

Markers emit in a deterministic block immediately after `@startwbs` (and
after the `title` line if present), in ascending `nodeId` order, grouped by
kind (descriptions first, then icons, then cssClasses). Tree body follows:
one `* ` per depth level, node `name` after one space. No inline `:value;`
syntax — descriptions always travel via the marker.

**Diagnostics emitted by the exporter:**

- None on the canonical path.
- Node `name` contains a newline → `.lossyTransform(.idSanitization,
  "PlantUML WBS node names must be single-line", …)`. Strip newlines
  silently.
- `TreeViewDiagram.accTitle` / `accDescr` non-nil →
  `.featureDropped(.slotUnsupported, "PlantUML WBS does not preserve
  accessibility metadata", …)`. A future spec can add markers.

**No exporter modes / no encoding selector.** All `.treeView` payloads route
through this single canonical path. JSON and YAML are import-only entry
points that converge to WBS on export.

**Registry wiring.** `Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift`
gains a `case .treeView(let diagram):` branch delegating to
`PlantUMLTreeViewExporter().export(diagram)`.

**Error behavior.** `PlantUMLTreeViewExporter` never throws — every
`TreeViewDiagram` produces a valid `@startwbs … @endwbs` block. Empty
diagrams (no nodes) produce an empty body with just `@startwbs` / `@endwbs`
plus optional title.

## Diagnostics and `RoundTripLoss` allowances

| Stage | Site | Factory | Category |
|-------|------|---------|----------|
| WBS parse | `<<shape>>` token | `.featureDropped` | `.slotUnsupported` |
| WBS parse | `#color` suffix | `.featureDropped` | `.slotUnsupported` |
| WBS parse | Multiple roots | `.informational` | `.parserRecovery` |
| WBS parse | Skipped indent level | `.informational` | `.parserRecovery` |
| JSON parse | `JSONSerialization` throws | `throw .malformedSource` | — |
| YAML parse | Unsupported feature | `.featureDropped` | `.slotUnsupported` |
| YAML parse | Invalid indent / scalar | `throw .malformedSource` | — |
| Exporter | Newline in node `name` | `.lossyTransform` | `.idSanitization` |
| Exporter | `accTitle` / `accDescr` set | `.featureDropped` | `.slotUnsupported` |

No new `DiagnosticCategory` cases. No new `RoundTripLoss` kinds — reuses the
existing `.slotUnsupported` and `.idSanitization` kinds.

Per-cell `allowedLosses` (registered in
`Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift`):

| Cell | Allowed losses |
|------|----------------|
| `treeView × plantuml` same-format (WBS fixture) | `[.slotUnsupported]` |
| `treeView × plantuml` same-format (JSON fixture) | `[]` |
| `treeView × plantuml` same-format (YAML fixture) | `[.slotUnsupported]` (only when the fixture exercises an unsupported feature; minimal fixture is `[]`) |
| `treeView × plantuml` cross-format pairs | `[.slotUnsupported, .idSanitization]` |

The discipline script `Scripts/check-diagnostic-discipline.sh` continues to
enforce typed-factory usage at the source-grep level. New parser/exporter
files use the typed factories only — no raw
`DiagramDiagnostic(severity:message:)` constructor calls.

## Round-trip fixtures

### New same-format fixtures (3)

Under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-treeview/`:

1. `plantuml-treeview-wbs.puml` — exercises WBS canonical encoding: 3-level
   hierarchy, mixed branch/leaf, one node with `<<box>>` shape variant, one
   with `#LightBlue` color suffix, `title` set, `accTitle` set (drops with
   diagnostic).
2. `plantuml-treeview-json.puml` — `@startjson` source with nested object +
   array + each primitive type (string, int, float, bool, null). Exercises
   the description-marker round-trip path.
3. `plantuml-treeview-yaml.puml` — `@startyaml` source with nested mappings
   + sequences + scalars. Plain unsupported-features fixture (no anchors,
   tags, or multi-doc).

### New cross-format directed pairs (6 directed / 3 unordered)

Under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-treeview-plantuml/`:

- `mermaid ↔ plantuml` (treeView): 2 directed. Mermaid file-tree source with
  iconIds exercises the icon-marker preservation path.
- `d2 ↔ plantuml` (treeView): 2 directed. D2 tree source.
- `dot ↔ plantuml` (treeView): 2 directed. DOT tree source.

Each cross-format pair gets one fixture per source format. Fixtures use
minimal trees that exercise structural shape plus at least one `iconId` or
`description` per node where the source format supports it.

### Registry updates

- `Tests/DiagramKitTests/RoundTrip/RoundTripCellRegistry.swift` — new
  `treeView × plantuml` same-format `RoundTripCell` with `allowedLosses` per
  the table above.
- `Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift` — six new
  directed cross-format entries pointing at the new cross fixtures.

### Fixture totals after this spec lands

- Same-format: 40 → 43 (+3).
- Cross-format directed: 76 → 82 (+6).
- Cross-format unordered: 38 → 41 (+3).

All new fixtures run under the existing `RoundTripCellTests` parameterized
run. No new XCTest target. `swift test --filter "RoundTrip"` exercises the
new fixtures automatically.

## `COVERAGE.md` updates

- **Import matrix**: row `treeView`, column `PlantUML`: `—` → `✓`. PlantUML
  totals: 9/28 → 10/28.
- **Export matrix**: row `treeView`, column `PlantUML`: `—` → `✓`. PlantUML
  totals: 9/28 → 10/28.
- **Round-trip discipline table**: PlantUML same-format set gains
  `treeView`. Cross-format pairs gain `treeView × {mermaid↔plantuml,
  d2↔plantuml, dot↔plantuml}`.
- **Last-audited line**: "Last audited: 2026-05-21 (Wave G)" → "Last
  audited: 2026-05-21 (Wave H)".
- **Partial-support detail prose**: append a `Wave H` paragraph (text
  provided in [Closing-commit prose](#closing-commit-prose) below).
- **Backlog summary**: append a struck-through item 9:
  > 9. ~~**PlantUML expansion: treeView (one family × three import dialects
  >    + one canonical export encoding, marker-recovered round-trip + 3 new
  >    cross-format pairs).**~~ Closed by Wave H (2026-05-21-plantuml-treeview spec).

### Closing-commit prose

> **Wave H — PlantUML treeView (WBS + JSON + YAML).** PlantUML gains one
> family (no matrix `⚠` involved; the cell was `—`). Detection:
> marker-forced via outer-probe start keywords (`@startwbs`, `@startjson`,
> `@startyaml`); body-content probes unchanged. Three new shared
> recovery-marker kinds (`treeViewNodeDescription`, `treeViewNodeIcon`,
> `treeViewNodeCssClass`) preserve `TreeViewNode.description` (where
> JSON/YAML primitive values land), `TreeViewNode.iconId`, and
> `TreeViewNode.cssClass` across same-format and cross-format round-trip.
> PlantUML treeView export emits a single canonical encoding (`@startwbs` +
> markers); JSON and YAML are import-only entry points that converge to WBS
> on export. **Behavior change**: `@startwbs` previously routed to
> `PlantUMLMindmapParser` and produced a `MindmapDiagram` payload; this
> spec retargets it to `PlantUMLWBSParser` → `TreeViewDiagram`.
> WBS-specific shape variants (`<<arrow>>`, `<<separator>>`, `<<box>>`)
> and color suffixes (`#color`) are lossy-dropped on import via
> `.featureDropped(.slotUnsupported, …)` with no marker preservation.
> Cross-format paths `mermaid ↔ plantuml`, `d2 ↔ plantuml`, `dot ↔
> plantuml` (3 unordered, 6 directed) bridge through the canonical
> `TreeViewDiagram` payload. No new `DiagnosticCategory` cases; reuses
> `.slotUnsupported` / `.idSanitization` / `.parserRecovery`. No new
> `RoundTripLoss` cases. Closes
> [`docs/superpowers/specs/2026-05-21-plantuml-treeview-design.md`](2026-05-21-plantuml-treeview-design.md).

## Implementation order

Suggested wave plan (one commit per task, mirroring Wave F / Wave G
cadence):

1. Extend `PlantUMLProbe.swift` regex to recognize `json` + `yaml` start
   kinds; add `isPlantUMLWBS` / `isPlantUMLJSON` / `isPlantUMLYAML` family
   probes; tighten `isPlantUMLMindmap` to drop the `wbs` branch.
2. Add the three new `PlantUMLRecoveryMarker.Kind` cases + parse/emit
   helpers.
3. WBS parser + AST + mapper. Tests: `PlantUMLWBSParserTests`,
   `PlantUMLWBSMapperTests`. Migrate existing WBS test cases out of
   `PlantUMLMindmapImporterTests.swift` into a new
   `PlantUMLWBSImporterTests.swift`.
4. JSON parser + mapper. Tests: `PlantUMLJSONParserTests`,
   `PlantUMLJSONMapperTests`.
5. YAML parser + mapper. Tests: `PlantUMLYAMLParserTests`,
   `PlantUMLYAMLMapperTests`.
6. Wire WBS / JSON / YAML branches into `PlantUMLImporter.parse`. Add
   `.treeView` to `supportedDiagramTypes`. Update importer top-level test
   coverage.
7. `PlantUMLTreeViewExporter` + dispatch in `PlantUMLExporter.swift`. Tests:
   `PlantUMLTreeViewExporterTests`.
8. Same-format fixtures + `RoundTripCellRegistry` entries (3 new fixtures
   under `plantuml-treeview/`).
9. Cross-format fixtures + `RoundTripCrossRegistry` entries (3 unordered /
   6 directed under `cross-treeview-plantuml/`).
10. `COVERAGE.md` updates (matrix flips, totals, fixture counts, prose
    paragraph, backlog item, last-audited line) — the wave closer.

Each step is independently testable. Steps 1–5 don't change observable
public behavior; step 6 is the user-visible flip. Step 10 is doc-only.

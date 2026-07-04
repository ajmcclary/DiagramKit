# DiagramKit Editor Redesign — Design

**Date:** 2026-07-04
**Status:** Approved (brainstorming cycle)
**Scope:** Full native-SwiftUI redesign of the `DiagramKitSample` editor to match
the "DiagramKit Editor Redesign" Claude Design comp — a **Zed Trek / LCARS Dark**
visual language, an **activity-rail + switchable side panel** shell, the
**Inspector promoted to an editing surface**, a wired **status bar**, and a
7-tab **Settings sheet (⌘,)**. Reskin + reorganization only — no engine, parser,
layout, or renderer changes.

**Visual source of truth:** the comp is transcribed verbatim (every hex, every
pixel, every label) in
[`2026-07-04-editor-redesign-comp-transcription.md`](./2026-07-04-editor-redesign-comp-transcription.md).
This design doc is the architecture and mapping; the transcription is the pixel
reference. Where they overlap, the transcription wins on exact values.

## Goal

Make `DiagramKitSample` look and navigate like the comp: a slim far-left
**activity rail** switches an adjacent panel between Organize / Browse / Search /
Source; the **canvas** carries floating tool/zoom/selection chrome; the
**Inspector** on the right edits the selected node (EDIT NODE / ARRANGE /
DIAGRAM / INSERT) instead of holding global config; a **status bar** runs along
the bottom; and all global configuration lives in a calm **Settings sheet**
opened with ⌘, or the rail's bottom tile. The whole thing is dark "LCARS Dark"
by default but is driven entirely by design tokens, so the existing appearances
still work and it adapts light↔dark.

## Decisions (from brainstorming)

| Question | Decision |
| --- | --- |
| Scope | **Everything, sequenced** — all three turns (editor shell, four rail panels, seven-tab settings sheet). |
| Integration | **Replace + token-driven.** Restructure the shell; add Zed Trek as a new `PlaygroundAppearance` and make it the default; drive **all** colors through `PlaygroundTokens` so `dark/light/forest/neutral` still work and it adapts light↔dark. The old `SidebarView` globals and inspector-global sections are **superseded**; affected tests are updated, not deleted. |
| Zed Trek themes | **Make them real.** The six named cards (LCARS Dark default, LCARS Light, Federation, Red Alert, Sick Bay, Borg Cube) become real selectable `PlaygroundAppearance` presets that re-skin the whole app. The Theme tab's "Diagram palette" row wires to the existing diagram themes. |
| macOS window chrome | The rounded window + traffic lights are the **real** OS window chrome; we match the comp's *inner* chrome and keep the native unified toolbar. iOS gets the drawn title bar. |
| Settings presentation | Reuse the app's existing **dimmed/blurred overlay** pattern (already used for Export/Convert sheets) to match the comp's scrim + `blur(3px)`. |
| Inspector sections not in the comp | Diagnostics stays in the existing bottom `DiagnosticsDrawer`; History stays reachable via the undo timeline; the Citations toggle moves into **General** settings. |

## Current State (what already exists)

From the codebase map (all paths under `Sources/DiagramKitSample/`):

- **Shell:** `Views/Workspace/PlaygroundShell.swift` — three columns
  (`SidebarView` 220pt · `bodyForMode` · `InspectorView` 350pt) + bottom
  `DiagnosticsDrawer` + modal overlays (Export/Convert/RenderFailed/Explain).
- **Token system:** `Views/DesignSystem/PlaygroundTokens.swift` —
  `PlaygroundAppearance { dark, light, forest, neutral }`, `PlaygroundPalette`
  (bg tiers, fg1/2/3, accent, borders, status, rows, glass), `PlaygroundFont`,
  `PlaygroundSpacing/Radius/Shadow`, `Color(hex:)`. Delivered via
  `@Environment(\.playgroundTokens)`; appearance persisted at
  `@AppStorage("playground.chromeAppearance")`. DS primitives under
  `Views/DesignSystem/Components/` (`Surface`, `SectionHeader`, `ChipGroup`,
  `SwatchTile`, `KeyValueRow`, `FieldInput`, `DotPicker`, `ToolbarPill`, …).
- **Inspector sections (become Settings tab bodies):**
  `InspectorRenderBackendSection` (→ Render Backend), `InspectorThemeSection` +
  `ThemePicker` + `ThemeBuilderCard` (→ Theme), `Inspector/PlatformRow`
  (→ Platform Parity), `Inspector/MutationsCatalogCard` +
  `Models/Mutations/MutationCatalog.swift` (→ Mutations Catalog). Also
  `InspectorDocumentSection`, `InspectorDiagnosticsSection`,
  `InspectorHistorySection`, `InspectorCitationsToggle`.
- **Status bar:** `Views/Workspace/StatusbarView.swift` is fully built but
  **unwired** — ready to adopt.
- **Editor / visual canvas:** `VisualPane`, `FlowchartEditCanvas`,
  `VisualToolPalette`, `CanvasZoomToolbar`, `CanvasCenterToolbar`,
  `SelectionHUD`, `UndoTimelineView`; `DiagramKitInteractive.DiagramEditor`
  (`perform`/`performFlowchart`, snapshot undo, `syncSource()`).
- **Store:** `LiveEditorStore` owns `editor: DiagramEditor?`, `state`
  (`workspaceMode`, `renderBackend`, `selectedThemeName`, grid/zoom, …),
  mutation routing (`performMutation`/`performFlowchartMutation`), corpus
  loading (`SampleDiagramPanel`, `TestDiagrams`, `CorpusIndex`).
- **Themes:** `DiagramKitModel/Theme.swift` — 18 named `DiagramTheme`s (incl. Zed Trek Dark, the sample default).
- **Platforms:** macOS 26 + iOS 26; `#if os()` splits in app entry, shell,
  toolbar, `DiagramView`.
- **Run/verify:** `swift run DiagramKitSample`; logic/state tests in
  `DiagramKitTests` (Swift Testing) — e.g. `WorkspaceModeDefaultTests`,
  `LiveEditorStateInspectorOpenTests`, `LiveEditorStateVisualZoomTests`,
  `CanvasTransformTests`. No XCUITest. Library snapshot suite is renderer-level
  (unaffected by sample-UI changes).

## Architecture

### A. Token layer (`Views/DesignSystem/`)

**A1. Expand `PlaygroundPalette`** with the roles the comp uses that the current
struct lacks. New/confirmed semantic fields (names illustrative):

- Surfaces: `bgWindow` (#05060A), `bgRail`, `bgPanel` (#0C111B), `bgSheet`
  (#0E1421), `bgSidebarNav` (#0B0F18), `bgTitlebar`/`bgStatusbar` (#0D1018),
  `bgCard` (#111827), `bgTrack` (#151A24), `bgField` (#080A0F).
- Borders: `borderWarm` (#2A2030), `borderInner` (#252B36), `borderFaint`
  (#1c2432), `borderSwatch` (#3a4250), `borderDestructive` (#3a2626).
- Text: `text1` (#F2E7D8), `text2` (#B8BFC9), `text3` (#8B93A1), `textFaint`
  (#687282), `gutter` (#6F7888), `textFaintest` (#4F5868).
- Accents: `accent` (#FF9933), `accentTint16`/`accentTint14`/`accentTint08`,
  `accentBorder40`, `onAccent` (#1a1205), `accentSecondary` (#FFCC66),
  `accentPeach` (#FFD8B0).
- Status: `statusGreen` (#30D158), `statusAmber` (#FF9F0A), `statusRed`
  (#EF5A5A), traffic `#FF5D57/#FEBC2E/#28C840`.
- Category: `catCyan` (#7EC8DE), `catMint` (#4EE6A6), `catPurple` (#CC99FF).

Existing `dark/light/forest/neutral` presets get the new fields filled from
their current values (no visual change to them).

**A2. Six new `PlaygroundAppearance` cases** with real presets:

- `zedTrekDark` — **new default**. Exact comp values (the transcription's §1.1
  tables are the source): window #05060A, panel #0C111B, sheet #0E1421, card
  #111827, accent #FF9933, secondary #FFCC66, text #F2E7D8, category #7EC8DE.
- `zedTrekLight` — LCARS Light: base #FBF7F1, accents #E07A1E/#B8945A/#C77D28,
  inverted text tiers.
- `federation` — base #0A1020; accent gold #FFCC66; secondary blue #3B6FE0;
  category cyan #7EC8DE.
- `redAlert` — base #160404; accent red #FF453A; secondary amber #FF9F0A;
  tertiary gold #FFCC66.
- `sickBay` — base #04120F; accent mint #4EE6A6; category cyan #7EC8DE; green
  #30D158.
- `borgCube` — base #04120A; accent green #39FF57; secondary mint #4EE6A6;
  lime #A8FF60.

`zedTrekDark` and `zedTrekLight` are fully specified by the comp. The other four
supply the 4-colour specimen (base + accent + secondary + tertiary); the
implementer derives their full surface/text ladders by applying the **same
relative-luminance offsets** `zedTrekDark` uses from its base `#05060A`, so
every appearance has a complete, consistent token set. The default flips from
`.dark` to `.zedTrekDark` in the `@AppStorage` seed + `PlaygroundAppearance`
default.

**A3. New DS components** under `Views/DesignSystem/Components/` (each
token-driven, previewable, under the 500-line warning gate). Specs are in the
transcription §1.4 / §7:

`ToggleRow`, `StepperRow`, `MenuRow`, `StatusRow`, `SettingsGroupCard`,
`SidebarNavItem`, `SegmentedFormatControl`, `ThemeSwatchCard`, `ParityTable`,
`InfoCallout`, `DestructiveButton`, `ActivityRailItem`, `ColorDotPicker`,
`SelectionBreadcrumb`, `ValuePill`, `SliderRow`, `AlignButtonRow`. Reuse
existing `Surface/SectionHeader/ChipGroup/SwatchTile/KeyValueRow` where they fit
(e.g. Render Backend readouts).

### B. State model additions

Add to `LiveEditorState` (or the store, matching existing conventions):

- `activeRailTab: ActivityRailTab` (`organize | browse | search | source`),
  default `.organize`.
- `isSettingsPresented: Bool`, `settingsTab: SettingsTab`
  (`general | editor | renderBackend | theme | platformParity |
  mutationsCatalog | fonts`).
- `@AppStorage` keys for genuinely-new settings: `confirmBeforeDelete`,
  `sendAnonymousDiagnostics`, `restoreLastDocument`, `gridSize`,
  `keyboardNudge`, `defaultNodeShape`, `defaultEdgeStyle`, `uiTextSize`,
  plus the moved `showSourceCitations`. Where a setting already has state
  (grid visibility/snap, render backend, appearance, theme name), bind to the
  existing source — do not duplicate.
- `searchQuery`/`searchFilter` for the Search panel (transient, not persisted).

⌘, (a new `.commands` entry) and the rail's bottom tile both set
`isSettingsPresented = true`.

### C. Shell restructure (`PlaygroundShell`)

Replace the left `SidebarView` (220pt) with **`ActivityRail` (52pt)** +
**`ActivityPanel` (236pt)**; keep `bodyForMode`; the right column becomes the
new editing **`InspectorView`** (312pt). Wire `StatusbarView` along the bottom
(above/below the existing `DiagnosticsDrawer`, restyled). `fullScreenBody`
surfaces (Coverage/Corpus/CrossFormat/Probe/Snippets) remain reachable from the
Browse panel. The modal-overlay mechanism gains the `SettingsSheet`.

## Turn-by-turn implementation

### Turn 3 — Settings sheet (built first; self-contained)

`SettingsSheet` — 748×520, `bgSheet`, radius 20, header (52pt: red traffic dot +
"Settings" + search field) + 196pt `SidebarNavItem` list (7 tabs) + scrolling
content pane. Presented over the dimmed/blurred editor via the existing overlay
pattern. Tabs and wiring:

1. **General** — `MenuRow` Default format (Auto-detect) + On startup (Restore
   last document); `ToggleRow` Confirm before delete, Send anonymous
   diagnostics; the moved **Show source citations** toggle; `DestructiveButton`
   Reset All Settings (clears the new `@AppStorage` keys + confirms).
2. **Editor** — `ToggleRow` Snap to grid (→ existing grid/snap state), Show
   connection handles; `StepperRow` Grid size (26 px), Keyboard nudge (8 px);
   `MenuRow` Default node shape (Rectangle), Default edge style (Solid arrow).
3. **Render Backend** — re-host `InspectorRenderBackendSection` logic as
   `SegmentedFormatControl` (SVG/Image/ASCII → `state.renderBackend`) +
   `SettingsGroupCard` rows (Renderer `renderSVG(_:)`, ID policy Stable, auto
   toggle, `StatusRow` Worker thread "on").
4. **Theme** — `ThemeGrid` of 6 `ThemeSwatchCard`s bound to
   `@AppStorage("playground.chromeAppearance")` (the real Zed Trek presets;
   active card shows the check + 1.5px accent border) + `MenuRow` Appearance
   (Match system) + Diagram palette (→ the named `DiagramTheme`s, current
   `selectedThemeName`) + Edit theme… → existing `ThemeBuilder`.
5. **Platform Parity** — `ParityTable` (FEATURE / macOS / iOS / Linux) populated
   from real capability data (`DiagramDescriptor.linuxSupport`, renderer
   availability) with check/partial-dot/dash cells + legend; reuses
   `PlatformRow`'s data.
6. **Mutations Catalog** — grouped Node/Edge/Subgraph rows from
   `MutationCatalog`, header search "Filter mutations…", trailing mono API
   signatures.
7. **Fonts** — `MenuRow` UI font / Mono font (web-fallback note in amber) /
   Diagram font + Diagram mono with **Bundled** badges (from
   `DiagramFontRegistry.registeredFontNames`); `StepperRow` UI text size (13 pt);
   `InfoCallout` about bundled Noto neutralizing font drift.

### Turn 1 — Editor shell

- **`ActivityRail`** (52pt, `bgRail`): 5 `ActivityRailItem`s —
  Organize/Browse/Search/Source (switch `activeRailTab`, active = tint + accent
  + left marker bar) + bottom sliders tile (opens Settings).
- **`ActivityPanel`** (236pt, `bgPanel`): renders the Turn-2 panel for
  `activeRailTab`.
- **`InspectorView` (editing surface, 312pt):** header (icon badge + node title
  + mono id) + sections **EDIT NODE** (label `FieldInput`, Shape `ValuePill`,
  Border `SegmentedFormatControl`, Background/Border color `SwatchTile`,
  `ColorDotPicker`), **ARRANGE** (`AlignButtonRow`), **DIAGRAM** (Direction
  segmented, Node spacing `SliderRow`), **INSERT** (2×2 grid: Subgraph/Icon/
  Image/Rearrange). Empty-selection state shows the DIAGRAM/INSERT sections only.
  - **Backing-mutation boundary (respects "no engine changes"):** controls bind
    to *existing* `DiagramEditor` mutations only — EDIT NODE → `setLabel`,
    `setNodeShape`, `setNodeStyle`; INSERT → `insertSubgraph`, `setNodeIcon`,
    `setNodeImage`, relayout; DIAGRAM Node spacing → `relayout(config:)` spacing.
    **ARRANGE align buttons have no backing mutation** in an ELK auto-layout
    graph (nodes aren't free-positioned), so they render **presentational /
    disabled** this cycle (styled per comp, not wired). **DIAGRAM Direction**
    (TB/LR/BT/RL) is wired **only if** it reduces to an existing source/layout
    operation; otherwise it too is presentational this cycle. No new mutations,
    parser changes, or a free-positioning system are introduced here — those are
    a separate follow-up.
- **`StatusbarView`** wired + restyled to the comp's 4 segments (family·format
  dot / counts / backend·worker / cursor pos).
- **Canvas chrome** restyle to tokens + comp geometry: `VisualToolPalette`
  (select/pan/marquee/connector), `CanvasZoomToolbar` (Fit/−/100%/+/1:1),
  `SelectionBreadcrumb` (`flowchart:node:A`), selected-node 1.5px accent border +
  corner handles.
- **Title bar:** restyle `WorkspaceModePicker` (Code/Editor/Split) + right icon
  cluster to tokens. macOS keeps the native unified toolbar; iOS uses the drawn
  `TitlebarView`.

### Turn 2 — Rail panels (inside `ActivityPanel`)

- **`OrganizePanel`** — header "ORGANIZE" + filter field + tree of
  subgraphs/nodes/edges derived from `editor.document`; selected row syncs
  `editor.selection`; caret expand/collapse.
- **`BrowsePanel`** — the old `SidebarView` content: nav links (Coverage/Corpus/
  Cross-format/Probe/Snippets → `fullScreenBody`) + search + collapsible sample
  groups (re-skinned `SampleDiagramPanel`, loads via `store.setSource`).
- **`SearchPanel`** — focused search field + filter chips (All/Nodes/Edges/
  Labels) + grouped result cards with highlight marks + mono locus; searches the
  current document's nodes/edges/labels.
- **`SourcePanel`** — syntax-highlighted Mermaid (reuse the existing highlighter)
  with the active line tracking `editor.selection`; synced status footer.

## Supersessions & test updates

- `SidebarView` global brand/browse → folded into `BrowsePanel`; the view is
  removed or reduced to the panel.
- `InspectorView` global sections (RenderBackend/Theme/PlatformRow/Mutations/
  Document/Diagnostics/History/Citations) → RenderBackend/Theme/Platform/
  Mutations move to Settings; Diagnostics stays in the bottom drawer; History via
  the undo timeline; Citations → General; Document info folds into the new
  inspector header. The old `InspectorView` becomes the editing surface.
- Tests referencing the old structure — e.g. `LiveEditorStateInspectorOpenTests`
  (inspector open/close semantics), any that assert `SidebarView`/inspector
  section presence — are updated to the new IA (rail tab + settings state).
  `WorkspaceModeDefaultTests`, `CanvasTransformTests`, zoom tests are unaffected.
- New logic tests: `ActivityRailTab` default + switching; settings presentation
  state + ⌘,; `SettingsTab` selection; Search derivation (query → node/edge/
  label matches); Organize tree derivation from a document; Parity table data;
  new-appearance default is `zedTrekDark`; each new `PlaygroundAppearance`
  resolves a complete palette.

## Verification

1. `swift build` and `swift build --build-tests` clean.
2. New + updated logic tests: `swift test --filter <exact-suite>` (per the
   repo's chunked-filter discipline — never a bare full run).
3. **Run the app** (`swift run DiagramKitSample`) and screenshot each screen —
   editor shell, all four rail panels, all seven settings tabs, each of the six
   Zed Trek appearances — and compare against the comp / transcription.
4. Discipline gates that apply: `check-file-sizes.sh`,
   `check-sendable-annotations.sh` (no new `@unchecked Sendable` expected),
   strict-concurrency build. Library snapshot suite untouched (renderer-level).

## Sequencing (review checkpoint after each stage)

1. **Foundation** — `PlaygroundPalette` expansion, six Zed Trek appearances
   (default → `zedTrekDark`), DS components. Parallelizable (independent
   components).
2. **Settings sheet** — `SettingsSheet` + all seven tabs + ⌘, + overlay
   presentation. The seven tab bodies are independent → parallel fan-out; the
   sheet chrome + presentation is the join.
3. **Editor shell** — `ActivityRail` + `ActivityPanel` container, `PlaygroundShell`
   restructure, inspector-as-editor, status bar, canvas + title-bar restyle.
   Sequential (shared files: `PlaygroundShell`, `InspectorView`).
4. **Rail panels + cleanup** — Organize/Browse/Search/Source (independent →
   parallel), then supersession test updates, build/gate fixes, and the
   run/screenshot verification pass.

Given ultracode, stages 1/2/4 use Workflow fan-out for the independent units;
stage 3's shared-file restructuring stays sequential in the main line.

## Risks / open items

- **Appearance derivation for the four non-LCARS themes:** the comp only gives a
  4-colour specimen each. The relative-luminance-offset derivation keeps them
  consistent; they will be plausible but not comp-pixel-exact beyond their four
  named colours (the comp never shows their full UI). Acceptable per "make them
  real."
- **macOS vs iOS title bar:** native window chrome differs from the drawn comp;
  we match inner chrome only on macOS. No fake traffic lights on macOS.
- **File-size gate:** `PlaygroundTokens.swift` grows with six presets — may need
  splitting the presets into a `PlaygroundAppearance+ZedTrek.swift` extension to
  stay under 500 lines.
- **`SampleDiagramPanel` reuse:** re-skinning in place vs. wrapping — decide
  during stage 4 to avoid churn to corpus-loading logic.

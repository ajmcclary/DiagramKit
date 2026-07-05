# Zed Trek Theme Family — Design Spec

**Date:** 2026-07-05
**Status:** Approved (design), pending implementation plan
**Scope:** `DiagramKitSample` app-chrome theming + matching diagram-canvas themes

## 1. Overview

Port the design project **"CodeEditorPlugin Design System"** (claude.ai design
`50c9c2ef-8ed4-445e-870e-0273e3d082fc`) "Zed Trek" theme family into the sample
app. The family is **10 named themes**, each available in **light and dark**:

1. **LCARS** ★ (default) 2. Black Alert 3. Borg Cube 4. Command
5. Federation 6. Red Alert 7. Yellow Alert 8. Sick Bay 9. Mission Control
10. Ready Room

Authoritative source: `themes/zed-trek.json` in the design project — a Zed
theme file with **20 entries** (10 families × light/dark), each carrying the
full Zed semantic token set (`background`, `surface.background`,
`elevated_surface.background`, `panel.background`, `editor.*`, `title_bar.*`,
`border*`, `text*`, `icon*`, `success/warning/error/info`, `syntax`, …). The
per-theme *specimen* colors (card bg, name color, 5 accent swatches) are pinned
verbatim in §6 from the design's `preview/colors-theme-family-{dark,light}.html`.

### Goals
- The app ships **exactly these 10 themes**, each in light + dark.
- A **theme × mode** model (family + Light/Dark/System) that activates the
  currently-dead "Match system / Always dark / Always light" menu.
- The **diagram canvas** recolors to match the selected theme.
- Theme picker cards visually match the design images (name in signature color,
  5 accent swatches, `let n = 42` sample).

### Non-goals
- Porting Zed `syntax`/`terminal`/`players` tokens (the app has no code editor
  surface that consumes them).
- Any change to the diagram *rendering* pipeline beyond adding canvas themes.
- New snapshot baselines for the chrome (there are none today; none added).

## 2. Current state (what we replace)

- `PlaygroundAppearance` (`PlaygroundTokens.swift:18`) — flat enum, 10 cases:
  4 legacy (`dark/light/forest/neutral`) + 6 Zed (`zedTrekDark/Light,
  federation, redAlert, sickBay, borgCube`). Light/dark is a **fixed per-case**
  `preferredColorScheme` switch.
- `PlaygroundPalette` (struct, `PlaygroundTokens.swift:62`) — the chrome token
  bag. **Kept as-is structurally** (all fields reused).
- `DiagramTheme` (`Sources/DiagramKitModel/Theme.swift`) — canvas themes; 18
  presets incl. `zedTrekDark`. Selected in the sample by *name string*
  (`LiveEditorState.selectedThemeName`, default `"Zed Trek Dark"`).
- Env: `.playgroundAppearance(_:)` installs tokens + forces
  `preferredColorScheme` (`Environment+PlaygroundTokens.swift:25`).
- Persistence: single key `playground.chromeAppearance` (rawValue), **not** in
  `PlaygroundSettingsKeys.all` (Reset doesn't clear it).

## 3. Data model (new)

New file `Sources/DiagramKitSample/Views/DesignSystem/ZedTrekTheme.swift`:

```swift
enum ZedTrekTheme: String, CaseIterable, Hashable, Codable, Sendable {
    case lcars, blackAlert, borgCube, command, federation
    case redAlert, yellowAlert, sickBay, missionControl, readyRoom

    var displayName: String { … }   // "LCARS", "Black Alert", "Borg Cube", …
    var isStarred: Bool { self == .lcars }
}

enum ThemeMode: String, CaseIterable, Hashable, Codable, Sendable {
    case system, light, dark
    var displayName: String { … }    // "System" / "Light" / "Dark"
    func scheme(system: ColorScheme) -> ColorScheme  // .system → system arg
}
```

`CaseIterable` order = the grid order in the images (LCARS first).

## 4. Resolution & environment

`PlaygroundTokens` gains a `(family:scheme:)` initializer that assembles the
chrome palette. Default env value becomes **LCARS dark**.

New host view replaces `.playgroundAppearance(_:)`:

```swift
struct PlaygroundThemeHost<Content: View>: View {
    let family: ZedTrekTheme
    let mode: ThemeMode
    let onEffectiveScheme: (ColorScheme) -> Void   // canvas-follow hook
    @Environment(\.colorScheme) private var systemScheme
    @ViewBuilder var content: Content
    var body: some View {
        let effective = mode.scheme(system: systemScheme)
        content
            .environment(\.playgroundTokens, PlaygroundTokens(family: family, scheme: effective))
            .preferredColorScheme(mode == .system ? nil : effective)
            .onChange(of: effective, initial: true) { _, s in onEffectiveScheme(s) }
    }
}
```

- `mode == .system` → don't force scheme (`nil`); descendants + palette follow
  the OS scheme via `systemScheme`.
- `mode == .light/.dark` → force it; `effective` is independent of `systemScheme`.
- `onEffectiveScheme` drives the canvas-follow sync (§8).

`SwatchTile.textColor(on:)` currently reads `tokens.appearance.preferredColorScheme`
(removed). Replace with a **luminance test on the tile's own background** so it
stays correct without an appearance enum.

## 5. Chrome palette mapping (`zed-trek.json style.*` → `PlaygroundPalette`)

Applied to all 20. When a Zed key is absent (Zed themes may omit tokens — e.g.
Command Dark has no `surface.background`), use the listed fallback.

| PlaygroundPalette field(s) | Zed token | Fallback |
| --- | --- | --- |
| `bgApp`, `bgWindow`, `bgRail` | `background` | — |
| `bgField`, `bgSunken` | `editor.background` | `background` |
| `bgPanel`, `bgSurface`, `bgSidebarNav` | `panel.background` | `surface.background` → `background` |
| `bgSheet` | `elevated_surface.background` | `surface.background` → `panel.background` |
| `bgChrome` | `title_bar.background` | `panel.background` |
| `bgCard`, `bgElevated` | `elevated_surface.background` | `surface.background` |
| `bgTrack` | `element.background` | `elevated_surface.background` |
| `fg1` | `text` | `editor.foreground` |
| `fg2` | `text.muted` | blend fg1→bg 60% |
| `fg3` | `text.placeholder` | `text.muted` |
| `textFaint`, `textFaintest` | `text.disabled` | `text.placeholder` |
| `gutter` | `editor.line_number` | `text.disabled` |
| `accent` | `border.focused` | `accents[0]` |
| `accentSecondary` | specimen `accents[1]` (§6) | `accent` |
| `accentPeach` | `#FFD8B0` if in specimen `accents`, else `accentSecondary` | `accentSecondary` |
| `catCyan` | `info` | `#7EC8DE` |
| `catMint` | `success` | `#4EE6A6` |
| `catPurple` | `renamed` | `accent` |
| `onAccent` | relative-luminance(`accent`) < 0.55 ? `#FFFFFF` : `#100A02` | — |
| `statusSuccess` | `success` | keep struct default |
| `statusWarning` | `warning` | keep struct default |
| `statusError` | `error` | keep struct default |
| `statusInfo` | `info` | `catCyan` |
| `borderHairline`, `borderFaint` | `border.variant` | `border` |
| `borderSubtle`, `borderWarm` | `border` | `border.variant` |
| `borderStrong`, `borderSwatch` | `pane_group.border` | `border` |
| `borderDestructive` | `error.border` | `error` @ 0.45 |
| `rowHover` | `accent` @ 0.08 | — |
| `rowSelected` | `accent` @ 0.16 | — |
| `glassBg` | `bgChrome` @ 0.90 | — |
| `trafficRed/Yellow/Green` | keep struct defaults (`#FF5D57/#FEBC2E/#28C840`) | — |

`accent ← border.focused` gives the theme's signature color (Black Alert cyan
`#7ec8de`, Borg Cube green `#5EFC8D`, Command orange `#FF9933`, …), matching the
name color in the design cards.

Implementation form: author each of the 20 as an explicit
`PlaygroundPalette(...)` literal via a `fromZedTrek(...)` helper that takes the
mapped hex set — one file
`PlaygroundPalette+ZedTrekFamily.swift`. Values are **read from the JSON**, not
guessed; each is verified against the JSON during implementation (see §11).

## 6. Picker specimens (pinned verbatim from design preview HTML)

`ZedTrekSpecimen { cardBackground, textColor, nameColor, accents:[Color] }`
drives the picker cards so they match the images exactly. New file
`ZedTrekSpecimen.swift`.

### Dark
| Family | card bg | text | name | accents (5) |
| --- | --- | --- | --- | --- |
| LCARS ★ | `#080A0F` | `#F2E7D8` | `#FFCC66` | `#FF9933 #FFD8B0 #FFCC66 #7EC8DE #CC99FF` |
| Black Alert | `#010204` | `#DFE7F1` | `#7EC8DE` | `#7EC8DE #C7E9F1 #B5A7FF #4EE6A6 #FF9933` |
| Borg Cube | `#020402` | `#D8F5DC` | `#5EFC8D` | `#5EFC8D #27C267 #9EFFA8 #7EC8DE #FF9933` |
| Command | `#09090B` | `#D3D8DE` | `#FFD8B0` | `#FF9933 #FFD8B0 #7EC8DE #257EA7 #EF5A5A` |
| Federation | `#050911` | `#DBE8F2` | `#C7E9F1` | `#7EC8DE #C7E9F1 #FFD8B0 #FF9933 #FF7373` |
| Red Alert | `#0C0506` | `#F6D7CF` | `#FF8A8A` | `#EF5A5A #FF9933 #FFD8B0 #7EC8DE #C7E9F1` |
| Yellow Alert | `#080602` | `#F3E8CF` | `#FFD166` | `#FFD166 #FF9933 #7EC8DE #C7E9F1 #FF7373` |
| Sick Bay | `#050B0F` | `#D9F2F6` | `#3CCF91` | `#7EC8DE #C7E9F1 #3CCF91 #FFD8B0 #FF7373` |
| Mission Control | `#03070D` | `#DCEBF6` | `#7EC8DE` | `#7EC8DE #C7E9F1 #FF9933 #FFD8B0 #4EE6A6` |
| Ready Room | `#0B0F16` | `#EADFD3` | `#FFD8B0` | `#FFD8B0 #7EC8DE #257EA7 #B87952 #EF5A5A` |

### Light
| Family | card bg | text | name | accents (5) |
| --- | --- | --- | --- | --- |
| LCARS ★ | `#FFFCF4` | `#2A1F0A` | `#8B5D1A` | `#C16E1D #FF9933 #FFCC66 #1F8EA5 #8B5DBE` |
| Black Alert | `#FCFDFF` | `#1E2530` | `#09090B` | `#09090B #257EA7 #7EC8DE #B5A7FF #4EE6A6` |
| Borg Cube | `#FBFFF9` | `#1D2A22` | `#1F6B3C` | `#2FA85B #5EFC8D #1F6B3C #7EC8DE #4A5766` |
| Command | `#FFFFFF` | `#4A5766` | `#257EA7` | `#257EA7 #7EC8DE #FFD8B0 #FF9933 #EF5A5A` |
| Federation | `#FBFCFE` | `#1E2936` | `#1E3A5F` | `#1E3A5F #257EA7 #7EC8DE #FF9933 #FFD8B0` |
| Red Alert | `#FFFAF8` | `#4A1F24` | `#A4333F` | `#EF5A5A #FF9933 #FFD8B0 #257EA7 #1E3A5F` |
| Yellow Alert | `#FFFDF7` | `#2E2A21` | `#8A5300` | `#FFD166 #FF9933 #1E3A5F #257EA7 #EF5A5A` |
| Sick Bay | `#FBFEFF` | `#263943` | `#1E3A5F` | `#7EC8DE #257EA7 #3CCF91 #FFD8B0 #EF5A5A` |
| Mission Control | `#FBFDFF` | `#223142` | `#1E3A5F` | `#1E3A5F #257EA7 #7EC8DE #FF9933 #4EE6A6` |
| Ready Room | `#FFFAF3` | `#2F343B` | `#1E3A5F` | `#1E3A5F #257EA7 #7EC8DE #FFD8B0 #9B5F42` |

## 7. Canvas mapping (`zed-trek.json` → `DiagramTheme`)

20 new canvas themes (`Theme.swift`, gated Apple-only like the file). Per
family/mode:

| DiagramTheme param | Zed token | Fallback |
| --- | --- | --- |
| `background` | `editor.background` | `background` |
| `foreground` | `editor.foreground` | `text` |
| `accent` | `border.focused` | `accents[0]` |
| `muted` | `text.muted` | — |
| `line` | `editor.indent_guide` | `border` |
| `surface` | `elevated_surface.background` | `surface.background` |
| `border` | `border` | `border.variant` |
| `noteBkg` | `surface.background` | `panel.background` |
| `noteBorder` | `border.variant` | `border` |

`lineWidth = 1`, `cornerRadius = 8` (same as the existing `zedTrekDark` preset).

Names: `"LCARS Dark"`, `"LCARS Light"`, `"Black Alert Dark"`, … added to
`DiagramTheme.allThemes`. The existing `zedTrekDark` value is reused for
`"LCARS Dark"` (unchanged colors) so `DefaultDiagramThemeTests` still holds; the
old `"Zed Trek Dark"` list entry is renamed to `"LCARS Dark"`.
`LiveEditorState.defaultThemeName` → `"LCARS Dark"` (resolves to
`DiagramTheme.zedTrekDark`, i.e. `resolved == .zedTrekDark`, `!= .default`).

## 8. Canvas-follows-chrome

New `@AppStorage("playground.canvasFollowsAppTheme")` default `true`. When true,
the `PlaygroundThemeHost.onEffectiveScheme` callback (and family changes) set
`store.state.selectedThemeName` to the canvas theme name for
`(family, effectiveScheme)`. This reacts to OS scheme changes in `.system` mode.
When false, the existing diagram-palette `ThemePicker` controls the canvas as
today. Frontmatter-pinned theme still wins for `previewTheme` (unchanged logic).

Store gets a small helper `func syncCanvasToApp(family:scheme:)` guarded by the
toggle; no change to the `theme` / `previewTheme` derivation itself.

## 9. Persistence & migration

New keys in `PlaygroundChromePersistence`:
- `themeKey = "playground.zedTrekTheme"` — default `lcars`
- `modeKey = "playground.themeMode"` — default `dark`
- `canvasFollowsKey = "playground.canvasFollowsAppTheme"` — default `true`

`migrateLegacyIfNeeded()` (called once at app launch): if `themeKey` unset and
legacy `appearanceKey` set, write mapped values then leave legacy key.

| legacy `chromeAppearance` | → theme | → mode |
| --- | --- | --- |
| `zedTrekDark` | lcars | dark |
| `zedTrekLight` | lcars | light |
| `federation` | federation | dark |
| `redAlert` | redAlert | dark |
| `sickBay` | sickBay | dark |
| `borgCube` | borgCube | dark |
| `dark` / `forest` | lcars | dark |
| `light` / `neutral` | lcars | light |
| (unknown) | lcars | dark |

`themeKey`, `modeKey`, `canvasFollowsKey`, and `appearanceKey` all added to
`PlaygroundSettingsKeys.all` so Reset clears them.

## 10. UI

**Settings ▸ Theme** (`SettingsThemeTab.swift`):
- 10 specimen cards in a `LazyVGrid` over `ZedTrekTheme.allCases`, each rendered
  by a reworked `ThemeSwatchCard`: card bg = specimen bg, title in specimen name
  color, a row of 5 accent swatches, and a `let n = 42` mono line — matching the
  design images. Star on LCARS. Card uses the specimen for the **current mode**.
- A **Light / Dark / System** segmented control bound to `modeKey`.
- The "Appearance" `MenuRow` becomes functional (writes `modeKey`).
- Diagram-palette row + theme-builder retained; add "Match app theme" toggle
  bound to `canvasFollowsKey`.

**Inspector ▸ Theme** (`InspectorThemeSection.swift`):
- Family tiles (`SwatchTile`, specimen-driven) over `ZedTrekTheme.allCases` +
  a compact mode control. Diagram-palette / theme-builder disclosures retained;
  "Match app theme" toggle added.

`LiveEditorView` reads `themeKey` + `modeKey`, wraps content in
`PlaygroundThemeHost`, and paints the macOS window toolbar from the resolved
palette's `bgApp`.

## 11. Testing

- **Rewrite** `EditorRedesignTokenTests`:
  - `ZedTrekTheme.allCases.count == 10`; every `(family, scheme)` palette is
    complete (`accent != bgWindow`, `onAccent != accent`, all surfaces distinct
    from accent).
  - Default: `PlaygroundTokensKey.defaultValue` is LCARS dark with exact hexes
    (`accent #FF9933`, `bgWindow #05060A`, `bgSheet #0E1421`, `fg1 #F2E7D8`).
  - `ThemeMode` resolution: `.system` → system arg; `.light/.dark` forced.
  - Migration table (all rows in §9).
- **New** `ZedTrekSpecimenTests`: 20 specimens exist, each 5 accents, name/bg
  distinct; specimen[0] relates to palette accent per family.
- **New** `ZedTrekCanvasTests`: a `DiagramTheme` exists for each `(family,
  scheme)` in `allThemes`; `"LCARS Dark" == .zedTrekDark`.
- **Update** `DefaultDiagramThemeTests`: `defaultThemeName == "LCARS Dark"`,
  still resolves to `.zedTrekDark`.
- `PalettePinTests` auto-covers the 20 new canvas themes (must stay green: each
  produces distinct valid hexes, no `NaN`/empty fill).
- Each palette/canvas value **verified against `zed-trek.json`** (adversarial
  check in the implementation workflow) — no transcription drift.

## 12. Files

**New**
- `Sources/DiagramKitSample/Views/DesignSystem/ZedTrekTheme.swift`
- `Sources/DiagramKitSample/Views/DesignSystem/ZedTrekSpecimen.swift`
- `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundPalette+ZedTrekFamily.swift`
- `Tests/DiagramKitTests/EditorRedesign/ZedTrekSpecimenTests.swift`
- `Tests/DiagramKitTests/EditorRedesign/ZedTrekCanvasTests.swift`

**Modified**
- `PlaygroundTokens.swift` (remove `PlaygroundAppearance` + 4 legacy palettes;
  add `PlaygroundTokens(family:scheme:)`)
- `Environment+PlaygroundTokens.swift` (host view; LCARS-dark default)
- `LiveEditorView.swift`, `SettingsThemeTab.swift`, `InspectorThemeSection.swift`
- `ThemeSwatchCard.swift` (specimen card), `SwatchTile.swift` (luminance text)
- `PlaygroundSettingsKeys.swift`, `LiveEditorState.swift`
- `Sources/DiagramKitModel/Theme.swift` (20 canvas themes; rename default entry)
- App entry (migration call)
- `EditorRedesignTokenTests.swift`, `DefaultDiagramThemeTests.swift`

**Removed**
- `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundPalette+ZedTrek.swift`

## 13. Risks / notes

- **`preferredColorScheme(nil)` + `@Environment(\.colorScheme)`**: verify on
  macOS that `.system` mode truly follows OS appearance and re-resolves live.
- **Zed key omissions**: several themes omit `surface.background` /
  `text.placeholder` — the §5/§7 fallbacks must be exercised; the verification
  pass confirms no field lands on an unintended default.
- **`allThemes` growth**: `PalettePinTests` renders every entry — 20 extra
  renders, still < a few seconds; keep names unique.
- **File size**: `PlaygroundPalette+ZedTrekFamily.swift` (20 palettes) may
  approach the 500-line soft warning; split light/dark if needed to stay under.
- **No chrome snapshots exist**; visual fidelity verified by running the app
  (`swift run DiagramKitSample`) and comparing to the design images.

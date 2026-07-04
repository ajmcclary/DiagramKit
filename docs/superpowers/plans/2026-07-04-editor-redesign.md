# DiagramKit Editor Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the `DiagramKitSample` editor to match the "DiagramKit Editor Redesign" comp — a token-driven Zed Trek / LCARS Dark look, an activity-rail + switchable-panel shell, an inspector-as-editing-surface, a wired status bar, and a 7-tab Settings sheet (⌘,).

**Architecture:** Replace + token-driven. All chrome reads an expanded `PlaygroundTokens` layer; six new `PlaygroundAppearance` presets (LCARS Dark default) are real and selectable; the redesigned surfaces supersede `SidebarView` globals and inspector-global sections. No engine/parser/layout/renderer changes — controls without a backing `DiagramEditor` mutation render presentational this cycle.

**Tech Stack:** SwiftUI (macOS 26 / iOS 26), Swift 6 strict concurrency, Swift Testing (`@Test`/`#expect`), `@Observable` `LiveEditorStore`, `@Environment(\.playgroundTokens)`.

> **Implementation status (2026-07-04):** this plan document was written through
> Stage 2; the actual implementation ran ahead of it and shipped Stages 1–3 in full
> (tokens + 6 Zed Trek appearances, Settings sheet + 7 tabs, activity-rail shell,
> inspector-as-editor, canvas + title-bar restyle). See commits `9a436334..ee8cf162`
> and the memory note `project-editor-redesign`. Stages 3–4 were never transcribed
> here as prose — the committed source is the source of truth.

**Companion references (read alongside every task):**
- Spec: `docs/superpowers/specs/2026-07-04-editor-redesign-design.md`
- **Pixel source of truth:** `docs/superpowers/specs/2026-07-04-editor-redesign-comp-transcription.md` (every hex + pixel, cited per section as e.g. "transcription §3.1"). When a task says "exact values: transcription §X", copy them from there.

## Global Constraints

- **Platform:** sample UI is Apple-only (macOS 26 + iOS 26). Gate any AppKit/UIKit exactly as the neighboring files do (`#if os(macOS)` / `#if canImport(UIKit)`). Everything here is view/state code — no Linux concern.
- **Colors only via tokens.** Views must read `tokens.palette.*` / `PlaygroundFont` / `PlaygroundSpacing` / `PlaygroundRadius`. Raw `Color(hex:)` is allowed ONLY inside `PlaygroundPalette` preset definitions (Tasks 1–2). Pixel dimensions (widths/heights/paddings/radii) are literal numbers from the transcription.
- **DS component conventions:** `@Environment(\.playgroundTokens) private var tokens`; first init arg unlabeled (`_ style` / `_ title`); content via `@ViewBuilder`; keep each new file focused.
- **File-size gate** (`Scripts/check-file-sizes.sh`): 500-line warning / 1000-line error. Split presets into extension files (below). Keep each component/screen in its own file.
- **Strict concurrency (Swift 6):** view structs are `@MainActor`; any new state type mirrors `LiveEditorState`’s conformances (`Codable, Equatable, Sendable`). No new `@unchecked Sendable`. No thread pools (irrelevant here but do not add any).
- **State lives in `LiveEditorState`** (like `inspectorOpen`), mutated through store methods (like `toggleInspector()`), so it is testable and UI-test-seedable. Transient view-only state (search text, disclosure flags) may be `@State`/`@AppStorage` in the view, following `InspectorThemeSection`’s pattern.
- **Settings persistence:** genuinely-new settings use `@AppStorage` with keys centralized in `PlaygroundSettingsKeys` (Task 6). Existing settings bind to their existing source (`gridEnabled`, `renderBackend`, `updateMode`, `selectedThemeName`, chrome appearance).
- **Testing discipline** (repo memory): Swift Testing suites under `Tests/DiagramKitTests/`. Run with **exact suite filters**, never a bare `swift test` and never a substring that matches corpus cases (e.g. `swift test --filter EditorRedesignTokenTests`, not `--filter Token`). SwiftUI view *rendering* is not unit-tested — verify views via `swift build` and the run/screenshot pass (Task 29); unit tests cover the extractable logic (palette completeness, state transitions, search/tree/parity derivation).
- **Git:** work on `main`, commit after each task (repo default; messages end with the `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` trailer).
- **Default appearance flip (dark → zedTrekDark) touches exactly 4 sites** — track them so none is missed: `PlaygroundTokensKey.defaultValue` (`Environment+PlaygroundTokens.swift:12`), `PlaygroundTokens` default usage, `LiveEditorView.chromeAppearanceRaw` default (`LiveEditorView.swift:21`), `InspectorThemeSection.chromeAppearanceRaw` default. Done in Task 2.

---

## File Structure

**Created**
```
Sources/DiagramKitSample/
  Views/DesignSystem/
    PlaygroundPalette+ZedTrek.swift        # 6 new presets (Task 2)
    Components/
      ToggleRow.swift  StepperRow.swift  MenuRow.swift  StatusRow.swift        # Task 3
      SettingsGroupCard.swift  SidebarNavItem.swift  SegmentedFormatControl.swift
      DestructiveButton.swift  InfoCallout.swift                               # Task 4
      ThemeSwatchCard.swift  ParityTable.swift  ColorDotPicker.swift
      ActivityRailItem.swift  SelectionBreadcrumb.swift  ValuePill.swift
      SliderRow.swift  AlignButtonRow.swift                                    # Task 5
  Views/Settings/
    SettingsSheet.swift                    # chrome + routing (Task 7)
    SettingsGeneralTab.swift               # Task 8
    SettingsEditorTab.swift                # Task 9
    SettingsRenderBackendTab.swift         # Task 10
    SettingsThemeTab.swift                 # Task 11
    SettingsPlatformParityTab.swift        # Task 12
    SettingsMutationsCatalogTab.swift      # Task 13
    SettingsFontsTab.swift                 # Task 14
  Views/Rail/
    ActivityRail.swift                     # Task 17
    ActivityPanel.swift                    # Task 18
    OrganizePanel.swift                    # Task 24
    BrowsePanel.swift                      # Task 25
    SearchPanel.swift                      # Task 26
    SourcePanel.swift                      # Task 27
  Models/
    ActivityRailTab.swift                  # Task 16
    SettingsTab.swift                      # Task 6
    PlaygroundSettingsKeys.swift           # Task 6
    LiveEditorStore+Settings.swift         # Task 6
    DiagramSearchIndex.swift               # Task 26 (search derivation logic)
    DiagramOutline.swift                   # Task 24 (organize-tree derivation logic)
    PlatformParityMatrix.swift             # Task 12 (parity data)
Tests/DiagramKitTests/EditorRedesign/
  EditorRedesignTokenTests.swift           # Task 1,2
  SettingsStateTests.swift                 # Task 6
  ActivityRailStateTests.swift             # Task 16
  DiagramSearchIndexTests.swift            # Task 26
  DiagramOutlineTests.swift                # Task 24
  PlatformParityMatrixTests.swift          # Task 12
```

**Modified**
```
Sources/DiagramKitSample/
  Views/DesignSystem/PlaygroundTokens.swift            # add palette fields, appearance cases, tokens(for:) (Tasks 1,2)
  Views/DesignSystem/PlaygroundPalette+Base.swift      # NEW: existing 4 presets moved here + new fields filled (Task 1)
  Views/DesignSystem/Environment+PlaygroundTokens.swift# defaultValue → .zedTrekDark (Task 2)
  Views/LiveEditorView.swift                           # chromeAppearanceRaw default → zedTrekDark (Task 2)
  Views/Workspace/InspectorThemeSection.swift          # chromeAppearanceRaw default → zedTrekDark (Task 2) [file later superseded]
  Models/LiveEditorState.swift                         # activeRailTab, settingsPresented, settingsTab (Tasks 6,16)
  DiagramKitSampleApp.swift                            # ⌘, CommandGroup (Task 6)
  Views/Workspace/PlaygroundShell.swift                # rail + panel + inspector + statusbar + settings overlay (Tasks 15,20)
  Views/Workspace/StatusbarView.swift                  # restyle to comp 4-segment (Task 21)
  Views/Workspace/InspectorView.swift                  # becomes editing surface (Task 19)
  Views/Visual/VisualToolPalette.swift, CanvasZoomToolbar.swift  # token restyle (Task 22)
  Views/Workspace/WorkspaceModePicker.swift            # token restyle (Task 23)
```

**Superseded / removed** (Task 28): `SidebarView` globals fold into `BrowsePanel`; inspector-global sections (RenderBackend/Theme/PlatformRow/Mutations) move to Settings; `InspectorView` becomes the editing surface.

---

## Stage 1 — Token & Design-System Foundation

### Task 1: Expand `PlaygroundPalette` (new fields, existing 4 presets keep working)

**Files:**
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundTokens.swift` (add fields to the `PlaygroundPalette` struct, ~L43-73)
- Create: `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundPalette+Base.swift` (move the four existing presets here, filling the new fields)
- Test: `Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift`

**Interfaces:**
- Produces: `PlaygroundPalette` gains stored properties — `bgWindow, bgRail, bgPanel, bgSheet, bgSidebarNav, bgChrome, bgCard, bgTrack, bgField: Color`; `borderWarm, borderFaint, borderSwatch, borderDestructive: Color`; `textFaint, gutter, textFaintest: Color`; `onAccent, accentSecondary, accentPeach: Color`; `catCyan, catMint, catPurple: Color`; `trafficRed, trafficYellow, trafficGreen: Color`. Existing fields unchanged.
- Consumes: nothing new.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift
import Testing
import SwiftUI
@testable import DiagramKitSample

@Suite struct EditorRedesignTokenTests {
    @Test func existingAppearancesStillResolve() {
        for appearance in [PlaygroundAppearance.dark, .light, .forest, .neutral] {
            let tokens = PlaygroundTokens.tokens(for: appearance)
            #expect(tokens.appearance == appearance)
            // New fields are populated (not defaulted to clear) — spot-check a few.
            #expect(tokens.palette.bgCard != tokens.palette.accent)
            #expect(tokens.palette.onAccent != tokens.palette.accent)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter EditorRedesignTokenTests`
Expected: FAIL — compile error, `PlaygroundPalette` has no member `bgCard`.

- [ ] **Step 3: Add the new fields to the struct**

In `PlaygroundTokens.swift`, extend the `PlaygroundPalette` struct (keep existing fields; add before the derived-accents comment):

```swift
struct PlaygroundPalette: Equatable, Sendable {
    var bgApp: Color
    var bgSurface: Color
    var bgElevated: Color
    var bgSunken: Color

    var fg1: Color
    var fg2: Color
    var fg3: Color

    var accent: Color

    var borderHairline: Color
    var borderSubtle: Color
    var borderStrong: Color

    var statusSuccess: Color
    var statusWarning: Color
    var statusError: Color
    var statusInfo: Color

    var rowHover: Color
    var rowSelected: Color

    var glassBg: Color

    // --- Redesign additions (layered surfaces from the comp) ---
    var bgWindow: Color        // #05060A — outermost window / rail
    var bgRail: Color          // activity-rail bg
    var bgPanel: Color         // #0C111B — side panel / inspector
    var bgSheet: Color         // #0E1421 — settings sheet
    var bgSidebarNav: Color    // #0B0F18 — settings nav / info callout
    var bgChrome: Color        // #0D1018 — title bar / status bar / zoom control
    var bgCard: Color          // #111827 — cards, node fill
    var bgTrack: Color         // #151A24 — segmented track, pill, chip
    var bgField: Color         // #080A0F — search/input/code bg

    var borderWarm: Color      // #2A2030 — warm outer panel border
    var borderFaint: Color     // #1c2432 — faint table row divider
    var borderSwatch: Color    // #3a4250 — color-swatch border
    var borderDestructive: Color // #3a2626 — reset-button border

    var textFaint: Color       // #687282 — placeholder / faint mono
    var gutter: Color          // #6F7888 — code gutter
    var textFaintest: Color    // #4F5868 — dashes / faint mono ids

    var onAccent: Color        // #1a1205 — text/icon drawn ON accent
    var accentSecondary: Color // #FFCC66 — amber/gold
    var accentPeach: Color     // #FFD8B0 — pencil icons

    var catCyan: Color         // #7EC8DE
    var catMint: Color         // #4EE6A6
    var catPurple: Color       // #CC99FF

    var trafficRed: Color      // #FF5D57
    var trafficYellow: Color   // #FEBC2E
    var trafficGreen: Color    // #28C840

    // Derived accents (color-mix in the CSS, opacity here).
    var accent10: Color { accent.opacity(0.10) }
    var accent15: Color { accent.opacity(0.15) }
    var accent20: Color { accent.opacity(0.20) }
    // Redesign tints from the comp.
    var accentTint16: Color { accent.opacity(0.16) }
    var accentTint14: Color { accent.opacity(0.14) }
    var accentTint08: Color { accent.opacity(0.08) }
}
```

- [ ] **Step 4: Move the four existing presets into `PlaygroundPalette+Base.swift`, filling new fields**

Cut the `extension PlaygroundPalette { static let dark/light/forest/neutral ... }` block (L153-239) out of `PlaygroundTokens.swift` into a new file. For each preset, append the new fields, deriving them from the preset's own tokens so nothing regresses visually. Example for `dark` (apply the SAME derivation formula to light/forest/neutral, substituting each preset's own values):

```swift
// Sources/DiagramKitSample/Views/DesignSystem/PlaygroundPalette+Base.swift
import SwiftUI

extension PlaygroundPalette {
    static let dark = PlaygroundPalette(
        bgApp:          Color(hex: 0x1C1C1E),
        bgSurface:      Color(hex: 0x2C2C2E),
        bgElevated:     Color(hex: 0x2C2C2E),
        bgSunken:       Color(hex: 0x3A3A3C),
        fg1:            .white,
        fg2:            Color(white: 0.92, opacity: 0.60),
        fg3:            Color(white: 0.92, opacity: 0.30),
        accent:         Color(hex: 0x0A84FF),
        borderHairline: .white.opacity(0.08),
        borderSubtle:   .white.opacity(0.12),
        borderStrong:   .white.opacity(0.20),
        statusSuccess:  Color(hex: 0x30D158),
        statusWarning:  Color(hex: 0xFF9F0A),
        statusError:    Color(hex: 0xFF453A),
        statusInfo:     Color(hex: 0x0A84FF),
        rowHover:       .white.opacity(0.06),
        rowSelected:    Color(hex: 0x0A84FF).opacity(0.15),
        glassBg:        Color(hex: 0x2C2C2E).opacity(0.75),
        // derived redesign fields (dark base): surfaces step from bgApp, text from fg tiers
        bgWindow:       Color(hex: 0x141416),
        bgRail:         Color(hex: 0x141416),
        bgPanel:        Color(hex: 0x1C1C1E),
        bgSheet:        Color(hex: 0x1C1C1E),
        bgSidebarNav:   Color(hex: 0x161618),
        bgChrome:       Color(hex: 0x222224),
        bgCard:         Color(hex: 0x2C2C2E),
        bgTrack:        Color(hex: 0x3A3A3C),
        bgField:        Color(hex: 0x141416),
        borderWarm:     .white.opacity(0.12),
        borderFaint:    .white.opacity(0.06),
        borderSwatch:   .white.opacity(0.20),
        borderDestructive: Color(hex: 0xFF453A).opacity(0.35),
        textFaint:      Color(white: 0.92, opacity: 0.30),
        gutter:         Color(white: 0.92, opacity: 0.35),
        textFaintest:   Color(white: 0.92, opacity: 0.22),
        onAccent:       .white,
        accentSecondary: Color(hex: 0x64D2FF),
        accentPeach:    Color(hex: 0xFFD8B0),
        catCyan:        Color(hex: 0x64D2FF),
        catMint:        Color(hex: 0x30D158),
        catPurple:      Color(hex: 0xBF5AF2),
        trafficRed:     Color(hex: 0xFF5D57),
        trafficYellow:  Color(hex: 0xFEBC2E),
        trafficGreen:   Color(hex: 0x28C840)
    )

    // light / forest / neutral: same field list, each deriving the redesign
    // fields from its own base (light uses light surfaces + .black text tiers;
    // forest keeps the green accent; neutral stays chroma-free). Fill every new
    // field for all three — do not leave any unset (the struct has no defaults).
}
```

For `light`: `onAccent: .white`, surfaces `bgWindow/bgField: Color(hex:0xFFFFFF)`, `bgPanel/bgSheet/bgSidebarNav: Color(hex:0xF2F2F7)`, `bgChrome: Color(hex:0xE5E5EA)`, `bgCard: .white`, `bgTrack: Color(hex:0xE5E5EA)`, `borderWarm/Subtle`: `.black.opacity(0.12)`, `borderFaint: .black.opacity(0.06)`, `textFaint/gutter/textFaintest`: the `fg3`/`fg2` grays, `accentSecondary: Color(hex:0xFF9500)`, `catCyan: Color(hex:0x5AC8FA)`, `catMint: Color(hex:0x34C759)`, `catPurple: Color(hex:0xAF52DE)`, traffic lights same as dark. `forest`/`neutral` analogous (forest = dark-derivation with green accents; neutral = light-derivation, chroma-free grays for cat*).

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter EditorRedesignTokenTests`
Expected: PASS.

- [ ] **Step 6: Build the whole app to catch any consumer breakage**

Run: `swift build`
Expected: builds clean (existing views only read old fields).

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitSample/Views/DesignSystem/PlaygroundTokens.swift \
        Sources/DiagramKitSample/Views/DesignSystem/PlaygroundPalette+Base.swift \
        Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift
git commit -m "Redesign: expand PlaygroundPalette with layered surface/text/accent tokens

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Six real Zed Trek appearances (LCARS Dark default)

**Files:**
- Modify: `PlaygroundTokens.swift` (`PlaygroundAppearance` cases + `displayName` + `preferredColorScheme` + `PlaygroundTokens.tokens(for:)` + static presets)
- Create: `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundPalette+ZedTrek.swift` (6 presets)
- Modify: `Environment+PlaygroundTokens.swift:12` (defaultValue), `LiveEditorView.swift:21`, `InspectorThemeSection.swift` (appearance defaults)
- Test: `EditorRedesignTokenTests.swift` (extend)

**Interfaces:**
- Produces: `PlaygroundAppearance` cases `.zedTrekDark, .zedTrekLight, .federation, .redAlert, .sickBay, .borgCube`; `PlaygroundPalette.zedTrekDark/…`; `PlaygroundTokens.zedTrekDark/…`. Default appearance is `.zedTrekDark` everywhere.
- Consumes: `PlaygroundPalette` fields from Task 1.

- [ ] **Step 1: Write the failing test** (append to the suite)

```swift
    @Test func zedTrekAppearancesResolveCompletePalettes() {
        let zedTrek: [PlaygroundAppearance] =
            [.zedTrekDark, .zedTrekLight, .federation, .redAlert, .sickBay, .borgCube]
        for appearance in zedTrek {
            let t = PlaygroundTokens.tokens(for: appearance)
            #expect(t.appearance == appearance)
            #expect(t.palette.accent != t.palette.bgWindow)   // real, distinct accent
            #expect(t.palette.onAccent != t.palette.accent)
        }
        #expect(PlaygroundAppearance.allCases.count == 10)
    }

    @Test func lcarsDarkIsTheDefault() {
        #expect(PlaygroundTokensKey.defaultValue.appearance == .zedTrekDark)
        // exact LCARS Dark anchors (transcription §1.1)
        let p = PlaygroundPalette.zedTrekDark
        #expect(p.accent == Color(hex: 0xFF9933))
        #expect(p.bgWindow == Color(hex: 0x05060A))
        #expect(p.bgSheet == Color(hex: 0x0E1421))
        #expect(p.fg1 == Color(hex: 0xF2E7D8))
    }
```

Note: `PlaygroundTokensKey` is `private` today — change it to internal (drop `private`) in `Environment+PlaygroundTokens.swift` so the test can read `defaultValue`.

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter EditorRedesignTokenTests`
Expected: FAIL — unknown cases `.zedTrekDark` etc.

- [ ] **Step 3: Add the appearance cases**

In `PlaygroundTokens.swift`, extend the enum:

```swift
enum PlaygroundAppearance: String, CaseIterable, Hashable, Codable, Sendable {
    case dark, light, forest, neutral
    case zedTrekDark, zedTrekLight, federation, redAlert, sickBay, borgCube

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .forest: return "Forest"
        case .neutral: return "Neutral"
        case .zedTrekDark: return "LCARS Dark"
        case .zedTrekLight: return "LCARS Light"
        case .federation: return "Federation"
        case .redAlert: return "Red Alert"
        case .sickBay: return "Sick Bay"
        case .borgCube: return "Borg Cube"
        }
    }

    var preferredColorScheme: ColorScheme {
        switch self {
        case .dark, .forest, .zedTrekDark, .federation, .redAlert, .sickBay, .borgCube:
            return .dark
        case .light, .neutral, .zedTrekLight:
            return .light
        }
    }

    /// The six comp themes shown in the Theme tab grid (transcription §5.4).
    static let zedTrekFamily: [PlaygroundAppearance] =
        [.zedTrekDark, .zedTrekLight, .federation, .redAlert, .sickBay, .borgCube]
}
```

- [ ] **Step 4: Add the 6 presets** in `PlaygroundPalette+ZedTrek.swift`

LCARS Dark uses the comp's exact §1.1 values. The other five supply their §1.1 specimen (base bg + accent + secondary + category) and derive the surface/text ladder with the SAME relative offsets LCARS Dark uses from `#05060A`.

```swift
// Sources/DiagramKitSample/Views/DesignSystem/PlaygroundPalette+ZedTrek.swift
import SwiftUI

extension PlaygroundPalette {
    /// LCARS Dark — fully specified by the comp (transcription §1.1).
    static let zedTrekDark = PlaygroundPalette(
        bgApp:          Color(hex: 0x05060A),
        bgSurface:      Color(hex: 0x0C111B),
        bgElevated:     Color(hex: 0x111827),
        bgSunken:       Color(hex: 0x080A0F),
        fg1:            Color(hex: 0xF2E7D8),
        fg2:            Color(hex: 0xB8BFC9),
        fg3:            Color(hex: 0x8B93A1),
        accent:         Color(hex: 0xFF9933),
        borderHairline: Color(hex: 0x252B36),
        borderSubtle:   Color(hex: 0x2A2030),
        borderStrong:   Color(hex: 0x3A4250),
        statusSuccess:  Color(hex: 0x30D158),
        statusWarning:  Color(hex: 0xFF9F0A),
        statusError:    Color(hex: 0xEF5A5A),
        statusInfo:     Color(hex: 0x7EC8DE),
        rowHover:       Color(hex: 0xFF9933).opacity(0.08),
        rowSelected:    Color(hex: 0xFF9933).opacity(0.16),
        glassBg:        Color(hex: 0x0D1018).opacity(0.90),
        bgWindow:       Color(hex: 0x05060A),
        bgRail:         Color(hex: 0x05060A),
        bgPanel:        Color(hex: 0x0C111B),
        bgSheet:        Color(hex: 0x0E1421),
        bgSidebarNav:   Color(hex: 0x0B0F18),
        bgChrome:       Color(hex: 0x0D1018),
        bgCard:         Color(hex: 0x111827),
        bgTrack:        Color(hex: 0x151A24),
        bgField:        Color(hex: 0x080A0F),
        borderWarm:     Color(hex: 0x2A2030),
        borderFaint:    Color(hex: 0x1C2432),
        borderSwatch:   Color(hex: 0x3A4250),
        borderDestructive: Color(hex: 0x3A2626),
        textFaint:      Color(hex: 0x687282),
        gutter:         Color(hex: 0x6F7888),
        textFaintest:   Color(hex: 0x4F5868),
        onAccent:       Color(hex: 0x1A1205),
        accentSecondary: Color(hex: 0xFFCC66),
        accentPeach:    Color(hex: 0xFFD8B0),
        catCyan:        Color(hex: 0x7EC8DE),
        catMint:        Color(hex: 0x4EE6A6),
        catPurple:      Color(hex: 0xCC99FF),
        trafficRed:     Color(hex: 0xFF5D57),
        trafficYellow:  Color(hex: 0xFEBC2E),
        trafficGreen:   Color(hex: 0x28C840)
    )

    /// LCARS Light — base #FBF7F1, accents #E07A1E/#B8945A/#C77D28 (transcription §1.1 theme table).
    static let zedTrekLight = zedTrekDark.recolored(
        base: 0xFBF7F1, panel: 0xF3ECE1, sheet: 0xFBF7F1, card: 0xFFFFFF, track: 0xEDE4D6,
        field: 0xFFFFFF, chrome: 0xF0E8DC, sidebarNav: 0xF3ECE1,
        text1: 0x2A2118, text2: 0x6B5D48, text3: 0x9A8C74, textFaint: 0xB8A794,
        accent: 0xE07A1E, secondary: 0xC77D28, cyan: 0x3E93B0, mint: 0x3FA37A, purple: 0x8A6FC0,
        onAccent: 0xFFFFFF, borderWarm: 0xD8CBB6, borderInner: 0xE3D9C7, scheme: .light)

    /// Federation — base #0A1020, accent gold #FFCC66, secondary blue #3B6FE0, cyan #7EC8DE.
    static let federation = zedTrekDark.recolored(
        base: 0x0A1020, panel: 0x0E1830, sheet: 0x101A34, card: 0x152244, track: 0x1A2A50,
        field: 0x070C1A, chrome: 0x0C1428, sidebarNav: 0x0B1226,
        text1: 0xF2E7D8, text2: 0xB8BFC9, text3: 0x8B93A1, textFaint: 0x687282,
        accent: 0xFFCC66, secondary: 0x3B6FE0, cyan: 0x7EC8DE, mint: 0x4EE6A6, purple: 0xCC99FF,
        onAccent: 0x1A1205, borderWarm: 0x24314F, borderInner: 0x1E2A46, scheme: .dark)

    /// Red Alert — base #160404, accent red #FF453A, secondary amber #FF9F0A, gold #FFCC66.
    static let redAlert = zedTrekDark.recolored(
        base: 0x160404, panel: 0x210808, sheet: 0x260A0A, card: 0x2E1010, track: 0x381616,
        field: 0x0F0303, chrome: 0x1C0606, sidebarNav: 0x190505,
        text1: 0xF2E7D8, text2: 0xC9B8B8, text3: 0xA18B8B, textFaint: 0x826868,
        accent: 0xFF453A, secondary: 0xFF9F0A, cyan: 0xFFCC66, mint: 0x30D158, purple: 0xFF7A6E,
        onAccent: 0x1A0505, borderWarm: 0x4F2424, borderInner: 0x3A1C1C, scheme: .dark)

    /// Sick Bay — base #04120F, accent mint #4EE6A6, cyan #7EC8DE, green #30D158.
    static let sickBay = zedTrekDark.recolored(
        base: 0x04120F, panel: 0x081E18, sheet: 0x0A241C, card: 0x102E24, track: 0x163830,
        field: 0x030F0C, chrome: 0x061C16, sidebarNav: 0x051915,
        text1: 0xF2E7D8, text2: 0xB8C9C2, text3: 0x8BA199, textFaint: 0x688278,
        accent: 0x4EE6A6, secondary: 0x30D158, cyan: 0x7EC8DE, mint: 0x4EE6A6, purple: 0x99FFCC,
        onAccent: 0x05120E, borderWarm: 0x244F42, borderInner: 0x1C3A32, scheme: .dark)

    /// Borg Cube — base #04120A, accent green #39FF57, secondary mint #4EE6A6, lime #A8FF60.
    static let borgCube = zedTrekDark.recolored(
        base: 0x04120A, panel: 0x081E12, sheet: 0x0A2416, card: 0x102E1C, track: 0x163826,
        field: 0x030F08, chrome: 0x061C10, sidebarNav: 0x051910,
        text1: 0xE8F2D8, text2: 0xB8C9B8, text3: 0x8BA18B, textFaint: 0x688268,
        accent: 0x39FF57, secondary: 0x4EE6A6, cyan: 0xA8FF60, mint: 0x4EE6A6, purple: 0xA8FF60,
        onAccent: 0x05120A, borderWarm: 0x244F32, borderInner: 0x1C3A26, scheme: .dark)
}
```

Add the `recolored(...)` helper in the same file — it clones `self` and overrides only the fields a theme respecifies, so every preset stays a complete palette:

```swift
extension PlaygroundPalette {
    func recolored(
        base: UInt32, panel: UInt32, sheet: UInt32, card: UInt32, track: UInt32,
        field: UInt32, chrome: UInt32, sidebarNav: UInt32,
        text1: UInt32, text2: UInt32, text3: UInt32, textFaint: UInt32,
        accent: UInt32, secondary: UInt32, cyan: UInt32, mint: UInt32, purple: UInt32,
        onAccent: UInt32, borderWarm: UInt32, borderInner: UInt32, scheme: ColorScheme
    ) -> PlaygroundPalette {
        var p = self
        p.bgApp = Color(hex: base); p.bgWindow = Color(hex: base); p.bgRail = Color(hex: base)
        p.bgSunken = Color(hex: field); p.bgField = Color(hex: field)
        p.bgPanel = Color(hex: panel); p.bgSurface = Color(hex: panel)
        p.bgSheet = Color(hex: sheet); p.bgSidebarNav = Color(hex: sidebarNav)
        p.bgChrome = Color(hex: chrome); p.bgCard = Color(hex: card); p.bgElevated = Color(hex: card)
        p.bgTrack = Color(hex: track)
        p.fg1 = Color(hex: text1); p.fg2 = Color(hex: text2); p.fg3 = Color(hex: text3)
        p.textFaint = Color(hex: textFaint); p.gutter = Color(hex: text3); p.textFaintest = Color(hex: textFaint)
        p.accent = Color(hex: accent); p.accentSecondary = Color(hex: secondary); p.onAccent = Color(hex: onAccent)
        p.catCyan = Color(hex: cyan); p.catMint = Color(hex: mint); p.catPurple = Color(hex: purple)
        p.borderWarm = Color(hex: borderWarm); p.borderSubtle = Color(hex: borderWarm)
        p.borderHairline = Color(hex: borderInner); p.borderFaint = Color(hex: borderInner)
        p.rowHover = Color(hex: accent).opacity(0.08); p.rowSelected = Color(hex: accent).opacity(0.16)
        p.statusInfo = Color(hex: cyan)
        p.glassBg = Color(hex: chrome).opacity(0.90)
        return p
    }
}
```

- [ ] **Step 5: Register presets + flip the default**

In `PlaygroundTokens.swift`, add the static tokens + switch arms:

```swift
struct PlaygroundTokens: Equatable, Sendable {
    var appearance: PlaygroundAppearance
    var palette: PlaygroundPalette

    static let dark    = PlaygroundTokens(appearance: .dark,    palette: .dark)
    static let light   = PlaygroundTokens(appearance: .light,   palette: .light)
    static let forest  = PlaygroundTokens(appearance: .forest,  palette: .forest)
    static let neutral = PlaygroundTokens(appearance: .neutral, palette: .neutral)
    static let zedTrekDark  = PlaygroundTokens(appearance: .zedTrekDark,  palette: .zedTrekDark)
    static let zedTrekLight = PlaygroundTokens(appearance: .zedTrekLight, palette: .zedTrekLight)
    static let federation   = PlaygroundTokens(appearance: .federation,   palette: .federation)
    static let redAlert     = PlaygroundTokens(appearance: .redAlert,     palette: .redAlert)
    static let sickBay      = PlaygroundTokens(appearance: .sickBay,      palette: .sickBay)
    static let borgCube     = PlaygroundTokens(appearance: .borgCube,     palette: .borgCube)

    static func tokens(for appearance: PlaygroundAppearance) -> PlaygroundTokens {
        switch appearance {
        case .dark: return .dark
        case .light: return .light
        case .forest: return .forest
        case .neutral: return .neutral
        case .zedTrekDark: return .zedTrekDark
        case .zedTrekLight: return .zedTrekLight
        case .federation: return .federation
        case .redAlert: return .redAlert
        case .sickBay: return .sickBay
        case .borgCube: return .borgCube
        }
    }
}
```

Then flip the default at all four sites:
- `Environment+PlaygroundTokens.swift:12` — `static let defaultValue: PlaygroundTokens = .zedTrekDark` (and drop `private` from `struct PlaygroundTokensKey`).
- `LiveEditorView.swift:21` — `private var chromeAppearanceRaw: String = PlaygroundAppearance.zedTrekDark.rawValue`, and its computed `chromeAppearance` fallback `?? .zedTrekDark` (L26).
- `InspectorThemeSection.swift` — same `@AppStorage` default + fallback → `.zedTrekDark`.

- [ ] **Step 6: Run to verify it passes**

Run: `swift test --filter EditorRedesignTokenTests`
Expected: PASS (10 appearances, LCARS Dark default, exact anchors).

- [ ] **Step 7: Build + commit**

```bash
swift build
git add Sources/DiagramKitSample/Views/DesignSystem/ Sources/DiagramKitSample/Views/LiveEditorView.swift \
        Sources/DiagramKitSample/Views/Workspace/InspectorThemeSection.swift \
        Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift
git commit -m "Redesign: six real Zed Trek appearances, LCARS Dark default

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: DS row components — `ToggleRow`, `StepperRow`, `MenuRow`, `StatusRow`

**Files:** Create `Views/DesignSystem/Components/{ToggleRow,StepperRow,MenuRow,StatusRow}.swift`

**Interfaces (Produces):**
- `ToggleRow(title: String, description: String? = nil, isOn: Binding<Bool>)` + `PillSwitch(isOn: Binding<Bool>)`
- `StepperRow(title:, description:? , value: Binding<Int>, range: ClosedRange<Int> = 0...999, step: Int = 1, unit: String = "")`
- `MenuRow<Menu: View>(title:, description:?, value: String, leadingSwatch: AnyView? = nil, @ViewBuilder content: () -> Menu)`
- `StatusRow(title:, description:?, value: String, valueColor: Color? = nil, dotColor: Color? = nil, monospaced: Bool = false)`

- [ ] **Step 1: Create the four files with this code**

```swift
// ToggleRow.swift
import SwiftUI

struct ToggleRow: View {
    let title: String
    var description: String? = nil
    @Binding var isOn: Bool
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
                if let description {
                    Text(description).font(PlaygroundFont.caption).foregroundStyle(tokens.palette.textFaint)
                }
            }
            Spacer(minLength: PlaygroundSpacing.md)
            PillSwitch(isOn: $isOn)
        }
        .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
    }
}

struct PillSwitch: View {
    @Binding var isOn: Bool
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        Capsule().fill(isOn ? tokens.palette.accent : tokens.palette.bgTrack)
            .frame(width: 40, height: 24)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle().fill(isOn ? .white : tokens.palette.fg3).frame(width: 20, height: 20).padding(2)
            }
            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { isOn.toggle() } }
            .accessibilityAddTraits(.isButton).accessibilityValue(isOn ? "on" : "off")
    }
}
```

```swift
// StepperRow.swift
import SwiftUI

struct StepperRow: View {
    let title: String
    var description: String? = nil
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999
    var step: Int = 1
    var unit: String = ""
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
                if let description {
                    Text(description).font(PlaygroundFont.caption).foregroundStyle(tokens.palette.textFaint)
                }
            }
            Spacer(minLength: PlaygroundSpacing.md)
            stepper
        }.padding(.horizontal, 14).padding(.vertical, 12)
    }
    private var stepper: some View {
        HStack(spacing: 0) {
            button("−") { value = max(range.lowerBound, value - step) }
            Text("\(value)\(unit.isEmpty ? "" : " \(unit)")").font(PlaygroundFont.mono(12))
                .foregroundStyle(tokens.palette.fg1).padding(.horizontal, 10).padding(.vertical, 5)
                .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(width: 0.5), alignment: .leading)
                .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(width: 0.5), alignment: .trailing)
            button("+") { value = min(range.upperBound, value + step) }
        }
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
    private func button(_ glyph: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph).font(PlaygroundFont.mono(12)).foregroundStyle(tokens.palette.fg3)
                .padding(.horizontal, 10).padding(.vertical, 5)
        }.buttonStyle(.plain)
    }
}
```

```swift
// MenuRow.swift
import SwiftUI

struct MenuRow<Menu: View>: View {
    let title: String
    var description: String? = nil
    let value: String
    var leadingSwatch: AnyView? = nil
    @ViewBuilder var content: () -> Menu
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
                if let description {
                    Text(description).font(PlaygroundFont.caption).foregroundStyle(tokens.palette.textFaint)
                }
            }
            Spacer(minLength: PlaygroundSpacing.md)
            SwiftUI.Menu {
                content()
            } label: {
                HStack(spacing: 6) {
                    if let leadingSwatch { leadingSwatch }
                    Text(value).font(PlaygroundFont.sans(12)).foregroundStyle(tokens.palette.fg2)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(tokens.palette.fg3)
                }
            }.menuStyle(.button).buttonStyle(.plain).fixedSize()
        }.padding(.horizontal, 14).padding(.vertical, 12)
    }
}
```

```swift
// StatusRow.swift
import SwiftUI

struct StatusRow: View {
    let title: String
    var description: String? = nil
    let value: String
    var valueColor: Color? = nil
    var dotColor: Color? = nil
    var monospaced: Bool = false
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
                if let description {
                    Text(description).font(monospaced ? PlaygroundFont.mono(11) : PlaygroundFont.caption)
                        .foregroundStyle(tokens.palette.textFaint)
                }
            }
            Spacer(minLength: PlaygroundSpacing.md)
            HStack(spacing: 6) {
                if let dotColor { Circle().fill(dotColor).frame(width: 7, height: 7) }
                Text(value).font(monospaced ? PlaygroundFont.mono(12) : PlaygroundFont.sans(12))
                    .foregroundStyle(valueColor ?? tokens.palette.fg2)
            }
        }.padding(.horizontal, 14).padding(.vertical, 12)
    }
}
```

- [ ] **Step 2: Build** — `swift build` → clean.
- [ ] **Step 3: Commit** — `git add Sources/DiagramKitSample/Views/DesignSystem/Components/{ToggleRow,StepperRow,MenuRow,StatusRow}.swift && git commit -m "Redesign: settings row components (toggle/stepper/menu/status)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"`

---

### Task 4: DS container/control components — `SettingsGroupCard`, `SidebarNavItem`, `SegmentedFormatControl`, `DestructiveButton`, `InfoCallout`

**Files:** Create `Views/DesignSystem/Components/{SettingsGroupCard,SidebarNavItem,SegmentedFormatControl,DestructiveButton,InfoCallout}.swift`

**Interfaces (Produces):**
- `SettingsGroupCard { <rows> }` — draws the `bgCard` container and auto-inserts 0.5px dividers between its children (via `_VariadicView`).
- `SidebarNavItem(title: String, systemImage: String, isActive: Bool, action: () -> Void)`
- `SegmentedFormatControl<Value: Hashable>(segments: [.init(value:label:systemImage:?:monospaced:?)], selection: Binding<Value>)`
- `DestructiveButton(title: String, systemImage: String = "arrow.counterclockwise", action: () -> Void)`
- `InfoCallout(text: String, systemImage: String = "info.circle")`

- [ ] **Step 1: Create the five files**

```swift
// SettingsGroupCard.swift
import SwiftUI

struct SettingsGroupCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        _VariadicView.Tree(DividedRows(divider: tokens.palette.borderHairline)) { content() }
            .background(tokens.palette.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: PlaygroundRadius.md))
            .overlay(RoundedRectangle(cornerRadius: PlaygroundRadius.md).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
    }
}

private struct DividedRows: _VariadicView_MultiViewRoot {
    let divider: Color
    @ViewBuilder func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id
        VStack(spacing: 0) {
            ForEach(children) { child in
                child
                if child.id != last { Rectangle().fill(divider).frame(height: 0.5) }
            }
        }
    }
}
```

```swift
// SidebarNavItem.swift
import SwiftUI

struct SidebarNavItem: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isActive ? tokens.palette.accent : tokens.palette.fg3).frame(width: 15)
                Text(title).font(PlaygroundFont.sans(12.5, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? tokens.palette.accentSecondary : tokens.palette.fg2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).frame(height: 32)
            .background(isActive ? tokens.palette.accentTint16 : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 7)).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
```

```swift
// SegmentedFormatControl.swift
import SwiftUI

struct SegmentedFormatControl<Value: Hashable>: View {
    struct Segment: Identifiable {
        let value: Value; let label: String
        var systemImage: String? = nil; var monospaced: Bool = false
        var id: Value { value }
    }
    let segments: [Segment]
    @Binding var selection: Value
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        HStack(spacing: 3) {
            ForEach(segments) { seg in
                let active = seg.value == selection
                Button { selection = seg.value } label: {
                    HStack(spacing: 6) {
                        if let img = seg.systemImage { Image(systemName: img).font(.system(size: 12, weight: .medium)) }
                        Text(seg.label).font(seg.monospaced
                            ? PlaygroundFont.mono(12.5, weight: active ? .semibold : .regular)
                            : PlaygroundFont.sans(12.5, weight: active ? .semibold : .regular))
                    }
                    .foregroundStyle(active ? tokens.palette.onAccent : tokens.palette.fg3)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(active ? tokens.palette.accent : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain)
            }
        }
        .padding(3).background(tokens.palette.bgTrack)
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
```

```swift
// DestructiveButton.swift
import SwiftUI

struct DestructiveButton: View {
    let title: String
    var systemImage: String = "arrow.counterclockwise"
    let action: () -> Void
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 13, weight: .medium))
                Text(title).font(PlaygroundFont.sans(12.5))
            }
            .foregroundStyle(tokens.palette.statusError)
            .padding(.horizontal, 14).frame(height: 34)
            .background(tokens.palette.bgTrack)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.palette.borderDestructive, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
}
```

```swift
// InfoCallout.swift
import SwiftUI

struct InfoCallout: View {
    let text: String
    var systemImage: String = "info.circle"
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage).font(.system(size: 14, weight: .medium)).foregroundStyle(tokens.palette.catCyan)
            Text(text).font(PlaygroundFont.sans(11.5)).lineSpacing(3).foregroundStyle(tokens.palette.fg3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(tokens.palette.bgSidebarNav)
        .overlay(RoundedRectangle(cornerRadius: PlaygroundRadius.md).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: PlaygroundRadius.md))
    }
}
```

- [ ] **Step 2: Build** — `swift build` → clean. (If `_VariadicView_MultiViewRoot` triggers a warning, it is acceptable SPI already used across SwiftUI apps; keep it.)
- [ ] **Step 3: Commit** — `git add … && git commit -m "Redesign: settings container/control components\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"`

---

### Task 5: DS editor/canvas components — `ThemeSwatchCard`, `ParityTable`, `ColorDotPicker`, `ActivityRailItem`, `SelectionBreadcrumb`, `ValuePill`, `SliderRow`, `AlignButtonRow`

**Files:** Create `Views/DesignSystem/Components/{ThemeSwatchCard,ParityTable,ColorDotPicker,ActivityRailItem,SelectionBreadcrumb,ValuePill,SliderRow,AlignButtonRow}.swift`

**Interfaces (Produces):**
- `ThemeSwatchCard(name: String, background: Color, bars: [Color], isActive: Bool, action: () -> Void)`
- `ParityTable(columns: [String], rows: [ParityTable.Row])`; `ParityTable.Cell = .full | .partial | .unsupported`; `ParityTable.Row(feature: String, mono: String? = nil, cells: [Cell])`
- `ColorDotPicker(colors: [Color], selectedIndex: Binding<Int?>)`
- `ActivityRailItem(systemImage: String, isActive: Bool, help: String, action: () -> Void)`
- `SelectionBreadcrumb(text: String, systemImage: String = "rectangle")`
- `ValuePill(label: String, systemImage: String? = nil, action: () -> Void)`
- `SliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double> = 0...100)`
- `AlignButtonRow()` (presentational/disabled — ARRANGE has no backing mutation)

- [ ] **Step 1: Create the eight files** (full source; exact dims from transcription §1.4/§3.1/§5.4)

```swift
// ThemeSwatchCard.swift
import SwiftUI

struct ThemeSwatchCard: View {
    let name: String
    let background: Color
    let bars: [Color]
    let isActive: Bool
    let action: () -> Void
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    if bars.count > 0 { bar(bars[0], 0.55, 5) }
                    if bars.count > 1 { bar(bars[1], 0.82, 4) }
                    if bars.count > 2 { bar(bars[2], 0.44, 4) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 9).frame(height: 60).background(background)
                HStack {
                    Text(name).font(PlaygroundFont.sans(11.5)).foregroundStyle(isActive ? tokens.palette.fg1 : tokens.palette.fg2)
                    Spacer()
                    if isActive { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(tokens.palette.accent) }
                }
                .padding(.horizontal, 10).padding(.vertical, 7).frame(maxWidth: .infinity).background(tokens.palette.bgCard)
                .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5), alignment: .top)
            }
            .clipShape(RoundedRectangle(cornerRadius: PlaygroundRadius.md))
            .overlay(RoundedRectangle(cornerRadius: PlaygroundRadius.md)
                .stroke(isActive ? tokens.palette.accent : tokens.palette.borderHairline, lineWidth: isActive ? 1.5 : 0.5))
        }.buttonStyle(.plain)
    }
    private func bar(_ color: Color, _ frac: CGFloat, _ h: CGFloat) -> some View {
        GeometryReader { geo in RoundedRectangle(cornerRadius: 2).fill(color).frame(width: geo.size.width * frac, height: h) }
            .frame(height: h)
    }
}
```

```swift
// ParityTable.swift
import SwiftUI

struct ParityTable: View {
    enum Cell { case full, partial, unsupported }
    struct Row: Identifiable { let feature: String; var mono: String? = nil; let cells: [Cell]; var id: String { feature } }
    let columns: [String]
    let rows: [Row]
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        VStack(spacing: 0) {
            header
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                rowView(row)
                if i < rows.count - 1 { Rectangle().fill(tokens.palette.borderFaint).frame(height: 0.5) }
            }
        }
        .background(tokens.palette.bgCard)
        .overlay(RoundedRectangle(cornerRadius: PlaygroundRadius.md).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: PlaygroundRadius.md))
    }
    private var header: some View {
        HStack(spacing: 0) {
            Text("FEATURE").font(PlaygroundFont.sans(10, weight: .bold)).tracking(0.6)
                .foregroundStyle(tokens.palette.fg3).frame(maxWidth: .infinity, alignment: .leading)
            ForEach(columns, id: \.self) { c in
                Text(c.uppercased()).font(PlaygroundFont.sans(10, weight: .bold)).tracking(0.6)
                    .foregroundStyle(tokens.palette.fg3).frame(width: 60)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .overlay(Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5), alignment: .bottom)
    }
    private func rowView(_ row: Row) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(row.feature).font(PlaygroundFont.sans(12.5)).foregroundStyle(tokens.palette.fg1)
                if let mono = row.mono { Text(mono).font(PlaygroundFont.mono(11)).foregroundStyle(tokens.palette.fg3) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in cellView(cell).frame(width: 60) }
        }.padding(.horizontal, 14).padding(.vertical, 11)
    }
    @ViewBuilder private func cellView(_ cell: Cell) -> some View {
        switch cell {
        case .full: Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(tokens.palette.statusSuccess)
        case .partial: Circle().fill(tokens.palette.statusWarning).frame(width: 8, height: 8)
        case .unsupported: Text("—").font(PlaygroundFont.sans(12)).foregroundStyle(tokens.palette.textFaintest)
        }
    }
}
```

```swift
// ColorDotPicker.swift
import SwiftUI

struct ColorDotPicker: View {
    let colors: [Color]
    @Binding var selectedIndex: Int?
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        HStack(spacing: 9) {
            ForEach(Array(colors.enumerated()), id: \.offset) { i, color in
                Circle().fill(color).frame(width: 26, height: 26)
                    .overlay { if selectedIndex == i { Circle().stroke(tokens.palette.accent, lineWidth: 2).padding(-3.5) } }
                    .onTapGesture { selectedIndex = i }
            }
        }
    }
}
```

```swift
// ActivityRailItem.swift
import SwiftUI

struct ActivityRailItem: View {
    let systemImage: String
    let isActive: Bool
    let help: String
    let action: () -> Void
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 18))
                .foregroundStyle(isActive ? tokens.palette.accent : tokens.palette.fg3)
                .frame(width: 38, height: 38)
                .background(isActive ? tokens.palette.accentTint16 : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(alignment: .leading) {
                    if isActive {
                        RoundedRectangle(cornerRadius: 2).fill(tokens.palette.accent).frame(width: 2.5).padding(.vertical, 9).offset(x: -10)
                    }
                }
        }.buttonStyle(.plain).help(help)
    }
}
```

```swift
// SelectionBreadcrumb.swift
import SwiftUI

struct SelectionBreadcrumb: View {
    let text: String
    var systemImage: String = "rectangle"
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.system(size: 11))
            Text(text).font(PlaygroundFont.mono(12))
        }
        .foregroundStyle(tokens.palette.accentSecondary)
        .padding(.horizontal, 11).padding(.vertical, 5)
        .background(tokens.palette.accentTint14)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.palette.accent.opacity(0.4), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

```swift
// ValuePill.swift
import SwiftUI

struct ValuePill: View {
    let label: String
    var systemImage: String? = nil
    let action: () -> Void
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let img = systemImage { Image(systemName: img).font(.system(size: 11)) }
                Text(label).font(PlaygroundFont.sans(12))
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(tokens.palette.fg3)
            }
            .foregroundStyle(tokens.palette.fg1).padding(.horizontal, 8).frame(height: 28)
            .background(tokens.palette.bgTrack)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain)
    }
}
```

```swift
// SliderRow.swift
import SwiftUI

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(PlaygroundFont.sans(12.5)).foregroundStyle(tokens.palette.fg3)
                Spacer()
                Text("\(Int(value))").font(PlaygroundFont.mono(12)).foregroundStyle(tokens.palette.accentSecondary)
            }
            Slider(value: $value, in: range).tint(tokens.palette.accent)
        }
    }
}
```

```swift
// AlignButtonRow.swift
import SwiftUI

/// ARRANGE align buttons. Presentational this cycle — an ELK auto-layout graph has no
/// free node positions to align (spec "Backing-mutation boundary"). Rendered disabled.
struct AlignButtonRow: View {
    @Environment(\.playgroundTokens) private var tokens
    private let leading = ["align.horizontal.left", "align.horizontal.center", "align.horizontal.right"]
    private let trailing = ["align.vertical.top", "align.vertical.center", "align.vertical.bottom"]
    var body: some View {
        HStack(spacing: 6) {
            ForEach(leading, id: \.self) { alignButton($0) }
            Rectangle().fill(tokens.palette.borderHairline).frame(width: 0.5, height: 20)
            ForEach(trailing, id: \.self) { alignButton($0) }
        }
    }
    private func alignButton(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(tokens.palette.fg2.opacity(0.5))
            .frame(width: 34, height: 30).background(tokens.palette.bgTrack)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(tokens.palette.borderHairline, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .help("Alignment is presentational for auto-laid-out diagrams")
    }
}
```

- [ ] **Step 2: Build** — `swift build`. If any SF Symbol name is rejected (e.g. `align.horizontal.left`), substitute the closest valid symbol (`arrow.left.to.line`, etc.) — SF Symbol availability is the only thing to verify here.
- [ ] **Step 3: Commit** — `git add … && git commit -m "Redesign: editor/canvas DS components (theme swatch, parity table, rail item, …)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"`

---

## Stage 2 — Settings Sheet (⌘,)

### Task 6: Settings state, tab enum, persistence keys, store methods, shared tab header

**Files:**
- Create: `Models/SettingsTab.swift`, `Models/PlaygroundSettingsKeys.swift`, `Models/LiveEditorStore+Settings.swift`, `Views/Settings/SettingsTabHeader.swift`
- Modify: `Models/LiveEditorState.swift` (add `settingsPresented`, `settingsTab`)
- Test: `Tests/DiagramKitTests/EditorRedesign/SettingsStateTests.swift`

**Interfaces (Produces):**
- `enum SettingsTab: String, CaseIterable, Codable, Sendable, Hashable` with `.displayName`, `.systemImage`.
- `LiveEditorState.settingsPresented: Bool = false`, `.settingsTab: SettingsTab = .general`.
- `LiveEditorStore.presentSettings(tab:) / dismissSettings() / setSettingsTab(_:)`.
- `enum PlaygroundSettingsKeys` (string keys + `resetAll()`).
- `SettingsTabHeader(title:subtitle:)`, `SettingsSectionCaption(text:)`.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/DiagramKitTests/EditorRedesign/SettingsStateTests.swift
import Testing
@testable import DiagramKitSample

@MainActor @Suite struct SettingsStateTests {
    @Test func presentAndDismiss() {
        let store = LiveEditorStore()
        #expect(store.state.settingsPresented == false)
        store.presentSettings(tab: .theme)
        #expect(store.state.settingsPresented)
        #expect(store.state.settingsTab == .theme)
        store.dismissSettings()
        #expect(store.state.settingsPresented == false)
    }
    @Test func setTab() {
        let store = LiveEditorStore()
        store.setSettingsTab(.fonts)
        #expect(store.state.settingsTab == .fonts)
    }
    @Test func sevenTabs() { #expect(SettingsTab.allCases.count == 7) }
}
```

- [ ] **Step 2: Run — expect FAIL** (`swift test --filter SettingsStateTests` → unknown `settingsPresented`).

- [ ] **Step 3: Add `SettingsTab.swift`**

```swift
import Foundation

enum SettingsTab: String, CaseIterable, Codable, Sendable, Hashable {
    case general, editor, renderBackend, theme, platformParity, mutationsCatalog, fonts
    var displayName: String {
        switch self {
        case .general: "General"; case .editor: "Editor"; case .renderBackend: "Render Backend"
        case .theme: "Theme"; case .platformParity: "Platform Parity"
        case .mutationsCatalog: "Mutations Catalog"; case .fonts: "Fonts"
        }
    }
    var systemImage: String {
        switch self {
        case .general: "gearshape"; case .editor: "chevron.left.forwardslash.chevron.right"
        case .renderBackend: "rectangle.on.rectangle"; case .theme: "paintpalette"
        case .platformParity: "rectangle.split.2x1"; case .mutationsCatalog: "number"; case .fonts: "textformat"
        }
    }
}
```

- [ ] **Step 4: Add state props** in `LiveEditorState.swift` — add two stored properties next to `inspectorOpen` (with matching `public var`), and set their defaults in the `init` (both are `Codable`/`Equatable`/`Sendable`-safe since `SettingsTab` conforms):

```swift
public var settingsPresented: Bool = false
public var settingsTab: SettingsTab = .general
```

(If `LiveEditorState.init` lists every field explicitly, add `settingsPresented = false` and `settingsTab = .general` there too.)

- [ ] **Step 5: Add store methods** `LiveEditorStore+Settings.swift`

```swift
import Foundation

extension LiveEditorStore {
    public func presentSettings(tab: SettingsTab = .general) {
        state.settingsTab = tab
        state.settingsPresented = true
    }
    public func dismissSettings() { state.settingsPresented = false }
    public func setSettingsTab(_ tab: SettingsTab) { state.settingsTab = tab }
}
```

- [ ] **Step 6: Add `PlaygroundSettingsKeys.swift`**

```swift
import Foundation

enum PlaygroundSettingsKeys {
    static let confirmBeforeDelete       = "playground.settings.confirmBeforeDelete"
    static let sendAnonymousDiagnostics  = "playground.settings.sendAnonymousDiagnostics"
    static let restoreLastDocument       = "playground.settings.restoreLastDocument"
    static let showConnectionHandles     = "playground.settings.showConnectionHandles"
    static let gridSize                  = "playground.settings.gridSize"
    static let keyboardNudge             = "playground.settings.keyboardNudge"
    static let defaultNodeShape          = "playground.settings.defaultNodeShape"
    static let defaultEdgeStyle          = "playground.settings.defaultEdgeStyle"
    static let uiTextSize                = "playground.settings.uiTextSize"

    static let all = [confirmBeforeDelete, sendAnonymousDiagnostics, restoreLastDocument,
                      showConnectionHandles, gridSize, keyboardNudge, defaultNodeShape,
                      defaultEdgeStyle, uiTextSize]

    @MainActor static func resetAll() {
        for key in all { UserDefaults.standard.removeObject(forKey: key) }
    }
}
```

- [ ] **Step 7: Add `SettingsTabHeader.swift`**

```swift
import SwiftUI

struct SettingsTabHeader: View {
    let title: String
    let subtitle: String
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(PlaygroundFont.sans(16, weight: .semibold)).foregroundStyle(tokens.palette.fg1)
            Text(subtitle).font(PlaygroundFont.sans(12.5)).foregroundStyle(tokens.palette.fg3)
        }.padding(.bottom, 13)
    }
}

struct SettingsSectionCaption: View {
    let text: String
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        Text(text.uppercased()).font(PlaygroundFont.sans(10, weight: .bold)).tracking(0.6)
            .foregroundStyle(tokens.palette.fg3).padding(.top, 4).padding(.bottom, 9)
    }
}
```

- [ ] **Step 8: Run — expect PASS** (`swift test --filter SettingsStateTests`), then `swift build`, then commit.

```bash
git add Sources/DiagramKitSample/Models/SettingsTab.swift \
        Sources/DiagramKitSample/Models/PlaygroundSettingsKeys.swift \
        Sources/DiagramKitSample/Models/LiveEditorStore+Settings.swift \
        Sources/DiagramKitSample/Models/LiveEditorState.swift \
        Sources/DiagramKitSample/Views/Settings/SettingsTabHeader.swift \
        Tests/DiagramKitTests/EditorRedesign/SettingsStateTests.swift
git commit -m "Redesign: settings sheet state, tabs, persistence keys

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: `SettingsGeneralTab` (§5.1)

**Files:** Create `Views/Settings/SettingsGeneralTab.swift`
**Interfaces:** Consumes `store.state.showCitations`/`store.setShowCitations`, `PlaygroundSettingsKeys`, DS rows. Produces `SettingsGeneralTab(store:)`.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct SettingsGeneralTab: View {
    @Bindable var store: LiveEditorStore
    @AppStorage(PlaygroundSettingsKeys.confirmBeforeDelete) private var confirmBeforeDelete = true
    @AppStorage(PlaygroundSettingsKeys.sendAnonymousDiagnostics) private var sendDiagnostics = false
    @AppStorage(PlaygroundSettingsKeys.restoreLastDocument) private var restoreLast = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "General", subtitle: "Workspace and document defaults.")
            SettingsGroupCard {
                MenuRow(title: "Default format", value: "Auto-detect") { Button("Auto-detect") {} }
                MenuRow(title: "On startup", value: restoreLast ? "Restore last document" : "New document") {
                    Button("Restore last document") { restoreLast = true }
                    Button("New document") { restoreLast = false }
                }
                ToggleRow(title: "Confirm before delete", description: "Ask before removing nodes or edges", isOn: $confirmBeforeDelete)
                ToggleRow(title: "Send anonymous diagnostics", description: "Crash reports and usage counts", isOn: $sendDiagnostics)
                ToggleRow(title: "Show source citations", description: "Trace nodes back to source lines",
                          isOn: Binding(get: { store.state.showCitations }, set: { store.setShowCitations($0) }))
            }
            .padding(.bottom, 18)
            SettingsSectionCaption(text: "Reset")
            DestructiveButton(title: "Reset All Settings") { PlaygroundSettingsKeys.resetAll() }
            Spacer(minLength: 0)
        }
    }
}
```

- [ ] **Step 2:** `swift build` → clean. **Step 3:** commit.

---

### Task 8: `SettingsEditorTab` (§5.2)

**Files:** Create `Views/Settings/SettingsEditorTab.swift`
**Note:** the app has no free-node snapping; "Snap to grid" binds to the existing `state.gridEnabled` (grid visibility) — the honest closest binding. Grid size / nudge / shapes / edge style are net-new `@AppStorage` prefs (not yet consumed by the canvas — wiring them into the canvas is out of scope this cycle; they persist and display).

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct SettingsEditorTab: View {
    @Bindable var store: LiveEditorStore
    @AppStorage(PlaygroundSettingsKeys.showConnectionHandles) private var showHandles = true
    @AppStorage(PlaygroundSettingsKeys.gridSize) private var gridSize = 26
    @AppStorage(PlaygroundSettingsKeys.keyboardNudge) private var nudge = 8
    @AppStorage(PlaygroundSettingsKeys.defaultNodeShape) private var nodeShape = "Rectangle"
    @AppStorage(PlaygroundSettingsKeys.defaultEdgeStyle) private var edgeStyle = "Solid arrow"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Editor", subtitle: "Canvas and interaction.")
            SettingsGroupCard {
                ToggleRow(title: "Snap to grid", isOn: $store.state.gridEnabled)
                StepperRow(title: "Grid size", value: $gridSize, range: 8...64, step: 2, unit: "px")
                ToggleRow(title: "Show connection handles", isOn: $showHandles)
                MenuRow(title: "Default node shape", value: nodeShape) {
                    ForEach(["Rectangle","Rounded","Stadium","Circle","Diamond"], id: \.self) { s in Button(s) { nodeShape = s } }
                }
                MenuRow(title: "Default edge style", value: edgeStyle) {
                    ForEach(["Solid arrow","Dotted","Thick","Open"], id: \.self) { s in Button(s) { edgeStyle = s } }
                }
                StepperRow(title: "Keyboard nudge", description: "Arrow-key move distance", value: $nudge, range: 1...32, unit: "px")
            }
            Spacer(minLength: 0)
        }
    }
}
```

- [ ] **Step 2:** build → clean. **Step 3:** commit.

---

### Task 9: `SettingsRenderBackendTab` (§5.3 — re-host `InspectorRenderBackendSection`)

**Files:** Create `Views/Settings/SettingsRenderBackendTab.swift`
**Interfaces:** Consumes `store.state.renderBackend` (Binding), `store.state.updateMode`.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct SettingsRenderBackendTab: View {
    @Bindable var store: LiveEditorStore
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Render Backend", subtitle: "How diagrams are rasterized and rendered.")
            SegmentedFormatControl(segments: [
                .init(value: RenderBackend.svg, label: "SVG", systemImage: "doc.text"),
                .init(value: RenderBackend.image, label: "Image", systemImage: "photo"),
                .init(value: RenderBackend.ascii, label: "ASCII", monospaced: true),
            ], selection: $store.state.renderBackend)
            .padding(.bottom, 16)
            SettingsGroupCard {
                StatusRow(title: "Renderer", value: rendererText, valueColor: tokens.palette.accentSecondary, monospaced: true)
                MenuRow(title: "ID policy", value: "Stable") { Button("Stable") {}; Button("Random per render") {} }
                ToggleRow(title: "Render on every keystroke", description: "auto vs manual",
                          isOn: Binding(get: { store.state.updateMode == .auto },
                                        set: { store.state.updateMode = $0 ? .auto : .manual }))
                StatusRow(title: "Worker thread", description: "8 MB stack · fresh per call", value: "on",
                          valueColor: tokens.palette.statusSuccess, dotColor: tokens.palette.statusSuccess, monospaced: true)
            }
            Spacer(minLength: 0)
        }
    }
    private var rendererText: String {
        switch store.state.renderBackend {
        case .svg: "renderSVG(_:)"; case .image: "renderImage(_:)"; case .ascii: "renderASCII(_:)"
        }
    }
}
```

- [ ] **Step 2:** build → clean. **Step 3:** commit.

---

### Task 10: `SettingsThemeTab` (§5.4 — six real appearances + diagram palette + theme builder)

**Files:** Create `Views/Settings/SettingsThemeTab.swift`
**Interfaces:** Consumes `@AppStorage(PlaygroundChromePersistence.appearanceKey)`, `PlaygroundAppearance.zedTrekFamily`, `store.setTheme(named:)`, `DiagramTheme.allThemes`, `ThemeBuilderCard(store:)`.
**Note:** subtitle uses the real family count (6), not the comp's aspirational "20".

- [ ] **Step 1: Create the file**

```swift
import SwiftUI
import DiagramKit

struct SettingsThemeTab: View {
    @Bindable var store: LiveEditorStore
    @AppStorage(PlaygroundChromePersistence.appearanceKey) private var chromeAppearanceRaw = PlaygroundAppearance.zedTrekDark.rawValue
    @State private var showThemeBuilder = false
    @Environment(\.playgroundTokens) private var tokens
    private var chromeAppearance: PlaygroundAppearance { PlaygroundAppearance(rawValue: chromeAppearanceRaw) ?? .zedTrekDark }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Theme",
                subtitle: "Zed Trek — \(PlaygroundAppearance.zedTrekFamily.count) variants. \(chromeAppearance.displayName) is active.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(PlaygroundAppearance.zedTrekFamily, id: \.self) { appearance in
                    let p = PlaygroundTokens.tokens(for: appearance).palette
                    ThemeSwatchCard(name: appearance.displayName, background: p.bgWindow,
                                    bars: [p.accent, p.catCyan, p.accentSecondary],
                                    isActive: appearance == chromeAppearance) { chromeAppearanceRaw = appearance.rawValue }
                }
            }.padding(.bottom, 18)
            SettingsGroupCard {
                MenuRow(title: "Appearance", value: "Match system") {
                    Button("Match system") {}; Button("Always dark") {}; Button("Always light") {}
                }
                MenuRow(title: "Diagram palette", value: store.state.selectedThemeName,
                        leadingSwatch: AnyView(RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [tokens.palette.fg1, tokens.palette.fg3], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 12, height: 12))) {
                    ForEach(DiagramTheme.allThemes, id: \.name) { theme in Button(theme.name) { store.setTheme(named: theme.name) } }
                }
                Button { showThemeBuilder = true } label: {
                    HStack {
                        Text("Edit theme…").font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(tokens.palette.fg3)
                    }.padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .sheet(isPresented: $showThemeBuilder) {
            ThemeBuilderCard(store: store).padding().frame(minWidth: 340, minHeight: 380)
        }
    }
}
```

- [ ] **Step 2:** build → clean (note: `DiagramTheme` requires `import DiagramKit`; `.name` is the theme property used by `ThemePicker`). **Step 3:** commit.

---

### Task 11: `SettingsPlatformParityTab` + parity matrix data (§5.5)

**Files:** Create `Models/PlatformParityMatrix.swift`, `Views/Settings/SettingsPlatformParityTab.swift`; Test `Tests/DiagramKitTests/EditorRedesign/PlatformParityMatrixTests.swift`
**Interfaces (Produces):** `PlatformParityMatrix.columns: [String]`, `PlatformParityMatrix.rows: [ParityTable.Row]`.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import DiagramKitSample

@Suite struct PlatformParityMatrixTests {
    @Test func shapeMatchesComp() {
        #expect(PlatformParityMatrix.columns == ["macOS", "iOS", "Linux"])
        #expect(PlatformParityMatrix.rows.count == 6)
        // SVG render is partial on Linux (transcription §5.5)
        let svg = PlatformParityMatrix.rows.first { $0.feature == "SVG render" }
        #expect(svg?.cells == [.full, .full, .partial])
        // Image render unsupported on Linux
        let img = PlatformParityMatrix.rows.first { $0.feature == "Image render" }
        #expect(img?.cells == [.full, .full, .unsupported])
    }
}
```

Add `Equatable` to `ParityTable.Cell` (it is a plain enum; add `: Equatable`) so the test can compare.

- [ ] **Step 2: Run — expect FAIL** (`swift test --filter PlatformParityMatrixTests`).

- [ ] **Step 3: Create `PlatformParityMatrix.swift`**

```swift
import Foundation

enum PlatformParityMatrix {
    static let columns = ["macOS", "iOS", "Linux"]
    static var rows: [ParityTable.Row] {
        [
            .init(feature: "Parse & layout", cells: [.full, .full, .full]),
            .init(feature: "SVG render", cells: [.full, .full, .partial]),
            .init(feature: "Image render", mono: "CG", cells: [.full, .full, .unsupported]),
            .init(feature: "ASCII render", cells: [.full, .full, .full]),
            .init(feature: "Interactive edit", cells: [.full, .full, .unsupported]),
            .init(feature: "Local LSP", cells: [.full, .unsupported, .unsupported]),
        ]
    }
}
```

- [ ] **Step 4: Create the tab**

```swift
import SwiftUI

struct SettingsPlatformParityTab: View {
    @Environment(\.playgroundTokens) private var tokens
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Platform Parity", subtitle: "Feature coverage across build targets.")
            ParityTable(columns: PlatformParityMatrix.columns, rows: PlatformParityMatrix.rows).padding(.bottom, 14)
            legend
            Spacer(minLength: 0)
        }
    }
    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) { Image(systemName: "checkmark").foregroundStyle(tokens.palette.statusSuccess); Text("Full") }
            HStack(spacing: 5) { Circle().fill(tokens.palette.statusWarning).frame(width: 8, height: 8); Text("Partial") }
            HStack(spacing: 5) { Text("—").foregroundStyle(tokens.palette.textFaintest); Text("Unsupported") }
            Spacer()
            Text("src_text_metrics.swift").font(PlaygroundFont.mono(11)).foregroundStyle(tokens.palette.textFaint)
        }
        .font(PlaygroundFont.sans(11)).foregroundStyle(tokens.palette.textFaint).padding(.horizontal, 2)
    }
}
```

- [ ] **Step 5: Run — expect PASS**, build, commit.

---

### Task 12: `SettingsMutationsCatalogTab` (§5.6 — from `MutationCatalog`)

**Files:** Create `Views/Settings/SettingsMutationsCatalogTab.swift`
**Interfaces:** Consumes `MutationCatalog.all`, `MutationCatalogEntry.Group`. Renders real catalog data grouped Node/Edge/Subgraph; `entry.label` is the mono API string. Human names + icons come from small local maps (comp §5.6).

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct SettingsMutationsCatalogTab: View {
    @Environment(\.playgroundTokens) private var tokens
    private let groups: [MutationCatalogEntry.Group] = [.node, .edge, .subgraph]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Mutations Catalog", subtitle: "Searchable, grouped reference.")
            ForEach(groups, id: \.self) { group in
                let entries = MutationCatalog.all.filter { $0.group == group }
                if !entries.isEmpty {
                    Text(group.label.uppercased()).font(PlaygroundFont.sans(10, weight: .bold)).tracking(0.6)
                        .foregroundStyle(color(for: group)).padding(.top, 6).padding(.bottom, 8)
                    SettingsGroupCard {
                        ForEach(entries) { entry in
                            HStack(spacing: 10) {
                                Image(systemName: icon(for: entry)).font(.system(size: 13)).foregroundStyle(color(for: group)).frame(width: 16)
                                Text(displayName(entry)).font(PlaygroundFont.sans(12.5)).foregroundStyle(tokens.palette.fg1)
                                Spacer()
                                Text(entry.label).font(PlaygroundFont.mono(11.5)).foregroundStyle(tokens.palette.catCyan)
                            }.padding(.horizontal, 14).padding(.vertical, 9)
                        }
                    }.padding(.bottom, 12)
                }
            }
            Spacer(minLength: 0)
        }
    }
    private func color(for group: MutationCatalogEntry.Group) -> Color {
        switch group { case .edge: tokens.palette.catCyan; default: tokens.palette.accentSecondary }
    }
    private func displayName(_ e: MutationCatalogEntry) -> String {
        switch e.id {
        case "insertNode": "Add node"; case "setLabel": "Edit label"; case "deleteElement": "Remove node"
        case "insertEdge": "Add edge"; case "groupIntoSubgraph": "Create / move subgraph"
        default: e.id.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    private func icon(for e: MutationCatalogEntry) -> String {
        switch e.id {
        case "insertNode", "insertEdge": "plus.circle"; case "deleteElement": "minus.circle"
        case "setLabel": "pencil"; case "groupIntoSubgraph": "square.on.square"; default: "circle"
        }
    }
}
```

- [ ] **Step 2:** build → clean. **Step 3:** commit.

---

### Task 13: `SettingsFontsTab` (§5.7)

**Files:** Create `Views/Settings/SettingsFontsTab.swift`
**Interfaces:** Consumes `DiagramFontRegistry.registeredFontNames` (import DiagramKit), `PlaygroundSettingsKeys.uiTextSize`.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI
import DiagramKit

struct SettingsFontsTab: View {
    @AppStorage(PlaygroundSettingsKeys.uiTextSize) private var uiTextSize = 13
    @Environment(\.playgroundTokens) private var tokens
    private var diagramFonts: [String] { DiagramFontRegistry.registeredFontNames }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsTabHeader(title: "Fonts", subtitle: "Bundled and system typefaces.")
            SettingsGroupCard {
                MenuRow(title: "UI font", value: "SF Pro Text") { Button("SF Pro Text") {} }
                MenuRow(title: "Mono font", description: "Web fallback: JetBrains Mono", value: "SF Mono") { Button("SF Mono") {} }
                bundledRow(title: "Diagram font", value: diagramFonts.first ?? "Noto Sans")
                bundledRow(title: "Diagram mono", value: diagramFonts.count > 1 ? diagramFonts[1] : "Noto Sans Mono", mono: true)
                StepperRow(title: "UI text size", value: $uiTextSize, range: 10...20, unit: "pt")
            }.padding(.bottom, 16)
            InfoCallout(text: "Bundled Noto fonts neutralize system-font drift — the same source renders the same glyph positions across macOS and iOS versions.")
            Spacer(minLength: 0)
        }
    }
    private func bundledRow(title: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(title).font(PlaygroundFont.body).foregroundStyle(tokens.palette.fg1)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(tokens.palette.statusSuccess)
                Text("Bundled").font(PlaygroundFont.sans(11)).foregroundStyle(tokens.palette.statusSuccess)
                Text(value).font(mono ? PlaygroundFont.mono(12) : PlaygroundFont.sans(12)).foregroundStyle(tokens.palette.fg2)
            }
        }.padding(.horizontal, 14).padding(.vertical, 12)
    }
}
```

- [ ] **Step 2:** build → clean. **Step 3:** commit.

---

### Task 14: `SettingsSheet` chrome + tab routing

**Files:** Create `Views/Settings/SettingsSheet.swift`
**Interfaces:** Consumes all seven tab views + `store.state.settingsTab` + `store.setSettingsTab` + `store.dismissSettings`. Produces `SettingsSheet(store:)` (748×520).

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct SettingsSheet: View {
    @Bindable var store: LiveEditorStore
    @State private var searchText = ""
    @Environment(\.playgroundTokens) private var tokens

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(tokens.palette.borderHairline).frame(height: 0.5)
            HStack(spacing: 0) {
                nav
                Rectangle().fill(tokens.palette.borderHairline).frame(width: 0.5)
                content
            }
        }
        .frame(width: 748, height: 520)
        .background(tokens.palette.bgSheet)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(tokens.palette.borderWarm, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.55), radius: 35, y: 30)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle().fill(tokens.palette.trafficRed).frame(width: 11, height: 11)
                .onTapGesture { store.dismissSettings() }
            Text("Settings").font(PlaygroundFont.sans(14, weight: .semibold)).foregroundStyle(tokens.palette.fg1)
            Spacer()
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(tokens.palette.textFaint)
                TextField("Search settings…", text: $searchText).textFieldStyle(.plain)
                    .font(PlaygroundFont.sans(12)).foregroundStyle(tokens.palette.fg1)
            }
            .padding(.horizontal, 10).frame(width: 180, height: 30)
            .background(tokens.palette.bgField)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tokens.palette.borderWarm, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }.padding(.horizontal, 16).frame(height: 52)
    }

    private var nav: some View {
        VStack(spacing: 2) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                SidebarNavItem(title: tab.displayName, systemImage: tab.systemImage,
                               isActive: store.state.settingsTab == tab) { store.setSettingsTab(tab) }
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 12).frame(width: 196)
        .background(tokens.palette.bgSidebarNav)
    }

    private var content: some View {
        ScrollView {
            Group {
                switch store.state.settingsTab {
                case .general: SettingsGeneralTab(store: store)
                case .editor: SettingsEditorTab(store: store)
                case .renderBackend: SettingsRenderBackendTab(store: store)
                case .theme: SettingsThemeTab(store: store)
                case .platformParity: SettingsPlatformParityTab()
                case .mutationsCatalog: SettingsMutationsCatalogTab()
                case .fonts: SettingsFontsTab()
                }
            }.padding(.horizontal, 22).padding(.vertical, 20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2:** build → clean. **Step 3:** commit.

---

### Task 15: Present the sheet in `PlaygroundShell` + wire ⌘,

**Files:** Modify `Views/Workspace/PlaygroundShell.swift` (add overlay), `DiagramKitSampleApp.swift` (⌘, command)

- [ ] **Step 1: Add the overlay** inside the top `ZStack(alignment: .bottom)` in `PlaygroundShell.body`, after the CitationOverlay line:

```swift
            // Settings sheet (redesign)
            if store.state.settingsPresented {
                ZStack {
                    tokens.palette.bgWindow.opacity(0.62)
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture { store.dismissSettings() }
                    SettingsSheet(store: store)
                }
                .transition(.opacity)
                .zIndex(10)
            }
```

Add `@Environment(\.playgroundTokens) private var tokens` to `PlaygroundShell` (it has none today), and add `.animation(.easeInOut(duration: 0.15), value: store.state.settingsPresented)` next to the existing drawer animation.

- [ ] **Step 2: Add the ⌘, command** in `DiagramKitSampleApp.swift`’s `.commands { }` block (macOS), alongside the existing groups:

```swift
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { store.presentSettings() }
                .keyboardShortcut(",", modifiers: .command)
        }
```

For iOS parity, the rail’s bottom tile (Stage 3, Task 17) also calls `store.presentSettings()`.

- [ ] **Step 3: Verify by running** — `swift run DiagramKitSample`, press ⌘, → the sheet appears over a dimmed editor; click each of the 7 nav items → content switches; ⌘, again or click the red dot / backdrop → dismiss. Screenshot the sheet on the Theme tab and confirm the six swatch cards render with LCARS Dark checked.
- [ ] **Step 4: Commit.**

<!-- APPEND-MARKER-STAGE3 -->

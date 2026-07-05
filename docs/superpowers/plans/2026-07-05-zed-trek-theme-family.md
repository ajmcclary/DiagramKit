# Zed Trek Theme Family Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the design project's "Zed Trek" family — 10 themes each in light & dark — in `DiagramKitSample`, as a theme × mode model with a matching diagram canvas, replacing the 4 legacy chrome appearances.

**Architecture:** Two new enums (`ZedTrekTheme`, `ThemeMode`) resolve to a chrome `PlaygroundPalette` (mapped from `zed-trek.json` semantic tokens), a picker `ZedTrekSpecimen` (pinned from the design preview), and a canvas `DiagramTheme`. A host view reads `@Environment(\.colorScheme)` so `.system` mode follows the OS. The old flat `PlaygroundAppearance` enum is removed last, after all consumers are migrated.

**Tech Stack:** Swift 6, SwiftUI, SwiftPM. Tests: swift-testing (`@Suite/@Test`) + XCTest. Design source of truth: `docs/superpowers/specs/2026-07-05-zed-trek-theme-family-design.md` and the `zed-trek.json` data file (§ Data Inputs).

## Global Constraints

- Package platform floor macOS 26 / iOS 26; `DiagramKitSample` is Apple-only. `Theme.swift` edits are inside its existing `#if canImport(UIKit) || canImport(AppKit)` gate.
- Chrome colors use `Color(hex: 0xRRGGBB)` (UInt32, no `#`). Canvas colors use `BMColor(hex: "#RRGGBB")` (string, with `#`). Never cross the two forms.
- Color equality in canvas/`DiagramTheme` tests uses `bmColorEquals()`, never `hexString` round-trips. Chrome tests compare SwiftUI `Color` via `==` (both built from identical `Color(hex:)`).
- `@AppStorage` stores the enum `rawValue` string; rawValue == case name and must stay stable.
- Test runs are always `swift test --filter <ExactSuiteName>` — never a bare `swift test` (full runs hang on a known signal-10). Use exact suite names, not substrings.
- File-size gate: 500-line soft warning / 1000 hard error per Swift file. Split `PlaygroundPalette+ZedTrekFamily.swift` (dark/light) if it approaches 500.
- Never introduce a thread pool on the parse/layout/render path (not relevant here, but do not add one).

## Data Inputs

- **`Scripts/zed-trek.json`** — authoritative 20-theme token file, committed to
  the repo. Re-fetchable via `DesignSync get_file themes/zed-trek.json` on project
  `50c9c2ef-8ed4-445e-870e-0273e3d082fc`. Regenerate the Swift literals with
  `Scripts/gen_zedtrek.py` (prints chrome + canvas Swift to stdout).
- **Spec §5** — chrome mapping table (`zed-trek.json` → `PlaygroundPalette`) + fallbacks.
- **Spec §6** — the 20 picker specimens, pinned verbatim (card bg / text / name / 5 accents).
- **Spec §7** — canvas mapping (`zed-trek.json` → `DiagramTheme`).

## File Structure

**New**
- `Sources/DiagramKitSample/Views/DesignSystem/ZedTrekTheme.swift` — `ZedTrekTheme` + `ThemeMode` enums (Task 1).
- `Sources/DiagramKitSample/Views/DesignSystem/ZedTrekSpecimen.swift` — `ZedTrekSpecimen` struct + 20 specimens + `ZedTrekTheme.specimen(for:)` (Task 2).
- `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundPalette+ZedTrekFamily.swift` — `fromZedTrek(...)` helper + 20 palettes + `ZedTrekTheme.palette(for:)` (Task 3).
- `Tests/DiagramKitTests/EditorRedesign/ZedTrekSpecimenTests.swift` (Task 2)
- `Tests/DiagramKitTests/EditorRedesign/ZedTrekCanvasTests.swift` (Task 4)

**Modified**
- `Sources/DiagramKitModel/Theme.swift` — 20 canvas themes; rename default list entry (Task 4).
- `Sources/DiagramKitSample/Models/LiveEditorState.swift` — `defaultThemeName` (Task 4).
- `Sources/DiagramKitSample/Views/Workspace/InspectorThemeSection.swift` — persistence keys enum + migration (Task 5), UI (Task 7).
- `Sources/DiagramKitSample/Models/PlaygroundSettingsKeys.swift` — reset coverage (Task 5).
- `Sources/DiagramKitSample/DiagramKitSampleApp.swift` (app entry) — migration call (Task 5).
- `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundTokens.swift` — `PlaygroundTokens(family:scheme:)`, remove `PlaygroundAppearance`+legacy (Tasks 6, 8).
- `Sources/DiagramKitSample/Views/DesignSystem/Environment+PlaygroundTokens.swift` — host view (Task 6), remove legacy modifier (Task 8).
- `Sources/DiagramKitSample/Views/DesignSystem/Components/SwatchTile.swift` — luminance text (Task 6).
- `Sources/DiagramKitSample/Views/DesignSystem/Components/ThemeSwatchCard.swift` — specimen card (Task 7).
- `Sources/DiagramKitSample/Views/LiveEditorView.swift` — host + canvas-follow (Task 7).
- `Sources/DiagramKitSample/Views/Settings/SettingsThemeTab.swift` — grid + mode control (Task 7).
- `Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift` — rewrite (Task 8).
- `Tests/DiagramKitTests/EditorRedesign/DefaultDiagramThemeTests.swift` — updated name (Task 4).

**Removed**
- `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundPalette+ZedTrek.swift` (Task 8).

**Compilation invariant:** Tasks 1–5 are additive (build stays green with the old path intact). Task 6 adds the new resolution path *beside* the old. Task 7 migrates all view consumers. Task 8 deletes the old enum/palettes/modifier. Build + targeted tests are green at the end of every task.

---

### Task 1: `ZedTrekTheme` + `ThemeMode` enums

**Files:**
- Create: `Sources/DiagramKitSample/Views/DesignSystem/ZedTrekTheme.swift`
- Test: `Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift` (add cases; full rewrite is Task 8)

**Interfaces:**
- Produces: `enum ZedTrekTheme: String, CaseIterable, Hashable, Codable, Sendable` cases `lcars, blackAlert, borgCube, command, federation, redAlert, yellowAlert, sickBay, missionControl, readyRoom`; `var displayName: String`; `var isStarred: Bool`. `enum ThemeMode: String, CaseIterable, Hashable, Codable, Sendable` cases `system, light, dark`; `var displayName: String`; `func scheme(system: ColorScheme) -> ColorScheme`.

- [ ] **Step 1: Write the failing test** (append to `EditorRedesignTokenTests.swift`)

```swift
@Test func zedTrekThemeRoster() {
    #expect(ZedTrekTheme.allCases.count == 10)
    #expect(ZedTrekTheme.allCases.first == .lcars)
    #expect(ZedTrekTheme.lcars.isStarred)
    #expect(!ZedTrekTheme.command.isStarred)
    #expect(ZedTrekTheme.blackAlert.displayName == "Black Alert")
    #expect(ZedTrekTheme.missionControl.displayName == "Mission Control")
}

@Test func themeModeResolution() {
    #expect(ThemeMode.system.scheme(system: .dark) == .dark)
    #expect(ThemeMode.system.scheme(system: .light) == .light)
    #expect(ThemeMode.light.scheme(system: .dark) == .light)
    #expect(ThemeMode.dark.scheme(system: .light) == .dark)
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter EditorRedesignTokenTests`
Expected: FAIL — `cannot find 'ZedTrekTheme' in scope`.

- [ ] **Step 3: Create `ZedTrekTheme.swift`**

```swift
//
//  ZedTrekTheme.swift
//  DiagramPlayground
//
//  The Zed Trek theme family (design project 50c9c2ef…): 10 named themes,
//  each resolvable in light or dark. Replaces the flat PlaygroundAppearance.
//

import SwiftUI

enum ZedTrekTheme: String, CaseIterable, Hashable, Codable, Sendable {
    case lcars, blackAlert, borgCube, command, federation
    case redAlert, yellowAlert, sickBay, missionControl, readyRoom

    var displayName: String {
        switch self {
        case .lcars:          return "LCARS"
        case .blackAlert:     return "Black Alert"
        case .borgCube:       return "Borg Cube"
        case .command:        return "Command"
        case .federation:     return "Federation"
        case .redAlert:       return "Red Alert"
        case .yellowAlert:    return "Yellow Alert"
        case .sickBay:        return "Sick Bay"
        case .missionControl: return "Mission Control"
        case .readyRoom:      return "Ready Room"
        }
    }

    /// LCARS is the flagship (★ in the design).
    var isStarred: Bool { self == .lcars }
}

enum ThemeMode: String, CaseIterable, Hashable, Codable, Sendable {
    case system, light, dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// Effective color scheme: `.system` follows the supplied OS scheme.
    func scheme(system: ColorScheme) -> ColorScheme {
        switch self {
        case .system: return system
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter EditorRedesignTokenTests`
Expected: PASS (existing cases still pass; new cases pass).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Views/DesignSystem/ZedTrekTheme.swift Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift
git commit -m "Add ZedTrekTheme + ThemeMode enums"
```

---

### Task 2: `ZedTrekSpecimen` + 20 specimens

**Files:**
- Create: `Sources/DiagramKitSample/Views/DesignSystem/ZedTrekSpecimen.swift`
- Create: `Tests/DiagramKitTests/EditorRedesign/ZedTrekSpecimenTests.swift`

**Interfaces:**
- Consumes: `ZedTrekTheme` (Task 1), `Color(hex:)` (existing, `PlaygroundTokens.swift:319`).
- Produces: `struct ZedTrekSpecimen: Equatable, Sendable { var cardBackground: Color; var textColor: Color; var nameColor: Color; var accents: [Color] }`; `func ZedTrekTheme.specimen(for scheme: ColorScheme) -> ZedTrekSpecimen`.

- [ ] **Step 1: Write the failing test** (`ZedTrekSpecimenTests.swift`)

```swift
import Testing
import SwiftUI
@testable import DiagramKitSample

@Suite struct ZedTrekSpecimenTests {
    @Test func everyFamilyModeHasFiveDistinctAccents() {
        for family in ZedTrekTheme.allCases {
            for scheme in [ColorScheme.dark, .light] {
                let s = family.specimen(for: scheme)
                #expect(s.accents.count == 5)
                #expect(s.nameColor != s.cardBackground)
                #expect(s.textColor != s.cardBackground)
            }
        }
    }

    @Test func pinnedSpecimenValues() {
        // Spec §6 anchors — LCARS dark & light, Black Alert dark.
        let lcarsDark = ZedTrekTheme.lcars.specimen(for: .dark)
        #expect(lcarsDark.cardBackground == Color(hex: 0x080A0F))
        #expect(lcarsDark.nameColor == Color(hex: 0xFFCC66))
        #expect(lcarsDark.accents.first == Color(hex: 0xFF9933))

        let lcarsLight = ZedTrekTheme.lcars.specimen(for: .light)
        #expect(lcarsLight.cardBackground == Color(hex: 0xFFFCF4))
        #expect(lcarsLight.nameColor == Color(hex: 0x8B5D1A))

        let blackDark = ZedTrekTheme.blackAlert.specimen(for: .dark)
        #expect(blackDark.nameColor == Color(hex: 0x7EC8DE))
        #expect(blackDark.accents == [0x7EC8DE, 0xC7E9F1, 0xB5A7FF, 0x4EE6A6, 0xFF9933].map { Color(hex: $0) })
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter ZedTrekSpecimenTests`
Expected: FAIL — `cannot find 'ZedTrekSpecimen'` / `specimen(for:)`.

- [ ] **Step 3: Create `ZedTrekSpecimen.swift`** — transcribe **spec §6** tables verbatim (dark + light), one `ZedTrekSpecimen` per family per scheme. Structure:

```swift
import SwiftUI

struct ZedTrekSpecimen: Equatable, Sendable {
    var cardBackground: Color
    var textColor: Color
    var nameColor: Color
    var accents: [Color]   // exactly 5

    fileprivate init(bg: UInt32, text: UInt32, name: UInt32, _ accents: [UInt32]) {
        self.cardBackground = Color(hex: bg)
        self.textColor = Color(hex: text)
        self.nameColor = Color(hex: name)
        self.accents = accents.map { Color(hex: $0) }
    }
}

extension ZedTrekTheme {
    func specimen(for scheme: ColorScheme) -> ZedTrekSpecimen {
        scheme == .dark ? Self.darkSpecimens[self]! : Self.lightSpecimens[self]!
    }

    fileprivate static let darkSpecimens: [ZedTrekTheme: ZedTrekSpecimen] = [
        .lcars:          ZedTrekSpecimen(bg: 0x080A0F, text: 0xF2E7D8, name: 0xFFCC66, [0xFF9933, 0xFFD8B0, 0xFFCC66, 0x7EC8DE, 0xCC99FF]),
        .blackAlert:     ZedTrekSpecimen(bg: 0x010204, text: 0xDFE7F1, name: 0x7EC8DE, [0x7EC8DE, 0xC7E9F1, 0xB5A7FF, 0x4EE6A6, 0xFF9933]),
        .borgCube:       ZedTrekSpecimen(bg: 0x020402, text: 0xD8F5DC, name: 0x5EFC8D, [0x5EFC8D, 0x27C267, 0x9EFFA8, 0x7EC8DE, 0xFF9933]),
        .command:        ZedTrekSpecimen(bg: 0x09090B, text: 0xD3D8DE, name: 0xFFD8B0, [0xFF9933, 0xFFD8B0, 0x7EC8DE, 0x257EA7, 0xEF5A5A]),
        .federation:     ZedTrekSpecimen(bg: 0x050911, text: 0xDBE8F2, name: 0xC7E9F1, [0x7EC8DE, 0xC7E9F1, 0xFFD8B0, 0xFF9933, 0xFF7373]),
        .redAlert:       ZedTrekSpecimen(bg: 0x0C0506, text: 0xF6D7CF, name: 0xFF8A8A, [0xEF5A5A, 0xFF9933, 0xFFD8B0, 0x7EC8DE, 0xC7E9F1]),
        .yellowAlert:    ZedTrekSpecimen(bg: 0x080602, text: 0xF3E8CF, name: 0xFFD166, [0xFFD166, 0xFF9933, 0x7EC8DE, 0xC7E9F1, 0xFF7373]),
        .sickBay:        ZedTrekSpecimen(bg: 0x050B0F, text: 0xD9F2F6, name: 0x3CCF91, [0x7EC8DE, 0xC7E9F1, 0x3CCF91, 0xFFD8B0, 0xFF7373]),
        .missionControl: ZedTrekSpecimen(bg: 0x03070D, text: 0xDCEBF6, name: 0x7EC8DE, [0x7EC8DE, 0xC7E9F1, 0xFF9933, 0xFFD8B0, 0x4EE6A6]),
        .readyRoom:      ZedTrekSpecimen(bg: 0x0B0F16, text: 0xEADFD3, name: 0xFFD8B0, [0xFFD8B0, 0x7EC8DE, 0x257EA7, 0xB87952, 0xEF5A5A]),
    ]

    fileprivate static let lightSpecimens: [ZedTrekTheme: ZedTrekSpecimen] = [
        .lcars:          ZedTrekSpecimen(bg: 0xFFFCF4, text: 0x2A1F0A, name: 0x8B5D1A, [0xC16E1D, 0xFF9933, 0xFFCC66, 0x1F8EA5, 0x8B5DBE]),
        .blackAlert:     ZedTrekSpecimen(bg: 0xFCFDFF, text: 0x1E2530, name: 0x09090B, [0x09090B, 0x257EA7, 0x7EC8DE, 0xB5A7FF, 0x4EE6A6]),
        .borgCube:       ZedTrekSpecimen(bg: 0xFBFFF9, text: 0x1D2A22, name: 0x1F6B3C, [0x2FA85B, 0x5EFC8D, 0x1F6B3C, 0x7EC8DE, 0x4A5766]),
        .command:        ZedTrekSpecimen(bg: 0xFFFFFF, text: 0x4A5766, name: 0x257EA7, [0x257EA7, 0x7EC8DE, 0xFFD8B0, 0xFF9933, 0xEF5A5A]),
        .federation:     ZedTrekSpecimen(bg: 0xFBFCFE, text: 0x1E2936, name: 0x1E3A5F, [0x1E3A5F, 0x257EA7, 0x7EC8DE, 0xFF9933, 0xFFD8B0]),
        .redAlert:       ZedTrekSpecimen(bg: 0xFFFAF8, text: 0x4A1F24, name: 0xA4333F, [0xEF5A5A, 0xFF9933, 0xFFD8B0, 0x257EA7, 0x1E3A5F]),
        .yellowAlert:    ZedTrekSpecimen(bg: 0xFFFDF7, text: 0x2E2A21, name: 0x8A5300, [0xFFD166, 0xFF9933, 0x1E3A5F, 0x257EA7, 0xEF5A5A]),
        .sickBay:        ZedTrekSpecimen(bg: 0xFBFEFF, text: 0x263943, name: 0x1E3A5F, [0x7EC8DE, 0x257EA7, 0x3CCF91, 0xFFD8B0, 0xEF5A5A]),
        .missionControl: ZedTrekSpecimen(bg: 0xFBFDFF, text: 0x223142, name: 0x1E3A5F, [0x1E3A5F, 0x257EA7, 0x7EC8DE, 0xFF9933, 0x4EE6A6]),
        .readyRoom:      ZedTrekSpecimen(bg: 0xFFFAF3, text: 0x2F343B, name: 0x1E3A5F, [0x1E3A5F, 0x257EA7, 0x7EC8DE, 0xFFD8B0, 0x9B5F42]),
    ]
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `swift test --filter ZedTrekSpecimenTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Views/DesignSystem/ZedTrekSpecimen.swift Tests/DiagramKitTests/EditorRedesign/ZedTrekSpecimenTests.swift
git commit -m "Add ZedTrekSpecimen (20 picker specimens from design preview)"
```

---

### Task 3: 20 chrome palettes (`PlaygroundPalette+ZedTrekFamily.swift`)

**Files:**
- Create: `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundPalette+ZedTrekFamily.swift`
- Test: `Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift` (add palette completeness + pinned checks)

**Interfaces:**
- Consumes: `ZedTrekTheme` (Task 1), `PlaygroundPalette` (existing), `Color(hex:)`.
- Produces: `static func PlaygroundPalette.fromZedTrek(...)` (full-field builder); `func ZedTrekTheme.palette(for scheme: ColorScheme) -> PlaygroundPalette`.

**Generation method (deterministic port):** For each of the 20 themes, read its `style` object from `zed-trek.json` (§ Data Inputs) and apply the **spec §5** mapping + fallbacks to fill `fromZedTrek(...)`'s arguments. This is mechanical; during execution, generate the 20 calls with a workflow that reads the JSON and applies §5, then **adversarially verify** each emitted value against the JSON before writing. Do not hand-guess hexes.

- [ ] **Step 1: Write the failing test** (append to `EditorRedesignTokenTests.swift`)

```swift
@Test func everyFamilyModeResolvesCompletePalette() {
    for family in ZedTrekTheme.allCases {
        for scheme in [ColorScheme.dark, .light] {
            let p = family.palette(for: scheme)
            #expect(p.accent != p.bgWindow)
            #expect(p.onAccent != p.accent)
            #expect(p.bgCard != p.accent)
            #expect(p.fg1 != p.bgApp)
        }
    }
}

@Test func pinnedChromePaletteValues() {
    // LCARS dark keeps the comp-exact values (spec §5, existing zedTrekDark).
    let lcarsDark = ZedTrekTheme.lcars.palette(for: .dark)
    #expect(lcarsDark.bgWindow == Color(hex: 0x05060A))
    #expect(lcarsDark.accent == Color(hex: 0xFF9933))
    #expect(lcarsDark.fg1 == Color(hex: 0xF2E7D8))

    // Black Alert dark — mapped from zed-trek.json (spec §5).
    let blackDark = ZedTrekTheme.blackAlert.palette(for: .dark)
    #expect(blackDark.bgApp == Color(hex: 0x020204))      // background
    #expect(blackDark.bgField == Color(hex: 0x010204))    // editor.background
    #expect(blackDark.accent == Color(hex: 0x7EC8DE))     // border.focused
    #expect(blackDark.fg1 == Color(hex: 0xDFE7F1))        // text
    #expect(blackDark.statusError == Color(hex: 0xFF7373))// error
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter EditorRedesignTokenTests`
Expected: FAIL — `cannot find 'palette(for:)'`.

- [ ] **Step 3: Add the `fromZedTrek` helper** to the new file

```swift
import SwiftUI

extension PlaygroundPalette {
    /// Relative luminance (sRGB, no gamma) — good enough to pick on-accent text.
    fileprivate static func luminance(_ hex: UInt32) -> Double {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Build a complete chrome palette from mapped zed-trek.json tokens (spec §5).
    static func fromZedTrek(
        background: UInt32, editorBg: UInt32, panelBg: UInt32, elevatedBg: UInt32,
        titleBg: UInt32, elementBg: UInt32,
        text: UInt32, textMuted: UInt32, textPlaceholder: UInt32, textDisabled: UInt32,
        lineNumber: UInt32,
        accent: UInt32, accentSecondary: UInt32, accentPeach: UInt32,
        info: UInt32, success: UInt32, warning: UInt32, error: UInt32, renamed: UInt32,
        border: UInt32, borderVariant: UInt32, paneGroupBorder: UInt32, errorBorder: UInt32
    ) -> PlaygroundPalette {
        let onAccent: UInt32 = luminance(accent) < 0.55 ? 0xFFFFFF : 0x100A02
        return PlaygroundPalette(
            bgApp: Color(hex: background),
            bgSurface: Color(hex: panelBg),
            bgElevated: Color(hex: elevatedBg),
            bgSunken: Color(hex: editorBg),
            fg1: Color(hex: text), fg2: Color(hex: textMuted), fg3: Color(hex: textPlaceholder),
            accent: Color(hex: accent),
            borderHairline: Color(hex: borderVariant),
            borderSubtle: Color(hex: border),
            borderStrong: Color(hex: paneGroupBorder),
            statusSuccess: Color(hex: success), statusWarning: Color(hex: warning),
            statusError: Color(hex: error), statusInfo: Color(hex: info),
            rowHover: Color(hex: accent).opacity(0.08),
            rowSelected: Color(hex: accent).opacity(0.16),
            glassBg: Color(hex: titleBg).opacity(0.90),
            bgWindow: Color(hex: background), bgRail: Color(hex: background),
            bgPanel: Color(hex: panelBg), bgSheet: Color(hex: elevatedBg),
            bgSidebarNav: Color(hex: panelBg), bgChrome: Color(hex: titleBg),
            bgCard: Color(hex: elevatedBg), bgTrack: Color(hex: elementBg),
            bgField: Color(hex: editorBg),
            borderWarm: Color(hex: border), borderFaint: Color(hex: borderVariant),
            borderSwatch: Color(hex: paneGroupBorder),
            borderDestructive: Color(hex: errorBorder),
            textFaint: Color(hex: textDisabled), gutter: Color(hex: lineNumber),
            textFaintest: Color(hex: textDisabled),
            onAccent: Color(hex: onAccent),
            accentSecondary: Color(hex: accentSecondary), accentPeach: Color(hex: accentPeach),
            catCyan: Color(hex: info), catMint: Color(hex: success), catPurple: Color(hex: renamed)
        )
    }
}
```

> Note: `bgWindow`/`bgApp` for LCARS dark must be `0x05060A` (comp value, per the existing `zedTrekDark` preset + `lcarsDarkIsTheDefault` test), even though the specimen card bg is `0x080A0F`. Keep LCARS dark's mapped `background`/`editorBg` at the comp values `0x05060A` / `0x080A0F` respectively (spec §5 note). Verify against `PlaygroundPalette.zedTrekDark` before it is removed in Task 8.

- [ ] **Step 4: Generate the 20 palettes + dispatch** — add `palette(for:)` and the two dictionaries. Fill each `fromZedTrek(...)` from the JSON per §5. Example (Black Alert Dark, fully worked from the JSON):

```swift
extension ZedTrekTheme {
    func palette(for scheme: ColorScheme) -> PlaygroundPalette {
        scheme == .dark ? Self.darkPalettes[self]! : Self.lightPalettes[self]!
    }

    fileprivate static let darkPalettes: [ZedTrekTheme: PlaygroundPalette] = [
        .blackAlert: .fromZedTrek(
            background: 0x020204, editorBg: 0x010204, panelBg: 0x080B12, elevatedBg: 0x10121C,
            titleBg: 0x080B12, elementBg: 0x10121C,
            text: 0xDFE7F1, textMuted: 0x8B99AB, textPlaceholder: 0x68778C, textDisabled: 0x4F5D70,
            lineNumber: 0x5D6B7F,
            accent: 0x7EC8DE, accentSecondary: 0xC7E9F1, accentPeach: 0xC7E9F1,
            info: 0x7EC8DE, success: 0x4EE6A6, warning: 0xFF9933, error: 0xFF7373, renamed: 0xB5A7FF,
            border: 0x1A2232, borderVariant: 0x121826, paneGroupBorder: 0x121826, errorBorder: 0xEF5A5A),
        // … the other 9 dark families, each mapped from zed-trek.json per spec §5 …
    ]

    fileprivate static let lightPalettes: [ZedTrekTheme: PlaygroundPalette] = [
        // … 10 light families, mapped from zed-trek.json per spec §5 …
    ]
}
```

Generate all 20 entries this way. For LCARS, `accentSecondary` = specimen `accents[1]`, `accentPeach` = `0xFFD8B0` if present in the specimen else `accentSecondary` (spec §5). Split this file into `+ZedTrekFamily.swift` (dark) and a second file if it nears 500 lines.

- [ ] **Step 5: Verify each value against the JSON** — during execution, run a verification pass (workflow agents) that re-reads `zed-trek.json` and confirms each emitted hex equals the mapped source token (or its declared fallback). Fix any drift.

- [ ] **Step 6: Run to verify it passes**

Run: `swift test --filter EditorRedesignTokenTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitSample/Views/DesignSystem/PlaygroundPalette+ZedTrekFamily.swift Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift
git commit -m "Add 20 Zed Trek chrome palettes mapped from zed-trek.json"
```

---

### Task 4: 20 canvas `DiagramTheme`s + default rename

**Files:**
- Modify: `Sources/DiagramKitModel/Theme.swift:319-356` (add themes; rename list entry)
- Modify: `Sources/DiagramKitSample/Models/LiveEditorState.swift:318`
- Create: `Tests/DiagramKitTests/EditorRedesign/ZedTrekCanvasTests.swift`
- Modify: `Tests/DiagramKitTests/EditorRedesign/DefaultDiagramThemeTests.swift`

**Interfaces:**
- Produces: 20 `static let` `DiagramTheme` presets (e.g. `zedTrekLCARSDark`/`…Light`, `zedTrekBlackAlertDark`, …) and 20 `(name, theme)` rows in `allThemes` (`"LCARS Dark"`, `"LCARS Light"`, `"Black Alert Dark"`, …). `LiveEditorState.defaultThemeName == "LCARS Dark"`.

- [ ] **Step 1: Write the failing test** (`ZedTrekCanvasTests.swift`)

```swift
import Testing
@testable import DiagramKit
@testable import DiagramKitModel
@testable import DiagramKitSample

@Suite struct ZedTrekCanvasTests {
    private static let families = [
        "LCARS", "Black Alert", "Borg Cube", "Command", "Federation",
        "Red Alert", "Yellow Alert", "Sick Bay", "Mission Control", "Ready Room",
    ]

    @Test func everyFamilyModeHasCanvasTheme() {
        for family in Self.families {
            for mode in ["Dark", "Light"] {
                #expect(DiagramTheme.theme(named: "\(family) \(mode)") != nil,
                        "missing canvas theme for \(family) \(mode)")
            }
        }
    }

    @Test func lcarsDarkIsZedTrekDark() {
        #expect(DiagramTheme.theme(named: "LCARS Dark") == DiagramTheme.zedTrekDark)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter ZedTrekCanvasTests`
Expected: FAIL — themes not found.

- [ ] **Step 3: Add 20 canvas presets to `Theme.swift`** (inside the existing `extension DiagramTheme`, Apple-gated). Map each from `zed-trek.json` per **spec §7**. `zedTrekLCARSDark` reuses the existing `zedTrekDark` value. Example shape (LCARS + Black Alert; generate all 20 from the JSON):

```swift
public static let zedTrekLCARSDark = zedTrekDark   // unchanged colors
public static let zedTrekLCARSLight = DiagramTheme(
    background: BMColor(hex: "#FFFCF4"), foreground: BMColor(hex: "#2A1F0A"),
    line: /* editor.indent_guide */ BMColor(hex: "#E4D8C4"),
    accent: BMColor(hex: "#C16E1D"), muted: BMColor(hex: "#6B5D48"),
    surface: BMColor(hex: "#FFFFFF"), border: BMColor(hex: "#D8CBB6"),
    noteBkg: BMColor(hex: "#F3ECE1"), noteBorder: BMColor(hex: "#E3D9C7"),
    lineWidth: 1, cornerRadius: 8)
public static let zedTrekBlackAlertDark = DiagramTheme(
    background: BMColor(hex: "#010204"), foreground: BMColor(hex: "#DFE7F1"),
    line: BMColor(hex: "#121826"), accent: BMColor(hex: "#7EC8DE"),
    muted: BMColor(hex: "#8B99AB"), surface: BMColor(hex: "#10121C"),
    border: BMColor(hex: "#1A2232"), noteBkg: BMColor(hex: "#07090F"),
    noteBorder: BMColor(hex: "#121826"), lineWidth: 1, cornerRadius: 8)
// … remaining 17 canvas presets, mapped from zed-trek.json per spec §7 …
```

- [ ] **Step 4: Update `allThemes`** — replace the `("Zed Trek Dark", zedTrekDark)` row and append the family set:

```swift
("Zinc Light", zincLight), /* … existing 16 non-Zed rows unchanged … */
("LCARS Dark", zedTrekLCARSDark), ("LCARS Light", zedTrekLCARSLight),
("Black Alert Dark", zedTrekBlackAlertDark), ("Black Alert Light", zedTrekBlackAlertLight),
("Borg Cube Dark", zedTrekBorgCubeDark), ("Borg Cube Light", zedTrekBorgCubeLight),
("Command Dark", zedTrekCommandDark), ("Command Light", zedTrekCommandLight),
("Federation Dark", zedTrekFederationDark), ("Federation Light", zedTrekFederationLight),
("Red Alert Dark", zedTrekRedAlertDark), ("Red Alert Light", zedTrekRedAlertLight),
("Yellow Alert Dark", zedTrekYellowAlertDark), ("Yellow Alert Light", zedTrekYellowAlertLight),
("Sick Bay Dark", zedTrekSickBayDark), ("Sick Bay Light", zedTrekSickBayLight),
("Mission Control Dark", zedTrekMissionControlDark), ("Mission Control Light", zedTrekMissionControlLight),
("Ready Room Dark", zedTrekReadyRoomDark), ("Ready Room Light", zedTrekReadyRoomLight),
```

- [ ] **Step 5: Update default name + test**

`LiveEditorState.swift:318`: `public static let defaultThemeName = "LCARS Dark"`.
`DefaultDiagramThemeTests.swift`: keep `resolved == DiagramTheme.zedTrekDark`; the name is now resolved from `"LCARS Dark"` — no assertion text change needed beyond confirming it still passes.

- [ ] **Step 6: Run to verify it passes**

Run: `swift test --filter ZedTrekCanvasTests` then `swift test --filter DefaultDiagramThemeTests` then `swift test --filter PalettePinTests`
Expected: all PASS (PalettePinTests now renders the 20 new themes too).

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitModel/Theme.swift Sources/DiagramKitSample/Models/LiveEditorState.swift Tests/DiagramKitTests/EditorRedesign/ZedTrekCanvasTests.swift
git commit -m "Add 20 Zed Trek canvas themes; default → LCARS Dark"
```

---

### Task 5: Persistence keys + legacy migration

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Workspace/InspectorThemeSection.swift:127-129` (extend `PlaygroundChromePersistence`)
- Modify: `Sources/DiagramKitSample/Models/PlaygroundSettingsKeys.swift:22-30`
- Modify: app entry `Sources/DiagramKitSample/DiagramKitSampleApp.swift` (confirm exact filename during execution)
- Test: `Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift` (migration table)

**Interfaces:**
- Produces: `PlaygroundChromePersistence.themeKey`/`.modeKey`/`.canvasFollowsKey`; `static func migratedSelection(fromLegacy: String?) -> (theme: ZedTrekTheme, mode: ThemeMode)`; `static func migrateLegacyIfNeeded(defaults: UserDefaults = .standard)`.

- [ ] **Step 1: Write the failing test** (append to `EditorRedesignTokenTests.swift`)

```swift
@Test func legacyMigrationTable() {
    typealias P = PlaygroundChromePersistence
    #expect(P.migratedSelection(fromLegacy: "zedTrekDark") == (.lcars, .dark))
    #expect(P.migratedSelection(fromLegacy: "zedTrekLight") == (.lcars, .light))
    #expect(P.migratedSelection(fromLegacy: "federation") == (.federation, .dark))
    #expect(P.migratedSelection(fromLegacy: "redAlert") == (.redAlert, .dark))
    #expect(P.migratedSelection(fromLegacy: "sickBay") == (.sickBay, .dark))
    #expect(P.migratedSelection(fromLegacy: "borgCube") == (.borgCube, .dark))
    #expect(P.migratedSelection(fromLegacy: "light") == (.lcars, .light))
    #expect(P.migratedSelection(fromLegacy: "forest") == (.lcars, .dark))
    #expect(P.migratedSelection(fromLegacy: nil) == (.lcars, .dark))
    #expect(P.migratedSelection(fromLegacy: "garbage") == (.lcars, .dark))
}
```

(Requires `ZedTrekTheme`/`ThemeMode` to be `Equatable` — they are via `Hashable`. Tuple equality of two `Equatable`s compiles.)

- [ ] **Step 2: Run to verify it fails**

Run: `swift test --filter EditorRedesignTokenTests`
Expected: FAIL — `migratedSelection` not found.

- [ ] **Step 3: Extend `PlaygroundChromePersistence`** (in `InspectorThemeSection.swift`)

```swift
enum PlaygroundChromePersistence {
    static let appearanceKey = "playground.chromeAppearance"     // legacy (migration source)
    static let themeKey = "playground.zedTrekTheme"
    static let modeKey = "playground.themeMode"
    static let canvasFollowsKey = "playground.canvasFollowsAppTheme"

    static func migratedSelection(fromLegacy raw: String?) -> (theme: ZedTrekTheme, mode: ThemeMode) {
        switch raw {
        case "zedTrekDark", "dark", "forest": return (.lcars, .dark)
        case "zedTrekLight", "light", "neutral": return (.lcars, .light)
        case "federation": return (.federation, .dark)
        case "redAlert":   return (.redAlert, .dark)
        case "sickBay":    return (.sickBay, .dark)
        case "borgCube":   return (.borgCube, .dark)
        default:           return (.lcars, .dark)
        }
    }

    @MainActor static func migrateLegacyIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: themeKey) == nil,
              let legacy = defaults.string(forKey: appearanceKey) else { return }
        let (theme, mode) = migratedSelection(fromLegacy: legacy)
        defaults.set(theme.rawValue, forKey: themeKey)
        defaults.set(mode.rawValue, forKey: modeKey)
    }
}
```

- [ ] **Step 4: Cover in Reset** (`PlaygroundSettingsKeys.swift`) — append to `all`:

```swift
static let all = [
    confirmBeforeDelete, sendAnonymousDiagnostics, restoreLastDocument,
    showConnectionHandles, gridSize, keyboardNudge, defaultNodeShape,
    defaultEdgeStyle, uiTextSize,
    PlaygroundChromePersistence.themeKey,
    PlaygroundChromePersistence.modeKey,
    PlaygroundChromePersistence.canvasFollowsKey,
    PlaygroundChromePersistence.appearanceKey,
]
```

- [ ] **Step 5: Call migration at launch** — in the app entry's `init()` (locate the `@main struct …App`), add `PlaygroundChromePersistence.migrateLegacyIfNeeded()`.

- [ ] **Step 6: Run to verify it passes**

Run: `swift test --filter EditorRedesignTokenTests`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitSample/Views/Workspace/InspectorThemeSection.swift Sources/DiagramKitSample/Models/PlaygroundSettingsKeys.swift Sources/DiagramKitSample/DiagramKitSampleApp.swift Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift
git commit -m "Add theme/mode persistence keys + legacy appearance migration"
```

---

### Task 6: `PlaygroundTokens(family:scheme:)` + host view (new path, old kept)

**Files:**
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundTokens.swift` (add init; keep `PlaygroundAppearance` for now)
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/Environment+PlaygroundTokens.swift` (add `PlaygroundThemeHost` + modifier)
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/Components/SwatchTile.swift` (luminance text)

**Interfaces:**
- Produces: `init PlaygroundTokens(family: ZedTrekTheme, scheme: ColorScheme)`; `struct PlaygroundThemeHost<Content>`; `func View.playgroundTheme(family:mode:onEffectiveScheme:) -> some View`. `PlaygroundTokens` gains `var family: ZedTrekTheme` and `var scheme: ColorScheme` (replacing reliance on `appearance` for scheme; keep `appearance` field temporarily defaulted for the legacy path).

- [ ] **Step 1: Add the token initializer** (`PlaygroundTokens.swift`). Add stored `family`/`scheme` and a convenience init; keep the existing `appearance`-based statics compiling.

```swift
extension PlaygroundTokens {
    init(family: ZedTrekTheme, scheme: ColorScheme) {
        self.init(appearance: .zedTrekDark, palette: family.palette(for: scheme))
        // `appearance` retained only for the legacy path removed in Task 8.
    }
}
```

- [ ] **Step 2: Add host view** (`Environment+PlaygroundTokens.swift`)

```swift
struct PlaygroundThemeHost<Content: View>: View {
    let family: ZedTrekTheme
    let mode: ThemeMode
    var onEffectiveScheme: (ColorScheme) -> Void = { _ in }
    @Environment(\.colorScheme) private var systemScheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        let effective = mode.scheme(system: systemScheme)
        content()
            .environment(\.playgroundTokens, PlaygroundTokens(family: family, scheme: effective))
            .preferredColorScheme(mode == .system ? nil : effective)
            .onChange(of: effective, initial: true) { _, s in onEffectiveScheme(s) }
    }
}

extension View {
    func playgroundTheme(family: ZedTrekTheme, mode: ThemeMode,
                         onEffectiveScheme: @escaping (ColorScheme) -> Void = { _ in }) -> some View {
        PlaygroundThemeHost(family: family, mode: mode, onEffectiveScheme: onEffectiveScheme) { self }
    }
}
```

- [ ] **Step 3: Fix `SwatchTile.textColor(on:)`** to not depend on the (soon-removed) `tokens.appearance`:

```swift
private func textColor(on background: Color) -> Color {
    #if canImport(UIKit)
    let ui = UIColor(background); var w: CGFloat = 0
    ui.getWhite(&w, alpha: nil)
    return w < 0.6 ? .white.opacity(0.9) : .black.opacity(0.85)
    #elseif canImport(AppKit)
    let ns = NSColor(background).usingColorSpace(.deviceRGB)
    let l = ns.map { 0.2126*$0.redComponent + 0.7152*$0.greenComponent + 0.0722*$0.blueComponent } ?? 0
    return l < 0.6 ? .white.opacity(0.9) : .black.opacity(0.85)
    #else
    return .white.opacity(0.9)
    #endif
}
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: builds (old `.playgroundAppearance` path and new `.playgroundTheme` path both present).

- [ ] **Step 5: Run token tests**

Run: `swift test --filter EditorRedesignTokenTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Views/DesignSystem/PlaygroundTokens.swift Sources/DiagramKitSample/Views/DesignSystem/Environment+PlaygroundTokens.swift Sources/DiagramKitSample/Views/DesignSystem/Components/SwatchTile.swift
git commit -m "Add PlaygroundTokens(family:scheme:) + PlaygroundThemeHost (system-follow)"
```

---

### Task 7: Migrate view consumers to theme × mode

**Files:**
- Modify: `Sources/DiagramKitSample/Views/LiveEditorView.swift:20-83`
- Modify: `Sources/DiagramKitSample/Views/Settings/SettingsThemeTab.swift`
- Modify: `Sources/DiagramKitSample/Views/Workspace/InspectorThemeSection.swift:17-62`
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/Components/ThemeSwatchCard.swift`

**Interfaces:**
- Consumes: `ZedTrekTheme`, `ThemeMode`, `PlaygroundChromePersistence.{themeKey,modeKey,canvasFollowsKey}`, `playgroundTheme(family:mode:onEffectiveScheme:)`, `ZedTrekTheme.specimen(for:)`, `LiveEditorStore.syncCanvasToApp(...)` (add small helper).
- Produces: fully theme×mode-driven pickers; `ThemeSwatchCard` rendered from a `ZedTrekSpecimen`.

- [ ] **Step 1: Rework `ThemeSwatchCard`** to a specimen card matching the design images — card bg = specimen bg, title in `specimen.nameColor` (★ for LCARS), a row of 5 accent swatches, and a `let n = 42` mono line. Signature:

```swift
struct ThemeSwatchCard: View {
    let title: String
    let specimen: ZedTrekSpecimen
    let isStarred: Bool
    let isActive: Bool
    let action: () -> Void
    // body: rounded card, bg = specimen.cardBackground, name in specimen.nameColor,
    //       HStack of 5 RoundedRectangles filled from specimen.accents,
    //       Text("let n = 42") in PlaygroundFont.mono over specimen.textColor,
    //       active → accent ring + checkmark. (Full body written during execution.)
}
```

- [ ] **Step 2: Rewrite `SettingsThemeTab`** — read `themeKey`/`modeKey`; 10-card `LazyVGrid` over `ZedTrekTheme.allCases` using `family.specimen(for: mode.scheme(system:))`; a `Picker("Appearance", selection: mode).pickerStyle(.segmented)` (System/Light/Dark); wire the "Match app theme" toggle to `canvasFollowsKey`. Keep the diagram-palette `MenuRow` + theme-builder.

- [ ] **Step 3: Rewrite `InspectorThemeSection.chromeTiles`** — `SwatchTile` over `ZedTrekTheme.allCases` (specimen-driven) + a compact mode control; keep the diagram-palette/theme-builder disclosures; add the "Match app theme" toggle.

- [ ] **Step 4: Rewrite `LiveEditorView`** theming — replace `chromeAppearanceRaw` with `@AppStorage(themeKey) family` + `@AppStorage(modeKey) mode`; apply `.playgroundTheme(family:mode:) { effectiveScheme in if canvasFollows { store.syncCanvasToApp(family: family, scheme: effectiveScheme) } }`; paint macOS toolbar from `PlaygroundTokens(family:scheme:).palette.bgApp`. Add to `LiveEditorStore`:

```swift
public func syncCanvasToApp(family: ZedTrekTheme, scheme: ColorScheme) {
    let name = "\(family.displayName) \(scheme == .dark ? "Dark" : "Light")"
    setTheme(named: name)
}
```

- [ ] **Step 5: Build + smoke tests**

Run: `swift build`
Expected: builds. (Nothing app-facing should reference `PlaygroundAppearance` now except the legacy statics still in `PlaygroundTokens.swift` and the not-yet-rewritten `EditorRedesignTokenTests` — both removed in Task 8.)

Run: `swift test --filter EditorRedesignTokenTests` and `swift test --filter SettingsStateTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Views/LiveEditorView.swift Sources/DiagramKitSample/Views/Settings/SettingsThemeTab.swift Sources/DiagramKitSample/Views/Workspace/InspectorThemeSection.swift Sources/DiagramKitSample/Views/DesignSystem/Components/ThemeSwatchCard.swift Sources/DiagramKitSample/Models/LiveEditorStore.swift
git commit -m "Wire pickers + canvas-follow to theme × mode model"
```

---

### Task 8: Remove legacy `PlaygroundAppearance`; rewrite token tests

**Files:**
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundTokens.swift` (remove `PlaygroundAppearance` enum + 4 legacy palette statics + `tokens(for:)` + `appearance` field)
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/Environment+PlaygroundTokens.swift` (remove `playgroundTokens(_:)`/`playgroundAppearance(_:)`; default = `PlaygroundTokens(family: .lcars, scheme: .dark)`)
- Delete: `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundPalette+ZedTrek.swift`
- Rewrite: `Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift`

**Interfaces:**
- `PlaygroundTokens` loses `appearance`; the `init(family:scheme:)` becomes the sole/primary init (`palette` stored). `PlaygroundTokensKey.defaultValue = PlaygroundTokens(family: .lcars, scheme: .dark)`.

- [ ] **Step 1: Delete the legacy palette file + statics** — remove `PlaygroundPalette+ZedTrek.swift`; delete `PlaygroundPalette.{dark,light,forest,neutral}` and `legacyRedesignFields()`/`recolored()` if now unused (grep first); delete `PlaygroundAppearance`, the 8 `PlaygroundTokens` statics, and `tokens(for:)`. Simplify `PlaygroundTokens` to `struct { var palette: PlaygroundPalette }` + `init(family:scheme:)`.

- [ ] **Step 2: Preserve the LCARS-dark pin** — before deleting `PlaygroundPalette.zedTrekDark`, confirm `ZedTrekTheme.lcars.palette(for: .dark)` equals its `accent 0xFF9933`, `bgWindow 0x05060A`, `bgSheet 0x0E1421`, `fg1 0xF2E7D8` (the removed `lcarsDarkIsTheDefault` assertions, re-homed in Step 4).

- [ ] **Step 3: Update the environment default**

```swift
struct PlaygroundTokensKey: EnvironmentKey {
    static let defaultValue = PlaygroundTokens(family: .lcars, scheme: .dark)
}
```

- [ ] **Step 4: Rewrite `EditorRedesignTokenTests`** — drop `PlaygroundAppearance`-based cases; keep `zedTrekThemeRoster`, `themeModeResolution`, `everyFamilyModeResolvesCompletePalette`, `pinnedChromePaletteValues`, `legacyMigrationTable`; add:

```swift
@Test func lcarsDarkIsTheDefault() {
    let p = PlaygroundTokensKey.defaultValue.palette
    #expect(p.accent == Color(hex: 0xFF9933))
    #expect(p.bgWindow == Color(hex: 0x05060A))
    #expect(p.bgSheet == Color(hex: 0x0E1421))
    #expect(p.fg1 == Color(hex: 0xF2E7D8))
}
```

- [ ] **Step 5: Build + full targeted test sweep**

Run: `swift build`
Expected: builds; no reference to `PlaygroundAppearance` remains (`rg PlaygroundAppearance Sources Tests` → empty).

Run: `swift test --filter EditorRedesignTokenTests`, `--filter ZedTrekSpecimenTests`, `--filter ZedTrekCanvasTests`, `--filter DefaultDiagramThemeTests`, `--filter PalettePinTests`, `--filter SettingsStateTests`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Remove legacy PlaygroundAppearance; LCARS dark is the sole default"
```

---

### Task 9: End-to-end verification

**Files:** none (verification only).

- [ ] **Step 1: Discipline gates** (that apply to this change)

Run: `Scripts/check-file-sizes.sh`
Expected: no new file over 1000 lines; if `PlaygroundPalette+ZedTrekFamily.swift` warns near 500, split dark/light. `Scripts/check-sendable-annotations.sh` and `Scripts/check-diagnostic-discipline.sh` should be unaffected — run them to confirm.

- [ ] **Step 2: Run the app + compare to the design images**

Run: `swift run DiagramKitSample`
Verify: Settings ▸ Theme shows 10 cards matching the design (name in signature color, 5 swatches, `let n = 42`); switching family recolors chrome; Light/Dark/System works and `.system` follows OS appearance; the diagram canvas recolors with the theme when "Match app theme" is on. Capture while frontmost (per sample-screenshot caveats).

- [ ] **Step 3: Final commit if any split/tweak was needed**

```bash
git add -A && git commit -m "Zed Trek theme family: file-size split + polish"
```

## Self-Review Notes

- **Spec coverage:** §3 → T1; §6 → T2; §5 → T3; §2/§4 → T6/T8; §7 → T4; §8 → T7; §9 → T5; §10 → T7; §11 → T1/T2/T3/T4/T5/T8; §12/§13 → T9.
- **Compilation invariant** stated per task; legacy removal deferred to T8.
- **Type consistency:** `palette(for:)`, `specimen(for:)`, `PlaygroundTokens(family:scheme:)`, `playgroundTheme(family:mode:onEffectiveScheme:)`, `migratedSelection(fromLegacy:)`, `syncCanvasToApp(family:scheme:)` are used consistently across tasks.
- **Data tasks (T3, T4):** values are ported from `zed-trek.json` via the spec §5/§7 rules and verified against the JSON — not hand-guessed; the plan carries fully-worked examples (Black Alert dark chrome, LCARS/Black Alert canvas) plus the helper, and the exact JSON location.

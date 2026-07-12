# DiagramKitSample Design-System Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every DiagramKitSample application-chrome surface consume a generated semantic design-system adapter, satisfy the approved accessibility and interaction contract, and pass enforceable design-adherence and merge gates.

**Architecture:** Two committed JSON inputs generate a standalone `DiagramKitSampleDesignSystem` SwiftPM target containing semantic tokens, themes, and icons. Handwritten SwiftUI primitives resolve platform and accessibility environment state; the sample migrates directory-by-directory behind a temporary compatibility adapter, then deletes the old `Playground*` layer after a zero-violation source audit.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit/UIKit adapters, SwiftPM, Python 3 deterministic generation, swift-testing, SnapshotTesting, existing Zed Trek JSON, repository governance scripts.

## Global Constraints

- Preserve the package floor: macOS 26.0 and iOS 26.0.
- Do not add a `CodeEditorPlugin` dependency in this cycle.
- Do not modify the separate `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin` checkout.
- Do not change DiagramKit parser, layout, renderer, importer, exporter, or public engine behavior.
- Keep `DiagramTheme` restricted to diagram/editor content; all application chrome uses `DSTheme`.
- Keep `DiagramFontRegistry.registerBundledFontsIfNeeded()` first in every existing pipeline method.
- Never introduce a thread pool.
- Use `bmColorEquals()` for diagram-color comparisons.
- Use native `NavigationSplitView`, `.inspector`, `.sheet`, `.popover`, `Toggle`, focus, and accessibility semantics.
- Do not re-record diagram snapshots unless a separately identified intentional rendering change requires it.
- Every production behavior change follows red-green-refactor.
- Existing user changes are preserved; commits stage only files belonging to the current task.

---

## File structure

```text
Scripts/
  codeeditor-design-system-contract.json       # normalized committed input
  gen_codeeditor_design_system.py              # deterministic generator/checker
  check_codeeditor_design_system.sh            # generated-output gate
  check-sample-design-adherence.sh              # source-pattern gate
Sources/DiagramKitSampleDesignSystem/
  Generated/
    DSContract.generated.swift                  # scalar tokens and control metrics
    DSThemes.generated.swift                    # 20 variants and semantic roles
    DSIcons.generated.swift                     # semantic icon-to-SF-Symbol mapping
  DSAccessibility.swift                        # preference resolution
  DSThemeEnvironment.swift                     # SwiftUI environment host
  DSTypography.swift                            # semantic, platform-aware font roles
  DSButtonStyle.swift                           # button roles and states
  DSToggleStyle.swift                           # native ToggleStyle
  DSControls.swift                              # segment, chip, field, icon button
  DSRows.swift                                  # settings/status/header/code badge
  DSSurface.swift                               # flat surfaces and role-based glass
Sources/DiagramKitSample/Views/DesignSystem/
  PlaygroundCompatibility.swift                # temporary aliases; deleted in Task 14
Tests/DiagramKitTests/DesignSystem/
  DSGenerationTests.swift
  DSThemeTests.swift
  DSContrastTests.swift
  DSAccessibilityTests.swift
  DSPrimitiveTests.swift
  DSSnapshotTests.swift
```

---

### Task 1: Normalize the committed design-system contract

**Files:**
- Create: `Scripts/codeeditor-design-system-contract.json`
- Create: `Scripts/gen_codeeditor_design_system.py`
- Create: `Tests/DiagramKitTests/DesignSystem/DSGenerationTests.swift`

**Interfaces:**
- Consumes: `Scripts/zed-trek.json` and the approved specification.
- Produces: generator CLI `gen_codeeditor_design_system.py [--check] [--output-root PATH]` and schema version `1`.

- [ ] **Step 1: Add the design-system test directory and a failing contract-presence test**

Create `DSGenerationTests.swift` without importing a not-yet-created target:

```swift
import Foundation
import Testing

@Suite("Design-system generation")
struct DSGenerationTests {
    private var root: URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return root
    }

    @Test("normalized contract is committed")
    func contractExists() {
        let contract = root.appending(path: "Scripts/codeeditor-design-system-contract.json")
        #expect(FileManager.default.fileExists(atPath: contract.path))
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

```bash
swift test --filter DSGenerationTests
```

Expected: the test compiles and fails only because the normalized contract is absent.

- [ ] **Step 3: Create the normalized contract**

The JSON root is exactly:

```json
{
  "schemaVersion": 1,
  "upstream": {
    "name": "CodeEditorPlugin Design System",
    "snapshotDate": "2026-07-12",
    "integration": "generated-adapter"
  },
  "tokens": {
    "spacing": {"xxxs":2,"xxs":4,"xs":6,"sm":8,"smMd":10,"md":12,"lg":16,"xl":20,"xxl":24,"xxxl":32},
    "radius": {"xs":4,"sm":6,"md":10,"lg":12,"xl":16,"xxl":20,"chip":8,"window":40,"full":9999},
    "stroke": {"hairline":0.5,"thin":1,"mediumLight":1.5,"medium":2,"thick":3,"ring":8},
    "opacity": {"faint":0.03,"dim":0.04,"subtle":0.05,"mist":0.06,"soft":0.08,"tint":0.10,"glassFill":0.12,"glassBorder":0.14,"glassHighlight":0.15,"light":0.20,"disabled":0.30,"medium":0.50,"strong":0.70,"heavy":0.80,"near":0.85},
    "durationMilliseconds": {"instant":100,"fast":150,"quick":200,"drawer":250,"control":300,"page":350,"section":400,"screen":500,"verySlow":600},
    "easing": {"outSoft":[0.16,1.0,0.30,1.0],"inOutSoft":[0.25,0.80,0.25,1.0],"springSnappy":[0.22,1.0,0.36,1.0]},
    "control": {"button":32,"buttonCompact":27,"row":34,"rowCompact":28,"chip":26,"switchWidth":38,"switchHeight":22,"switchKnob":18,"titleBar":38,"tabStrip":36,"tabStripCompact":28,"statusBar":28,"accentBar":2},
    "touch": {"macOS":28,"iOS":44},
    "icon": {"indicator":10,"micro":12,"xs":16,"sm":18,"md":24,"lg":32,"xl":44,"xxl":48},
    "typography": {"largeTitle":34,"title":28,"title2":22,"title3":20,"headline":17,"subheadline":15,"body":17,"callout":16,"footnote":13,"caption":12,"caption2":11,"overlineTracking":0.5},
    "interaction": {"pressedScale":1.0,"focusGlow":1.5}
  },
  "icons": {
    "close":"xmark","search":"magnifyingglass","settings":"slider.horizontal.3","reset":"arrow.counterclockwise","run":"play.fill","export":"square.and.arrow.up","convert":"arrow.left.arrow.right","diagnostics":"exclamationmark.bubble","warning":"exclamationmark.triangle.fill","error":"xmark.octagon.fill","info":"info.circle.fill","success":"checkmark.circle.fill","disclosureDown":"chevron.down","disclosureRight":"chevron.right","add":"plus","remove":"minus","copy":"doc.on.doc","history":"clock.arrow.circlepath","theme":"paintpalette","code":"chevron.left.slash.chevron.right"
  }
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

```bash
swift test --filter DSGenerationTests
```

- [ ] **Step 5: Add a failing generator-presence test**

Add to `DSGenerationTests`:

```swift
@Test("generator CLI is committed")
func generatorExists() {
    let generator = root.appending(path: "Scripts/gen_codeeditor_design_system.py")
    #expect(FileManager.default.fileExists(atPath: generator.path))
}
```

Run `swift test --filter DSGenerationTests` and verify RED because the generator
does not exist.

- [ ] **Step 6: Create the minimal generator CLI and verify GREEN**

Create an executable Python script that accepts `--contract`, `--themes`,
`--output-root`, and `--check`, then exits successfully without emitting Swift.
Run `swift test --filter DSGenerationTests` and verify GREEN.

- [ ] **Step 7: Add a failing malformed-contract test**

Add a subprocess test that invokes the minimal generator against a temporary
malformed contract:

```swift
@Test("missing required role is rejected")
func missingRole() throws {
    let temporary = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    let malformed = temporary.appending(path: "contract.json")
    try #"{"schemaVersion":1,"tokens":{}}"#.write(to: malformed, atomically: true, encoding: .utf8)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
        "python3", root.appending(path: "Scripts/gen_codeeditor_design_system.py").path,
        "--contract", malformed.path,
        "--themes", root.appending(path: "Scripts/zed-trek.json").path,
        "--output-root", temporary.path,
    ]
    let error = Pipe()
    process.standardError = error
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus != 0)
    let message = String(decoding: error.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    #expect(message.contains("tokens.spacing"))
}
```

Run `swift test --filter DSGenerationTests` and verify RED because the minimal
generator still accepts the malformed input.

- [ ] **Step 8: Implement strict generator validation**

The generator defines `REQUIRED_TOKEN_PATHS`, validates numeric ranges, requires
the icon keys above, requires exactly 10 families and 20 unique theme names,
and exits through:

```python
from typing import NoReturn

def fail(message: str) -> NoReturn:
    raise SystemExit(f"design-system contract error: {message}")

def require_path(root: dict, path: str):
    value = root
    for component in path.split("."):
        if component not in value:
            fail(path)
        value = value[component]
    return value
```

At this stage it validates only and creates the output directories; Swift emission lands in Task 2.

- [ ] **Step 9: Run the test and verify GREEN**

```bash
swift test --filter DSGenerationTests
```

Expected: the malformed contract test passes because the generator exits with `tokens.spacing` in stderr.

- [ ] **Step 10: Commit**

```bash
git add Scripts/codeeditor-design-system-contract.json Scripts/gen_codeeditor_design_system.py Tests/DiagramKitTests/DesignSystem/DSGenerationTests.swift
git commit -m "Add normalized sample design-system contract"
```

---

### Task 2: Generate the standalone token, theme, and icon target

**Files:**
- Modify: `Package.swift`
- Modify: `Scripts/gen_codeeditor_design_system.py`
- Create: `Sources/DiagramKitSampleDesignSystem/Generated/DSContract.generated.swift`
- Create: `Sources/DiagramKitSampleDesignSystem/Generated/DSThemes.generated.swift`
- Create: `Sources/DiagramKitSampleDesignSystem/Generated/DSIcons.generated.swift`
- Create: `Scripts/check_codeeditor_design_system.sh`
- Modify: `Tests/DiagramKitTests/DesignSystem/DSGenerationTests.swift`
- Create: `Tests/DiagramKitTests/DesignSystem/DSThemeTests.swift`

**Interfaces:**
- Produces: `DSTokens`, `DSThemeFamily`, `DSThemeMode`, `DSThemeVariant`, `DSTheme`, `DSIcon`, and `DSGeneratedMetadata`; every `DSThemeVariant` exposes its generated `theme`.

- [ ] **Step 1: Write failing API tests**

```swift
import DiagramKitSampleDesignSystem
import Testing

@Suite("Generated design-system API")
struct DSThemeTests {
    @Test("all Zed Trek variants are generated")
    func variantRoster() {
        #expect(DSThemeFamily.allCases.count == 10)
        #expect(DSThemeVariant.allCases.count == 20)
        #expect(DSTheme.lcarsDark.name == "LCARS Dark")
        #expect(DSTheme.lcarsDark.colors.accent.hex == "#FF9933")
    }

    @Test("canonical metrics are pinned")
    func metrics() {
        #expect(DSTokens.Control.switchWidth == 38)
        #expect(DSTokens.Control.switchHeight == 22)
        #expect(DSTokens.Control.switchKnob == 18)
        #expect(DSTokens.Opacity.disabled == 0.30)
        #expect(DSTokens.Interaction.pressedScale == 1)
    }

    @Test("semantic icons resolve")
    func icons() {
        #expect(DSIcon.close.systemName == "xmark")
        #expect(DSIcon.diagnostics.systemName == "exclamationmark.bubble")
    }
}
```

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter DSThemeTests
```

Expected: compile failure because generated types do not exist.

- [ ] **Step 3: Add the SwiftPM target**

Add:

```swift
.target(
    name: "DiagramKitSampleDesignSystem",
    swiftSettings: strictConcurrencySettings
),
```

Add it to `DiagramKitSample.dependencies` and `DiagramKitTests.dependencies`.

- [ ] **Step 4: Emit scalar tokens and icons**

The generator emits nested `DSTokens` enums with `CGFloat` values and durations/easings as a framework-neutral `DSEasing` value. It emits:

```swift
public enum DSIcon: String, CaseIterable, Sendable {
    case close, search, settings, reset, run, export, convert, diagnostics
    case warning, error, info, success, disclosureDown, disclosureRight
    case add, remove, copy, history, theme, code

    public var systemName: String { DSGeneratedIconNames.values[self]! }
}
```

- [ ] **Step 5: Emit full semantic themes**

Decode every Zed style entry into `DSThemeColors`, preserving chrome, element,
border, text, icon, status, editor, search, and syntax dictionaries. Use a
generated `DSColorValue` with normalized `#RRGGBB`/alpha storage so the target
does not depend on AppKit/UIKit. Emit `DSGeneratedMetadata` with schema version,
both input SHA-256 values, upstream name, snapshot date, and generated-adapter
provenance.

The public lookup is:

```swift
public extension DSTheme {
    static func theme(family: DSThemeFamily, mode: DSThemeMode) -> DSTheme
}
```

- [ ] **Step 6: Add deterministic check mode**

`--check` writes generated content to memory and compares exact UTF-8 bytes.
It exits nonzero with a sorted list of stale paths. Add the executable shell
wrapper:

```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$repo_root/Scripts/gen_codeeditor_design_system.py" \
  --contract "$repo_root/Scripts/codeeditor-design-system-contract.json" \
  --themes "$repo_root/Scripts/zed-trek.json" \
  --output-root "$repo_root" --check
```

- [ ] **Step 7: Generate, test, and verify GREEN**

```bash
python3 Scripts/gen_codeeditor_design_system.py --contract Scripts/codeeditor-design-system-contract.json --themes Scripts/zed-trek.json --output-root .
Scripts/check_codeeditor_design_system.sh
swift test --filter DSGenerationTests
swift test --filter DSThemeTests
```

Expected: all commands pass and a second generator run changes no files.

- [ ] **Step 8: Commit**

```bash
git add Package.swift Scripts/gen_codeeditor_design_system.py Scripts/check_codeeditor_design_system.sh Sources/DiagramKitSampleDesignSystem Tests/DiagramKitTests/DesignSystem
git commit -m "Generate sample design-system Swift adapter"
```

---

### Task 3: Resolve platform and accessibility environment state

**Files:**
- Create: `Sources/DiagramKitSampleDesignSystem/DSAccessibility.swift`
- Create: `Sources/DiagramKitSampleDesignSystem/DSThemeEnvironment.swift`
- Create: `Sources/DiagramKitSampleDesignSystem/DSTypography.swift`
- Create: `Tests/DiagramKitTests/DesignSystem/DSAccessibilityTests.swift`

**Interfaces:**
- Produces: `DSAccessibilityPreferences`, `DSResolvedEnvironment`, `DSFontRole`, `DSResolvedFont`, `EnvironmentValues.dsEnvironment`, and `View.dsTheme(family:mode:)`.

- [ ] **Step 1: Write failing preference-resolution tests**

```swift
@Test("accessibility preferences resolve deterministic behavior")
func preferenceResolution() {
    let resolved = DSResolvedEnvironment.resolve(
        theme: .lcarsDark,
        platform: .iOS,
        preferences: .init(
            increasedContrast: true,
            reduceMotion: true,
            differentiateWithoutColor: true,
            reduceTransparency: true
        )
    )
    #expect(resolved.minimumTarget == 44)
    #expect(resolved.motion == .reduced)
    #expect(resolved.usesOpaqueChrome)
    #expect(resolved.statusPresentation == .iconAndText)
    #expect(resolved.theme.isHighContrast)
    #expect(resolved.font(.body).usesRelativeTextStyle)
    #expect(resolved.font(.code).isMonospaced)
}
```

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter DSAccessibilityTests
```

Expected: missing `DSResolvedEnvironment` compile failure.

- [ ] **Step 3: Implement pure resolution types**

Use plain `Sendable`, `Equatable` values. `resolve` selects the platform target,
reduced motion, opaque glass fallback, icon-and-text statuses, and a generated
high-contrast theme variant/derivation. Implement semantic display, title,
headline, body, callout, subheadline, footnote, caption, caption2, code, metric,
badge, and overline roles. iOS roles resolve through relative Apple text styles;
macOS roles use the dense contract metrics. Limit weights to regular, medium,
semibold, and bold, and apply the contract tracking token only to overlines.

- [ ] **Step 4: Add SwiftUI environment host**

The host reads `colorScheme`, `accessibilityContrast`,
`accessibilityReduceMotion`, `accessibilityDifferentiateWithoutColor`,
`accessibilityReduceTransparency`, and `dynamicTypeSize`, then installs one
`DSResolvedEnvironment` value.

- [ ] **Step 5: Run and verify GREEN**

```bash
swift test --filter DSAccessibilityTests
```

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSampleDesignSystem/DSAccessibility.swift Sources/DiagramKitSampleDesignSystem/DSThemeEnvironment.swift Sources/DiagramKitSampleDesignSystem/DSTypography.swift Tests/DiagramKitTests/DesignSystem/DSAccessibilityTests.swift
git commit -m "Resolve design-system accessibility environment"
```

---

### Task 4: Implement canonical buttons and toggles

**Files:**
- Create: `Sources/DiagramKitSampleDesignSystem/DSButtonStyle.swift`
- Create: `Sources/DiagramKitSampleDesignSystem/DSToggleStyle.swift`
- Create: `Tests/DiagramKitTests/DesignSystem/DSPrimitiveTests.swift`

**Interfaces:**
- Produces: `DSButtonRole`, `DSButtonSize`, `DSButtonVisualState`, `.buttonStyle(.ds(role:size:))`, and `.toggleStyle(.ds)`.

- [ ] **Step 1: Write failing button state tests**

```swift
@Test("pressed state changes fill without scaling")
func pressedButton() {
    let state = DSButtonVisualState.resolve(
        role: .secondary, isHovered: false, isPressed: true,
        isFocused: false, isEnabled: true
    )
    #expect(state.fillRole == .elementActive)
    #expect(state.scale == 1)
    #expect(state.opacity == 1)
}

@Test("disabled state uses contract opacity")
func disabledButton() {
    let state = DSButtonVisualState.resolve(
        role: .ghost, isHovered: true, isPressed: false,
        isFocused: false, isEnabled: false
    )
    #expect(state.opacity == 0.30)
}
```

- [ ] **Step 2: Write failing toggle metric tests**

```swift
@Test("toggle uses canonical metrics")
func toggleMetrics() {
    #expect(DSToggleMetrics.track == .init(width: 38, height: 22))
    #expect(DSToggleMetrics.knob == 18)
    #expect(DSToggleMetrics.onKnobRole == .onAccent)
}
```

- [ ] **Step 3: Run and verify RED**

```bash
swift test --filter DSPrimitiveTests
```

- [ ] **Step 4: Implement `DSButtonStyle`**

Use `ButtonStyle.Configuration.isPressed`, `@Environment(\.isEnabled)`,
hover state, focus-visible treatment, semantic role lookup, contract timing,
and `frame(minWidth:minHeight:)` from `dsEnvironment.minimumTarget`. Never call
`scaleEffect`.

- [ ] **Step 5: Implement `DSToggleStyle`**

Use `ToggleStyle` and `configuration.isOn`; the label remains in the native
toggle accessibility tree. Render the canonical track/knob, focus ring,
disabled opacity, semantic hover/active fills, and no sliding animation under
Reduce Motion.

- [ ] **Step 6: Run and verify GREEN**

```bash
swift test --filter DSPrimitiveTests
```

- [ ] **Step 7: Replace the old test that locks in scale behavior**

Delete `Tests/DiagramKitTests/PlaygroundButtonStyleTests.swift`; its no-scale
replacement is now `DSPrimitiveTests.pressedButton`.

- [ ] **Step 8: Commit**

```bash
git add Sources/DiagramKitSampleDesignSystem/DSButtonStyle.swift Sources/DiagramKitSampleDesignSystem/DSToggleStyle.swift Tests/DiagramKitTests/DesignSystem/DSPrimitiveTests.swift Tests/DiagramKitTests/PlaygroundButtonStyleTests.swift
git commit -m "Add canonical design-system buttons and toggles"
```

---

### Task 5: Implement repeating controls, rows, surfaces, and icons

**Files:**
- Create: `Sources/DiagramKitSampleDesignSystem/DSControls.swift`
- Create: `Sources/DiagramKitSampleDesignSystem/DSRows.swift`
- Create: `Sources/DiagramKitSampleDesignSystem/DSSurface.swift`
- Modify: `Tests/DiagramKitTests/DesignSystem/DSPrimitiveTests.swift`

**Interfaces:**
- Produces: `DSSegmentedControl`, `DSChip`, `DSChipGroup`, `DSField`, `DSIconView`, `DSIconButton`, `DSSettingRow`, `DSSettingGroup`, `DSStatusIndicator`, `DSSectionHeader`, `DSCodeBadge`, `DSSurface`, and `DSGlassSurface`.

- [ ] **Step 1: Add failing role and accessibility tests**

Test that selected segments use `.elementSelected`, popovers alone receive a
shadow, Reduce Transparency resolves glass to an opaque role, and
Differentiate Without Color resolves status to icon + text.

```swift
@Test("only popovers receive elevation")
func elevation() {
    #expect(DSSurfaceRole.card.elevation == .none)
    #expect(DSSurfaceRole.panel.elevation == .none)
    #expect(DSSurfaceRole.popover.elevation == .popover)
}
```

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter DSPrimitiveTests
```

- [ ] **Step 3: Implement controls and rows**

All components read `dsEnvironment`, use `DSIcon`, use canonical metrics, own
their labels/values, and route actions through native `Button`, `Toggle`,
`TextField`, and focus APIs.

- [ ] **Step 4: Implement flat and glass surfaces**

`DSSurface` supports card/panel/sunken/popover roles. Only popover calls
`.shadow`. `DSGlassSurface` layers semantic role background, tint, material,
and optional popover elevation; Reduce Transparency returns the opaque role
background without material.

- [ ] **Step 5: Run and verify GREEN**

```bash
swift test --filter DSPrimitiveTests
```

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSampleDesignSystem/DSControls.swift Sources/DiagramKitSampleDesignSystem/DSRows.swift Sources/DiagramKitSampleDesignSystem/DSSurface.swift Tests/DiagramKitTests/DesignSystem/DSPrimitiveTests.swift
git commit -m "Add semantic sample design-system primitives"
```

---

### Task 6: Install a temporary compatibility bridge and root theme host

**Files:**
- Create: `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundCompatibility.swift`
- Modify: `Sources/DiagramKitSample/Views/LiveEditorView.swift`
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/Environment+PlaygroundTokens.swift`
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/ZedTrekTheme.swift`
- Modify: `Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift`

**Interfaces:**
- Consumes: generated `DSThemeFamily`/`DSThemeMode` and `View.dsTheme`.
- Produces: root-installed `dsEnvironment` and temporary aliases for unmigrated views.

- [ ] **Step 1: Write failing root-resolution tests**

Update token tests to assert that persisted `ZedTrekTheme` maps one-to-one to
`DSThemeFamily`, that system/light/dark modes resolve through the new target,
and that LCARS Dark remains default.

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter EditorRedesignTokenTests
```

- [ ] **Step 3: Add compatibility mappings**

Use typealiases where shapes match and computed adapters where the legacy
palette is smaller. Mark every legacy alias deprecated with the replacement
name. No new call site may import the compatibility file.

- [ ] **Step 4: Replace the root host**

`LiveEditorView.body` installs `.dsTheme(family:mode:)`. Preserve persistence,
system-follow callback, and canvas-follow synchronization. The macOS toolbar
reads the resolved DS window role.

- [ ] **Step 5: Run and verify GREEN**

```bash
swift test --filter EditorRedesignTokenTests
swift build --product DiagramKitSample
```

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Views/DesignSystem Sources/DiagramKitSample/Views/LiveEditorView.swift Tests/DiagramKitTests/EditorRedesign/EditorRedesignTokenTests.swift
git commit -m "Install generated design-system theme host"
```

---

### Task 7: Theme the editor, syntax highlighter, ruler, and tab strip

**Files:**
- Modify: `Sources/DiagramKitSample/Models/DiagramSyntaxHighlighter.swift`
- Modify: `Sources/DiagramKitSample/Views/Editor/NativeCodeEditor.swift`
- Modify: `Sources/DiagramKitSample/Views/Editor/LineNumberRuler.swift`
- Modify: `Sources/DiagramKitSample/Views/Editor/EditorTabBar.swift`
- Modify: `Sources/DiagramKitSample/Views/Editor/DiagramEditorPane.swift`
- Modify: `Sources/DiagramKitSample/Views/Editor/EditorModePicker.swift`
- Modify: `Sources/DiagramKitSample/Views/Editor/SourceFormatPicker.swift`
- Create: `Tests/DiagramKitTests/DesignSystem/DSEditorThemeTests.swift`

**Interfaces:**
- Produces: semantic highlighter modes `.mermaid`, `.d2`, `.dot`, `.structurizr`, `.plantUML`, `.json`, `.plain`; `colorMap(for: DSTheme)`.

- [ ] **Step 1: Write failing syntax-role tests**

For each format, tokenize a minimal source and assert at least one semantic
keyword/type/string token. Assert every `TokenCategory` resolves from LCARS
Dark and Light without a literal fallback.

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter DSEditorThemeTests
```

Expected: missing format modes and DS theme mapping.

- [ ] **Step 3: Expand tokenization modes**

Add compact, precompiled patterns for the five diagram languages. Preserve
off-main immutable tokenization and stale-result guards. Map categories to the
generated syntax dictionary with documented semantic fallbacks.

- [ ] **Step 4: Migrate native editor and ruler**

Pass `DSTheme` separately from `DiagramTheme`. Use DS editor background,
foreground, caret, selection, line-number, active-line, and diagnostic roles.
Keep the diagram theme only for rendered preview content.

- [ ] **Step 5: Rebuild the tab strip and editor controls**

Use `DSSurface(.tabBar)`, fixed tab height, `DSButtonStyle`, `DSIcon`, semantic
selected/hover/focus roles, category icon + text when Differentiate Without
Color is active, and DS typography/spacing/radii.

- [ ] **Step 6: Run and verify GREEN**

```bash
swift test --filter DSEditorThemeTests
swift test --filter DiagramPlaygroundRegressionTests
swift build --product DiagramKitSample
```

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitSample/Models/DiagramSyntaxHighlighter.swift Sources/DiagramKitSample/Views/Editor Tests/DiagramKitTests/DesignSystem/DSEditorThemeTests.swift
git commit -m "Theme the sample editor and all source formats"
```

---

### Task 8: Fix adaptive shell and compact-theme boundaries

**Files:**
- Modify: `Sources/DiagramKitSample/Views/LiveEditorView.swift`
- Modify: `Sources/DiagramKitSample/Views/Workspace/PlaygroundShell.swift`
- Modify: `Sources/DiagramKitSample/Views/Workspace/TitlebarView.swift`
- Modify: `Sources/DiagramKitSample/Views/Workspace/StatusbarView.swift`
- Modify: `Sources/DiagramKitSample/Views/Workspace/WorkspaceModePicker.swift`
- Modify: `Sources/DiagramKitSample/Views/Workspace/InspectorView.swift`
- Modify: `Sources/DiagramKitSample/Views/Workspace/Inspector*.swift`
- Create: `Tests/DiagramKitTests/DesignSystem/DSShellThemeTests.swift`

**Interfaces:**
- Ensures all shell chrome uses `DSTheme`; `DiagramTheme` remains canvas-only.

- [ ] **Step 1: Write failing shell boundary tests**

Extract pure `ShellChromeResolution` and assert that changing the independent
canvas theme cannot change navigation, status, panel, sheet, or toolbar roles.
Assert compact, regular, and wide layouts preserve reachable settings and
inspector actions.

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter DSShellThemeTests
```

- [ ] **Step 3: Replace compact canvas-theme chrome**

Replace every `Color(store.theme...)` used for navigation, mode strip, control
sheet, and preview-sheet chrome with the resolved DS role. Keep `store.theme`
inside `PreviewCanvas` and diagram-content rendering only.

- [ ] **Step 4: Migrate shell components**

Use fixed DS chrome heights, semantic separators, target sizes, status
indicators, icon mappings, and reduced-motion drawer transitions. Preserve
native split view, inspector, sheet, keyboard shortcut, and persistence logic.

- [ ] **Step 5: Run and verify GREEN**

```bash
swift test --filter DSShellThemeTests
swift build --product DiagramKitSample
```

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Views/LiveEditorView.swift Sources/DiagramKitSample/Views/Workspace Tests/DiagramKitTests/DesignSystem/DSShellThemeTests.swift
git commit -m "Apply design-system theme to adaptive shell"
```

---

### Task 9: Migrate diagnostics, export, convert, and settings

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Drawers/*.swift`
- Modify: `Sources/DiagramKitSample/Views/Sheets/*.swift`
- Modify: `Sources/DiagramKitSample/Views/Settings/*.swift`
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/Components/*.swift`
- Create: `Tests/DiagramKitTests/DesignSystem/DSPrimarySurfaceTests.swift`

**Interfaces:**
- Consumes: shared DS primitives.
- Produces: token-complete primary feature surfaces with preserved actions and identifiers.

- [ ] **Step 1: Add failing source and state tests**

Test diagnostic severity role mapping, export/convert status mapping, settings
mode persistence, and accessibility labels/values. Add a temporary scoped
source scan asserting no raw color/font/radius/material/shadow/direct-icon
patterns remain in Drawers, Sheets, or Settings.

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter DSPrimarySurfaceTests
```

- [ ] **Step 3: Migrate diagnostics**

Replace duplicate chips, category rows, headers, close buttons, severity
colors, material background, and explanation-card shadow with `DSChipGroup`,
`DSSettingRow`, `DSSectionHeader`, `DSIconButton`, `DSStatusIndicator`, and
`DSSurface`. Preserve filtering and explanation actions.

- [ ] **Step 4: Migrate export and convert**

Replace target rows, previews, diagnostic badges, toggles, footer buttons,
materials, colors, and typography. Preserve copy/save/round-trip behavior,
tasks, shortcuts, and fitted sheet sizing.

- [ ] **Step 5: Migrate settings and consolidate local components**

Make existing settings components thin DS wrappers or delete them when the DS
primitive is a direct replacement. Preserve seven tabs, theme specimens,
render backend, fonts, mutation catalog, parity, reset, and search behavior.

- [ ] **Step 6: Run and verify GREEN**

```bash
swift test --filter DSPrimarySurfaceTests
swift build --product DiagramKitSample
```

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitSample/Views/Drawers Sources/DiagramKitSample/Views/Sheets Sources/DiagramKitSample/Views/Settings Sources/DiagramKitSample/Views/DesignSystem/Components Tests/DiagramKitTests/DesignSystem/DSPrimarySurfaceTests.swift
git commit -m "Migrate primary sample surfaces to design system"
```

---

### Task 10: Migrate full-window browser and report surfaces

**Files:**
- Modify: `Sources/DiagramKitSample/Views/FullWindow/*.swift`
- Create: `Tests/DiagramKitTests/DesignSystem/DSFullWindowSurfaceTests.swift`

**Interfaces:**
- Produces: DS-styled corpus, snippets, coverage, probe, cross-format, and thumbnail surfaces.

- [ ] **Step 1: Add a failing scoped source audit**

The test scans `Views/FullWindow` and fails on raw colors, raw fonts, numeric
radii, direct icons, plain button controls, shadows, and materials. Add behavior
assertions for corpus filters and empty-state copy.

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter DSFullWindowSurfaceTests
```

- [ ] **Step 3: Migrate shared headers, fields, filters, cards, and statuses**

Use `DSSectionHeader`/`DSIconButton`, `DSField`, `DSChipGroup`, flat
`DSSurface`, `DSStatusIndicator`, semantic typography, spacing, and icons.
Use `ContentUnavailableView` with action-oriented text for empty results.

- [ ] **Step 4: Run and verify GREEN**

```bash
swift test --filter DSFullWindowSurfaceTests
swift build --product DiagramKitSample
```

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Views/FullWindow Tests/DiagramKitTests/DesignSystem/DSFullWindowSurfaceTests.swift
git commit -m "Migrate full-window sample surfaces to design system"
```

---

### Task 11: Migrate visual editor, history, toolbars, and legacy surfaces

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Visual/**/*.swift`
- Modify: `Sources/DiagramKitSample/Views/History/*.swift`
- Modify: `Sources/DiagramKitSample/Views/Toolbar/*.swift`
- Modify: `Sources/DiagramKitSample/Views/Rail/*.swift`
- Modify: `Sources/DiagramKitSample/Views/Inspector/*.swift`
- Modify: `Sources/DiagramKitSample/Views/ActionsView.swift`
- Modify: `Sources/DiagramKitSample/Views/ShareView.swift`
- Modify: `Sources/DiagramKitSample/Views/SidebarView.swift`
- Modify: `Sources/DiagramKitSample/Views/PreviewCanvas.swift`
- Modify: `Sources/DiagramKitSample/Views/CanvasTopToolbar.swift`
- Modify: `Sources/DiagramKitSample/Views/CanvasZoomToolbar.swift`
- Modify: `Sources/DiagramKitSample/Views/ThemePicker.swift`
- Create: `Tests/DiagramKitTests/DesignSystem/DSRemainingSurfaceTests.swift`

**Interfaces:**
- Completes application-view migration outside platform drawing adapters.

- [ ] **Step 1: Add failing directory source audits and state tests**

Scan the listed files for forbidden styling. Add pure tests for selection,
active tool, status, loading, retry, and Differentiate Without Color mappings.

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter DSRemainingSurfaceTests
```

- [ ] **Step 3: Migrate visual-editor floating chrome**

Use `DSGlassSurface` for toolbars/HUD/popovers only, DS buttons/icons/fields for
controls, semantic selection and diagnostic roles, contract motion, and opaque
fallback under Reduce Transparency. Preserve all mutations, drag/zoom,
selection, undo, catalog, icon, image, subgraph, and rearrange behavior.

- [ ] **Step 4: Migrate remaining content and legacy surfaces**

Convert history, toolbar panels, rail panels, inspector cards, actions, share,
sidebar, preview loading/failure, zoom, and theme picker. Replace color-only
signals with `DSStatusIndicator` under the resolved preference.

- [ ] **Step 5: Run and verify GREEN**

```bash
swift test --filter DSRemainingSurfaceTests
swift build --product DiagramKitSample
```

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Views Tests/DiagramKitTests/DesignSystem/DSRemainingSurfaceTests.swift
git commit -m "Complete sample surface design-system migration"
```

---

### Task 12: Add and satisfy the repository source-adherence gate

**Files:**
- Create: `Scripts/check-sample-design-adherence.sh`
- Modify: `Scripts/bootstrap-smoke-check.sh`
- Create: `Tests/DiagramKitTests/DesignSystem/DSAdherenceGateTests.swift`

**Interfaces:**
- Produces: a standalone zero-violation audit with path-based allowlists.

- [ ] **Step 1: Write a failing gate fixture test**

Create temporary compliant and noncompliant Swift fixtures and assert the gate
reports `file:line: rule` for a literal color, system font size, numeric radius,
direct chrome icon, shadow, material, literal animation, scale effect, gesture
switch, undersized target, and uncontrolled plain button.

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter DSAdherenceGateTests
```

- [ ] **Step 3: Implement the audit script**

Use `rg` rules with explicit allowlists for:

- `Sources/DiagramKitSampleDesignSystem/Generated/**`;
- `NativeCodeEditor.swift` and `LineNumberRuler.swift` platform bridges for
  framework color/font conversion only;
- diagram-content colors supplied by the user or `DiagramTheme`;
- transparent hit-test fills documented by rule.

The default scan root is `Sources/DiagramKitSample/Views` plus sample UI model
files. Sort output and exit 1 on any violation.

- [ ] **Step 4: Add both design gates to bootstrap**

Run `check_codeeditor_design_system.sh` and
`check-sample-design-adherence.sh` before the expensive full test/build sweep.

- [ ] **Step 5: Run and verify GREEN**

```bash
swift test --filter DSAdherenceGateTests
Scripts/check_codeeditor_design_system.sh
Scripts/check-sample-design-adherence.sh
```

- [ ] **Step 6: Commit**

```bash
git add Scripts/check-sample-design-adherence.sh Scripts/bootstrap-smoke-check.sh Tests/DiagramKitTests/DesignSystem/DSAdherenceGateTests.swift
git commit -m "Enforce sample design-system adherence"
```

---

### Task 13: Add contrast, snapshot, and responsive verification

**Files:**
- Create: `Tests/DiagramKitTests/DesignSystem/DSContrastTests.swift`
- Create: `Tests/DiagramKitTests/DesignSystem/DSSnapshotTests.swift`
- Create: `Tests/DiagramKitTests/DesignSystem/DSResponsiveLayoutTests.swift`
- Create: `Tests/DiagramKitTests/DesignSystem/__Snapshots__/DSSnapshotTests/`
- Create: `docs/verification/diagramkit-sample-theme-sweep.md`

**Interfaces:**
- Proves contrast for all themes and renders representative application surfaces.

- [ ] **Step 1: Write failing contrast tests**

Implement WCAG relative luminance in test support and assert:

```swift
for theme in DSThemeVariant.allCases.map(\.theme) {
    #expect(contrast(theme.colors.textPrimary, theme.colors.windowBackground) >= 4.5)
    #expect(contrast(theme.colors.onAccent, theme.colors.accent) >= 4.5)
    #expect(contrast(theme.colors.borderFocused, theme.colors.windowBackground) >= 3.0)
    for syntax in theme.colors.syntax.values {
        #expect(contrast(syntax.foreground, theme.colors.editorBackground) >= 4.5)
    }
}
```

- [ ] **Step 2: Run and verify RED**

```bash
swift test --filter DSContrastTests
```

Expected: any generated source colors that do not meet thresholds are listed by
theme and role.

- [ ] **Step 3: Add deterministic contrast hardening to generation**

Preserve hue while adjusting foreground lightness until the applicable ratio
passes. Keep original decorative/fill values in separate roles. Regenerate and
document every hardened role in generated metadata.

- [ ] **Step 4: Add SwiftUI snapshots**

Snapshot the shell, editor tabs, diagnostics, export, settings, corpus, and
visual overlay in LCARS Dark, LCARS Light, one high-contrast mode, Red Alert,
and Borg Cube. Snapshot theme specimen cards for all 20 variants. Use fixed
macOS view sizes and the existing precision conventions.

- [ ] **Step 5: Add responsive layout tests**

Test pure layout resolution for iPhone compact, iPad regular, and macOS wide
widths, including reachable Settings/Inspector controls and minimum target
sizes.

- [ ] **Step 6: Record the runtime sweep**

Populate `diagramkit-sample-theme-sweep.md` with date, commit, macOS window
size, iPhone simulator, iPad simulator, all 20 theme results, contrast mode,
Reduce Motion, Differentiate Without Color, and Reduce Transparency outcomes.
Every row is `Pass` or contains a linked issue fixed before completion.

- [ ] **Step 7: Run and verify GREEN**

```bash
swift test --filter DSContrastTests
swift test --filter DSSnapshotTests
swift test --filter DSResponsiveLayoutTests
```

- [ ] **Step 8: Commit**

```bash
git add Tests/DiagramKitTests/DesignSystem docs/verification/diagramkit-sample-theme-sweep.md
git commit -m "Add sample design-system visual verification"
```

---

### Task 14: Delete compatibility aliases and dead local design components

**Files:**
- Delete: `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundCompatibility.swift`
- Delete or reduce: `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundTokens.swift`
- Delete or reduce: `Sources/DiagramKitSample/Views/DesignSystem/Environment+PlaygroundTokens.swift`
- Delete or reduce: `Sources/DiagramKitSample/Views/DesignSystem/GlassChrome.swift`
- Delete or reduce: `Sources/DiagramKitSample/Views/DesignSystem/TouchTarget.swift`
- Delete migrated files: `Sources/DiagramKitSample/Views/DesignSystem/Components/*.swift`
- Modify: affected tests under `Tests/DiagramKitTests/EditorRedesign/`

**Interfaces:**
- Removes all `Playground*` compatibility API and duplicate components.

- [ ] **Step 1: Add failing legacy-symbol assertions**

Extend the adherence gate to fail on `PlaygroundPalette`, `PlaygroundTokens`,
`PlaygroundFont`, `PlaygroundSpacing`, `PlaygroundRadius`,
`PlaygroundButtonStyle`, `PillSwitch`, and `.glassChrome`.

- [ ] **Step 2: Run and verify RED**

```bash
Scripts/check-sample-design-adherence.sh
```

Expected: legacy symbol list with current paths.

- [ ] **Step 3: Remove aliases and dead files**

Use `rg` to prove each legacy symbol has no application call sites, delete its
definition, remove obsolete tests, and keep only genuinely DiagramKit-specific
specimen/persistence types renamed to `DS*`.

- [ ] **Step 4: Run and verify GREEN**

```bash
Scripts/check-sample-design-adherence.sh
swift build --product DiagramKitSample
swift test --filter DS
```

- [ ] **Step 5: Commit**

```bash
git add -A Sources/DiagramKitSample/Views/DesignSystem Tests/DiagramKitTests/EditorRedesign Scripts/check-sample-design-adherence.sh
git commit -m "Remove legacy sample design-system layer"
```

---

### Task 15: Full completion audit and merge-gate verification

**Files:**
- Modify only if verification exposes a tested defect.

**Interfaces:**
- Produces final evidence for every specification requirement.

- [ ] **Step 1: Run fast deterministic gates**

```bash
swift package dump-package >/dev/null
Scripts/check_codeeditor_design_system.sh
Scripts/check-sample-design-adherence.sh
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
```

Expected: all pass with zero design-adherence violations.

- [ ] **Step 2: Build application and tests**

```bash
swift build --product DiagramKitSample
swift build --build-tests
```

Expected: both pass without new warnings from remediation files.

- [ ] **Step 3: Run focused and full tests**

```bash
swift test --filter DS
swift test
```

Expected: all tests pass; no diagram snapshot is re-recorded.

- [ ] **Step 4: Run Linux check under the repository rule**

```bash
Scripts/linux-check.sh
```

Expected: pass, or documented environment skip only when Docker/Podman is
missing or unavailable.

- [ ] **Step 5: Run the complete merge gate**

```bash
Scripts/bootstrap-smoke-check.sh
```

Expected: package dump, full tests, governance, Linux rule, and multiplatform
`xcodebuild` sweep pass.

- [ ] **Step 6: Audit every completion criterion**

Create a temporary checklist from specification section 13. For each item,
record the exact source file, test, gate, snapshot, or runtime-sweep row that
proves it. Any missing or indirect evidence returns to the responsible task;
do not mark completion from absence of failures.

- [ ] **Step 7: Check final worktree scope**

```bash
git status --short
git diff --check HEAD~1
```

Expected: no uncommitted remediation changes and no whitespace errors.

- [ ] **Step 8: Commit verification-only fixes if required**

For each defect found in steps 1–7, write a failing focused test, verify RED,
apply the minimal fix, verify GREEN, rerun the affected gate, and commit only
those files with a message naming the defect. If no defect is found, create no
empty commit.

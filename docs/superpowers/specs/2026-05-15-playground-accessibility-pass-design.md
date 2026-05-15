# DiagramPlayground Accessibility Pass — Design

**Status:** Approved 2026-05-15
**Source:** REVIEW.md §5 "Minor / polish items" — "Accessibility labels missing across `DiagramEditorPane` insert/delete/undo controls — for a demo app, this is a missed showcase."
**Scope expansion:** approved during brainstorming — full chrome surface, not just the editor pane.

## Problem

The DiagramPlayground demo app currently ships **zero** accessibility modifiers across its entire chrome. Many interactive controls are icon-only `Image(systemName:)` buttons whose only labeling affordance is `.help(…)`, which is a macOS hover tooltip — not an accessibility label. VoiceOver/Switch Control users on iOS, iPadOS, macCatalyst, and visionOS hear "button" with no context. For a demo app whose purpose is to showcase DiagramKit, this is a visible quality gap.

REVIEW.md flagged this as a missed showcase but did not bound the work. The pass had not been picked up because every reasonable scope — minimal patch, full chrome, rendered-diagram a11y — needs a labeling-idiom decision and a verification mechanism before implementation can land in a maintainable way.

## Goal

1. Every interactive control across the playground chrome (editor pane, top toolbar, preview toolbar, sample/version/theme/source pickers, action panels) announces a meaningful label under VoiceOver on iOS 17+, macOS 14+, macCatalyst, and visionOS 1.
2. The labeling correctness is automatically verified in CI via Xcode's `XCUIApplication.performAccessibilityAudit(…)`, so regressions are caught before merge.
3. Future maintainers have a typed, ergonomic helper surface that makes the right thing the easy thing.

## Non-goals

1. **Rendered diagram content accessibility.** The CG/SVG output is treated as a single opaque image. Per-node focus, semantic structure, rotor navigation on the rendered surface is a substantial library-side effort. Separate spec.
2. **Library-side `DiagramView` host a11y.** Adjacent to (1). Separate spec.
3. **Dynamic-Type / sizing pass.** The audit will flag dynamic-type clipping issues; we will opt-out at the audit level for this pass and file findings for follow-up.
4. **Localization.** Labels land as `LocalizedStringKey` to leave the door open; no `.strings` files or locale matrix in the audit.
5. **Library targets.** No changes to `DiagramKitViews`, `DiagramKitInteractive`, or any renderer/model code.
6. **iOS host target for UI tests.** macOS-only in this spec; iPhone/iPad simulator destinations added as a follow-up once macOS is green.
7. **File-size splits.** `DiagramEditorPane.swift` (557 LOC), `PreviewCanvas.swift` (617 LOC), `ActionsView.swift` (595 LOC) are in REVIEW §5's "candidates for split" list. Not split here. A11y modifiers add a small per-call-site growth; accepted.
8. **Historical REVIEW.md edits.** Implementation will add a new "Session 16" resolution entry at close; no changes to prior session tables.

## Architecture

### Unit boundaries

1. **`Examples/DiagramPlayground/Views/Support/View+Accessibility.swift`** *(new)*
   Small typed-modifier surface so call sites stay tight:
   - `func a11y(label: LocalizedStringKey, hint: LocalizedStringKey? = nil, id: String) -> some View`
   - `func a11yToggle(label: LocalizedStringKey, isOn: Bool, hint: LocalizedStringKey? = nil, id: String) -> some View`
     - Applies `accessibilityLabel(label)`, `accessibilityValue(isOn ? "On" : "Off")`, optional `accessibilityHint(hint)`, and `accessibilityAddTraits(isOn ? .isSelected : [])`.
   - `func a11yIdentifier(_ id: String) -> some View` — for controls whose label is already auto-derived by SwiftUI.
   - `enum A11yID` — namespaced identifier constants so the audit suite and the views share the string truth (`A11yID.Editor.titleSet`, `A11yID.Toolbar.inspectorToggle`, etc.).

2. **Per-view edits** *(mechanical, ~10 files)*
   `DiagramEditorPane.swift`, `LiveEditorToolbar.swift`, `PreviewToolbar.swift`, `PreviewCanvas.swift`, `EditorModePicker.swift`, `SourceFormatPicker.swift`, `SampleDiagramPanel.swift`, `ThemePicker.swift`, `VersionSecurityPanel.swift`, `ActionsPanel.swift`. Each interactive call site picks one of the four helper modifiers (or `.accessibilityHidden(true)` for decorative glyphs) per the rules in the Labeling Specification section.

3. **`Examples/DiagramPlayground/project.yml`** — new `DiagramPlaygroundUITests` xcodegen target (macOS host).

4. **`Examples/DiagramPlayground/UITests/`** *(new directory)*
   - `AccessibilityAuditTests.swift` — drives `XCUIApplication.performAccessibilityAudit(…)` across screen states.
   - `IdentifierPresenceTests.swift` — asserts every `A11yID` constant resolves to a real control.
   - `XCTestCase+PlaygroundLaunch.swift` — launch helper that seeds initial state via `app.launchArguments`.

5. **`Scripts/playground-a11y-check.sh`** *(new)* — wraps `xcodebuild test -scheme DiagramPlayground -only-testing:DiagramPlaygroundUITests -destination 'platform=macOS,arch=arm64'`.

6. **`Examples/DiagramPlayground/DiagramPlaygroundApp.swift`** — ~10 lines `#if DEBUG`-gated to read `-uitest-state <state-id>` launch args and seed `LiveEditorStore` accordingly.

### Out-of-tree

- Library targets unchanged.
- `Scripts/bootstrap-smoke-check.sh` unchanged — the new a11y check is opt-in, parallel to `Scripts/linux-check.sh`'s pattern.
- `Dockerfile.linux-check` unchanged (Linux can't run XCUI).
- `CLAUDE.md` "Commands" section gets one new line documenting the script; "Discipline Gates" gets the opt-in lane documented.

## Labeling Specification

Every audited control receives an `accessibilityIdentifier`. Labels/hints depend on category.

### A. Buttons with visible text

Examples: `Button("Set")`, `Button("Clear")`, `Button("Rename")`, `Button("Insert")`, `Button("Delete selected")`, `Button("Done")`, `Button("OK")`.

SwiftUI derives the accessibility label from the button title. Add only `.a11yIdentifier(A11yID.Editor.titleSet)`. No label override, no hint. Visible text remains the single source of truth.

### B. Toolbar buttons wrapping `Label("Title", systemImage:)`

Examples: Theme / View / Actions / Info on the macOS toolbar (`LiveEditorToolbar.swift:47-94`).

Same as A — `Label` exposes the title to VoiceOver automatically. Add only `.a11yIdentifier(…)`. Existing `.help("…")` tooltips stay (orthogonal).

### C. Icon-only stateless buttons

Examples: section-close `xmark` (`DiagramEditorPane:46`), edge-direction `arrow.right` (`:367`), zoom in/out (`PreviewToolbar:88,101`), fit-to-view (`:63`), actual-size (`:111`), full-window (`:150`), search-clear (`SampleDiagramPanel:69`), category disclosure rows (`:108`), source-format chevron (`SourceFormatPicker:40`).

`.a11y(label: "Close section", id: A11yID.Editor.titleClose)`. Label is an action verb describing what tap does. Hint added only when the action is non-obvious (e.g., the swap-direction arrow needs `hint: "Swap from and to endpoints"`; the search-field `xmark.circle.fill` is self-evident).

### D. Icon-only stateful toggles

Examples: inspector toggle (`LiveEditorToolbar:97-104, 183`), pan/zoom toggle (`PreviewToolbar:120-131`), grid toggle (`:134-145`). `Picker` widgets are not in this category — see Special Cases.

```swift
.a11yToggle(
    label: "Inspector",
    isOn: store.state.inspectorOpen,
    hint: "Shows the editing controls panel",
    id: A11yID.Toolbar.inspectorToggle
)
```

Helper applies: `accessibilityLabel("Inspector")` + `accessibilityValue(isOn ? "On" : "Off")` + `accessibilityHint(hint)` + `accessibilityAddTraits(isOn ? .isSelected : [])`. Matches Apple HIG (label = noun, value = state).

### E. Decorative icons

Examples: warning glyphs adjacent to text (`PreviewCanvas:444, 473, 495, 521, 532, 550`), `magnifyingglass` inside a search field (`SampleDiagramPanel:56, 303`), badge icons (`:198`), `checkmark` indicators inside menu rows (`:164`, `SourceFormatPicker:29`, `ThemePicker:49`), header icons in `VersionSecurityPanel`, the action-row `link` and `arrow.up.right` glyphs.

`.accessibilityHidden(true)`. The adjacent text already conveys the meaning; doubling it bloats VoiceOver output. For diagnostic rows where the icon+text pair is the actionable region, hide the icon and apply the label to the containing element instead.

### Special cases

- **Undo / Redo** (`DiagramEditorPane.swift:485-499`): Category D. Label = "Undo" / "Redo" (stable noun); `accessibilityValue` = `editor.undoActionName` / `redoActionName` (varies per action, e.g., "Delete element"); hint empty. Matches macOS Edit menu pattern.
- **`Picker(label, selection:)` sites** (`DiagramEditorPane.swift:183, 308, 391, 402`, `LiveEditorToolbar.swift:261`, plus `EditorModePicker` and `SourceFormatPicker` whose inner controls are `Picker`s): the label argument is the a11y label — add only an identifier on the Picker container. This covers update-mode, source-format, view-mode, shape, from, to, and selected-element pickers.
- **Inspector toggle duplicated across macOS (line 97) and iOS-compact (line 183) call sites in `LiveEditorToolbar.swift`**: both call sites use the same `A11yID.Toolbar.inspectorToggle` constant. The identifier-presence test passes whenever one or the other renders on the current platform.

## Verification

### Test target

`DiagramPlaygroundUITests` — xcodegen UI test target hosting against `DiagramPlayground` (macOS). Sources under `Examples/DiagramPlayground/UITests/`. iOS scheme entry added as follow-up once macOS is green (out of scope here).

### Two test suites

**1. `AccessibilityAuditTests.swift`** — drives `XCUIApplication.performAccessibilityAudit(for: .all, options:)` per screen state. The audit catches:
- Missing labels
- Duplicate labels within a screen
- Hit targets smaller than 44×44 (where relevant)
- Contrast violations
- Dynamic-type clipping
- Trait incoherence (e.g., a button without the `.button` trait)

Screen states covered:
| State | Setup | Audit focus |
|---|---|---|
| Empty | Fresh launch, no diagram loaded | Top toolbar + sidebar |
| Editing | Load corpus `flow-1-simple`, open Inspector | Editor pane + preview + toolbars together |
| Selection | From Editing, select a node via the picker | Selection / rename / delete controls |
| Error | Paste invalid source ("garbage") | Error overlay + `parseError` banner |
| Theme picker open | Pop the Theme menu | Row controls inside the menu |

Per-state opt-outs land inline only if a fix turns out to be infeasible in the playground; each opt-out carries a one-line comment explaining why.

**2. `IdentifierPresenceTests.swift`** — one parameterized assertion per `A11yID` constant. Launches the playground into the state where the control should exist, then asserts `app.buttons[id].exists` (or `.pickers[id]`, `.toggles[id]`, etc.). Catches the silent-failure mode where someone removes a modifier and the audit suite doesn't notice because the element no longer renders at all.

### Launch helper

`XCTestCase+PlaygroundLaunch.swift` exposes `launchPlayground(initialState: PlaygroundState) -> XCUIApplication`. State is passed via `app.launchArguments = ["-uitest-state", "<state-id>"]`. The playground reads those args at startup under `#if DEBUG` and seeds `LiveEditorStore` accordingly.

### CI integration

- **`Scripts/playground-a11y-check.sh`** — wraps the xcodebuild invocation, captures exit code, tails the failure log on non-zero. Audit failures include element descriptions and screenshot paths via Xcode's built-in formatter — no custom reporter.
- **`Scripts/bootstrap-smoke-check.sh`** — **unchanged**. The a11y check is opt-in, mirroring `Scripts/linux-check.sh`'s policy (environment-dependent and slow).
- **`CLAUDE.md`** — one line added to "Commands" pointing at the new script; "Discipline Gates" section gains a paragraph for the new opt-in lane.

## Risks & mitigations

- **Audit false positives.** `performAccessibilityAudit` can flag SwiftUI-internal subviews. Mitigation: opt-out specific issue types per state with a one-line inline comment justifying each.
- **Launch-arg seeding leaking to release builds.** Mitigation: the seeding code is `#if DEBUG`-gated.
- **`A11yID` namespace drift.** Two places (views and tests) reference the constants; renaming one without the other silently breaks `IdentifierPresenceTests`. Mitigation: the constants live in a single source-of-truth file under `Examples/DiagramPlayground/Views/Support/`, imported by both the app target and the UI test target.
- **xcodegen project regeneration.** Adding the UI test target requires `xcodegen generate`. Mitigation: document the regeneration step in the implementation plan; the regenerated `.xcodeproj` is checked in already (matches existing repo practice).

## Acceptance criteria

1. `Scripts/playground-a11y-check.sh` exits 0 against `main`.
2. `xcodebuild` output reports zero `XCTAccessibilityAuditIssue` findings across all five screen states.
3. Every `A11yID` constant is referenced by both an audited view and an `IdentifierPresenceTests` case.
4. No regression in existing `swift test --filter` suites — library targets are untouched.
5. CLAUDE.md "Commands" and "Discipline Gates" updated.
6. REVIEW.md gains a Session 16 entry closing the §5 a11y bullet.

## References

- REVIEW.md §5 "Minor / polish items" — "Accessibility labels missing across `DiagramEditorPane` insert/delete/undo controls"
- Apple HIG — Accessibility, Labels & Values
- `XCTestCase.performAccessibilityAudit(for:options:)` — iOS 17 / macOS 14+
- Existing opt-in CI lane pattern: `Scripts/linux-check.sh`

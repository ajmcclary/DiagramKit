# DiagramKitSample Design-System Remediation — Design Spec

**Date:** 2026-07-12
**Status:** Approved design; implementation planning pending
**Scope:** Complete `DiagramKitSample` adherence to the CodeEditorPlugin design-system contract

## 1. Objective

Remediate every finding from the 2026-07-12 DiagramKitSample design-system
audit without changing DiagramKit's parsing, layout, rendering, import, or
export contracts. The completed sample app must use one semantic design-system
surface for all application chrome on macOS and iOS, preserve the independent
diagram-canvas theme boundary, and prove adherence through deterministic
generation, source audits, behavioral tests, contrast checks, snapshots, and
the repository merge gate.

The immediate architecture is a generated, checked-in adapter owned by this
repository. Direct consumption of `CodeEditorPlugin` is explicitly deferred
while that package is under separate active development. The adapter boundary
must deliberately mirror the eventual package concepts so a later dependency
swap does not require rewriting application views.

## 2. Authoritative inputs and precedence

The committed inputs are:

1. `Scripts/zed-trek.json` — the 20 Zed Trek theme variants.
2. `Scripts/codeeditor-design-system-contract.json` — normalized design tokens,
   component metrics, semantic icon mappings, accessibility policy, and
   upstream provenance.
3. This specification — DiagramKit-specific role mapping and migration rules.

The ignored `codeeditorplugin-design-system/` export is reference material, not
a build input. CI and clean clones must not require it.

When source artifacts disagree, precedence is:

1. normalized token contract;
2. live component behavior;
3. preview/specimen artifacts.

The normalized contract resolves the currently observed contradictions as
follows:

- switch geometry is `38 x 22` with an `18pt` knob;
- the enabled switch knob uses the semantic on-accent ink color;
- button radius is `6pt`;
- pressed controls change fill and never scale;
- disabled opacity is `0.30`;
- application chrome has one popover elevation and no general card shadow
  scale;
- glass is limited to role-based floating chrome and popovers.

## 3. Package architecture

Add a SwiftPM target named `DiagramKitSampleDesignSystem`.

```text
Scripts/zed-trek.json --------------------+
                                           +--> generator --> DiagramKitSampleDesignSystem
Scripts/codeeditor-design-system-contract.json +               |
                                                               v
                                                     DiagramKitSample views
```

The target contains only application-design concerns and depends on SwiftUI and
Foundation. It does not depend on `DiagramKit`, any parser/renderer target, or
the ignored design export. `DiagramKitSample` depends on this target.

The target exposes:

- `DSTheme`, `DSThemeFamily`, and `DSThemeMode`;
- semantic palette roles, including full Zed editor/syntax roles;
- typography, spacing, radius, stroke, size, opacity, motion, elevation, and
  control metrics;
- `DSIcon` semantic identifiers and SF Symbol resolution;
- platform/accessibility environment resolution;
- the shared SwiftUI primitives described in section 6.

Existing `Playground*` names may temporarily remain as compatibility aliases
during migration. They must be deleted after the last application call site is
converted. New code must use `DS*` names from the start.

## 4. Deterministic generation and drift control

Add `Scripts/gen_codeeditor_design_system.py` with two modes:

- default: emit the generated Swift files;
- `--check`: regenerate in memory and fail when committed output differs.

Add `Scripts/check_codeeditor_design_system.sh` as the repository-facing gate.
The generator must:

- parse and validate both committed JSON inputs;
- require exactly 10 named theme families and 20 variants;
- preserve all semantic theme roles needed by chrome, editor, syntax,
  diagnostics, search, gutter, borders, and interaction states;
- emit stable ordering and formatting;
- embed the contract schema version, input SHA-256 values, and upstream
  provenance in generated output;
- reject missing required roles instead of silently substituting unrelated
  colors;
- use documented, deterministic fallbacks only where Zed omits a role;
- never read from the network or the ignored design export during normal build
  or verification.

The check script is added to the local merge gate and must be runnable
independently.

## 5. Semantic design surface

### 5.1 Theme roles

Application views consume role names, never color literals. Required role
groups include:

- application/window, editor, surface, elevated surface, panel, sheet, rail,
  title bar, tab bar, status bar, toolbar, field, and track backgrounds;
- primary, secondary, muted, placeholder, disabled, and on-fill text;
- primary, muted, disabled, selected, and on-fill icons;
- base, variant, focused, destructive, and separator borders;
- element and ghost idle, hover, active, and selected fills;
- success, warning, error, info, caution, and unsupported statuses;
- editor foreground, line numbers, active line, selection, caret, indent guide,
  search result, and diagnostic gutter;
- syntax categories for diagram type, keyword, string, comment, transition,
  number, delimiter, annotation, variable, property, type, function, constant,
  operator, punctuation, and invalid text.

Diagram-canvas `DiagramTheme` remains separate. Only preview/editor-canvas
content reads it. Navigation, sheets, tabs, panels, status, fields, and other
application chrome always read `DSTheme`.

### 5.2 Typography

Typography uses semantic roles rather than arbitrary sizes:

- display, title, headline, body, callout, subheadline, footnote, caption, and
  caption2;
- code, metric, badge, and overline variants;
- SF Pro/system sans for UI and SF Mono/system monospaced for code;
- only regular, medium, semibold, and bold weights;
- uppercase overlines use the contract tracking token.

macOS receives dense editor-chrome metrics. iOS roles are relative to Apple
text styles so Dynamic Type scales. Fixed point sizes are permitted only in
platform drawing adapters such as `NSRulerView`/`UIView`, where a scaled value
is supplied by the design environment.

### 5.3 Geometry and motion

Spacing, radii, strokes, icon sizes, control heights, touch targets, chrome
heights, opacity, duration, and easing all come from the contract.

- iOS interactive target floor: `44 x 44pt`.
- macOS interactive target floor: `28 x 28pt`.
- title bar: `38pt`; tab strip: `36pt` (`28pt` compact); status bar: `28pt`.
- switch: `38 x 22pt`, `18pt` knob.
- focus uses the semantic focused border plus glow token.
- Reduce Motion replaces movement with immediate state changes or short
  opacity crossfades.
- no pressed-state scale transforms.

## 6. Canonical SwiftUI primitives

### 6.1 Buttons

`DSButtonStyle` supports primary, secondary, ghost, destructive, and icon-only
roles plus default/compact sizing. It provides:

- semantic idle/hover/pressed/focused/disabled fills;
- theme-derived on-fill foregrounds;
- contract timing and easing;
- pointer feedback on macOS;
- platform hit-target expansion;
- no scale transform.

`.buttonStyle(.plain)` remains allowed only for system-owned menu labels or
genuine inline text links that do not represent a design-system control.

### 6.2 Toggles

`DSToggleStyle` styles a native SwiftUI `Toggle`. It retains native switch
semantics, keyboard operation, focus, accessibility value, disabled behavior,
and full-row labeling. It implements canonical geometry, knob color, hover,
active, focus, and Reduce Motion behavior. Gesture-only custom switches are
removed.

### 6.3 Repeating controls

Provide:

- `DSSegmentedControl` for mutually exclusive 2–4 option sets;
- `DSChip` and `DSChipGroup` for filters/tags;
- `DSField` for text/search inputs and focus rings;
- `DSSettingRow` and `DSSettingGroup` for settings and inspector rows;
- `DSSurface` for flat card, sunken editor, panel, and popover roles;
- `DSIconButton` for compact action glyphs;
- `DSStatusIndicator` for status icon + text, never color alone;
- `DSSectionHeader` and `DSCodeBadge` for recurring typography patterns.

Every primitive owns its accessibility label/value contract, target size,
focus treatment, hover/pressed behavior, and token application.

### 6.4 Icons

`DSIcon` is the only application-level icon identifier. It maps semantic names
such as close, search, settings, reset, run, export, diagnostics, warning,
success, disclosure, and navigation to SF Symbols. Direct
`Image(systemName:)` calls are limited to the design-system target and
diagram-content code where the symbol is user data rather than application
chrome.

## 7. Accessibility environment

Add a single resolved design environment that reads:

- color scheme;
- accessibility contrast;
- Reduce Motion;
- Differentiate Without Color;
- Reduce Transparency;
- Dynamic Type size;
- enabled/focused state where relevant.

Behavioral requirements:

- increased contrast selects the generated high-contrast LCARS profile or an
  equivalent contrast-hardened derivation for the active family;
- Reduce Transparency replaces glass/material with the opaque role
  background;
- Differentiate Without Color adds an icon, pattern, label, or shape to every
  status/selection communicated by color;
- Reduce Motion removes sliding/morphing motion without delaying state
  feedback;
- all controls remain usable by keyboard, VoiceOver, and Switch Control;
- empty, loading, success, warning, and failure states contain actionable text.

## 8. Elevation, material, and glass

The only chrome shadow is the theme-provided popover shadow. Cards, title bars,
tab strips, panels, inspectors, drawers, and status bars are flat and use
surface contrast plus hairline separators.

`DSGlassSurface` accepts toolbar, HUD, and popover roles. It composes:

1. role background;
2. theme glass tint and opacity;
3. platform glass/material;
4. popover shadow only for the popover role.

When Reduce Transparency is enabled, step 3 is omitted. Editor and diagram
content surfaces remain opaque.

## 9. Screen migration

### 9.1 Theme boundary and adaptive shell

- Replace `PlaygroundTokens` environment installation with `DSTheme`.
- Keep existing family/mode persistence and migration behavior.
- Ensure light/dark/system mode resolves live.
- Keep canvas-following behavior, but restrict `DiagramTheme` to diagram and
  source-preview content.
- Paint compact iPhone navigation, control sheets, and full-screen preview
  chrome from `DSTheme`, never `store.theme`.
- Preserve native `NavigationSplitView`, `.inspector`, `.sheet`, and `.popover`
  structure.

### 9.2 Editor

- Rebuild the tab strip with semantic tab, close, dirty, selected, hover, and
  focus roles plus fixed chrome height.
- Route editor background, foreground, caret, selection, current line, gutter,
  and diagnostic markers through `DSTheme`.
- Replace hard-coded highlighter colors with generated syntax roles.
- Add semantic tokenization for Mermaid, D2, Graphviz DOT, Structurizr,
  PlantUML, and JSON. Unknown formats use themed plain text rather than an
  unrelated palette.
- Preserve cursor, selection, scroll, undo, debounce, and diagnostics behavior.

### 9.3 Primary feature surfaces

Migrate diagnostics, diagnostic explanation, export, convert, and settings to
the shared primitives. Preserve all commands, shortcuts, sheet sizing,
accessibility identifiers, and store actions.

### 9.4 Full-window surfaces

Migrate corpus browser, snippets, coverage matrix, importer probe, cross-format
view, and thumbnails. Consolidate duplicate filter chips, search fields,
headers, close controls, cards, status colors, and empty states.

### 9.5 Visual editing and remaining surfaces

Migrate history, flowchart/sequence/Gantt overlays, state stepper, tool
palettes, zoom controls, selection HUD, catalogs, popovers, prompts, toasts,
theme picker, share/actions panels, and legacy toolbar/sidebar surfaces.

No migration may remove behavior or replace a working native semantic control
with a gesture-only imitation.

## 10. Source-adherence gate

Add a sample-UI audit script that fails on unauthorized patterns outside
allowlisted adapters and diagram-content rendering code:

- color hex/RGB literals;
- raw system status colors and unqualified `.primary`/`.secondary` styling;
- arbitrary `.font(.system(size:))` values;
- numeric spacing, radius, stroke, icon, control, or chrome metrics;
- direct `Image(systemName:)` for application chrome;
- custom shadows outside the popover implementation;
- raw material/glass use outside `DSGlassSurface`;
- literal animation durations/easings;
- pressed-state scale transforms;
- custom gesture-driven switches;
- undersized interactive frames;
- uncontrolled `.buttonStyle(.plain)` usage.

The allowlist is narrow, documented inline, and path-based. The gate reports
file and line for every violation.

## 11. Testing strategy

All behavior changes use test-first development.

### 11.1 Generation and contract tests

- schema and required-role validation;
- deterministic generation and `--check` behavior;
- exact 10-family/20-variant roster;
- input hash/provenance pins;
- missing-token and malformed-color failures;
- compatibility alias removal check after migration.

### 11.2 Theme and contrast tests

- every semantic role resolves in every variant;
- normal text meets 4.5:1; large text and non-text UI meet 3:1;
- on-accent and on-danger meet the applicable threshold;
- syntax categories meet contrast requirements on editor backgrounds;
- high-contrast resolution hardens borderline roles;
- light/dark/system changes update all chrome without changing an independent
  canvas theme when matching is disabled.

### 11.3 Primitive behavior tests

- button idle, hover, pressed, focus, disabled, pointer, and no-scale states;
- toggle geometry, on/off colors, keyboard semantics, focus, disabled, and
  Reduce Motion behavior;
- segmented control selection, focus, and disabled behavior;
- target-size resolution on macOS and iOS;
- Differentiate Without Color status alternatives;
- Reduce Transparency glass fallback.

### 11.4 View snapshots and runtime coverage

- macOS SwiftUI snapshots for the shell, editor tabs, diagnostics, export,
  settings, corpus, and visual-editing overlays;
- light, dark, and high-contrast representative screen snapshots;
- specimen snapshots covering all 20 variants;
- compact, regular, and wide responsive geometry fixtures;
- iOS simulator build/test coverage where supported by the package scheme;
- a documented runtime theme sweep across all 20 variants on macOS and at
  least one iPhone and iPad simulator size.

Existing diagram SVG/image/ASCII snapshots are not re-recorded unless a
separately identified intentional canvas-rendering change requires it.

## 12. Verification gates

Completion requires all of the following:

1. `Scripts/check_codeeditor_design_system.sh`
2. sample UI source-adherence gate
3. focused design-system and sample-view tests
4. `swift build --product DiagramKitSample`
5. `swift build --build-tests`
6. full `swift test`
7. repository governance gates
8. `Scripts/bootstrap-smoke-check.sh`
9. clean scoped `git status`
10. requirement-by-requirement completion audit against this specification

The Linux container step may be recorded as environmentally skipped only under
the repository's existing Docker/Podman rule. All other failures are source or
verification failures and must be resolved.

## 13. Migration completion criteria

The remediation is complete only when:

- `DiagramKitSample` consumes `DiagramKitSampleDesignSystem`;
- generated artifacts match committed contract inputs;
- all application chrome uses semantic roles and primitives;
- every audit finding is covered by code plus an enforcing test/gate;
- editor syntax and diagnostics are theme-driven and contrast-compliant;
- accessibility preferences alter behavior as specified;
- compact iPhone chrome no longer uses the diagram canvas theme;
- legacy `Playground*` aliases and unused components are removed;
- the source-adherence audit reports zero unauthorized violations;
- required snapshots and runtime sweeps are recorded;
- the full merge gate passes.

## 14. Deferred direct package integration

Direct dependency on `CodeEditorPlugin` is deferred. The future migration may
replace `DiagramKitSampleDesignSystem` internals with package products after
the upstream package has a stable revision/tag and compatible platform floor.
Application views must not depend on adapter implementation details, local
checkout paths, or ignored export files, so that future work remains a bounded
dependency and type-mapping change.

## 15. Non-goals

- Changing DiagramKit parser, layout, renderer, importer, exporter, or public
  engine behavior.
- Modifying the separately active `CodeEditorPlugin` checkout.
- Raising DiagramKit's current macOS/iOS 26.0 package floor.
- Adding a network dependency or network access to generation/verification.
- Replacing native navigation, sheet, inspector, menu, toggle, focus, or
  accessibility semantics with custom imitations.

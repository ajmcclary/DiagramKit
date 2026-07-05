# DiagramKitSample — UX Audit & Prioritized Roadmap

**Date:** 2026-07-05
**Scope:** UX of the `DiagramKitSample` app across four axes — Liquid Glass / macOS-26
assimilation, interaction states, information hierarchy, iOS/macOS parity.
**Deliverable type:** Audit + ranked roadmap. No code changes; findings are for green-lighting.
**Platform floor:** macOS 26 + iOS 26 (all modern APIs available).
**Method:** Four parallel code readers (one per axis) + Apple Liquid Glass docs, findings
cross-verified against source. Two load-bearing claims independently re-verified (below).

---

## TL;DR

The sample app is *feature-rich and well-themed* but **re-implements the platform's structural
vocabulary by hand and then flattens it.** One root cause drives ~60% of the findings, and it
touches three of the four axes at once:

> `PlaygroundShell.swift:5` — *"Custom three-column shell that replaces NavigationSplitView."*

By hand-rolling the shell (and hand-rolling "sheets" as dimmed `ZStack` overlays), the app
forfeits — for free — native hierarchy, native adaptive iPad/iPhone layout, and the platform's
Liquid Glass treatment. Separately, **~110 `.buttonStyle(.plain)` controls share no `ButtonStyle`**,
so the entire app has essentially zero press/hover/focus/cursor/disabled feedback.

**The whole audit collapses into three foundational moves plus a short tail of localized fixes.**

---

## Verified defects (not polish — these are shipping bugs)

| # | Defect | Evidence | Severity |
|---|--------|----------|----------|
| B1 | **iPad loses its entire primary toolbar.** `regularLayout` is a bare `PlaygroundShell` with `.toolbar{…}` attached but **no `NavigationStack` ancestor** (compact path has one; regular path does not). On iPad, theme / view-options / actions / **inspector-toggle** don't render. Inspector becomes reachable only via `⌘I` hardware key. | `LiveEditorView.swift:82-86` vs `:72`, `:172-177` | **High** |
| B2 | **Settings is unreachable on iPhone.** `SettingsSheet` is only rendered inside `PlaygroundShell` (regular layout). The compact path never mounts it and the compact toolbar has no Settings entry. Render-backend, fonts, theme-builder, parity — all unreachable on iPhone. | `PlaygroundShell.swift:106`, `LiveEditorView.swift:106-167` | **High** |
| B3 | **Fake telemetry shipped as live UI.** `snapshotCount` hardcodes `"1044"`; `lastRenderText` hardcodes `"—"`. Presented in the status bar at the same weight as real signals. | `StatusbarView.swift:216-229` | **Medium** |
| B4 | **Non-functional inspector controls presented identically to functional ones.** "Arrange" and "Diagram direction" sections are purely presentational but styled like live controls — users click dead UI. | `InspectorView.swift` (sections) | **Medium** |

B1–B2 should be fixed regardless of the broader redesign — they make whole feature areas
unreachable on a shipping platform.

---

## The three foundational moves

### Move 1 — Adopt native structural containers
**Replaces:** hand-rolled shell, hand-rolled inspector, hand-rolled "sheets."
**Fixes axes:** information hierarchy + iOS/macOS parity, and *unlocks* Liquid Glass.

- `PlaygroundShell`'s manual `ZStack{VStack{HStack{ rail; panel; body; inspector }}}`
  (`PlaygroundShell.swift:26-53`) → **`NavigationSplitView`** for rail+content and the
  **`.inspector(isPresented:)`** modifier for the right column. Both available at the floor.
- Fixed column widths (rail 52 / panel 236 / inspector 312, ~600pt of chrome) currently
  overflow iPad portrait (~234pt of canvas on 11", ~144pt on mini). `NavigationSplitView`
  restores OS-driven collapse, drag-to-resize, and the sidebar/inspector toggles for free.
- The four hand-rolled modal overlays (Explain / Export / Convert / Settings — dimmed
  `Color.black.opacity(0.25/0.35/0.62)` scrims, `PlaygroundShell.swift:60-116`) → real
  **`.sheet` / `.popover`** with `.presentationDetents`. Restores Escape-to-dismiss, focus
  trapping, VoiceOver modal scoping, adaptive iPad/iPhone sizing — and platform sheet glass.
- Consolidate the muddy "sidebar" concept: today `sidebarVisible`, the always-on rail,
  the iOS-only `SidebarView`, and `activeRailTab` are four different switches with no single
  answer to "what is the sidebar." Unify on the rail as the split-view section switcher.

**Why first:** it is the enabling move. It resolves the two shipping parity bugs (B1/B2 fall
out of using a real navigation container), restores structural hierarchy the OS communicates
for you, and gives you real platform materials on sheets/popovers to build glass on.

### Move 2 — One shared `ButtonStyle`
**Replaces:** ~110 `.buttonStyle(.plain)` call-sites.
**Fixes axis:** interaction states — five gaps in one component.

Build `PlaygroundButtonStyle: ButtonStyle` that reads `configuration.isPressed` and
`@Environment(\.isEnabled)`:

- pressed: `.opacity(0.6)` + `.scaleEffect(0.97)`, `.animation(.easeOut(0.12), value: isPressed)`
- disabled: `.opacity(0.4)` (`.plain` does **not** auto-dim — disabled buttons currently look live)
- cursor: `.pointerStyle(.link)` (no control in the app shows a hand cursor today)
- focus: focus-ring overlay (`@FocusState`) — keyboard nav is currently invisible
- optional hover tint via `.onHover` / `.hoverEffect(.highlight)`

Applied wherever `.plain` is today, this single component fixes press, disabled, cursor, focus,
and hover across the whole control surface at once. **Zero-count confirmed** across the app:
`isPressed` 0, custom `ButtonStyle` 0, `.pointerStyle` 0, `hoverEffect` 0, `onHover` 1.

### Move 3 — A `.glassChrome()` modifier + one `GlassEffectContainer` over the canvas
**Replaces:** ~20 hand-rolled `RoundedRectangle/Capsule.fill(material) + manual stroke + shadow`
floating surfaces, plus the fake `glassBg` token and `Surface(.glass)` case.
**Fixes axis:** Liquid Glass / macOS-26 assimilation.

The app ships **zero** real glass APIs (`glassEffect`, `GlassEffectContainer`,
`.buttonStyle(.glass)`, `.glassProminent`, `scrollEdgeEffect`, `backgroundExtensionEffect` — all
confirmed absent). Its three floating canvas toolbars are byte-identical recipes
(`bgChrome.opacity(0.92)` + hairline stroke + `.black.opacity(0.35)` shadow), so one shared
modifier fixes all three:

- **Convert to glass** (the floating navigation/control layer): the three canvas toolbars
  (`CanvasZoomToolbar.swift:52`, `CanvasCenterToolbar.swift:115`, `VisualToolPalette.swift:34`),
  the selection HUD + toasts + stage banner, and the free-floating popover cards
  (`NodeEditPopover`, `QuickFixCard`, `CitationOverlay`, `EdgeEditPopover`, `RenderFailedSheet` —
  note these are ZStack overlays, **not** real `.popover`, so they get no system glass today).
  Wrap the canvas overlays in **one `GlassEffectContainer`** so they morph/merge when they
  overlap; use `.buttonStyle(.glass)` for tool buttons and `.glassProminent` for the active tool.
- **Do NOT convert** content backgrounds: `bgApp/bgPanel/bgSurface/bgField`, the editor code
  background, panel/inspector bodies, the canvas, the status bar. Glass is for the floating
  layer only.
- **Theme risk (real):** the 10 Zed Trek palettes are saturated and opaque and force
  light/dark via `ThemeMode`; naive `.glassEffect(.regular)` samples underlying content, not
  your brand color, and the vivid diagram will bleed through. **Mitigation:** always tint —
  `.glassEffect(.regular.tint(tokens.palette.bgChrome), in: shape)` — and test all 10 themes ×
  light/dark. The current `glassBg` token is a *solid* color at 0.90 opacity (no blur); retiring
  it in favor of real glass is the intent the naming already signals.
- Then layer `.scrollEdgeEffect(.soft)` on scroll containers under pinned chrome and
  `.backgroundExtensionEffect()` on the canvas so the floating glass genuinely lenses the diagram.

**Sequencing note:** Move 3 lands *after* Move 1 — real sheets/popovers get system glass for
free, and `scrollEdgeEffect`/`backgroundExtensionEffect` need real glass to blend into.

---

## Prioritized roadmap

Effort: S ≈ hours, M ≈ 1–2 days, L ≈ multi-day. Impact weighted by user-visible reach.

| Prio | Item | Axis | Impact | Effort |
|------|------|------|--------|--------|
| **P0** | B1 iPad toolbar (wrap `regularLayout` in `NavigationStack` or move controls into `TitlebarView`) | Parity | High | S |
| **P0** | B2 render `SettingsSheet` + Settings entry on iPhone compact | Parity | High | S |
| **P0** | Move 2 — shared `PlaygroundButtonStyle` (press/hover/cursor/focus/disabled) | Interaction | High | M |
| **P0** | B3 remove hardcoded `"1044"`/`"—"`; cut status bar to 2–3 real signals | Hierarchy | Med | S |
| **P1** | Move 1a — `NavigationSplitView` + `.inspector()` for the three columns | Hierarchy + Parity | High | L |
| **P1** | Move 1b — hand-rolled overlays → real `.sheet`/`.popover` + detents | Hierarchy + Parity | High | M |
| **P1** | Move 3a — `.glassChrome()` modifier + `GlassEffectContainer` for the 3 canvas toolbars + HUD/toasts + `.buttonStyle(.glass)` | Liquid Glass | High | M |
| **P1** | 44pt touch targets on shared chrome (rail 38→44, inspector-close 24, mode pills 22, swatches 20) when `canImport(UIKit)` | Parity | High | S |
| **P1** | Elevate one hero surface (canvas) + one prominent primary action; demote status/rail/inspector noise | Hierarchy | High | M |
| **P2** | Move 3b — retire `glassBg`/`Surface(.glass)`; floating popover cards → glass | Liquid Glass | Med | M |
| **P2** | Canvas hover-to-highlight (reuse `elementAtHover`, draw pre-selection ring); fix touch context-menu targeting (B: hover-dependent) | Interaction + Parity | Med | M |
| **P2** | `.rendering` loading state on `PreviewCanvas` (spinner / `.redacted`); retry-in-flight state on `RenderFailedSheet` | Interaction | Med | S |
| **P2** | Empty states → `ContentUnavailableView` (Corpus / Snippets / History) | Interaction | Med | S |
| **P2** | Typography: collapse 12/12.5/13 near-dupes to ~4 real steps; raise 10–10.5pt body off the floor; route through tokens | Hierarchy | Med | M |
| **P2** | De-border: replace uniform hairline outlines on every band with background-tone contrast; one real border max | Hierarchy | Med | S |
| **P3** | `.scrollEdgeEffect(.soft)` on scroll containers; `.backgroundExtensionEffect()` on canvas | Liquid Glass | Low-Med | S |
| **P3** | Animated segmented/mode selectors via `matchedGeometryEffect`; `PillSwitch` press/hover | Interaction | Low | S |
| **P3** | B4 mark or remove non-functional inspector controls (Arrange / direction) | Hierarchy | Med | S |

---

## Per-axis findings (detail)

### Information hierarchy
- 7–8 equally-weighted chrome bands (unified toolbar, 52pt rail, 236pt panel, content region
  with 2–3 sub-bars, 312pt inspector, diagnostics drawer, 10-segment status bar); no dominant
  content surface, no visible primary action. In `.code` mode the diagram isn't even visible.
- Convert/Export are ambiguous icon-only glyphs (`arrow.left.arrow.right`, `square.and.arrow.up`)
  occupying the primary title slot; the real primary verb (render/preview) has no CTA.
- Status bar: 10 low-contrast segments, several build/worker telemetry, two of them fake (B3).
- Content region prepends up to 3 thin control strips before any editor (`EditorPane.swift:22-49`).
- Type scale has too many near-identical sizes (12 / 12.5 / 13) to encode rank; lots of body
  text at 10–10.5pt below comfortable macOS reading size.
- Over-boxed: nearly every region draws its own hairline border, so none stands out.

### Liquid Glass
- Zero real glass APIs; three fakes — `Surface(.glass)` (material behind a tint that occludes
  the blur), `glassBg` (solid color, no blur), and ~20 manual `fill+stroke+shadow` floating
  surfaces. Full migration map with file:line and the exact API per surface is in Move 3.
- Real `.popover`/`.sheet`-presented content already inherits system glass on 26 — don't
  double-glass those.

### Interaction states
- ~110 `.plain` buttons, no shared `ButtonStyle` → no press, no hover, no cursor, no focus,
  no disabled dimming (Move 2 fixes all five).
- Canvas: selection rings exist but no pre-selection hover highlight; sequence/Gantt have no
  hover at all.
- No loading state on the main canvas during `.rendering`; retry button has no in-flight state.
- Empty states hand-rolled instead of `ContentUnavailableView` (inconsistent icon/copy).
- Segmented selectors snap with no sliding indicator.

### iOS/macOS parity
- iPhone-compact path is well-built (`NavigationStack`, detents, drag indicator). The
  **iPad-regular path inherits the macOS shell wholesale** and breaks (B1, overflow, hover-only
  context menu). Adaptation rests on a single `horizontalSizeClass == .compact` test — iPad
  portrait is `.regular`, so it never falls back.
- Settings unreachable on iPhone (B2); Settings sheet is a fixed 748×520 macOS-chrome overlay
  with an 11×11 traffic-light dismiss dot (below 44pt).
- Touch targets below 44pt HIG minimum throughout shared chrome.
- Keyboard shortcuts (`⌘,`, scoped `⌘Z`/`⌘⇧Z`) with no on-screen touch equivalent.

---

## Suggested sequencing

1. **P0 quick wins first** (B1, B2, B3, shared button style) — high reach, low-to-medium cost,
   ships value before the structural refactor.
2. **Move 1** (native containers) — the enabling refactor; resolves hierarchy + parity together.
3. **Move 3** (glass) — after Move 1, so sheets/popovers already carry system glass and the
   canvas has real glass for `scrollEdgeEffect`/`backgroundExtensionEffect` to blend into.
4. **P2/P3 tail** — localized polish, done opportunistically.

All chrome tinting must route through `tokens.palette` to keep the 10 Zed Trek themes intact;
every glass change must be spot-checked across all 10 themes × light/dark.

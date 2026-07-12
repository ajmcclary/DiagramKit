# DiagramKitSample design-system verification

- Date: 2026-07-12
- Verification base: `d7c114e5` (completion changes are in this document's commit)
- macOS snapshot viewport: 960 × 640 application board; 420 × 260 theme cards
- iPhone runtime: iPhone 17 Pro Max, iOS 27.0 simulator, compact width
- iPad runtime: iPad Pro 11-inch (M5), iOS 27.0 simulator, regular width
- Visual precision: `0.99`; perceptual precision: `0.98`

## Theme matrix

Every row passed the WCAG assertions in `DSContrastTests` and its committed
SwiftUI specimen snapshot in `DesignSystem/__Snapshots__/DSSnapshotTests`.
The five starred themes also passed the composite application-surface snapshot
covering shell chrome, editor tabs, diagnostics, export, settings, corpus, and
the visual overlay.

| Theme | Mode | Result |
|---|---|---|
| Black Alert* | Dark | Pass |
| Black Alert | Light | Pass |
| Borg Cube* | Dark | Pass |
| Borg Cube | Light | Pass |
| Command | Dark | Pass |
| Command | Light | Pass |
| Federation | Dark | Pass |
| Federation | Light | Pass |
| LCARS* | Dark | Pass |
| LCARS* | Light | Pass |
| Mission Control | Dark | Pass |
| Mission Control | Light | Pass |
| Ready Room | Dark | Pass |
| Ready Room | Light | Pass |
| Red Alert* | Dark | Pass |
| Red Alert | Light | Pass |
| Sick Bay | Dark | Pass |
| Sick Bay | Light | Pass |
| Yellow Alert | Dark | Pass |
| Yellow Alert | Light | Pass |

## Runtime and responsive sweep

| Check | Result | Evidence |
|---|---|---|
| macOS representative surfaces | Pass | 25 committed snapshot baselines; five application boards and all 20 specimen cards |
| iPhone compact layout | Pass | Built and launched on iPhone 17 Pro Max; compact navigation actions collapse to one reachable menu and sample controls remain reachable |
| iPad regular layout | Pass | Built and launched on iPad Pro 11-inch; split editor, rail, visual tools, zoom controls, and compact status fallback render without clipping or wrapping |
| macOS wide layout | Pass | `DSShellWidth.wide` resolves split columns and exposes Settings, Inspector, Export, and Convert |
| Minimum targets | Pass | iOS resolves 44 pt and macOS resolves 28 pt minimum interactive targets |

The first iPhone run exposed four full-size navigation actions competing with
the title; they were consolidated into one compact menu. The first iPad run
exposed status metrics wrapping vertically; `ViewThatFits` now selects a
non-wrapping compact status presentation. Both fixes were rebuilt and visually
rechecked on their simulators before this report was recorded.

## Accessibility sweep

| Preference | Result | Behavior verified |
|---|---|---|
| Increased Contrast | Pass | Resolves a high-contrast theme and retains required text, accent, focus-border, and syntax contrast |
| Reduce Motion | Pass | Resolves reduced motion and removes control animation duration |
| Differentiate Without Color | Pass | Status presentation includes icon and text without changing status meaning |
| Reduce Transparency | Pass | Glass surfaces resolve to opaque semantic chrome |

## Reproduction

```bash
Scripts/check_codeeditor_design_system.sh
Scripts/check-sample-design-adherence.sh
swift test --filter DSContrastTests
swift test --filter DSSnapshotTests
swift test --filter DSResponsiveLayoutTests
swift test --filter DSAccessibilityTests
xcodebuild -scheme DiagramKitSample -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
xcodebuild -scheme DiagramKitSample -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build
```

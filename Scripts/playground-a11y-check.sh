#!/usr/bin/env bash
#
# Scripts/playground-a11y-check.sh
#
# Opt-in CI lane for the DiagramPlayground accessibility audit.
# Mirrors the policy of Scripts/linux-check.sh: not invoked by
# bootstrap-smoke-check, run separately when needed.
#
# Usage:
#   Scripts/playground-a11y-check.sh
#
# Requires xcodegen (brew install xcodegen) and Xcode 15+.
#
# Known limitations (2026-05-15 / Xcode 26.4):
#   * Tests must be enumerated by explicit -only-testing:<class>/<method>
#     because class-level filters trigger an Xcode test-runner bug
#     ("The bundle identifier for DiagramPlayground couldn't be read").
#     Tracked in REVIEW.md Session 16.
#   * Preview-related tests use the editingFlow1 state (inspector
#     closed). Opening the inspector covers the preview surface; that
#     layout bug is also tracked in Session 16.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/Examples/DiagramPlayground/DiagramPlayground.xcodeproj"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "✗ xcodegen not installed (brew install xcodegen)" >&2
    exit 2
fi

echo "▶ Regenerating $PROJECT…"
(cd "$ROOT/Examples/DiagramPlayground" && xcodegen generate >/dev/null)

echo "▶ Building DiagramPlaygroundUITests for testing…"
xcodebuild \
    -project "$PROJECT" \
    -scheme DiagramPlayground \
    -destination 'platform=macOS,arch=arm64' \
    build-for-testing -quiet

echo "▶ Running accessibility audit + identifier-presence tests…"
xcodebuild \
    -project "$PROJECT" \
    -scheme DiagramPlayground \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:DiagramPlaygroundUITests/SmokeTests/testAppLaunchesEmptyState \
    -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testEditorPane_allIdentifiersPresent \
    -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testToolbar_macOS_allIdentifiersPresent \
    -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testSamplePanel_searchControlsPresent \
    -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testSmallPickers_alwaysVisibleIdentifiersPresent \
    -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testSmallPickers_themeMenuVisibleAfterPopoverOpens \
    -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testPreviewToolbar_allIdentifiersPresent \
    -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testPreviewCanvas_modePickerPresent \
    -only-testing:DiagramPlaygroundUITests/AccessibilityAuditTests/testEmptyState \
    -only-testing:DiagramPlaygroundUITests/AccessibilityAuditTests/testEditingState \
    -only-testing:DiagramPlaygroundUITests/AccessibilityAuditTests/testSelectionState \
    -only-testing:DiagramPlaygroundUITests/AccessibilityAuditTests/testErrorState \
    -only-testing:DiagramPlaygroundUITests/AccessibilityAuditTests/testThemePickerOpenState \
    test-without-building

echo "✓ Playground accessibility audit passed"

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

    @Test func everyFamilyModeMapsToAChromeFamily() {
        // The canvas-follow name convention "<displayName> <Mode>" resolves for
        // every ZedTrekTheme family in both modes.
        for family in ZedTrekTheme.allCases {
            for mode in ["Dark", "Light"] {
                #expect(DiagramTheme.theme(named: "\(family.displayName) \(mode)") != nil,
                        "canvas follow would fail for \(family.displayName) \(mode)")
            }
        }
    }
}

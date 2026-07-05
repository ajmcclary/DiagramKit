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

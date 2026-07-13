import DesignKitThemes
import Foundation
import Testing

@Suite("Design-system contrast")
struct DSContrastTests {
    @Test("all generated themes meet required contrast")
    func generatedThemes() throws {
        for variant in DSThemeVariant.allCases {
            let theme = variant.theme
            try expectContrast(
                theme.colors.textPrimary,
                on: theme.colors.windowBackground,
                minimum: 4.5,
                role: "text/background",
                theme: theme.name
            )
            try expectContrast(
                theme.colors.onAccent,
                on: theme.colors.accent,
                minimum: 4.5,
                role: "onAccent/accent",
                theme: theme.name
            )
            try expectContrast(
                theme.colors.borderFocused,
                on: theme.colors.windowBackground,
                minimum: 3,
                role: "borderFocused/background",
                theme: theme.name
            )
            for (role, syntax) in theme.colors.syntax.sorted(by: { $0.key < $1.key }) {
                try expectContrast(
                    syntax.foreground,
                    on: theme.colors.editorBackground,
                    minimum: 4.5,
                    role: "syntax.\(role)/editor",
                    theme: theme.name
                )
            }
        }
    }

    private func expectContrast(
        _ foreground: DSColorValue,
        on background: DSColorValue,
        minimum: Double,
        role: String,
        theme: String
    ) throws {
        let ratio = try contrast(foreground, background)
        #expect(
            ratio >= minimum,
            "\(theme) \(role) is \(ratio.formatted(.number.precision(.fractionLength(2)))):1; expected at least \(minimum):1"
        )
    }

    private func contrast(_ foreground: DSColorValue, _ background: DSColorValue) throws -> Double {
        let foregroundLuminance = try luminance(foreground)
        let backgroundLuminance = try luminance(background)
        return (max(foregroundLuminance, backgroundLuminance) + 0.05)
            / (min(foregroundLuminance, backgroundLuminance) + 0.05)
    }

    private func luminance(_ color: DSColorValue) throws -> Double {
        let hex = color.hex.dropFirst()
        guard hex.count == 6, let value = Int(hex, radix: 16) else {
            throw ContrastError.invalidHex(color.hex)
        }
        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private func linear(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}

private enum ContrastError: Error {
    case invalidHex(String)
}

import SwiftUI
import DiagramKitSampleDesignSystem

@available(*, deprecated, renamed: "DSThemeFamily")
typealias PlaygroundThemeFamily = DSThemeFamily

@available(*, deprecated, renamed: "DSThemeMode")
typealias PlaygroundThemeMode = DSThemeMode

extension PlaygroundTokens {
    init(dsTheme: DSTheme) {
        self.palette = PlaygroundPalette(dsTheme: dsTheme)
    }
}

extension PlaygroundPalette {
    init(dsTheme theme: DSTheme) {
        let colors = theme.colors
        self.init(
            bgApp: colors.windowBackground.color,
            bgSurface: colors.surfaceBackground.color,
            bgElevated: colors.elevatedSurfaceBackground.color,
            bgSunken: colors.editorBackground.color,
            fg1: colors.textPrimary.color,
            fg2: colors.textSecondary.color,
            fg3: colors.textPlaceholder.color,
            accent: colors.accent.color,
            borderHairline: colors.border.color,
            borderSubtle: colors.borderVariant.color,
            borderStrong: colors.borderFocused.color,
            statusSuccess: colors.success.color,
            statusWarning: colors.warning.color,
            statusError: colors.error.color,
            statusInfo: colors.info.color,
            rowHover: colors.elementHover.color,
            rowSelected: colors.elementSelected.color
        )
        bgWindow = colors.windowBackground.color
        bgRail = colors.windowBackground.color
        bgPanel = colors.panelBackground.color
        bgSheet = colors.elevatedSurfaceBackground.color
        bgSidebarNav = colors.surfaceBackground.color
        bgChrome = colors.titleBarBackground.color
        bgCard = colors.surfaceBackground.color
        bgTrack = colors.element.color
        bgField = colors.editorBackground.color
        borderWarm = colors.border.color
        borderFaint = colors.borderVariant.color
        borderSwatch = colors.borderSelected.color
        borderDestructive = colors.value("error.border").color
        textFaint = colors.textPlaceholder.color
        gutter = colors.value("editor.line_number").color
        textFaintest = colors.textDisabled.color
        onAccent = colors.onAccent.color
        accentSecondary = accent(at: 1, colors: colors)
        accentPeach = accent(at: 2, colors: colors)
        catCyan = syntax("function", colors: colors)
        catMint = syntax("string", colors: colors)
        catPurple = syntax("type", colors: colors)
        trafficRed = colors.error.color
        trafficYellow = colors.warning.color
        trafficGreen = colors.success.color
    }

    private func accent(at index: Int, colors: DSThemeColors) -> Color {
        guard colors.accents.indices.contains(index) else { return colors.accent.color }
        return colors.accents[index].color
    }

    private func syntax(_ role: String, colors: DSThemeColors) -> Color {
        colors.syntax[role]?.foreground.color ?? colors.textPrimary.color
    }
}

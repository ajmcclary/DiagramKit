import DesignKitThemes
import SwiftUI

public extension Tokens.Color {
    /// SwiftUI bridge kept ultra-short because it appears at hundreds of
    /// call sites as `theme.colors.<role>.color`.
    var color: Color { Color(tokens: self) }
}

/// Role accessors preserving the former generated-theme spellings, backed
/// by DesignKit's typed groups. Views write `theme.colors.textSecondary`.
public struct DSColors {
    let theme: Theme

    public var accent: Tokens.Color { theme.style.text.accent }
    public var onAccent: Tokens.Color { theme.glass.onAccent }
    public var windowBackground: Tokens.Color { theme.style.background }
    public var surfaceBackground: Tokens.Color { theme.style.chrome.surfaceBackground }
    public var elevatedSurfaceBackground: Tokens.Color { theme.style.chrome.elevatedSurfaceBackground }
    public var panelBackground: Tokens.Color { theme.style.chrome.panelBackground }
    public var editorBackground: Tokens.Color { theme.style.editor.background }
    public var editorForeground: Tokens.Color { theme.style.editor.foreground }
    public var editorGutterBackground: Tokens.Color { theme.style.editor.gutterBackground }
    public var titleBarBackground: Tokens.Color { theme.style.chrome.titleBarBackground }
    public var toolbarBackground: Tokens.Color { theme.style.chrome.toolbarBackground }
    public var tabBarBackground: Tokens.Color { theme.style.chrome.tabBarBackground }
    public var statusBarBackground: Tokens.Color { theme.style.chrome.statusBarBackground }
    public var textPrimary: Tokens.Color { theme.style.text.base }
    public var textSecondary: Tokens.Color { theme.style.text.muted }
    public var textDisabled: Tokens.Color { theme.style.text.disabled }
    public var textPlaceholder: Tokens.Color { theme.style.text.placeholder }
    public var iconPrimary: Tokens.Color { theme.style.icon.base }
    public var iconMuted: Tokens.Color { theme.style.icon.muted }
    public var iconDisabled: Tokens.Color { theme.style.icon.disabled }
    public var border: Tokens.Color { theme.style.borders.base }
    public var borderVariant: Tokens.Color { theme.style.borders.variant }
    public var borderFocused: Tokens.Color { theme.style.borders.focused }
    public var borderSelected: Tokens.Color { theme.style.borders.selected }
    public var element: Tokens.Color { theme.style.elements.element.background }
    public var elementHover: Tokens.Color { theme.style.elements.element.hover }
    public var elementActive: Tokens.Color { theme.style.elements.element.active }
    public var elementSelected: Tokens.Color { theme.style.elements.element.selected }
    public var ghostElement: Tokens.Color { theme.style.elements.ghostElement.background }
    public var ghostElementHover: Tokens.Color { theme.style.elements.ghostElement.hover }
    public var ghostElementActive: Tokens.Color { theme.style.elements.ghostElement.active }
    public var ghostElementSelected: Tokens.Color { theme.style.elements.ghostElement.selected }
    public var success: Tokens.Color { theme.style.status.success.base }
    public var warning: Tokens.Color { theme.style.status.warning.base }
    public var error: Tokens.Color { theme.style.status.error.base }
    public var info: Tokens.Color { theme.style.status.info.base }
    public var searchMatchBackground: Tokens.Color { theme.style.search.matchBackground }
    public var accents: [Tokens.Color] { theme.style.accents }
    public var syntax: [String: SyntaxStyle] { theme.style.syntax }

    /// Dotted-role escape hatch for the sites that used `value("…")`
    /// against the old flat dictionary. Covers exactly the roles used in
    /// this codebase; grep before extending.
    public func value(_ role: String) -> Tokens.Color {
        switch role {
        case "editor.active_line.background": theme.style.editor.activeLineBackground
        case "editor.active_line_number": theme.style.editor.activeLineNumber
        case "editor.document_highlight.read_background": theme.style.editor.documentHighlightRead
        case "editor.line_number": theme.style.editor.lineNumber
        case "error.background": theme.style.status.error.background
        case "info.background": theme.style.status.info.background
        case "success.background": theme.style.status.success.background
        case "warning.background": theme.style.status.warning.background
        default: theme.style.editor.foreground
        }
    }
}

public extension Theme {
    /// Former generated-theme accessor surface. See `DSColors`.
    var colors: DSColors { DSColors(theme: self) }
}

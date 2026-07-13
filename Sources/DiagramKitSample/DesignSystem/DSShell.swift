import Foundation

public enum DSShellWidth: CaseIterable, Equatable, Sendable {
    case compact
    case regular
    case wide

    public static func resolve(platform: DSPlatform, viewportWidth: CGFloat) -> Self {
        if viewportWidth < 600 {
            return .compact
        }
        if viewportWidth < 1_100 || platform == .iOS {
            return .regular
        }
        return .wide
    }
}

public enum DSShellLayout: Equatable, Sendable {
    case singleColumn
    case splitColumns
}

public enum DSShellAction: CaseIterable, Hashable, Sendable {
    case settings
    case inspector
    case export
    case convert
}

/// The semantic roles used by application chrome. Diagram/canvas themes are
/// deliberately absent from this API so content styling cannot leak into the
/// navigation, toolbar, panel, sheet, or status surfaces.
public struct DSShellChromeResolution: Equatable, Sendable {
    public let navigation: DSColorValue
    public let toolbar: DSColorValue
    public let panel: DSColorValue
    public let status: DSColorValue
    public let sheet: DSColorValue
    public let separator: DSColorValue
    public let layout: DSShellLayout
    public let showsInspectorColumn: Bool
    public let reachableActions: Set<DSShellAction>

    public static func resolve(theme: DSTheme, width: DSShellWidth) -> Self {
        let usesColumns = width != .compact
        return Self(
            navigation: theme.colors.titleBarBackground,
            toolbar: theme.colors.toolbarBackground,
            panel: theme.colors.panelBackground,
            status: theme.colors.statusBarBackground,
            sheet: theme.colors.surfaceBackground,
            separator: theme.colors.borderVariant,
            layout: usesColumns ? .splitColumns : .singleColumn,
            showsInspectorColumn: usesColumns,
            reachableActions: Set(DSShellAction.allCases)
        )
    }
}

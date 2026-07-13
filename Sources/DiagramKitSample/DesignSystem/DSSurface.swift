import DesignKitThemes
import SwiftUI

public enum DSElevation: Equatable, Sendable {
    case none
    case popover
}

public enum DSSurfaceRole: Equatable, Sendable {
    case card
    case panel
    case sunken
    case tabBar
    case titleBar
    case toolbar
    case statusBar
    case popover

    public var elevation: DSElevation {
        self == .popover ? .popover : .none
    }
}

public struct DSGlassResolution: Equatable, Sendable {
    public let usesMaterial: Bool
    public let elevation: DSElevation

    public static func resolve(
        role: DSSurfaceRole,
        environment context: DSContext
    ) -> Self {
        Self(
            usesMaterial: !context.usesOpaqueChrome,
            elevation: role.elevation
        )
    }
}

public struct DSSurface<Content: View>: View {
    private let role: DSSurfaceRole
    private let content: Content
    @Environment(\.designTheme) private var theme
    @Environment(\.dsContext) private var context

    public init(
        role: DSSurfaceRole = .card,
        @ViewBuilder content: () -> Content
    ) {
        self.role = role
        self.content = content()
    }

    public var body: some View {
        content
            .background(backgroundColor, in: shape)
            .overlay {
                if role.hasOutline {
                    shape.stroke(
                        theme.colors.borderVariant.color,
                        lineWidth: Tokens.Shape.strokeThin
                    )
                }
            }
            .shadow(
                color: shadowColor,
                radius: role.elevation == .popover ? Tokens.Shape.radiusMD : 0,
                y: role.elevation == .popover ? Tokens.Spacing.xs : 0
            )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: role.isEdgeToEdge ? 0 : Tokens.Shape.radiusMD,
            style: .continuous
        )
    }

    private var backgroundColor: Color {
        switch role {
        case .card: theme.colors.surfaceBackground.color
        case .panel: theme.colors.panelBackground.color
        case .sunken: theme.colors.editorBackground.color
        case .tabBar: theme.colors.tabBarBackground.color
        case .titleBar: theme.colors.titleBarBackground.color
        case .toolbar: theme.colors.toolbarBackground.color
        case .statusBar: theme.colors.statusBarBackground.color
        case .popover: theme.colors.elevatedSurfaceBackground.color
        }
    }

    private var shadowColor: Color {
        role.elevation == .popover
            ? Color.black.opacity(Tokens.Opacity.light)
            : .clear
    }
}

/// A floating glass container (tool palettes, canvas pills, HUDs). Always
/// rounded and softly elevated — glass surfaces float over the canvas, so
/// they never render edge-to-edge like `DSSurface` chrome roles.
public struct DSGlassSurface<Content: View>: View {
    private let role: DSSurfaceRole
    private let content: Content
    @Environment(\.designTheme) private var theme
    @Environment(\.dsContext) private var context

    public init(
        role: DSSurfaceRole = .popover,
        @ViewBuilder content: () -> Content
    ) {
        self.role = role
        self.content = content()
    }

    public var body: some View {
        let resolution = DSGlassResolution.resolve(
            role: role,
            environment: context
        )
        Group {
            if resolution.usesMaterial {
                content
                    .background(.ultraThinMaterial, in: shape)
                    .background(
                        theme.colors.elevatedSurfaceBackground.color
                            .opacity(Tokens.Opacity.glassFill),
                        in: shape
                    )
            } else {
                content.background(opaqueBackground, in: shape)
            }
        }
        .clipShape(shape)
        .overlay {
            shape.stroke(
                theme.colors.borderVariant.color
                    .opacity(Tokens.Opacity.heavy),
                lineWidth: Tokens.Shape.strokeThin
            )
        }
        .shadow(
            color: Color.black.opacity(Tokens.Opacity.light),
            radius: Tokens.Shape.radiusMD,
            y: Tokens.Spacing.xxs
        )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Tokens.Shape.radiusMD, style: .continuous)
    }

    private var opaqueBackground: Color {
        switch role {
        case .card: theme.colors.surfaceBackground.color
        case .panel: theme.colors.panelBackground.color
        case .sunken: theme.colors.editorBackground.color
        case .tabBar: theme.colors.tabBarBackground.color
        case .titleBar: theme.colors.titleBarBackground.color
        case .toolbar: theme.colors.toolbarBackground.color
        case .statusBar: theme.colors.statusBarBackground.color
        case .popover: theme.colors.elevatedSurfaceBackground.color
        }
    }
}

private extension DSSurfaceRole {
    /// Chrome bars and side panels run edge-to-edge: square corners, no
    /// perimeter stroke. Their edges are hairline separators drawn by the
    /// shell, not by the surface itself.
    var isEdgeToEdge: Bool {
        switch self {
        case .tabBar, .titleBar, .toolbar, .statusBar, .panel, .sunken: true
        case .card, .popover: false
        }
    }

    var hasOutline: Bool { !isEdgeToEdge }
}

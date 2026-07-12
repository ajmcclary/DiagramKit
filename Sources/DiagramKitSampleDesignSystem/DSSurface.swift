import SwiftUI

public enum DSElevation: Equatable, Sendable {
    case none
    case popover
}

public enum DSSurfaceRole: Equatable, Sendable {
    case card
    case panel
    case sunken
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
        environment: DSResolvedEnvironment
    ) -> Self {
        Self(
            usesMaterial: !environment.usesOpaqueChrome,
            elevation: role.elevation
        )
    }
}

public struct DSSurface<Content: View>: View {
    private let role: DSSurfaceRole
    private let content: Content
    @Environment(\.dsEnvironment) private var environment

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
                shape.stroke(
                    environment.theme.colors.borderVariant.color,
                    lineWidth: DSTokens.Stroke.thin
                )
            }
            .shadow(
                color: shadowColor,
                radius: role.elevation == .popover ? DSTokens.Radius.md : 0,
                y: role.elevation == .popover ? DSTokens.Spacing.xs : 0
            )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DSTokens.Radius.md, style: .continuous)
    }

    private var backgroundColor: Color {
        switch role {
        case .card: environment.theme.colors.surfaceBackground.color
        case .panel: environment.theme.colors.panelBackground.color
        case .sunken: environment.theme.colors.editorBackground.color
        case .popover: environment.theme.colors.elevatedSurfaceBackground.color
        }
    }

    private var shadowColor: Color {
        role.elevation == .popover
            ? Color.black.opacity(DSTokens.Opacity.light)
            : .clear
    }
}

public struct DSGlassSurface<Content: View>: View {
    private let role: DSSurfaceRole
    private let content: Content
    @Environment(\.dsEnvironment) private var environment

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
            environment: environment
        )
        Group {
            if resolution.usesMaterial {
                content
                    .background(.ultraThinMaterial, in: shape)
                    .background(
                        environment.theme.colors.elevatedSurfaceBackground.color
                            .opacity(DSTokens.Opacity.glassFill),
                        in: shape
                    )
            } else {
                content.background(opaqueBackground, in: shape)
            }
        }
        .overlay {
            shape.stroke(
                environment.theme.colors.borderVariant.color
                    .opacity(DSTokens.Opacity.heavy),
                lineWidth: DSTokens.Stroke.thin
            )
        }
        .shadow(
            color: resolution.elevation == .popover
                ? Color.black.opacity(DSTokens.Opacity.light)
                : .clear,
            radius: resolution.elevation == .popover ? DSTokens.Radius.md : 0,
            y: resolution.elevation == .popover ? DSTokens.Spacing.xs : 0
        )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DSTokens.Radius.md, style: .continuous)
    }

    private var opaqueBackground: Color {
        switch role {
        case .card: environment.theme.colors.surfaceBackground.color
        case .panel: environment.theme.colors.panelBackground.color
        case .sunken: environment.theme.colors.editorBackground.color
        case .popover: environment.theme.colors.elevatedSurfaceBackground.color
        }
    }
}

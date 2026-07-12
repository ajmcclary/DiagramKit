import SwiftUI

public enum DSButtonRole: Sendable {
    case primary
    case secondary
    case ghost
    case destructive
}

public enum DSButtonSize: Sendable {
    case regular
    case compact

    var height: CGFloat {
        switch self {
        case .regular: DSTokens.Control.button
        case .compact: DSTokens.Control.buttonCompact
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .regular: DSTokens.Spacing.md
        case .compact: DSTokens.Spacing.sm
        }
    }
}

public enum DSButtonFillRole: Equatable, Sendable {
    case accent
    case accentHover
    case accentActive
    case element
    case elementHover
    case elementActive
    case ghost
    case ghostHover
    case ghostActive
    case destructive
    case destructiveHover
    case destructiveActive
}

public enum DSButtonForegroundRole: Sendable {
    case onAccent
    case primary
    case error
}

public struct DSButtonVisualState: Equatable, Sendable {
    public let fillRole: DSButtonFillRole
    public let opacity: CGFloat
    public let scale: CGFloat
    public let showsFocusRing: Bool

    public static func resolve(
        role: DSButtonRole,
        isHovered: Bool,
        isPressed: Bool,
        isFocused: Bool,
        isEnabled: Bool
    ) -> Self {
        guard isEnabled else {
            return Self(
                fillRole: role.idleFill,
                opacity: DSTokens.Opacity.disabled,
                scale: DSTokens.Interaction.pressedScale,
                showsFocusRing: false
            )
        }
        let fillRole = if isPressed {
            role.activeFill
        } else if isHovered {
            role.hoverFill
        } else {
            role.idleFill
        }
        return Self(
            fillRole: fillRole,
            opacity: 1,
            scale: DSTokens.Interaction.pressedScale,
            showsFocusRing: isFocused
        )
    }
}

public struct DSButtonStyle: ButtonStyle {
    let role: DSButtonRole
    let size: DSButtonSize

    @Environment(\.dsEnvironment) private var environment
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false

    public init(role: DSButtonRole, size: DSButtonSize = .regular) {
        self.role = role
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        let state = DSButtonVisualState.resolve(
            role: role,
            isHovered: isHovered,
            isPressed: configuration.isPressed,
            isFocused: isFocused,
            isEnabled: isEnabled
        )
        let shape = RoundedRectangle(cornerRadius: DSTokens.Radius.sm, style: .continuous)
        configuration.label
            .dsFont(.badge)
            .foregroundStyle(role.foreground.color(in: environment.theme))
            .padding(.horizontal, size.horizontalPadding)
            .frame(minHeight: max(size.height, environment.minimumTarget))
            .background(state.fillRole.color(in: environment.theme), in: shape)
            .overlay {
                shape.stroke(
                    state.showsFocusRing
                        ? environment.theme.colors.borderFocused.color
                        : environment.theme.colors.borderVariant.color,
                    lineWidth: state.showsFocusRing
                        ? DSTokens.Stroke.medium
                        : DSTokens.Stroke.thin
                )
            }
            .contentShape(shape)
            .opacity(state.opacity)
            .animation(animation, value: configuration.isPressed)
            .animation(animation, value: isHovered)
            .onHover { isHovered = $0 }
            #if os(macOS)
            .pointerStyle(.link)
            #endif
    }

    private var animation: Animation? {
        guard environment.motion == .standard else { return nil }
        return .easeOut(
            duration: environment.motion.duration(
                milliseconds: DSTokens.DurationMilliseconds.fast
            )
        )
    }
}

public extension ButtonStyle where Self == DSButtonStyle {
    static func ds(
        role: DSButtonRole,
        size: DSButtonSize = .regular
    ) -> DSButtonStyle {
        DSButtonStyle(role: role, size: size)
    }
}

private extension DSButtonRole {
    var idleFill: DSButtonFillRole {
        switch self {
        case .primary: .accent
        case .secondary: .element
        case .ghost: .ghost
        case .destructive: .destructive
        }
    }

    var hoverFill: DSButtonFillRole {
        switch self {
        case .primary: .accentHover
        case .secondary: .elementHover
        case .ghost: .ghostHover
        case .destructive: .destructiveHover
        }
    }

    var activeFill: DSButtonFillRole {
        switch self {
        case .primary: .accentActive
        case .secondary: .elementActive
        case .ghost: .ghostActive
        case .destructive: .destructiveActive
        }
    }

    var foreground: DSButtonForegroundRole {
        switch self {
        case .primary: .onAccent
        case .secondary, .ghost: .primary
        case .destructive: .error
        }
    }
}

private extension DSButtonFillRole {
    func color(in theme: DSTheme) -> Color {
        switch self {
        case .accent: theme.colors.accent.color
        case .accentHover: theme.colors.accents[1].color
        case .accentActive: theme.colors.accents[2].color
        case .element: theme.colors.element.color
        case .elementHover: theme.colors.elementHover.color
        case .elementActive: theme.colors.elementActive.color
        case .ghost: theme.colors.ghostElement.color
        case .ghostHover: theme.colors.ghostElementHover.color
        case .ghostActive: theme.colors.ghostElementActive.color
        case .destructive: theme.colors.value("error.background").color
        case .destructiveHover: theme.colors.error.color.opacity(DSTokens.Opacity.light)
        case .destructiveActive: theme.colors.error.color.opacity(DSTokens.Opacity.disabled)
        }
    }
}

private extension DSButtonForegroundRole {
    func color(in theme: DSTheme) -> Color {
        switch self {
        case .onAccent: theme.colors.onAccent.color
        case .primary: theme.colors.textPrimary.color
        case .error: theme.colors.error.color
        }
    }
}

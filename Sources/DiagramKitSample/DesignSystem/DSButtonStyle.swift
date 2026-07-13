import DesignKitThemes
import SwiftUI

/// Interaction constants formerly generated as `DSTokens.Interaction`
/// (DiagramKit-local extras, not upstream design tokens).
enum DSButtonMetrics {
    static let pressedScale: CGFloat = 1
    static let focusGlow: CGFloat = 1.5
}

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
        case .regular: Tokens.Size.Control.height
        case .compact: Tokens.Size.Control.heightCompact
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .regular: Tokens.Spacing.md
        case .compact: Tokens.Spacing.sm
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
    case elementSelected
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
                opacity: Tokens.Opacity.disabled,
                scale: DSButtonMetrics.pressedScale,
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
            scale: DSButtonMetrics.pressedScale,
            showsFocusRing: isFocused
        )
    }
}

public struct DSButtonStyle: ButtonStyle {
    let role: DSButtonRole
    let size: DSButtonSize

    @Environment(\.designTheme) private var theme
    @Environment(\.dsContext) private var context
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
        let shape = RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM, style: .continuous)
        configuration.label
            .dsFont(.badge)
            .foregroundStyle(role.foreground.color(in: theme))
            .padding(.horizontal, size.horizontalPadding)
            .frame(minHeight: max(size.height, context.minimumTarget))
            .background(state.fillRole.color(in: theme), in: shape)
            .overlay {
                if state.showsFocusRing {
                    shape.stroke(
                        theme.colors.borderFocused.color,
                        lineWidth: Tokens.Shape.strokeMedium
                    )
                } else if role == .destructive {
                    shape.stroke(
                        theme.colors.error.color
                            .opacity(Tokens.Opacity.medium),
                        lineWidth: Tokens.Shape.strokeThin
                    )
                }
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
        guard context.motion == .standard else { return nil }
        return .easeOut(
            duration: context.motion.duration(Tokens.Animation.durFast)
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
    func color(in theme: Theme) -> Color {
        switch self {
        case .accent: theme.colors.accent.color
        case .accentHover: theme.colors.accents[1].color
        case .accentActive: theme.colors.accents[2].color
        case .element: theme.colors.element.color
        case .elementHover: theme.colors.elementHover.color
        case .elementActive: theme.colors.elementActive.color
        case .elementSelected: theme.colors.elementSelected.color
        case .ghost: theme.colors.ghostElement.color
        case .ghostHover: theme.colors.ghostElementHover.color
        case .ghostActive: theme.colors.ghostElementActive.color
        case .destructive: theme.colors.value("error.background").color
        case .destructiveHover: theme.colors.error.color.opacity(Tokens.Opacity.light)
        case .destructiveActive: theme.colors.error.color.opacity(Tokens.Opacity.disabled)
        }
    }
}

private extension DSButtonForegroundRole {
    func color(in theme: Theme) -> Color {
        switch self {
        case .onAccent: theme.colors.onAccent.color
        case .primary: theme.colors.textPrimary.color
        case .error: theme.colors.error.color
        }
    }
}

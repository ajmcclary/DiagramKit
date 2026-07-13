import DesignKitThemes
import SwiftUI

public struct DSSegmentVisualState: Equatable, Sendable {
    public let fillRole: DSButtonFillRole
    public let opacity: CGFloat

    public static func resolve(
        isSelected: Bool,
        isHovered: Bool,
        isEnabled: Bool
    ) -> Self {
        guard isEnabled else {
            return Self(fillRole: .element, opacity: Tokens.Opacity.disabled)
        }
        return Self(
            fillRole: isSelected ? .accent : isHovered ? .elementHover : .element,
            opacity: 1
        )
    }
}

public enum DSIconColorRole: Sendable {
    case primary
    case muted
    case disabled
    case accent
    case onAccent
    case success
    case warning
    case error
    case info
}

public struct DSIconView: View {
    private let icon: DSIcon
    private let size: CGFloat
    private let colorRole: DSIconColorRole
    @Environment(\.designTheme) private var theme
    @Environment(\.dsContext) private var context

    public init(
        _ icon: DSIcon,
        size: CGFloat = Tokens.Size.Icon.sm,
        colorRole: DSIconColorRole = .primary
    ) {
        self.icon = icon
        self.size = size
        self.colorRole = colorRole
    }

    public var body: some View {
        Image(systemName: icon.systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(colorRole.color(in: theme))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

public struct DSIconButton: View {
    private let icon: DSIcon
    private let label: String
    private let role: DSButtonRole
    private let action: () -> Void

    public init(
        _ icon: DSIcon,
        label: String,
        role: DSButtonRole = .ghost,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.role = role
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            DSIconView(icon)
        }
        .buttonStyle(.ds(role: role, size: .compact))
        .accessibilityLabel(label)
    }
}

public struct DSSegmentedControl<Option: Hashable, Label: View>: View {
    private let options: [Option]
    @Binding private var selection: Option
    private let label: (Option) -> Label

    public init(
        _ options: [Option],
        selection: Binding<Option>,
        @ViewBuilder label: @escaping (Option) -> Label
    ) {
        self.options = options
        self._selection = selection
        self.label = label
    }

    public var body: some View {
        HStack(spacing: Tokens.Shape.strokeThin) {
            ForEach(options, id: \.self) { option in
                DSSegmentButton(
                    isSelected: selection == option,
                    action: { selection = option },
                    label: { label(option) }
                )
            }
        }
        .padding(Tokens.Shape.strokeMedium)
        .background(theme.colors.element.color, in: containerShape)
    }

    @Environment(\.designTheme) private var theme
    @Environment(\.dsContext) private var context

    private var containerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Tokens.Shape.radiusChip, style: .continuous)
    }
}

fileprivate struct DSSegmentButton<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @Environment(\.designTheme) private var theme
    @Environment(\.dsContext) private var context
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.isSelected = isSelected
        self.action = action
        self.label = label
    }

    var body: some View {
        let state = DSSegmentVisualState.resolve(
            isSelected: isSelected,
            isHovered: isHovered,
            isEnabled: isEnabled
        )
        Button(action: action) {
            label()
                .dsFont(.badge)
                .foregroundStyle(
                    isSelected
                        ? theme.colors.onAccent.color
                        : theme.colors.textSecondary.color
                )
                .padding(.horizontal, Tokens.Spacing.smMd)
                .frame(minHeight: max(Tokens.Size.Control.chip, context.minimumTarget))
                .background(fillColor(state.fillRole), in: shape)
                .opacity(state.opacity)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM, style: .continuous)
    }

    private func fillColor(_ role: DSButtonFillRole) -> Color {
        switch role {
        case .accent: theme.colors.accent.color
        case .elementHover: theme.colors.elementHover.color
        default: .clear
        }
    }
}

public struct DSChip<Label: View>: View {
    private let isSelected: Bool
    private let action: () -> Void
    private let label: Label

    public init(
        isSelected: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.isSelected = isSelected
        self.action = action
        self.label = label()
    }

    public var body: some View {
        Button(action: action) { label }
            .buttonStyle(.ds(role: isSelected ? .secondary : .ghost, size: .compact))
    }
}

public struct DSChipGroup<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Tokens.Spacing.xs) { content }
    }
}

public struct DSField: View {
    private let label: String
    private let prompt: String?
    @Binding private var text: String
    @Environment(\.designTheme) private var theme
    @Environment(\.dsContext) private var context

    public init(
        _ label: String,
        text: Binding<String>,
        prompt: String? = nil
    ) {
        self.label = label
        self._text = text
        self.prompt = prompt
    }

    public var body: some View {
        TextField(label, text: $text, prompt: prompt.map(Text.init))
            .textFieldStyle(.plain)
            .dsFont(.body)
            .foregroundStyle(theme.colors.textPrimary.color)
            .padding(.horizontal, Tokens.Spacing.sm)
            .frame(minHeight: max(Tokens.Size.Control.row, context.minimumTarget))
            .background(theme.colors.element.color, in: shape)
            .overlay {
                shape.stroke(
                    theme.colors.borderVariant.color,
                    lineWidth: Tokens.Shape.strokeThin
                )
            }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Tokens.Shape.radiusSM, style: .continuous)
    }
}

private extension DSIconColorRole {
    func color(in theme: Theme) -> Color {
        switch self {
        case .primary: theme.colors.iconPrimary.color
        case .muted: theme.colors.iconMuted.color
        case .disabled: theme.colors.iconDisabled.color
        case .accent: theme.colors.accent.color
        case .onAccent: theme.colors.onAccent.color
        case .success: theme.colors.success.color
        case .warning: theme.colors.warning.color
        case .error: theme.colors.error.color
        case .info: theme.colors.info.color
        }
    }
}

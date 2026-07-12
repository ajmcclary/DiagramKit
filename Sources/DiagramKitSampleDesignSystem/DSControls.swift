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
            return Self(fillRole: .element, opacity: DSTokens.Opacity.disabled)
        }
        return Self(
            fillRole: isSelected ? .elementSelected : isHovered ? .elementHover : .element,
            opacity: 1
        )
    }
}

public enum DSIconColorRole: Sendable {
    case primary
    case muted
    case disabled
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
    @Environment(\.dsEnvironment) private var environment

    public init(
        _ icon: DSIcon,
        size: CGFloat = DSTokens.Icon.sm,
        colorRole: DSIconColorRole = .primary
    ) {
        self.icon = icon
        self.size = size
        self.colorRole = colorRole
    }

    public var body: some View {
        Image(systemName: icon.systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(colorRole.color(in: environment.theme))
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
        HStack(spacing: DSTokens.Stroke.thin) {
            ForEach(options, id: \.self) { option in
                DSSegmentButton(
                    isSelected: selection == option,
                    action: { selection = option },
                    label: { label(option) }
                )
            }
        }
        .padding(DSTokens.Stroke.medium)
        .background(environment.theme.colors.element.color, in: containerShape)
        .overlay {
            containerShape.stroke(
                environment.theme.colors.borderVariant.color,
                lineWidth: DSTokens.Stroke.thin
            )
        }
    }

    @Environment(\.dsEnvironment) private var environment

    private var containerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DSTokens.Radius.sm, style: .continuous)
    }
}

private struct DSSegmentButton<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @Environment(\.dsEnvironment) private var environment
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let state = DSSegmentVisualState.resolve(
            isSelected: isSelected,
            isHovered: isHovered,
            isEnabled: isEnabled
        )
        Button(action: action) {
            label()
                .dsFont(.badge)
                .foregroundStyle(environment.theme.colors.textPrimary.color)
                .padding(.horizontal, DSTokens.Spacing.sm)
                .frame(minHeight: max(DSTokens.Control.chip, environment.minimumTarget))
                .background(fillColor(state.fillRole), in: shape)
                .opacity(state.opacity)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DSTokens.Radius.xs, style: .continuous)
    }

    private func fillColor(_ role: DSButtonFillRole) -> Color {
        switch role {
        case .elementSelected: environment.theme.colors.elementSelected.color
        case .elementHover: environment.theme.colors.elementHover.color
        default: environment.theme.colors.element.color
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
        HStack(spacing: DSTokens.Spacing.xs) { content }
    }
}

public struct DSField: View {
    private let label: String
    private let prompt: String?
    @Binding private var text: String
    @Environment(\.dsEnvironment) private var environment

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
            .foregroundStyle(environment.theme.colors.textPrimary.color)
            .padding(.horizontal, DSTokens.Spacing.sm)
            .frame(minHeight: max(DSTokens.Control.row, environment.minimumTarget))
            .background(environment.theme.colors.element.color, in: shape)
            .overlay {
                shape.stroke(
                    environment.theme.colors.borderVariant.color,
                    lineWidth: DSTokens.Stroke.thin
                )
            }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DSTokens.Radius.sm, style: .continuous)
    }
}

private extension DSIconColorRole {
    func color(in theme: DSTheme) -> Color {
        switch self {
        case .primary: theme.colors.iconPrimary.color
        case .muted: theme.colors.iconMuted.color
        case .disabled: theme.colors.iconDisabled.color
        case .onAccent: theme.colors.onAccent.color
        case .success: theme.colors.success.color
        case .warning: theme.colors.warning.color
        case .error: theme.colors.error.color
        case .info: theme.colors.info.color
        }
    }
}

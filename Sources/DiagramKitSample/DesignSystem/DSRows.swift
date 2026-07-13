import DesignKitThemes
import SwiftUI

public enum DSStatusKind: Equatable, Sendable {
    case success
    case warning
    case error
    case info
    case unsupported
}

public struct DSStatusVisualState: Equatable, Sendable {
    public let icon: DSIcon
    public let colorRole: DSIconColorRole
    public let includesText: Bool

    public static func resolve(
        kind: DSStatusKind,
        environment context: DSContext
    ) -> Self {
        Self(
            icon: kind.icon,
            colorRole: kind.colorRole,
            includesText: context.statusPresentation == .iconAndText
        )
    }
}

public struct DSStatusIndicator: View {
    private let kind: DSStatusKind
    private let label: String
    @Environment(\.designTheme) private var theme
    @Environment(\.dsContext) private var context

    public init(_ kind: DSStatusKind, label: String) {
        self.kind = kind
        self.label = label
    }

    public var body: some View {
        let state = DSStatusVisualState.resolve(
            kind: kind,
            environment: context
        )
        HStack(spacing: Tokens.Spacing.xs) {
            DSIconView(state.icon, size: Tokens.Size.Icon.xs, colorRole: state.colorRole)
            if state.includesText {
                Text(label)
                    .dsFont(.caption)
            }
        }
        .foregroundStyle(kind.color(in: theme))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

public struct DSSettingRow<Content: View>: View {
    private let title: String
    private let detail: String?
    private let content: Content
    @Environment(\.designTheme) private var theme
    @Environment(\.dsContext) private var context

    public init(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Tokens.Spacing.md) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                Text(title)
                    .dsFont(.body)
                    .foregroundStyle(theme.colors.textPrimary.color)
                if let detail {
                    Text(detail)
                        .dsFont(.caption)
                        .foregroundStyle(theme.colors.textSecondary.color)
                }
            }
            Spacer(minLength: Tokens.Spacing.md)
            content
        }
        .padding(.vertical, Tokens.Spacing.sm)
        .frame(minHeight: context.minimumTarget)
    }
}

public struct DSSettingGroup<Content: View>: View {
    private let title: String?
    private let content: Content

    public init(
        _ title: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            if let title {
                DSSectionHeader(title)
            }
            content
        }
        .padding(Tokens.Spacing.md)
        .background {
            DSSurface(role: .card) { Color.clear }
        }
    }
}

public struct DSSectionHeader: View {
    private let title: String
    @Environment(\.designTheme) private var theme

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .dsFont(.overline)
            .foregroundStyle(theme.colors.textSecondary.color)
            .accessibilityLabel(title)
    }
}

public struct DSCodeBadge: View {
    private let text: String
    @Environment(\.designTheme) private var theme

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .dsFont(.badge)
            .foregroundStyle(theme.colors.textPrimary.color)
            .padding(.horizontal, Tokens.Spacing.xs)
            .padding(.vertical, Tokens.Spacing.xxs)
            .background(theme.colors.element.color, in: shape)
            .overlay {
                shape.stroke(
                    theme.colors.borderVariant.color,
                    lineWidth: Tokens.Shape.strokeThin
                )
            }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Tokens.Shape.radiusChip, style: .continuous)
    }
}

private extension DSStatusKind {
    var icon: DSIcon {
        switch self {
        case .success: .success
        case .warning, .unsupported: .warning
        case .error: .error
        case .info: .info
        }
    }

    var colorRole: DSIconColorRole {
        switch self {
        case .success: .success
        case .warning, .unsupported: .warning
        case .error: .error
        case .info: .info
        }
    }

    func color(in theme: Theme) -> Color {
        switch self {
        case .success: theme.colors.success.color
        case .warning, .unsupported: theme.colors.warning.color
        case .error: theme.colors.error.color
        case .info: theme.colors.info.color
        }
    }
}

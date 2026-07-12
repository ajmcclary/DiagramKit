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
        environment: DSResolvedEnvironment
    ) -> Self {
        Self(
            icon: kind.icon,
            colorRole: kind.colorRole,
            includesText: environment.statusPresentation == .iconAndText
        )
    }
}

public struct DSStatusIndicator: View {
    private let kind: DSStatusKind
    private let label: String
    @Environment(\.dsEnvironment) private var environment

    public init(_ kind: DSStatusKind, label: String) {
        self.kind = kind
        self.label = label
    }

    public var body: some View {
        let state = DSStatusVisualState.resolve(
            kind: kind,
            environment: environment
        )
        HStack(spacing: DSTokens.Spacing.xs) {
            DSIconView(state.icon, size: DSTokens.Icon.xs, colorRole: state.colorRole)
            if state.includesText {
                Text(label)
                    .dsFont(.caption)
            }
        }
        .foregroundStyle(kind.color(in: environment.theme))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

public struct DSSettingRow<Content: View>: View {
    private let title: String
    private let detail: String?
    private let content: Content
    @Environment(\.dsEnvironment) private var environment

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
        HStack(alignment: .center, spacing: DSTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DSTokens.Spacing.xxs) {
                Text(title)
                    .dsFont(.body)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                if let detail {
                    Text(detail)
                        .dsFont(.caption)
                        .foregroundStyle(environment.theme.colors.textSecondary.color)
                }
            }
            Spacer(minLength: DSTokens.Spacing.md)
            content
        }
        .padding(.vertical, DSTokens.Spacing.sm)
        .frame(minHeight: environment.minimumTarget)
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
        VStack(alignment: .leading, spacing: DSTokens.Spacing.sm) {
            if let title {
                DSSectionHeader(title)
            }
            content
        }
        .padding(DSTokens.Spacing.md)
        .background {
            DSSurface(role: .card) { Color.clear }
        }
    }
}

public struct DSSectionHeader: View {
    private let title: String
    @Environment(\.dsEnvironment) private var environment

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .dsFont(.overline)
            .foregroundStyle(environment.theme.colors.textSecondary.color)
            .accessibilityLabel(title)
    }
}

public struct DSCodeBadge: View {
    private let text: String
    @Environment(\.dsEnvironment) private var environment

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .dsFont(.badge)
            .foregroundStyle(environment.theme.colors.textPrimary.color)
            .padding(.horizontal, DSTokens.Spacing.xs)
            .padding(.vertical, DSTokens.Spacing.xxs)
            .background(environment.theme.colors.element.color, in: shape)
            .overlay {
                shape.stroke(
                    environment.theme.colors.borderVariant.color,
                    lineWidth: DSTokens.Stroke.thin
                )
            }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DSTokens.Radius.chip, style: .continuous)
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

    func color(in theme: DSTheme) -> Color {
        switch self {
        case .success: theme.colors.success.color
        case .warning, .unsupported: theme.colors.warning.color
        case .error: theme.colors.error.color
        case .info: theme.colors.info.color
        }
    }
}

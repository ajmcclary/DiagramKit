import SwiftUI

public enum DSContentColorRole: Equatable, Sendable {
    case onAccent
    case primary
}

public enum DSToggleMetrics {
    public static let track = CGSize(
        width: DSTokens.Control.switchWidth,
        height: DSTokens.Control.switchHeight
    )
    public static let knob = DSTokens.Control.switchKnob
    public static let onKnobRole = DSContentColorRole.onAccent
}

public struct DSToggleStyle: ToggleStyle {
    @Environment(\.dsEnvironment) private var environment
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: DSTokens.Spacing.sm) {
                configuration.label
                    .dsFont(.body)
                    .foregroundStyle(environment.theme.colors.textPrimary.color)
                Spacer(minLength: DSTokens.Spacing.sm)
                track(isOn: configuration.isOn)
            }
            .frame(minHeight: environment.minimumTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : DSTokens.Opacity.disabled)
        .animation(animation, value: configuration.isOn)
        .onHover { isHovered = $0 }
    }

    private func track(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(trackColor(isOn: isOn))
            Circle()
                .fill(knobColor(isOn: isOn))
                .frame(width: DSToggleMetrics.knob, height: DSToggleMetrics.knob)
                .padding(DSTokens.Stroke.medium)
        }
        .frame(width: DSToggleMetrics.track.width, height: DSToggleMetrics.track.height)
        .overlay {
            Capsule().stroke(
                isFocused
                    ? environment.theme.colors.borderFocused.color
                    : environment.theme.colors.borderVariant.color,
                lineWidth: isFocused ? DSTokens.Stroke.medium : DSTokens.Stroke.thin
            )
        }
    }

    private func trackColor(isOn: Bool) -> Color {
        if isOn { return environment.theme.colors.accent.color }
        if isHovered { return environment.theme.colors.elementHover.color }
        return environment.theme.colors.element.color
    }

    private func knobColor(isOn: Bool) -> Color {
        isOn
            ? environment.theme.colors.onAccent.color
            : environment.theme.colors.iconPrimary.color
    }

    private var animation: Animation? {
        guard environment.motion == .standard else { return nil }
        return .easeInOut(
            duration: environment.motion.duration(
                milliseconds: DSTokens.DurationMilliseconds.control
            )
        )
    }
}

public extension ToggleStyle where Self == DSToggleStyle {
    static var ds: DSToggleStyle { DSToggleStyle() }
}

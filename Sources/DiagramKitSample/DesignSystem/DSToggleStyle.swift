import DesignKitThemes
import SwiftUI

public enum DSContentColorRole: Equatable, Sendable {
    case onAccent
    case primary
}

public enum DSToggleMetrics {
    public static let track = CGSize(
        width: Tokens.Size.Control.switchWidth,
        height: Tokens.Size.Control.switchHeight
    )
    public static let knob = Tokens.Size.Control.switchKnob
    public static let onKnobRole = DSContentColorRole.onAccent
}

public struct DSToggleStyle: ToggleStyle {
    /// When true, only the switch renders. `.labelsHidden()` cannot suppress
    /// `configuration.label` in a custom style, so rows that draw their own
    /// title (e.g. `DSSettingRow`) opt out here to avoid a duplicate label.
    private let labelHidden: Bool

    @Environment(\.designTheme) private var theme
    @Environment(\.dsContext) private var context
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false

    public init(labelHidden: Bool = false) {
        self.labelHidden = labelHidden
    }

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Tokens.Spacing.sm) {
                if !labelHidden {
                    configuration.label
                        .dsFont(.body)
                        .foregroundStyle(theme.colors.textPrimary.color)
                    Spacer(minLength: Tokens.Spacing.sm)
                }
                track(isOn: configuration.isOn)
            }
            .frame(minHeight: context.minimumTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : Tokens.Opacity.disabled)
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
                .padding(Tokens.Shape.strokeMedium)
        }
        .frame(width: DSToggleMetrics.track.width, height: DSToggleMetrics.track.height)
        .overlay {
            if isFocused {
                Capsule().stroke(
                    theme.colors.borderFocused.color,
                    lineWidth: Tokens.Shape.strokeMedium
                )
            }
        }
    }

    private func trackColor(isOn: Bool) -> Color {
        if isOn { return theme.colors.accent.color }
        if isHovered { return theme.colors.elementHover.color }
        return theme.colors.element.color
    }

    private func knobColor(isOn: Bool) -> Color {
        isOn
            ? theme.colors.onAccent.color
            : theme.colors.iconPrimary.color
    }

    private var animation: Animation? {
        guard context.motion == .standard else { return nil }
        return .easeInOut(
            duration: context.motion.duration(Tokens.Animation.durControl)
        )
    }
}

public extension ToggleStyle where Self == DSToggleStyle {
    static var ds: DSToggleStyle { DSToggleStyle() }
    static var dsSwitchOnly: DSToggleStyle { DSToggleStyle(labelHidden: true) }
}

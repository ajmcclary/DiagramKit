import SwiftUI

public enum DSFontRole: String, CaseIterable, Sendable {
    case display
    case title
    case headline
    case body
    case callout
    case subheadline
    case footnote
    case caption
    case caption2
    case code
    case metric
    case badge
    case overline
}

public enum DSFontFamily: Equatable, Sendable {
    case systemSans
    case systemMonospaced
}

public enum DSFontWeight: Equatable, Sendable {
    case regular
    case medium
    case semibold
    case bold
}

public enum DSTextStyle: Equatable, Sendable {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case body
    case callout
    case subheadline
    case footnote
    case caption
    case caption2
}

public struct DSResolvedFont: Equatable, Sendable {
    public let family: DSFontFamily
    public let weight: DSFontWeight
    public let textStyle: DSTextStyle?
    public let pointSize: CGFloat?
    public let tracking: CGFloat

    public var usesRelativeTextStyle: Bool { textStyle != nil }
    public var isMonospaced: Bool { family == .systemMonospaced }

    public init(
        family: DSFontFamily,
        weight: DSFontWeight,
        textStyle: DSTextStyle? = nil,
        pointSize: CGFloat? = nil,
        tracking: CGFloat = 0
    ) {
        self.family = family
        self.weight = weight
        self.textStyle = textStyle
        self.pointSize = pointSize
        self.tracking = tracking
    }

    public var swiftUIFont: Font {
        let design: Font.Design = isMonospaced ? .monospaced : .default
        if let textStyle {
            return .system(textStyle.swiftUI, design: design).weight(weight.swiftUI)
        }
        return .system(
            size: pointSize ?? DSTokens.Typography.body,
            weight: weight.swiftUI,
            design: design
        )
    }
}

enum DSTypography {
    static func resolve(_ role: DSFontRole, platform: DSPlatform) -> DSResolvedFont {
        let descriptor = descriptor(for: role)
        switch platform {
        case .iOS:
            return DSResolvedFont(
                family: descriptor.family,
                weight: descriptor.weight,
                textStyle: descriptor.textStyle,
                tracking: descriptor.tracking
            )
        case .macOS:
            return DSResolvedFont(
                family: descriptor.family,
                weight: descriptor.weight,
                pointSize: descriptor.pointSize,
                tracking: descriptor.tracking
            )
        }
    }

    private static func descriptor(for role: DSFontRole) -> DSResolvedFont {
        switch role {
        case .display:
            DSResolvedFont(family: .systemSans, weight: .bold, textStyle: .largeTitle, pointSize: DSTokens.Typography.largeTitle)
        case .title:
            DSResolvedFont(family: .systemSans, weight: .semibold, textStyle: .title2, pointSize: DSTokens.Typography.title2)
        case .headline:
            DSResolvedFont(family: .systemSans, weight: .semibold, textStyle: .headline, pointSize: DSTokens.Typography.headline)
        case .body:
            DSResolvedFont(family: .systemSans, weight: .regular, textStyle: .body, pointSize: DSTokens.Typography.body)
        case .callout:
            DSResolvedFont(family: .systemSans, weight: .regular, textStyle: .callout, pointSize: DSTokens.Typography.callout)
        case .subheadline:
            DSResolvedFont(family: .systemSans, weight: .regular, textStyle: .subheadline, pointSize: DSTokens.Typography.subheadline)
        case .footnote:
            DSResolvedFont(family: .systemSans, weight: .regular, textStyle: .footnote, pointSize: DSTokens.Typography.footnote)
        case .caption:
            DSResolvedFont(family: .systemSans, weight: .regular, textStyle: .caption, pointSize: DSTokens.Typography.caption)
        case .caption2:
            DSResolvedFont(family: .systemSans, weight: .regular, textStyle: .caption2, pointSize: DSTokens.Typography.caption2)
        case .code:
            DSResolvedFont(
                family: .systemMonospaced,
                weight: .regular,
                textStyle: .body,
                pointSize: DSTokens.Typography.body
            )
        case .metric:
            DSResolvedFont(
                family: .systemMonospaced,
                weight: .semibold,
                textStyle: .headline,
                pointSize: DSTokens.Typography.headline
            )
        case .badge:
            DSResolvedFont(family: .systemSans, weight: .medium, textStyle: .caption2, pointSize: DSTokens.Typography.caption2)
        case .overline:
            DSResolvedFont(
                family: .systemSans,
                weight: .semibold,
                textStyle: .caption2,
                pointSize: DSTokens.Typography.caption2,
                tracking: DSTokens.Typography.overlineTracking
            )
        }
    }
}

private extension DSFontWeight {
    var swiftUI: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }
}

private extension DSTextStyle {
    var swiftUI: Font.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .footnote: .footnote
        case .caption: .caption
        case .caption2: .caption2
        }
    }
}

// Linux-portable rendering support.
//
// `RenderConfig`, `RenderTokens` and `DiagramTheme` are Apple-only on purpose:
// they carry `BMColor` / `BMFont`, which are undefined on Linux. The SVG and
// ASCII paths only need a small, colour-and-number subset of them, so on Linux
// this file defines same-named counterparts exposing exactly that subset. Shared
// code (shape specs, SVG renderers, the umbrella pipeline) compiles against
// either; the Apple types — and therefore Apple output — are untouched.
//
// Rules for keeping the two in step:
// - Numeric defaults live once, in `RenderMetricDefaults` (or the portable
//   `original_src_styles`), and both platforms read them.
// - Colour math mirrors `BMColor` in CrossPlatform.swift (`hexString`
//   truncates, `cssColorString` rounds, `mixed` is linear RGBA). AppKit routes
//   through `.deviceRGB`, so a Linux hex can differ from macOS by one step;
//   Linux output already differs (character-count text measurement).
// - Grow a Linux counterpart only when shared code needs a member; never
//   define `BMColor`/`BMFont` on Linux.

import Foundation
import DiagramKitCommon

/// Literal metric defaults shared by Apple's `RenderTokens` and the Linux
/// `RenderConfig`. Padding comes from `original_src_styles.NODE_PADDING`.
public enum RenderMetricDefaults {
    public static let minimumNodeWidth: Double = 60
    public static let minimumNodeHeight: Double = 36
    public static let statePseudostateSize: Double = 28
    public static let cylinderEllipseRadius: Double = 7
    public static let subroutineInset: Double = 8
    public static let asymmetricIndent: Double = 12
    public static let doubleCircleGap: Double = 5
}

#if !(canImport(UIKit) || canImport(AppKit))

// MARK: - DiagramThemeColor

/// Portable RGBA colour (components 0...1) standing in for `BMColor` on Linux.
public struct DiagramThemeColor: Sendable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Same parsing as `BMColor(hex:)`: `#RGB`, `#RRGGBB`, `#RRGGBBAA`;
    /// anything else reports an issue and yields opaque black.
    public init(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        raw = raw.replacingOccurrences(of: "#", with: "")
        let value = UInt64(raw, radix: 16) ?? 0
        let valid = UInt64(raw, radix: 16) != nil && [3, 6, 8].contains(raw.count)
        if !valid {
            _reportDiagramIssue("DiagramThemeColor(hex:) received invalid hex string: \"\(hex)\" — defaulting to opaque black.")
        }
        switch valid ? raw.count : 0 {
        case 3:
            self.init(red: Double((value & 0xF00) >> 8) / 15,
                      green: Double((value & 0x0F0) >> 4) / 15,
                      blue: Double(value & 0x00F) / 15)
        case 6:
            self.init(red: Double((value & 0xFF0000) >> 16) / 255,
                      green: Double((value & 0x00FF00) >> 8) / 255,
                      blue: Double(value & 0x0000FF) / 255)
        case 8:
            self.init(red: Double((value & 0xFF00_0000) >> 24) / 255,
                      green: Double((value & 0x00FF_0000) >> 16) / 255,
                      blue: Double((value & 0x0000_FF00) >> 8) / 255,
                      alpha: Double(value & 0x0000_00FF) / 255)
        default:
            self.init(red: 0, green: 0, blue: 0)
        }
    }

    public var hexString: String {
        String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    /// `#RRGGBB` when opaque, `rgba(r,g,b,a)` otherwise (as `BMColor`).
    public var cssColorString: String {
        let ri = Int(max(0, min(255, (red * 255).rounded())))
        let gi = Int(max(0, min(255, (green * 255).rounded())))
        let bi = Int(max(0, min(255, (blue * 255).rounded())))
        if alpha >= 0.9999 {
            return String(format: "#%02X%02X%02X", ri, gi, bi)
        }
        let a = (alpha * 1000).rounded() / 1000
        return "rgba(\(ri),\(gi),\(bi),\(a))"
    }

    public func mixed(with other: DiagramThemeColor, amount: Double) -> DiagramThemeColor {
        let t = max(0, min(1, amount))
        return DiagramThemeColor(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t,
            alpha: alpha + (other.alpha - alpha) * t
        )
    }
}

/// Linux overload of the Apple `_hex(_: BMColor)` helper.
public func _hex(_ color: DiagramThemeColor) -> String? {
    let ri = Int(max(0, min(255, (color.red * 255).rounded())))
    let gi = Int(max(0, min(255, (color.green * 255).rounded())))
    let bi = Int(max(0, min(255, (color.blue * 255).rounded())))
    return String(format: "#%02X%02X%02X", ri, gi, bi)
}

// MARK: - DiagramTheme (Linux)

/// Linux counterpart of the Apple `DiagramTheme`: colours and the transparent
/// flag only (no fonts or CoreGraphics metrics, which the SVG/ASCII paths do
/// not read).
public struct DiagramTheme: Sendable, Equatable {
    public let background: DiagramThemeColor
    public let foreground: DiagramThemeColor
    public let line: DiagramThemeColor?
    public let accent: DiagramThemeColor?
    public let muted: DiagramThemeColor?
    public let surface: DiagramThemeColor?
    public let border: DiagramThemeColor?
    public let noteBkg: DiagramThemeColor?
    public let noteBorder: DiagramThemeColor?
    public let transparent: Bool

    public init(
        background: DiagramThemeColor,
        foreground: DiagramThemeColor,
        line: DiagramThemeColor? = nil,
        accent: DiagramThemeColor? = nil,
        muted: DiagramThemeColor? = nil,
        surface: DiagramThemeColor? = nil,
        border: DiagramThemeColor? = nil,
        noteBkg: DiagramThemeColor? = nil,
        noteBorder: DiagramThemeColor? = nil,
        transparent: Bool = false
    ) {
        self.background = background
        self.foreground = foreground
        self.line = line
        self.accent = accent
        self.muted = muted
        self.surface = surface
        self.border = border
        self.noteBkg = noteBkg
        self.noteBorder = noteBorder
        self.transparent = transparent
    }

    public func withTransparent(_ transparent: Bool = true) -> DiagramTheme {
        DiagramTheme(background: background, foreground: foreground, line: line, accent: accent,
                     muted: muted, surface: surface, border: border, noteBkg: noteBkg,
                     noteBorder: noteBorder, transparent: transparent)
    }

    public func effectiveLine() -> DiagramThemeColor { line ?? background.mixed(with: foreground, amount: ColorMix.line) }
    public func effectiveAccent() -> DiagramThemeColor { accent ?? foreground }
    public func effectiveMuted() -> DiagramThemeColor { muted ?? background.mixed(with: foreground, amount: ColorMix.textMuted) }
    public func effectiveSurface() -> DiagramThemeColor { surface ?? background.mixed(with: foreground, amount: ColorMix.nodeFill) }
    public func effectiveBorder() -> DiagramThemeColor { border ?? background.mixed(with: foreground, amount: ColorMix.nodeStroke) }

    public static let zincLight = DiagramTheme(background: DiagramThemeColor(hex: "#FFFFFF"),
                                               foreground: DiagramThemeColor(hex: "#27272A"))
    public static let zincDark = DiagramTheme(background: DiagramThemeColor(hex: "#18181B"),
                                              foreground: DiagramThemeColor(hex: "#FAFAFA"))
    public static let `default` = zincLight
}

// MARK: - RenderConfig (Linux)

/// Linux counterpart of the Apple `RenderConfig`: the numeric shape metrics
/// the portable shape specs read, with the same defaults.
public struct RenderConfig: Sendable {
    public static let shared = RenderConfig()

    public var nodePaddingHorizontal = CGFloat(original_src_styles.NODE_PADDING.horizontal)
    public var nodePaddingVertical = CGFloat(original_src_styles.NODE_PADDING.vertical)
    public var nodePaddingDiamondExtra = CGFloat(original_src_styles.NODE_PADDING.diamondExtra)
    public var minimumNodeWidth = CGFloat(RenderMetricDefaults.minimumNodeWidth)
    public var minimumNodeHeight = CGFloat(RenderMetricDefaults.minimumNodeHeight)
    public var statePseudostateSize = CGFloat(RenderMetricDefaults.statePseudostateSize)
    public var cylinderEllipseRadius = CGFloat(RenderMetricDefaults.cylinderEllipseRadius)
    public var subroutineInset = CGFloat(RenderMetricDefaults.subroutineInset)
    public var asymmetricIndent = CGFloat(RenderMetricDefaults.asymmetricIndent)
    public var doubleCircleGap = CGFloat(RenderMetricDefaults.doubleCircleGap)

    public init() {}
}
#endif

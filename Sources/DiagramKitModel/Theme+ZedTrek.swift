// Apple-only — depends on BMColor (UIKit/AppKit). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
import DiagramKitCommon
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// The 20 Zed Trek diagram-canvas themes (10 families × light/dark), mapped from
// the design project's `themes/zed-trek.json` editor tokens via spec §7
// (docs/superpowers/specs/2026-07-05-zed-trek-theme-family-design.md). These
// let the rendered diagram recolor to match the app-chrome theme. Generated
// deterministically from the source — regenerate via Scripts/gen_zedtrek.py.
//
// `zedTrekLCARSDark` reuses the comp-exact `zedTrekDark` value so the default
// canvas is byte-identical to the pre-family build.
extension DiagramTheme {
    public static let zedTrekLCARSDark = zedTrekDark   // reuse comp-exact value
    public static let zedTrekLCARSLight = DiagramTheme(
        background: BMColor(hex: "#FFFCF7"), foreground: BMColor(hex: "#263746"),
        line: BMColor(hex: "#FFD8B0"), accent: BMColor(hex: "#C16E1D"),
        muted: BMColor(hex: "#6D6258"), surface: BMColor(hex: "#FFFFFF"),
        border: BMColor(hex: "#FFB66B"), noteBkg: BMColor(hex: "#FFE8CC"),
        noteBorder: BMColor(hex: "#FFD8B0"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekBlackAlertDark = DiagramTheme(
        background: BMColor(hex: "#010204"), foreground: BMColor(hex: "#DFE7F1"),
        line: BMColor(hex: "#121826"), accent: BMColor(hex: "#7EC8DE"),
        muted: BMColor(hex: "#8B99AB"), surface: BMColor(hex: "#10121C"),
        border: BMColor(hex: "#1A2232"), noteBkg: BMColor(hex: "#07090F"),
        noteBorder: BMColor(hex: "#121826"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekBlackAlertLight = DiagramTheme(
        background: BMColor(hex: "#FCFDFF"), foreground: BMColor(hex: "#1E2530"),
        line: BMColor(hex: "#D3D8DE"), accent: BMColor(hex: "#09090B"),
        muted: BMColor(hex: "#5B6675"), surface: BMColor(hex: "#FFFFFF"),
        border: BMColor(hex: "#A9B4C2"), noteBkg: BMColor(hex: "#E9EDF3"),
        noteBorder: BMColor(hex: "#C1CAD6"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekBorgCubeDark = DiagramTheme(
        background: BMColor(hex: "#020402"), foreground: BMColor(hex: "#D8F5DC"),
        line: BMColor(hex: "#132318"), accent: BMColor(hex: "#5EFC8D"),
        muted: BMColor(hex: "#7B9A82"), surface: BMColor(hex: "#101B12"),
        border: BMColor(hex: "#183221"), noteBkg: BMColor(hex: "#0B120D"),
        noteBorder: BMColor(hex: "#132318"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekBorgCubeLight = DiagramTheme(
        background: BMColor(hex: "#FBFFF9"), foreground: BMColor(hex: "#1D2A22"),
        line: BMColor(hex: "#B7C8BB"), accent: BMColor(hex: "#2FA85B"),
        muted: BMColor(hex: "#536A59"), surface: BMColor(hex: "#FBFFFB"),
        border: BMColor(hex: "#78947F"), noteBkg: BMColor(hex: "#E9F2EC"),
        noteBorder: BMColor(hex: "#B7C8BB"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekCommandDark = DiagramTheme(
        background: BMColor(hex: "#09090B"), foreground: BMColor(hex: "#D3D8DE"),
        line: BMColor(hex: "#27272A"), accent: BMColor(hex: "#FF9933"),
        muted: BMColor(hex: "#A1A1AA"), surface: BMColor(hex: "#18181B"),
        border: BMColor(hex: "#27272A"), noteBkg: BMColor(hex: "#18181B"),
        noteBorder: BMColor(hex: "#1E3A5F"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekCommandLight = DiagramTheme(
        background: BMColor(hex: "#FFFFFF"), foreground: BMColor(hex: "#4A5766"),
        line: BMColor(hex: "#D3D8DE"), accent: BMColor(hex: "#257EA7"),
        muted: BMColor(hex: "#71717A"), surface: BMColor(hex: "#FFFFFF"),
        border: BMColor(hex: "#C7E9F1"), noteBkg: BMColor(hex: "#EFF2F5"),
        noteBorder: BMColor(hex: "#D3D8DE"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekFederationDark = DiagramTheme(
        background: BMColor(hex: "#050911"), foreground: BMColor(hex: "#DBE8F2"),
        line: BMColor(hex: "#1A2B3F"), accent: BMColor(hex: "#7EC8DE"),
        muted: BMColor(hex: "#91A5B7"), surface: BMColor(hex: "#172536"),
        border: BMColor(hex: "#23384F"), noteBkg: BMColor(hex: "#0E1724"),
        noteBorder: BMColor(hex: "#1A2B3F"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekFederationLight = DiagramTheme(
        background: BMColor(hex: "#FBFCFE"), foreground: BMColor(hex: "#1E2936"),
        line: BMColor(hex: "#CCD8E4"), accent: BMColor(hex: "#1E3A5F"),
        muted: BMColor(hex: "#53606E"), surface: BMColor(hex: "#FFFFFF"),
        border: BMColor(hex: "#94A9BD"), noteBkg: BMColor(hex: "#EAF1F8"),
        noteBorder: BMColor(hex: "#BBCAD9"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekRedAlertDark = DiagramTheme(
        background: BMColor(hex: "#0C0506"), foreground: BMColor(hex: "#F6D7CF"),
        line: BMColor(hex: "#3A1D21"), accent: BMColor(hex: "#EF5A5A"),
        muted: BMColor(hex: "#B88483"), surface: BMColor(hex: "#260F13"),
        border: BMColor(hex: "#7E1D27"), noteBkg: BMColor(hex: "#1B0B0E"),
        noteBorder: BMColor(hex: "#3A1D21"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekRedAlertLight = DiagramTheme(
        background: BMColor(hex: "#FFFAF8"), foreground: BMColor(hex: "#4A1F24"),
        line: BMColor(hex: "#F0B4AA"), accent: BMColor(hex: "#EF5A5A"),
        muted: BMColor(hex: "#7D4E4C"), surface: BMColor(hex: "#FFFFFF"),
        border: BMColor(hex: "#A4333F"), noteBkg: BMColor(hex: "#FFF0EC"),
        noteBorder: BMColor(hex: "#F0B4AA"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekYellowAlertDark = DiagramTheme(
        background: BMColor(hex: "#080602"), foreground: BMColor(hex: "#F3E8CF"),
        line: BMColor(hex: "#33260E"), accent: BMColor(hex: "#FFD166"),
        muted: BMColor(hex: "#B6A37C"), surface: BMColor(hex: "#241A08"),
        border: BMColor(hex: "#4F3911"), noteBkg: BMColor(hex: "#171105"),
        noteBorder: BMColor(hex: "#33260E"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekYellowAlertLight = DiagramTheme(
        background: BMColor(hex: "#FFFDF7"), foreground: BMColor(hex: "#2E2A21"),
        line: BMColor(hex: "#DFCFAA"), accent: BMColor(hex: "#FFD166"),
        muted: BMColor(hex: "#6F634D"), surface: BMColor(hex: "#FFFEF9"),
        border: BMColor(hex: "#B99B57"), noteBkg: BMColor(hex: "#F7EFD9"),
        noteBorder: BMColor(hex: "#D2BD87"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekSickBayDark = DiagramTheme(
        background: BMColor(hex: "#050B0F"), foreground: BMColor(hex: "#D9F2F6"),
        line: BMColor(hex: "#16313D"), accent: BMColor(hex: "#7EC8DE"),
        muted: BMColor(hex: "#8FB4BF"), surface: BMColor(hex: "#142833"),
        border: BMColor(hex: "#1B3D4A"), noteBkg: BMColor(hex: "#0D1B22"),
        noteBorder: BMColor(hex: "#16313D"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekSickBayLight = DiagramTheme(
        background: BMColor(hex: "#FBFEFF"), foreground: BMColor(hex: "#263943"),
        line: BMColor(hex: "#BEDDE5"), accent: BMColor(hex: "#7EC8DE"),
        muted: BMColor(hex: "#5C747D"), surface: BMColor(hex: "#FFFFFF"),
        border: BMColor(hex: "#9FCBD6"), noteBkg: BMColor(hex: "#EDF7F9"),
        noteBorder: BMColor(hex: "#BEDDE5"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekMissionControlDark = DiagramTheme(
        background: BMColor(hex: "#03070D"), foreground: BMColor(hex: "#DCEBF6"),
        line: BMColor(hex: "#15263A"), accent: BMColor(hex: "#7EC8DE"),
        muted: BMColor(hex: "#8DA2B3"), surface: BMColor(hex: "#121D2D"),
        border: BMColor(hex: "#1C324A"), noteBkg: BMColor(hex: "#0A1220"),
        noteBorder: BMColor(hex: "#15263A"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekMissionControlLight = DiagramTheme(
        background: BMColor(hex: "#FBFDFF"), foreground: BMColor(hex: "#223142"),
        line: BMColor(hex: "#D3D8DE"), accent: BMColor(hex: "#1E3A5F"),
        muted: BMColor(hex: "#5F7183"), surface: BMColor(hex: "#FFFFFF"),
        border: BMColor(hex: "#A8BFD4"), noteBkg: BMColor(hex: "#EDF4FA"),
        noteBorder: BMColor(hex: "#C6D5E2"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekReadyRoomDark = DiagramTheme(
        background: BMColor(hex: "#0B0F16"), foreground: BMColor(hex: "#EADFD3"),
        line: BMColor(hex: "#283241"), accent: BMColor(hex: "#FFD8B0"),
        muted: BMColor(hex: "#A99C90"), surface: BMColor(hex: "#202633"),
        border: BMColor(hex: "#344052"), noteBkg: BMColor(hex: "#171B24"),
        noteBorder: BMColor(hex: "#283241"), lineWidth: 1, cornerRadius: 8)
    public static let zedTrekReadyRoomLight = DiagramTheme(
        background: BMColor(hex: "#FFFAF3"), foreground: BMColor(hex: "#2F343B"),
        line: BMColor(hex: "#C9B8A7"), accent: BMColor(hex: "#1E3A5F"),
        muted: BMColor(hex: "#6F6258"), surface: BMColor(hex: "#FFFDF8"),
        border: BMColor(hex: "#A9907B"), noteBkg: BMColor(hex: "#EFE8DF"),
        noteBorder: BMColor(hex: "#C9B8A7"), lineWidth: 1, cornerRadius: 8)

    /// The 20 (name, theme) rows appended to `allThemes` for the family.
    static let zedTrekFamilyThemes: [(name: String, theme: DiagramTheme)] = [
        ("LCARS Dark", zedTrekLCARSDark), ("LCARS Light", zedTrekLCARSLight),
        ("Black Alert Dark", zedTrekBlackAlertDark), ("Black Alert Light", zedTrekBlackAlertLight),
        ("Borg Cube Dark", zedTrekBorgCubeDark), ("Borg Cube Light", zedTrekBorgCubeLight),
        ("Command Dark", zedTrekCommandDark), ("Command Light", zedTrekCommandLight),
        ("Federation Dark", zedTrekFederationDark), ("Federation Light", zedTrekFederationLight),
        ("Red Alert Dark", zedTrekRedAlertDark), ("Red Alert Light", zedTrekRedAlertLight),
        ("Yellow Alert Dark", zedTrekYellowAlertDark), ("Yellow Alert Light", zedTrekYellowAlertLight),
        ("Sick Bay Dark", zedTrekSickBayDark), ("Sick Bay Light", zedTrekSickBayLight),
        ("Mission Control Dark", zedTrekMissionControlDark), ("Mission Control Light", zedTrekMissionControlLight),
        ("Ready Room Dark", zedTrekReadyRoomDark), ("Ready Room Light", zedTrekReadyRoomLight),
    ]
}
#endif

#!/usr/bin/env python3
"""Generate the DiagramKitSample design-system adapter."""

from __future__ import annotations

import argparse
import colorsys
import hashlib
import json
from pathlib import Path
import re
from typing import Any, NoReturn


SCHEMA_VERSION = 1

REQUIRED_TOKEN_KEYS = {
    "spacing": {"xxxs", "xxs", "xs", "sm", "smMd", "md", "lg", "xl", "xxl", "xxxl"},
    "radius": {"xs", "sm", "md", "lg", "xl", "xxl", "chip", "window", "full"},
    "stroke": {"hairline", "thin", "mediumLight", "medium", "thick", "ring"},
    "opacity": {
        "faint", "dim", "subtle", "mist", "soft", "tint", "glassFill",
        "glassBorder", "glassHighlight", "light", "disabled", "medium",
        "strong", "heavy", "near",
    },
    "durationMilliseconds": {
        "instant", "fast", "quick", "drawer", "control", "page", "section",
        "screen", "verySlow",
    },
    "easing": {"outSoft", "inOutSoft", "springSnappy"},
    "control": {
        "button", "buttonCompact", "row", "rowCompact", "chip", "switchWidth",
        "switchHeight", "switchKnob", "titleBar", "tabStrip", "tabStripCompact",
        "statusBar", "accentBar",
    },
    "touch": {"macOS", "iOS"},
    "icon": {"indicator", "micro", "xs", "sm", "md", "lg", "xl", "xxl"},
    "typography": {
        "largeTitle", "title", "title2", "title3", "headline", "subheadline",
        "body", "callout", "footnote", "caption", "caption2", "overlineTracking",
    },
    "interaction": {"pressedScale", "focusGlow"},
}

REQUIRED_ICON_KEYS = {
    "close", "search", "settings", "reset", "run", "export", "convert",
    "diagnostics", "warning", "error", "info", "success", "disclosureDown",
    "disclosureRight", "add", "remove", "copy", "history", "theme", "code",
}

REQUIRED_THEME_STYLE_KEYS = {
    "background", "surface.background", "elevated_surface.background",
    "panel.background", "editor.background", "editor.foreground",
    "editor.gutter.background", "title_bar.background",
    "title_bar.inactive_background", "toolbar.background", "tab_bar.background",
    "tab.active_background", "tab.inactive_background", "status_bar.background",
    "border", "border.disabled", "border.focused", "border.selected",
    "border.variant", "text", "text.disabled", "text.muted", "text.placeholder",
    "icon", "icon.disabled", "icon.muted", "element.background", "element.hover",
    "element.active", "element.selected", "element.disabled",
    "ghost_element.background", "ghost_element.hover", "ghost_element.active",
    "ghost_element.selected", "editor.active_line.background",
    "editor.active_line_number", "editor.line_number", "editor.invisible",
    "editor.indent_guide", "editor.indent_guide_active", "search.match_background",
    "info", "info.background", "success", "success.background", "warning",
    "warning.background", "error", "error.background", "syntax",
}


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--themes", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def fail(message: str) -> NoReturn:
    raise SystemExit(f"design-system contract error: {message}")


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"{label} file not found: {path}")
    except (OSError, json.JSONDecodeError) as error:
        fail(f"invalid {label}: {error}")
    if not isinstance(value, dict):
        fail(f"{label} root")
    return value


def require_path(root: dict[str, Any], path: str) -> Any:
    value: Any = root
    for component in path.split("."):
        if not isinstance(value, dict) or component not in value:
            fail(path)
        value = value[component]
    return value


def validate_number(value: Any, path: str, *, maximum: float | None = None) -> None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        fail(path)
    if value < 0 or (maximum is not None and value > maximum):
        fail(path)


def validate_contract(contract: dict[str, Any]) -> None:
    if contract.get("schemaVersion") != SCHEMA_VERSION:
        fail("schemaVersion")

    tokens = require_path(contract, "tokens")
    if not isinstance(tokens, dict):
        fail("tokens")
    for group, required_keys in REQUIRED_TOKEN_KEYS.items():
        values = require_path(contract, f"tokens.{group}")
        if not isinstance(values, dict):
            fail(f"tokens.{group}")
        missing = sorted(required_keys - values.keys())
        if missing:
            fail(f"tokens.{group}.{missing[0]}")
        for key in sorted(required_keys):
            path = f"tokens.{group}.{key}"
            value = values[key]
            if group == "easing":
                if not isinstance(value, list) or len(value) != 4:
                    fail(path)
                for component in value:
                    validate_number(component, path, maximum=1)
            else:
                validate_number(value, path, maximum=1 if group == "opacity" else None)

    icons = require_path(contract, "icons")
    if not isinstance(icons, dict):
        fail("icons")
    missing_icons = sorted(REQUIRED_ICON_KEYS - icons.keys())
    if missing_icons:
        fail(f"icons.{missing_icons[0]}")
    for key in sorted(REQUIRED_ICON_KEYS):
        if not isinstance(icons[key], str) or not icons[key]:
            fail(f"icons.{key}")

    for path in ("upstream.name", "upstream.snapshotDate", "upstream.integration"):
        value = require_path(contract, path)
        if not isinstance(value, str) or not value:
            fail(path)


def validate_themes(document: dict[str, Any]) -> None:
    themes = document.get("themes")
    if not isinstance(themes, list) or len(themes) != 20:
        fail("themes must contain exactly 20 variants")

    names: set[str] = set()
    families: dict[str, set[str]] = {}
    for index, theme in enumerate(themes):
        if not isinstance(theme, dict):
            fail(f"themes[{index}]")
        name = theme.get("name")
        appearance = theme.get("appearance")
        style = theme.get("style")
        if not isinstance(name, str) or not name:
            fail(f"themes[{index}].name")
        if name in names:
            fail(f"duplicate theme name: {name}")
        names.add(name)
        if appearance not in {"dark", "light"}:
            fail(f"themes[{index}].appearance")
        suffix = f" {appearance.title()}"
        if not name.endswith(suffix):
            fail(f"themes[{index}].name")
        families.setdefault(name.removesuffix(suffix), set()).add(appearance)
        if not isinstance(style, dict):
            fail(f"themes[{index}].style")
        missing_styles = sorted(REQUIRED_THEME_STYLE_KEYS - style.keys())
        if missing_styles:
            fail(f"themes[{index}].style.{missing_styles[0]}")
        syntax = style["syntax"]
        if not isinstance(syntax, dict) or not syntax:
            fail(f"themes[{index}].style.syntax")

    if len(families) != 10:
        fail("themes must contain exactly 10 families")
    incomplete = sorted(name for name, modes in families.items() if modes != {"dark", "light"})
    if incomplete:
        fail(f"theme family requires dark and light variants: {incomplete[0]}")


def swift_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def swift_number(value: int | float) -> str:
    return format(value, ".15g")


def lower_camel(value: str) -> str:
    words = re.findall(r"[A-Za-z0-9]+", value)
    if not words:
        fail(f"cannot form Swift identifier from {value!r}")
    return words[0].lower() + "".join(word.title() for word in words[1:])


def upper_camel(value: str) -> str:
    identifier = lower_camel(value)
    return identifier[0].upper() + identifier[1:]


def normalized_color(source: str) -> tuple[str, float]:
    if not re.fullmatch(r"#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?", source):
        fail(f"invalid color value: {source}")
    alpha = int(source[7:9], 16) / 255 if len(source) == 9 else 1.0
    return source[:7].upper(), alpha


def rgb_components(source: str) -> tuple[float, float, float]:
    hex_value, _ = normalized_color(source)
    return tuple(int(hex_value[index:index + 2], 16) / 255 for index in (1, 3, 5))


def relative_luminance(source: str) -> float:
    def linear(component: float) -> float:
        return component / 12.92 if component <= 0.04045 else ((component + 0.055) / 1.055) ** 2.4

    red, green, blue = rgb_components(source)
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)


def contrast_ratio(foreground: str, background: str) -> float:
    foreground_luminance = relative_luminance(foreground)
    background_luminance = relative_luminance(background)
    return (max(foreground_luminance, background_luminance) + 0.05) / (
        min(foreground_luminance, background_luminance) + 0.05
    )


def color_hex(red: float, green: float, blue: float) -> str:
    channels = [round(max(0, min(1, component)) * 255) for component in (red, green, blue)]
    return "#" + "".join(f"{channel:02X}" for channel in channels)


def hardened_foreground(source: str, background: str, minimum: float) -> str:
    """Preserve hue and saturation while moving HLS lightness just enough to pass."""
    source_hex, source_alpha = normalized_color(source)
    background_hex, background_alpha = normalized_color(background)
    if source_alpha != 1 or background_alpha != 1:
        fail("contrast foregrounds and backgrounds must be opaque")
    if contrast_ratio(source_hex, background_hex) >= minimum:
        return source_hex

    red, green, blue = rgb_components(source_hex)
    hue, lightness, saturation = colorsys.rgb_to_hls(red, green, blue)
    endpoint = 0.0 if relative_luminance(background_hex) > 0.5 else 1.0

    # Sampling at 1/4096 lightness increments is deterministic and, after
    # 8-bit quantization, selects the closest passing color to the source.
    for step in range(1, 4097):
        candidate_lightness = lightness + (endpoint - lightness) * step / 4096
        candidate = color_hex(*colorsys.hls_to_rgb(hue, candidate_lightness, saturation))
        if contrast_ratio(candidate, background_hex) >= minimum:
            return candidate
    fail(f"could not harden {source_hex} against {background_hex} to {minimum}:1")


def swift_color(source: str) -> str:
    hex_value, alpha = normalized_color(source)
    return (
        f"DSColorValue(hex: {swift_string(hex_value)}, "
        f"alpha: {swift_number(alpha)})"
    )


def render_contract(
    contract: dict[str, Any], contract_sha256: str, themes_sha256: str
) -> str:
    group_names = {
        "spacing": "Spacing",
        "radius": "Radius",
        "stroke": "Stroke",
        "opacity": "Opacity",
        "durationMilliseconds": "DurationMilliseconds",
        "easing": "Easing",
        "control": "Control",
        "touch": "Touch",
        "icon": "Icon",
        "typography": "Typography",
        "interaction": "Interaction",
    }
    lines = [
        "// Generated by Scripts/gen_codeeditor_design_system.py. Do not edit.",
        "import Foundation",
        "",
        "public struct DSEasing: Equatable, Sendable {",
        "    public let x1: Double",
        "    public let y1: Double",
        "    public let x2: Double",
        "    public let y2: Double",
        "",
        "    public init(x1: Double, y1: Double, x2: Double, y2: Double) {",
        "        self.x1 = x1",
        "        self.y1 = y1",
        "        self.x2 = x2",
        "        self.y2 = y2",
        "    }",
        "}",
        "",
        "public enum DSTokens {",
    ]
    for group, values in contract["tokens"].items():
        lines.append(f"    public enum {group_names[group]} {{")
        for key, value in values.items():
            if group == "easing":
                components = ", ".join(swift_number(component) for component in value)
                lines.append(
                    f"        public static let {key} = DSEasing(x1: {components.split(', ')[0]}, "
                    f"y1: {components.split(', ')[1]}, x2: {components.split(', ')[2]}, "
                    f"y2: {components.split(', ')[3]})"
                )
            else:
                lines.append(
                    f"        public static let {key}: CGFloat = {swift_number(value)}"
                )
        lines.append("    }")
    lines.extend(
        [
            "}",
            "",
            "public enum DSGeneratedMetadata {",
            f"    public static let schemaVersion = {contract['schemaVersion']}",
            f"    public static let contractSHA256 = {swift_string(contract_sha256)}",
            f"    public static let themesSHA256 = {swift_string(themes_sha256)}",
            f"    public static let upstreamName = {swift_string(contract['upstream']['name'])}",
            f"    public static let snapshotDate = {swift_string(contract['upstream']['snapshotDate'])}",
            f"    public static let integration = {swift_string(contract['upstream']['integration'])}",
            "}",
            "",
        ]
    )
    return "\n".join(lines)


def render_icons(contract: dict[str, Any]) -> str:
    icons: dict[str, str] = contract["icons"]
    cases = ", ".join(icons.keys())
    lines = [
        "// Generated by Scripts/gen_codeeditor_design_system.py. Do not edit.",
        "",
        "public enum DSIcon: String, CaseIterable, Sendable {",
        f"    case {cases}",
        "",
        "    public var systemName: String {",
        "        switch self {",
    ]
    for key, system_name in icons.items():
        lines.append(f"        case .{key}: {swift_string(system_name)}")
    lines.extend(["        }", "    }", "}", ""])
    return "\n".join(lines)


def render_themes(document: dict[str, Any]) -> str:
    themes: list[dict[str, Any]] = document["themes"]
    variants: list[dict[str, Any]] = []
    family_names: list[str] = []
    for theme in themes:
        mode = theme["appearance"]
        family = theme["name"].removesuffix(f" {mode.title()}")
        if family not in family_names:
            family_names.append(family)
        variants.append(
            {
                "theme": theme,
                "family": family,
                "family_case": lower_camel(family),
                "case": lower_camel(f"{family} {mode}"),
                "mode": mode,
            }
        )

    family_cases = ", ".join(
        f"{lower_camel(name)} = {swift_string(name)}" for name in family_names
    )
    variant_cases = ", ".join(
        f"{variant['case']} = {swift_string(variant['theme']['name'])}"
        for variant in variants
    )
    lines = [
        "// Generated by Scripts/gen_codeeditor_design_system.py. Do not edit.",
        "import Foundation",
        "",
        "public enum DSThemeFamily: String, CaseIterable, Sendable {",
        f"    case {family_cases}",
        "",
        "    public var displayName: String {",
        "        switch self {",
    ]
    for family in family_names:
        lines.append(f"        case .{lower_camel(family)}: {swift_string(family)}")
    lines.extend(
        [
            "        }",
            "    }",
            "}",
            "",
            "public enum DSThemeMode: String, CaseIterable, Sendable {",
            "    case system, dark, light",
            "}",
            "",
            "public enum DSThemeVariant: String, CaseIterable, Sendable {",
            f"    case {variant_cases}",
            "",
            "    public var family: DSThemeFamily {",
            "        switch self {",
        ]
    )
    for family in family_names:
        matching = [f".{item['case']}" for item in variants if item["family"] == family]
        lines.append(
            f"        case {', '.join(matching)}: .{lower_camel(family)}"
        )
    lines.extend(
        [
            "        }",
            "    }",
            "",
            "    public var mode: DSThemeMode {",
            "        switch self {",
        ]
    )
    dark_cases = ", ".join(f".{item['case']}" for item in variants if item["mode"] == "dark")
    light_cases = ", ".join(f".{item['case']}" for item in variants if item["mode"] == "light")
    lines.extend(
        [
            f"        case {dark_cases}: .dark",
            f"        case {light_cases}: .light",
            "        }",
            "    }",
            "",
            "    public var theme: DSTheme { DSGeneratedThemes.values[self]! }",
            "}",
            "",
            "public struct DSColorValue: Hashable, Sendable {",
            "    public let hex: String",
            "    public let alpha: Double",
            "",
            "    public init(hex: String, alpha: Double = 1) {",
            "        self.hex = hex",
            "        self.alpha = alpha",
            "    }",
            "}",
            "",
            "public struct DSSyntaxStyle: Equatable, Sendable {",
            "    public let foreground: DSColorValue",
            "    public let background: DSColorValue?",
            "    public let fontWeight: Int?",
            "    public let isItalic: Bool",
            "",
            "    public init(foreground: DSColorValue, background: DSColorValue? = nil, fontWeight: Int? = nil, isItalic: Bool = false) {",
            "        self.foreground = foreground",
            "        self.background = background",
            "        self.fontWeight = fontWeight",
            "        self.isItalic = isItalic",
            "    }",
            "}",
            "",
            "public struct DSContrastAdjustment: Equatable, Sendable {",
            "    public let role: String",
            "    public let original: DSColorValue",
            "    public let hardened: DSColorValue",
            "    public let minimumRatio: Double",
            "",
            "    public init(role: String, original: DSColorValue, hardened: DSColorValue, minimumRatio: Double) {",
            "        self.role = role",
            "        self.original = original",
            "        self.hardened = hardened",
            "        self.minimumRatio = minimumRatio",
            "    }",
            "}",
            "",
            "public struct DSThemeColors: Equatable, Sendable {",
            "    public let accents: [DSColorValue]",
            "    public let values: [String: DSColorValue]",
            "    public let syntax: [String: DSSyntaxStyle]",
            "",
            "    public init(accents: [DSColorValue], values: [String: DSColorValue], syntax: [String: DSSyntaxStyle]) {",
            "        self.accents = accents",
            "        self.values = values",
            "        self.syntax = syntax",
            "    }",
            "",
            "    public func value(_ role: String) -> DSColorValue { values[role]! }",
            "    public var accent: DSColorValue { value(\"design.accent\") }",
            "    public var onAccent: DSColorValue { value(\"design.onAccent\") }",
            "    public var windowBackground: DSColorValue { value(\"background\") }",
            "    public var surfaceBackground: DSColorValue { value(\"surface.background\") }",
            "    public var elevatedSurfaceBackground: DSColorValue { value(\"elevated_surface.background\") }",
            "    public var panelBackground: DSColorValue { value(\"panel.background\") }",
            "    public var editorBackground: DSColorValue { value(\"editor.background\") }",
            "    public var editorForeground: DSColorValue { value(\"editor.foreground\") }",
            "    public var editorGutterBackground: DSColorValue { value(\"editor.gutter.background\") }",
            "    public var titleBarBackground: DSColorValue { value(\"title_bar.background\") }",
            "    public var toolbarBackground: DSColorValue { value(\"toolbar.background\") }",
            "    public var tabBarBackground: DSColorValue { value(\"tab_bar.background\") }",
            "    public var statusBarBackground: DSColorValue { value(\"status_bar.background\") }",
            "    public var textPrimary: DSColorValue { value(\"text\") }",
            "    public var textSecondary: DSColorValue { value(\"text.muted\") }",
            "    public var textDisabled: DSColorValue { value(\"text.disabled\") }",
            "    public var textPlaceholder: DSColorValue { value(\"text.placeholder\") }",
            "    public var iconPrimary: DSColorValue { value(\"icon\") }",
            "    public var iconMuted: DSColorValue { value(\"icon.muted\") }",
            "    public var iconDisabled: DSColorValue { value(\"icon.disabled\") }",
            "    public var border: DSColorValue { value(\"border\") }",
            "    public var borderVariant: DSColorValue { value(\"border.variant\") }",
            "    public var borderFocused: DSColorValue { value(\"border.focused\") }",
            "    public var borderSelected: DSColorValue { value(\"border.selected\") }",
            "    public var element: DSColorValue { value(\"element.background\") }",
            "    public var elementHover: DSColorValue { value(\"element.hover\") }",
            "    public var elementActive: DSColorValue { value(\"element.active\") }",
            "    public var elementSelected: DSColorValue { value(\"element.selected\") }",
            "    public var ghostElement: DSColorValue { value(\"ghost_element.background\") }",
            "    public var ghostElementHover: DSColorValue { value(\"ghost_element.hover\") }",
            "    public var ghostElementActive: DSColorValue { value(\"ghost_element.active\") }",
            "    public var ghostElementSelected: DSColorValue { value(\"ghost_element.selected\") }",
            "    public var success: DSColorValue { value(\"success\") }",
            "    public var warning: DSColorValue { value(\"warning\") }",
            "    public var error: DSColorValue { value(\"error\") }",
            "    public var info: DSColorValue { value(\"info\") }",
            "    public var searchMatchBackground: DSColorValue { value(\"search.match_background\") }",
            "}",
            "",
            "public struct DSTheme: Equatable, Sendable {",
            "    public let name: String",
            "    public let family: DSThemeFamily",
            "    public let mode: DSThemeMode",
            "    public let colors: DSThemeColors",
            "    public let isHighContrast: Bool",
            "    public let contrastAdjustments: [DSContrastAdjustment]",
            "",
            "    public init(name: String, family: DSThemeFamily, mode: DSThemeMode, colors: DSThemeColors, isHighContrast: Bool = false, contrastAdjustments: [DSContrastAdjustment] = []) {",
            "        self.name = name",
            "        self.family = family",
            "        self.mode = mode",
            "        self.colors = colors",
            "        self.isHighContrast = isHighContrast",
            "        self.contrastAdjustments = contrastAdjustments",
            "    }",
            "",
            "    public static func theme(family: DSThemeFamily, mode: DSThemeMode) -> DSTheme {",
            "        let resolvedMode: DSThemeMode = mode == .system ? .dark : mode",
            "        return DSThemeVariant.allCases.first { $0.family == family && $0.mode == resolvedMode }!.theme",
            "    }",
        ]
    )
    for variant in variants:
        lines.append(
            f"    public static var {variant['case']}: DSTheme {{ DSThemeVariant.{variant['case']}.theme }}"
        )
    lines.extend(["}", "", "private enum DSGeneratedThemes {", "    static let values: [DSThemeVariant: DSTheme] = ["])

    for variant in variants:
        theme = variant["theme"]
        style: dict[str, Any] = theme["style"]
        adjustments: list[tuple[str, str, str, float]] = []

        def harden(role: str, source: str, background: str, minimum: float) -> str:
            hardened = hardened_foreground(source, background, minimum)
            original, _ = normalized_color(source)
            if hardened != original:
                adjustments.append((role, original, hardened, minimum))
            return hardened

        accents = ", ".join(swift_color(color) for color in style["accents"])
        flat_colors = {
            key: value
            for key, value in style.items()
            if isinstance(value, str) and value.startswith("#")
        }
        flat_colors["design.accent"] = style["icon.accent"]
        accent_hex, _ = normalized_color(style["icon.accent"])
        on_accent = max(("#000000", "#FFFFFF"), key=lambda color: contrast_ratio(color, accent_hex))
        flat_colors["design.onAccent"] = on_accent
        flat_colors["text"] = harden("text", style["text"], style["background"], 4.5)
        flat_colors["border.focused"] = harden(
            "border.focused", style["border.focused"], style["background"], 3.0
        )
        values = ", ".join(
            f"{swift_string(key)}: {swift_color(value)}"
            for key, value in sorted(flat_colors.items())
        )
        syntax_parts = []
        for key, syntax in sorted(style["syntax"].items()):
            foreground = syntax.get("color", style["editor.foreground"])
            foreground = harden(
                f"syntax.{key}", foreground, style["editor.background"], 4.5
            )
            background = syntax.get("background_color")
            background_expression = swift_color(background) if background else "nil"
            weight = syntax.get("font_weight")
            weight_expression = str(weight) if isinstance(weight, int) else "nil"
            italic = "true" if syntax.get("font_style") == "italic" else "false"
            syntax_parts.append(
                f"{swift_string(key)}: DSSyntaxStyle(foreground: {swift_color(foreground)}, "
                f"background: {background_expression}, fontWeight: {weight_expression}, "
                f"isItalic: {italic})"
            )
        syntax_values = ", ".join(syntax_parts)
        adjustment_values = ", ".join(
            "DSContrastAdjustment("
            f"role: {swift_string(role)}, original: {swift_color(original)}, "
            f"hardened: {swift_color(hardened)}, minimumRatio: {swift_number(minimum)}"
            ")"
            for role, original, hardened, minimum in adjustments
        )
        lines.extend(
            [
                f"        .{variant['case']}: DSTheme(",
                f"            name: {swift_string(theme['name'])}, family: .{variant['family_case']}, mode: .{variant['mode']},",
                "            colors: DSThemeColors(",
                f"                accents: [{accents}],",
                f"                values: [{values}],",
                f"                syntax: [{syntax_values}]",
                "            ),",
                f"            contrastAdjustments: [{adjustment_values}]",
                "        ),",
            ]
        )
    lines.extend(["    ]", "}", ""])
    return "\n".join(lines)


def generate_outputs(
    contract: dict[str, Any], themes: dict[str, Any], contract_path: Path, themes_path: Path
) -> dict[Path, str]:
    contract_sha256 = hashlib.sha256(contract_path.read_bytes()).hexdigest()
    themes_sha256 = hashlib.sha256(themes_path.read_bytes()).hexdigest()
    generated = Path("Sources/DiagramKitSampleDesignSystem/Generated")
    return {
        generated / "DSContract.generated.swift": render_contract(
            contract, contract_sha256, themes_sha256
        ),
        generated / "DSIcons.generated.swift": render_icons(contract),
        generated / "DSThemes.generated.swift": render_themes(themes),
    }


def write_or_check_outputs(
    outputs: dict[Path, str], output_root: Path, check: bool
) -> None:
    stale: list[str] = []
    for relative_path, content in outputs.items():
        destination = output_root / relative_path
        if check:
            if not destination.exists() or destination.read_text(encoding="utf-8") != content:
                stale.append(str(relative_path))
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists() or destination.read_text(encoding="utf-8") != content:
            destination.write_text(content, encoding="utf-8")
    if stale:
        fail("generated output is stale:\n" + "\n".join(sorted(stale)))


def main() -> None:
    arguments = parse_arguments()
    contract = load_json(arguments.contract, "contract")
    themes = load_json(arguments.themes, "themes")
    validate_contract(contract)
    validate_themes(themes)
    outputs = generate_outputs(contract, themes, arguments.contract, arguments.themes)
    write_or_check_outputs(outputs, arguments.output_root, arguments.check)


if __name__ == "__main__":
    main()

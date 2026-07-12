#!/usr/bin/env python3
"""Generate the DiagramKitSample design-system adapter."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
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


def main() -> None:
    arguments = parse_arguments()
    contract = load_json(arguments.contract, "contract")
    themes = load_json(arguments.themes, "themes")
    validate_contract(contract)
    validate_themes(themes)
    if not arguments.check:
        arguments.output_root.mkdir(parents=True, exist_ok=True)


if __name__ == "__main__":
    main()

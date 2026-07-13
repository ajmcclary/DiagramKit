#!/usr/bin/env python3
"""Regenerate the Swift Zed Trek theme literals from the design source.

Reads the Zed theme file `zed-trek.json` (the design project
50c9c2ef-8ed4-445e-870e-0273e3d082fc, `themes/zed-trek.json` — 20 entries,
10 families × light/dark) and emits, to stdout:

  1. CHROME dark/light dict entries — historically pasted into the sample
     app's PlaygroundPalette+ZedTrekFamily.swift. That file was retired in
     the DesignKit migration (chrome palettes now come from the external
     DesignKit package), and the sample app itself now lives outside this
     repo at apps/DiagramStudio in the workspace superproject.
  2. CANVAS `DiagramTheme` statics + `allThemes` rows → paste into
     Sources/DiagramKitModel/Theme+ZedTrek.swift

The mapping (zed-trek.json token → Swift field) is the spec §5 (chrome) / §7
(canvas) rules; see docs/superpowers/specs/2026-07-05-zed-trek-theme-family-design.md.
Values are ported deterministically — do NOT hand-edit the generated hexes.

Special cases:
  * LCARS Dark chrome uses the comp-exact legacy `lcarsDarkPalette` literal (kept
    in the Swift file), so it is emitted as a marker, not a fromZedTrek(...) call.
  * LCARS Dark canvas reuses the existing `zedTrekDark` value.
  * Brand accent = the design specimen's first swatch (spec §6), NOT
    `border.focused` (a functional focus-ring color that diverges from brand
    identity for LCARS light / Ready Room dark).

Usage:
    Scripts/gen_zedtrek.py [path-to-zed-trek.json]     # default: Scripts/zed-trek.json

Accepts either a plain Zed theme file or a DesignSync `get_file` wrapper
({"content": "<escaped json>"}), so you can point it straight at a fresh fetch.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "zed-trek.json")


def load_theme_file(path):
    """Return the parsed Zed theme document from a plain file or a get_file wrapper."""
    raw = open(path).read()
    try:
        obj = json.loads(raw)
        if isinstance(obj, dict) and "themes" in obj:
            return obj                       # plain Zed theme file
        if isinstance(obj, dict) and "content" in obj:
            return json.loads(obj["content"])  # DesignSync get_file wrapper
    except json.JSONDecodeError:
        pass
    m = re.search(r'"content":"(.*)","contentType"', raw, re.S)
    if m:
        return json.loads(json.loads('"' + m.group(1) + '"'))
    raise SystemExit(f"could not parse a Zed theme document from {path}")


data = load_theme_file(SRC)
themes = {t["name"]: t["style"] for t in data["themes"]}


def hx(v):
    """Normalize a Zed color string to a 6-digit uppercase hex (drop alpha)."""
    if v is None:
        return None
    v = v.lstrip("#").upper()
    return v[:6]


def pick(style, *keys):
    for k in keys:
        if k in style and style[k]:
            h = hx(style[k])
            if h and len(h) == 6:
                return h
    return None


# family case -> (display name, camel for canvas static)
FAMILIES = [
    ("lcars", "LCARS", "LCARS"),
    ("blackAlert", "Black Alert", "BlackAlert"),
    ("borgCube", "Borg Cube", "BorgCube"),
    ("command", "Command", "Command"),
    ("federation", "Federation", "Federation"),
    ("redAlert", "Red Alert", "RedAlert"),
    ("yellowAlert", "Yellow Alert", "YellowAlert"),
    ("sickBay", "Sick Bay", "SickBay"),
    ("missionControl", "Mission Control", "MissionControl"),
    ("readyRoom", "Ready Room", "ReadyRoom"),
]

# Design specimen accents (spec §6) — brand accent + accentSecondary / accentPeach.
SPEC = {
    ("lcars", "dark"): [0xFF9933, 0xFFD8B0, 0xFFCC66, 0x7EC8DE, 0xCC99FF],
    ("blackAlert", "dark"): [0x7EC8DE, 0xC7E9F1, 0xB5A7FF, 0x4EE6A6, 0xFF9933],
    ("borgCube", "dark"): [0x5EFC8D, 0x27C267, 0x9EFFA8, 0x7EC8DE, 0xFF9933],
    ("command", "dark"): [0xFF9933, 0xFFD8B0, 0x7EC8DE, 0x257EA7, 0xEF5A5A],
    ("federation", "dark"): [0x7EC8DE, 0xC7E9F1, 0xFFD8B0, 0xFF9933, 0xFF7373],
    ("redAlert", "dark"): [0xEF5A5A, 0xFF9933, 0xFFD8B0, 0x7EC8DE, 0xC7E9F1],
    ("yellowAlert", "dark"): [0xFFD166, 0xFF9933, 0x7EC8DE, 0xC7E9F1, 0xFF7373],
    ("sickBay", "dark"): [0x7EC8DE, 0xC7E9F1, 0x3CCF91, 0xFFD8B0, 0xFF7373],
    ("missionControl", "dark"): [0x7EC8DE, 0xC7E9F1, 0xFF9933, 0xFFD8B0, 0x4EE6A6],
    ("readyRoom", "dark"): [0xFFD8B0, 0x7EC8DE, 0x257EA7, 0xB87952, 0xEF5A5A],
    ("lcars", "light"): [0xC16E1D, 0xFF9933, 0xFFCC66, 0x1F8EA5, 0x8B5DBE],
    ("blackAlert", "light"): [0x09090B, 0x257EA7, 0x7EC8DE, 0xB5A7FF, 0x4EE6A6],
    ("borgCube", "light"): [0x2FA85B, 0x5EFC8D, 0x1F6B3C, 0x7EC8DE, 0x4A5766],
    ("command", "light"): [0x257EA7, 0x7EC8DE, 0xFFD8B0, 0xFF9933, 0xEF5A5A],
    ("federation", "light"): [0x1E3A5F, 0x257EA7, 0x7EC8DE, 0xFF9933, 0xFFD8B0],
    ("redAlert", "light"): [0xEF5A5A, 0xFF9933, 0xFFD8B0, 0x257EA7, 0x1E3A5F],
    ("yellowAlert", "light"): [0xFFD166, 0xFF9933, 0x1E3A5F, 0x257EA7, 0xEF5A5A],
    ("sickBay", "light"): [0x7EC8DE, 0x257EA7, 0x3CCF91, 0xFFD8B0, 0xEF5A5A],
    ("missionControl", "light"): [0x1E3A5F, 0x257EA7, 0x7EC8DE, 0xFF9933, 0x4EE6A6],
    ("readyRoom", "light"): [0x1E3A5F, 0x257EA7, 0x7EC8DE, 0xFFD8B0, 0x9B5F42],
}


def chrome_args(case, mode, style):
    background = pick(style, "background")
    editorBg = pick(style, "editor.background") or background
    panelBg = pick(style, "panel.background", "surface.background") or background
    elevatedBg = pick(style, "elevated_surface.background", "surface.background") or panelBg
    titleBg = pick(style, "title_bar.background") or panelBg
    elementBg = pick(style, "element.background") or elevatedBg
    text = pick(style, "text", "editor.foreground")
    textMuted = pick(style, "text.muted", "icon.muted") or text
    textPlaceholder = pick(style, "text.placeholder") or textMuted
    textDisabled = pick(style, "text.disabled") or textPlaceholder
    lineNumber = pick(style, "editor.line_number") or textDisabled
    # Brand accent = the design card's first swatch (spec §6), not border.focused.
    accent = "%06X" % SPEC[(case, mode)][0]
    info = pick(style, "info", "hint", "modified") or "7EC8DE"
    success = pick(style, "success", "created") or "4EE6A6"
    warning = pick(style, "warning", "conflict") or "FF9933"
    error = pick(style, "error", "deleted") or "EF5A5A"
    renamed = pick(style, "renamed") or accent
    border = pick(style, "border", "border.variant")
    borderVariant = pick(style, "border.variant", "border") or border
    paneGroupBorder = pick(style, "pane_group.border") or border
    errorBorder = pick(style, "error.border") or error
    spec = SPEC[(case, mode)]
    accentSecondary = "%06X" % spec[1]
    accentPeach = "FFD8B0" if 0xFFD8B0 in spec else accentSecondary
    return dict(background=background, editorBg=editorBg, panelBg=panelBg, elevatedBg=elevatedBg,
                titleBg=titleBg, elementBg=elementBg, text=text, textMuted=textMuted,
                textPlaceholder=textPlaceholder, textDisabled=textDisabled, lineNumber=lineNumber,
                accent=accent, accentSecondary=accentSecondary, accentPeach=accentPeach,
                info=info, success=success, warning=warning, error=error, renamed=renamed,
                border=border, borderVariant=borderVariant, paneGroupBorder=paneGroupBorder,
                errorBorder=errorBorder)


CHROME_ORDER = ["background", "editorBg", "panelBg", "elevatedBg", "titleBg", "elementBg",
                "text", "textMuted", "textPlaceholder", "textDisabled", "lineNumber",
                "accent", "accentSecondary", "accentPeach", "info", "success", "warning",
                "error", "renamed", "border", "borderVariant", "paneGroupBorder", "errorBorder"]


def emit_chrome(case, mode, style):
    a = chrome_args(case, mode, style)
    parts = ", ".join("%s: 0x%s" % (k, a[k]) for k in CHROME_ORDER)
    return "        .%s: .fromZedTrek(%s)," % (case, parts)


def emit_canvas(case, camel, mode, style):
    background = pick(style, "editor.background", "background")
    foreground = pick(style, "editor.foreground", "text")
    accent = "%06X" % SPEC[(case, mode)][0]   # brand accent (spec §6)
    muted = pick(style, "text.muted", "icon.muted") or foreground
    line = pick(style, "editor.indent_guide", "border")
    surface = pick(style, "elevated_surface.background", "surface.background")
    border = pick(style, "border", "border.variant")
    noteBkg = pick(style, "surface.background", "panel.background")
    noteBorder = pick(style, "border.variant", "border")
    name = "zedTrek%s%s" % (camel, mode.capitalize())
    return (f'    public static let {name} = DiagramTheme(\n'
            f'        background: BMColor(hex: "#{background}"), foreground: BMColor(hex: "#{foreground}"),\n'
            f'        line: BMColor(hex: "#{line}"), accent: BMColor(hex: "#{accent}"),\n'
            f'        muted: BMColor(hex: "#{muted}"), surface: BMColor(hex: "#{surface}"),\n'
            f'        border: BMColor(hex: "#{border}"), noteBkg: BMColor(hex: "#{noteBkg}"),\n'
            f'        noteBorder: BMColor(hex: "#{noteBorder}"), lineWidth: 1, cornerRadius: 8)')


def main():
    out = ["// ===== CHROME: dark dict entries (PlaygroundPalette+ZedTrekFamily.swift) ====="]
    for case, disp, _ in FAMILIES:
        if case == "lcars":
            out.append("        .lcars: .lcarsDarkPalette,")   # comp-exact literal in Swift
        else:
            out.append(emit_chrome(case, "dark", themes[f"{disp} Dark"]))

    out.append("\n// ===== CHROME: light dict entries =====")
    for case, disp, _ in FAMILIES:
        out.append(emit_chrome(case, "light", themes[f"{disp} Light"]))

    out.append("\n// ===== CANVAS: statics (Theme+ZedTrek.swift) =====")
    for case, disp, camel in FAMILIES:
        for mode in ("dark", "light"):
            if case == "lcars" and mode == "dark":
                out.append("    public static let zedTrekLCARSDark = zedTrekDark   // reuse comp-exact value")
            else:
                out.append(emit_canvas(case, camel, mode, themes[f"{disp} {mode.capitalize()}"]))

    out.append("\n// ===== CANVAS: allThemes rows =====")
    for case, disp, camel in FAMILIES:
        for mode in ("Dark", "Light"):
            out.append(f'        ("{disp} {mode}", zedTrek{camel}{mode}),')

    print("\n".join(out))


if __name__ == "__main__":
    main()

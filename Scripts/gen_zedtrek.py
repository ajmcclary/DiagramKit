#!/usr/bin/env python3
"""Regenerate the Swift Zed Trek diagram-canvas theme literals from the design source.

Reads the Zed theme file `zed-trek.json` (the design project
50c9c2ef-8ed4-445e-870e-0273e3d082fc, `themes/zed-trek.json` — 20 entries,
10 families × light/dark) and emits, to stdout:

  CANVAS `DiagramTheme` statics + `allThemes` rows → paste into
  Sources/DiagramKitModel/Theme+ZedTrek.swift

(The former CHROME half — `PlaygroundPalette+ZedTrekFamily.swift` dict
entries for the sample app — was retired with the DesignKit migration:
chrome palettes now come from the external DesignKit package, and the
sample app itself lives outside this repo at apps/DiagramStudio in the
workspace superproject. The generator no longer emits it.)

The mapping (zed-trek.json token → Swift field) is the spec §7 (canvas)
rules; see the workspace superproject's archived copy:
docs/archive/package/DiagramKit/superpowers/specs/2026-07-05-zed-trek-theme-family-design.md
Values are ported deterministically — do NOT hand-edit the generated hexes.
`Scripts/check-zedtrek-pin.sh` (wired into bootstrap-smoke-check.sh) fails
when Theme+ZedTrek.swift drifts from this generator's output.

Special cases:
  * LCARS Dark canvas reuses the existing `zedTrekDark` comp-exact value.
  * Brand accent = the design specimen's first swatch (spec §6), NOT
    `border.focused` (a functional focus-ring color that diverges from brand
    identity for LCARS light / Ready Room dark).

Usage:
    Scripts/gen_zedtrek.py [--check] [path-to-zed-trek.json]   # default: Scripts/zed-trek.json

    --check  do not emit; instead verify that the canvas statics in
             Sources/DiagramKitModel/Theme+ZedTrek.swift are exactly what
             this generator derives from zed-trek.json (exit 1 on drift)

Accepts either a plain Zed theme file or a DesignSync `get_file` wrapper
({"content": "<escaped json>"}), so you can point it straight at a fresh fetch.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TARGET = os.path.join(HERE, os.pardir, "Sources", "DiagramKitModel", "Theme+ZedTrek.swift")

argv = [a for a in sys.argv[1:]]
CHECK = "--check" in argv
argv = [a for a in argv if a != "--check"]
SRC = argv[0] if argv else os.path.join(HERE, "zed-trek.json")


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


def canvas_blocks(text, end_marker):
    """Return the `public static let zedTrek*` blocks between the first one and end_marker."""
    start = text.index("    public static let zedTrek")
    section = text[start:text.index(end_marker)]
    blocks = []
    for line in section.splitlines():
        if line.startswith("    public static let zedTrek"):
            blocks.append([line])
        elif blocks and line.startswith("        "):
            blocks[-1].append(line)
    return ["\n".join(b).rstrip() for b in blocks]


def main():
    emitted = []
    for case, disp, camel in FAMILIES:
        for mode in ("dark", "light"):
            if case == "lcars" and mode == "dark":
                emitted.append("    public static let zedTrekLCARSDark = zedTrekDark   // reuse comp-exact value")
            else:
                emitted.append(emit_canvas(case, camel, mode, themes[f"{disp} {mode.capitalize()}"]))

    rows = []
    for case, disp, camel in FAMILIES:
        for mode in ("Dark", "Light"):
            rows.append(f'        ("{disp} {mode}", zedTrek{camel}{mode}),')

    if CHECK:
        if not os.path.exists(TARGET):
            raise SystemExit(f"check-zedtrek-pin: missing {TARGET}")
        checked_in = canvas_blocks(open(TARGET).read(), "zedTrekFamilyThemes")
        if checked_in == [b.rstrip() for b in emitted]:
            print("check-zedtrek-pin: ✓ Theme+ZedTrek.swift matches gen_zedtrek.py output")
            return
        for i, (want, have) in enumerate(zip([b.rstrip() for b in emitted], checked_in)):
            if want != have:
                raise SystemExit(
                    "check-zedtrek-pin: DRIFT in Theme+ZedTrek.swift\n"
                    f"  generated: {want.splitlines()[0]}\n"
                    f"  checked in: {have.splitlines()[0] if have else '(missing)'}\n"
                    "  re-run Scripts/gen_zedtrek.py and re-paste the CANVAS statics")
        raise SystemExit(
            "check-zedtrek-pin: DRIFT in Theme+ZedTrek.swift "
            f"(generated {len(emitted)} statics, found {len(checked_in)}) — "
            "re-run Scripts/gen_zedtrek.py and re-paste the CANVAS statics")

    out = list(emitted)
    out.append("\n// ===== CANVAS: allThemes rows =====")
    out.extend(rows)
    print("\n".join(out))


if __name__ == "__main__":
    main()

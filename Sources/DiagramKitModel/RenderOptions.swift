// Extracted from Mermaid/src_index.swift during Stage 1 module split.
// `RenderOptions` and `DiagramColors` are model-layer config types used
// by every per-diagram renderer. They live in Model so all layers can
// reference them; the dispatcher / pipeline code in `src_index.swift`
// stays in the umbrella.

import Foundation

public struct RenderOptions: Sendable {
    public var bg: String?
    public var fg: String?
    public var line: String?
    public var accent: String?
    public var muted: String?
    public var surface: String?
    public var border: String?
    public var font: String?
    public var transparent: Bool?
    public var interactive: Bool?

    public init(
        bg: String? = nil,
        fg: String? = nil,
        line: String? = nil,
        accent: String? = nil,
        muted: String? = nil,
        surface: String? = nil,
        border: String? = nil,
        font: String? = nil,
        transparent: Bool? = nil,
        interactive: Bool? = nil
    ) {
        self.bg = bg
        self.fg = fg
        self.line = line
        self.accent = accent
        self.muted = muted
        self.surface = surface
        self.border = border
        self.font = font
        self.transparent = transparent
        self.interactive = interactive
    }
}

public struct DiagramColors: Sendable {
    public var bg: String
    public var fg: String
    public var line: String?
    public var accent: String?
    public var muted: String?
    public var surface: String?
    public var border: String?
    public var noteBkg: String?
    public var noteBorder: String?

    public init(
        bg: String,
        fg: String,
        line: String? = nil,
        accent: String? = nil,
        muted: String? = nil,
        surface: String? = nil,
        border: String? = nil,
        noteBkg: String? = nil,
        noteBorder: String? = nil
    ) {
        self.bg = bg
        self.fg = fg
        self.line = line
        self.accent = accent
        self.muted = muted
        self.surface = surface
        self.border = border
        self.noteBkg = noteBkg
        self.noteBorder = noteBorder
    }
}

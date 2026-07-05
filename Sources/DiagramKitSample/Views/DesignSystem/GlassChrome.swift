//
//  GlassChrome.swift
//  DiagramPlayground
//
//  Real Liquid Glass for the floating chrome layer (canvas toolbars, HUDs,
//  transient cards). Replaces the hand-rolled `fill(material) + stroke +
//  shadow` recipes. Always tinted from the active theme so the 10 Zed Trek
//  palettes survive — untinted glass would let the vivid diagram bleed
//  through and break the chrome/diagram separation.
//

import SwiftUI

enum PlaygroundGlassRole {
    case toolbar      // floating canvas toolbars, zoom cluster, tool palette
    case hud          // transient selection HUD / toasts / stage banner
    case popoverCard  // free-floating (non-.popover) editor cards
}

/// Pure: which palette token tints the glass for a given role. Keeps all
/// tinting routed through the theme.
func playgroundGlassTint(role: PlaygroundGlassRole, palette: PlaygroundPalette) -> Color {
    switch role {
    case .toolbar:     return palette.bgChrome
    case .hud:         return palette.accent
    case .popoverCard: return palette.bgPanel
    }
}

extension View {
    /// Real Liquid Glass for the floating chrome layer, tinted from the active
    /// theme. Replaces hand-rolled `fill(material) + stroke + shadow`.
    func glassChrome(_ role: PlaygroundGlassRole, in shape: some Shape) -> some View {
        modifier(GlassChromeModifier(role: role, shape: AnyShape(shape)))
    }
}

private struct GlassChromeModifier: ViewModifier {
    let role: PlaygroundGlassRole
    let shape: AnyShape
    @Environment(\.playgroundTokens) private var tokens

    func body(content: Content) -> some View {
        content.glassEffect(
            .regular.tint(playgroundGlassTint(role: role, palette: tokens.palette)),
            in: shape
        )
    }
}

//
//  PlaygroundButtonStyle.swift
//  DiagramPlayground
//
//  Shared interactive button style for playground chrome. Replaces bare
//  `.buttonStyle(.plain)` on design-system controls so every button gets a
//  pressed dip, disabled dimming, and (macOS) a link cursor — feedback the
//  ~110 `.plain` sites otherwise lack.
//

import SwiftUI

/// Resolved visual state for an interactive button.
struct ButtonVisualState: Equatable {
    var opacity: Double
    var scale: Double
}

/// Pure mapping from interaction inputs to visual state. Disabled dimming
/// takes precedence over the pressed dip.
func playgroundButtonVisualState(isPressed: Bool, isEnabled: Bool) -> ButtonVisualState {
    if !isEnabled { return ButtonVisualState(opacity: 0.4, scale: 1.0) }
    if isPressed  { return ButtonVisualState(opacity: 0.6, scale: 0.97) }
    return ButtonVisualState(opacity: 1.0, scale: 1.0)
}

struct PlaygroundButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let s = playgroundButtonVisualState(isPressed: configuration.isPressed, isEnabled: isEnabled)
        return configuration.label
            .opacity(s.opacity)
            .scaleEffect(s.scale)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            #if os(macOS)
            .pointerStyle(.link)
            #endif
    }
}

extension ButtonStyle where Self == PlaygroundButtonStyle {
    /// Chrome buttons: pressed dip + disabled dimming + (macOS) link cursor.
    /// Replaces bare `.buttonStyle(.plain)` on design-system controls. Keep
    /// `.plain` only where a control must show zero chrome (e.g. text links).
    static var playground: PlaygroundButtonStyle { PlaygroundButtonStyle() }
}

//
//  TouchTarget.swift
//  DiagramPlayground
//
//  Ensures small controls meet the 44pt HIG touch minimum on touch platforms,
//  without inflating their visual size (or the macOS chrome density).
//

import SwiftUI

extension View {
    /// Expands the hit area to at least `size`×`size` on touch platforms (iOS /
    /// iPadOS). No-op on macOS so pointer-scaled chrome density is preserved.
    @ViewBuilder
    func touchTarget(_ size: CGFloat = 44) -> some View {
        #if canImport(UIKit)
        self.frame(minWidth: size, minHeight: size).contentShape(Rectangle())
        #else
        self
        #endif
    }
}

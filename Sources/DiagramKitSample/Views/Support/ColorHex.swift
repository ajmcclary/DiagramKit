//
//  ColorHex.swift
//  DiagramPlayground
//
//  SwiftUI.Color ↔ "#rrggbb" bridge for the node style controls.
//  NodeStyleSpec carries lowercase hex strings; ColorPicker speaks
//  Color. sRGB both ways.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

extension Color {
    init?(hexRGB: String) {
        var hex = hexRGB.trimmingCharacters(in: .whitespaces).lowercased()
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }

    var hexRGB: String? {
        #if canImport(AppKit)
        guard let converted = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int((converted.redComponent * 255).rounded())
        let g = Int((converted.greenComponent * 255).rounded())
        let b = Int((converted.blueComponent * 255).rounded())
        #else
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        #endif
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

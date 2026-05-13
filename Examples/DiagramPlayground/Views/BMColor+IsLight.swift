//
//  BMColor+IsLight.swift
//  DiagramPlayground
//
//  Extension to detect light vs dark colors for toolbar styling.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

#if targetEnvironment(macCatalyst) || canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension BMColor {
    /// Returns true if this is a "light" color (perceived luminance > 0.5)
    var isLight: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif canImport(AppKit)
        guard let rgb = usingColorSpace(.sRGB) else { return true }
        rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #endif

        // Calculate perceived luminance
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.5
    }
}

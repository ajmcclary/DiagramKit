import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    /// Creates a SwiftUI color from a 24-bit RGB value used by specimen data.
    init(dsHex: UInt32, opacity: Double = 1) {
        let red = Double((dsHex >> 16) & 0xFF) / 255
        let green = Double((dsHex >> 8) & 0xFF) / 255
        let blue = Double(dsHex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }

    /// Resolves whether a specimen swatch needs dark foreground content.
    var dsIsLightSwatch: Bool {
        #if canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return false
        }
        return (0.2126 * red + 0.7152 * green + 0.0722 * blue) >= 0.6
        #elseif canImport(AppKit)
        guard let color = NSColor(self).usingColorSpace(.deviceRGB) else { return false }
        return (0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent) >= 0.6
        #else
        return false
        #endif
    }
}

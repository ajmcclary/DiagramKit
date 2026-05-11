// Apple-only — depends on BMColor/BMFont (UIKit/AppKit). Gated by `#if canImport(UIKit) || canImport(AppKit)`.
#if canImport(UIKit) || canImport(AppKit)
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum MarkdownLabelRenderer {
    public struct Config {
        public var fontSize: CGFloat
        public var textColor: BMColor

        public init(fontSize: CGFloat = 14, textColor: BMColor = .black) {
            self.fontSize = fontSize
            self.textColor = textColor
        }
    }

    public static func render(_ text: String, config: Config) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remaining = text[...]
        let baseSize = config.fontSize

        while !remaining.isEmpty {
            if remaining.hasPrefix("**") {
                let start = remaining.index(remaining.startIndex, offsetBy: 2)
                remaining = remaining[start...]
                let (content, endIdx) = extractUntil(remaining, delimiter: "**")
                let part = makeAttributed(String(content), config: config, bold: true, italic: false, mono: false, size: baseSize)
                result.append(part)
                remaining = remaining[endIdx...]
                if remaining.hasPrefix("**") {
                    remaining = remaining.dropFirst(2)
                }
            } else if remaining.hasPrefix("*") {
                let start = remaining.index(after: remaining.startIndex)
                remaining = remaining[start...]
                let (content, endIdx) = extractUntil(remaining, delimiter: "*")
                let part = makeAttributed(String(content), config: config, bold: false, italic: true, mono: false, size: baseSize)
                result.append(part)
                remaining = remaining[endIdx...]
                if remaining.hasPrefix("*") {
                    remaining = remaining.dropFirst()
                }
            } else if remaining.hasPrefix("`") {
                let start = remaining.index(after: remaining.startIndex)
                remaining = remaining[start...]
                let (content, endIdx) = extractUntil(remaining, delimiter: "`")
                let part = makeAttributed(String(content), config: config, bold: false, italic: false, mono: true, size: baseSize)
                result.append(part)
                remaining = remaining[endIdx...]
                if remaining.hasPrefix("`") {
                    remaining = remaining.dropFirst()
                }
            } else if remaining.hasPrefix("<br>") || remaining.hasPrefix("<br/>") {
                result.append(NSAttributedString(string: "\n"))
                let skip = remaining.hasPrefix("<br/>") ? 5 : 4
                remaining = remaining.dropFirst(skip)
            } else if remaining.hasPrefix("\n") {
                result.append(NSAttributedString(string: "\n"))
                remaining = remaining.dropFirst()
            } else {
                let (text, newIdx) = extractPlainText(remaining)
                let part = makeAttributed(String(text), config: config, bold: false, italic: false, mono: false, size: baseSize)
                result.append(part)
                remaining = remaining[newIdx...]
            }
        }

        return result
    }

    private static func extractUntil(_ text: Substring, delimiter: String) -> (Substring, Substring.Index) {
        var i = text.startIndex
        while i < text.endIndex {
            let rest = text[i...]
            if rest.hasPrefix(delimiter) {
                return (text[text.startIndex..<i], i)
            }
            i = text.index(after: i)
        }
        return (text, text.endIndex)
    }

    private static func extractPlainText(_ text: Substring) -> (Substring, Substring.Index) {
        var i = text.startIndex
        while i < text.endIndex {
            let ch = text[i]
            let rest = text[i...]
            if ch == "*" || ch == "`" || ch == "\n" ||
                rest.hasPrefix("<br>") || rest.hasPrefix("<br/>") {
                break
            }
            i = text.index(after: i)
        }
        return (text[text.startIndex..<i], i)
    }

    private static func makeAttributed(_ text: String, config: Config, bold: Bool, italic: Bool, mono: Bool, size: CGFloat) -> NSAttributedString {
        let font: BMFont
        if mono {
            #if os(macOS)
            font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
            #else
            font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
            #endif
        } else if bold && italic {
            #if os(macOS)
            font = NSFont.systemFont(ofSize: size, weight: .bold)
            #else
            font = UIFont.systemFont(ofSize: size, weight: .bold)
            #endif
        } else if bold {
            #if os(macOS)
            font = NSFont.boldSystemFont(ofSize: size)
            #else
            font = UIFont.boldSystemFont(ofSize: size)
            #endif
        } else if italic {
            #if os(macOS)
            let desc = BMFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits(.italic)
            font = BMFont(descriptor: desc, size: size) ?? BMFont.systemFont(ofSize: size)
            #else
            font = UIFont.italicSystemFont(ofSize: size)
            #endif
        } else {
            font = BMFont.systemFont(ofSize: size)
        }
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: config.textColor,
        ])
    }
}
#endif

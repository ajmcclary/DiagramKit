import Foundation

public enum _HTMLEntities {
    private static let namedEntities: [String: String] = [
        "amp": "&",
        "lt": "<",
        "gt": ">",
        "quot": "\"",
        "#39": "'",
        "apos": "'",
        "nbsp": "\u{00A0}",
    ]

    private static let namedHashEntities: [String: String] = [
        "quot": "\"",
        "amp": "&",
        "39": "'",
        "lt": "<",
        "gt": ">",
    ]

    /// Longest supported entity body is `nbsp`/`#39` (4 chars); the scan
    /// bound keeps a bare `&` (no `;` anywhere after it) from rescanning
    /// the whole remaining string — the previous unbounded loop was O(n²)
    /// in the number of bare `&`s.
    private static let maxEntityBodyLength = 32

    /// Upstream's `encodeEntities` pre-pass: on a `style` / `classDef` /
    /// `linkStyle` line that has a `:…#…;` colour, drop the line's last `;`
    /// before entity decoding, so `fill:#000;` stays a colour instead of
    /// decoding as the entity `#000;` (a NUL; `#333;` became `ō`). Mirrors
    /// upstream's `/style.*:\S*#.*;/` and `/classDef.*:\S*#.*;/`, which are
    /// unanchored and so also cover `linkStyle`.
    public static func stripStyleStatementTerminators(_ text: String) -> String {
        guard text.contains("#"), text.contains(";") else { return text }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var changed = false
        for index in lines.indices {
            let line = lines[index]
            guard line.contains(";"), line.contains("#"),
                  line.range(of: #"(?:style|classDef).*:\S*#.*;"#, options: .regularExpression) != nil,
                  let last = line.lastIndex(of: ";") else { continue }
            lines[index].remove(at: last)
            changed = true
        }
        return changed ? lines.joined(separator: "\n") : text
    }

    public static func decode(_ text: String) -> String {
        var result = ""
        var i = text.startIndex

        while i < text.endIndex {
            if text[i] == "&" {
                let start = i
                i = text.index(after: i)
                var entity = ""
                while i < text.endIndex, text[i] != ";",
                      entity.count < maxEntityBodyLength {
                    entity.append(text[i])
                    i = text.index(after: i)
                }
                if i < text.endIndex && text[i] == ";" {
                    i = text.index(after: i)
                    if let decoded = decodeEntity(entity, prefix: "&") {
                        result.append(decoded)
                        continue
                    }
                }
                result.append(String(text[start..<i]))
            } else if text[i] == "#" {
                let nextIdx = text.index(after: i)
                if nextIdx < text.endIndex, text[nextIdx].isLetter || text[nextIdx].isNumber {
                    let start = i
                    i = nextIdx
                    var entity = ""
                    while i < text.endIndex, text[i] != ";",
                          entity.count < maxEntityBodyLength {
                        entity.append(text[i])
                        i = text.index(after: i)
                    }
                    if i < text.endIndex && text[i] == ";" {
                        i = text.index(after: i)
                        if let decoded = decodeEntity(entity, prefix: "#") {
                            result.append(decoded)
                            continue
                        }
                    }
                    result.append(String(text[start..<i]))
                } else {
                    result.append(text[i])
                    i = text.index(after: i)
                }
            } else {
                result.append(text[i])
                i = text.index(after: i)
            }
        }
        return result
    }

    private static func decodeEntity(_ entity: String, prefix: String) -> String? {
        if prefix == "#" {
            if let named = namedHashEntities[entity] {
                return named
            }
            // A control character is never a meaningful label character and
            // makes the exported SVG invalid XML; leave such text alone.
            if let codePoint = UInt32(entity), !_isDisallowedControl(codePoint),
               let scalar = UnicodeScalar(codePoint) {
                return String(scalar)
            }
            return nil
        }
        if let named = namedEntities[entity] {
            return named
        }
        if entity.hasPrefix("#") {
            let numStr = String(entity.dropFirst())
            if numStr.hasPrefix("x") || numStr.hasPrefix("X") {
                if let codePoint = UInt32(String(numStr.dropFirst()), radix: 16),
                   !_isDisallowedControl(codePoint),
                   let scalar = UnicodeScalar(codePoint) {
                    return String(scalar)
                }
            } else if let codePoint = UInt32(numStr), !_isDisallowedControl(codePoint),
                      let scalar = UnicodeScalar(codePoint) {
                return String(scalar)
            }
        }
        return nil
    }

    /// C0 controls other than tab, LF and CR, and DEL.
    private static func _isDisallowedControl(_ codePoint: UInt32) -> Bool {
        (codePoint < 0x20 && codePoint != 0x09 && codePoint != 0x0A && codePoint != 0x0D) || codePoint == 0x7F
    }
}

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
    /// decoding as the entity `#000;` (a NUL; `#333;` became `ō`).
    ///
    /// Upstream's patterns are `/style.*:\S*#.*;/` and
    /// `/classDef.*:\S*#.*;/` (unanchored, case-sensitive, so `linkStyle`
    /// is *not* covered upstream; it is named explicitly here). Run as a
    /// regex they backtrack super-linearly on a line of repeated
    /// `style:` tokens, so the same condition is evaluated in one linear
    /// scan by `_lineHasStyleColourTerminator`.
    public static func stripStyleStatementTerminators(_ text: String) -> String {
        guard text.contains("#"), text.contains(";") else { return text }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var changed = false
        for index in lines.indices {
            let line = lines[index]
            guard _lineHasStyleColourTerminator(line), let last = line.lastIndex(of: ";") else { continue }
            lines[index].remove(at: last)
            changed = true
        }
        return changed ? lines.joined(separator: "\n") : text
    }

    /// `true` when `line` matches `(?:style|classDef|linkStyle).*:\S*#.*;`:
    /// after the first keyword there is a `:` followed by a run of
    /// non-whitespace characters that reaches a `#`, and a `;` comes after
    /// that `#`. Linear in the line length.
    static func _lineHasStyleColourTerminator(_ line: String) -> Bool {
        let chars = Array(line.utf8)
        guard let lastSemicolon = chars.lastIndex(of: UInt8(ascii: ";")) else { return false }
        // End of the earliest keyword occurrence (the earliest start gives
        // the regex the most room, and every later match is also a match
        // from it).
        var keywordEnd: Int?
        let keywords: [[UInt8]] = [Array("style".utf8), Array("classDef".utf8), Array("linkStyle".utf8)]
        var position = 0
        search: while position < chars.count {
            for keyword in keywords where position + keyword.count <= chars.count
                && chars[position..<(position + keyword.count)].elementsEqual(keyword) {
                keywordEnd = position + keyword.count
                break search
            }
            position += 1
        }
        guard let start = keywordEnd else { return false }
        var colonInRun = false
        var index = start
        while index < lastSemicolon {
            let byte = chars[index]
            switch byte {
            case UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\r"), 0x0B, 0x0C:
                colonInRun = false
            case UInt8(ascii: ":"):
                colonInRun = true
            case UInt8(ascii: "#"):
                if colonInRun { return true }
            default:
                break
            }
            index += 1
        }
        return false
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

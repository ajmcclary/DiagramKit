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

    public static func decode(_ text: String) -> String {
        var result = ""
        var i = text.startIndex

        while i < text.endIndex {
            if text[i] == "&" {
                let start = i
                i = text.index(after: i)
                var entity = ""
                while i < text.endIndex && text[i] != ";" {
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
                    while i < text.endIndex && text[i] != ";" {
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
            if let codePoint = UInt32(entity),
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
                   let scalar = UnicodeScalar(codePoint) {
                    return String(scalar)
                }
            } else if let codePoint = UInt32(numStr),
                      let scalar = UnicodeScalar(codePoint) {
                return String(scalar)
            }
        }
        return nil
    }
}

import Foundation

internal func eventModelingNormalizeSource(_ source: String) -> [String] {
    source
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
}

internal func eventModelingExtractMarkerId(from svg: String) -> String? {
    guard let range = svg.range(of: "id=\"em-arrowhead-") else { return nil }
    let afterPrefix = svg[range.upperBound...]
    guard let end = afterPrefix.firstIndex(of: "\"") else { return nil }
    return String(afterPrefix[..<end])
}

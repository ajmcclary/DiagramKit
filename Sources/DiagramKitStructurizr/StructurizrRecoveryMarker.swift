import Foundation

public struct StructurizrRecoveryMarker: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case elementTag(value: String)
        case boundaryParent(id: String)
    }

    public let lineNumber: Int
    public let kind: Kind

    public init(lineNumber: Int, kind: Kind) {
        self.lineNumber = lineNumber
        self.kind = kind
    }
}

public struct StructurizrPreLexerScanResult: Sendable, Equatable {
    public struct ElementDeclaration: Sendable, Equatable {
        public let alias: String
        public let line: Int
        public init(alias: String, line: Int) {
            self.alias = alias
            self.line = line
        }
    }

    public struct GroupDeclaration: Sendable, Equatable {
        public let label: String
        public let line: Int
        public init(label: String, line: Int) {
            self.label = label
            self.line = line
        }
    }

    public let markers: [StructurizrRecoveryMarker]
    public let elementDeclarations: [ElementDeclaration]
    public let groupDeclarations: [GroupDeclaration]

    public init(
        markers: [StructurizrRecoveryMarker],
        elementDeclarations: [ElementDeclaration],
        groupDeclarations: [GroupDeclaration]
    ) {
        self.markers = markers
        self.elementDeclarations = elementDeclarations
        self.groupDeclarations = groupDeclarations
    }

    public static let empty = StructurizrPreLexerScanResult(
        markers: [],
        elementDeclarations: [],
        groupDeclarations: []
    )
}

public func scanStructurizrRecoveryMarkers(_ source: String) -> [StructurizrRecoveryMarker] {
    var markers: [StructurizrRecoveryMarker] = []
    let tagPrefix = "diagramkit:tag="
    let boundaryParentPrefix = "diagramkit:boundary-parent="
    var lineNumber = 0
    for rawLine in source.components(separatedBy: "\n") {
        lineNumber += 1
        var trimmed = rawLine
        while let first = trimmed.first, first == " " || first == "\t" {
            trimmed.removeFirst()
        }
        guard trimmed.first == "#" else { continue }
        trimmed.removeFirst()
        while let first = trimmed.first, first == " " || first == "\t" {
            trimmed.removeFirst()
        }
        if trimmed.hasPrefix(tagPrefix) {
            var value = String(trimmed.dropFirst(tagPrefix.count))
            while let last = value.last, last == " " || last == "\t" || last == "\r" {
                value.removeLast()
            }
            markers.append(StructurizrRecoveryMarker(
                lineNumber: lineNumber,
                kind: .elementTag(value: value)
            ))
        } else if trimmed.hasPrefix(boundaryParentPrefix) {
            var value = String(trimmed.dropFirst(boundaryParentPrefix.count))
            while let last = value.last, last == " " || last == "\t" || last == "\r" {
                value.removeLast()
            }
            markers.append(StructurizrRecoveryMarker(
                lineNumber: lineNumber,
                kind: .boundaryParent(id: value)
            ))
        }
    }
    return markers
}

public func scanStructurizrPreLexer(_ source: String) -> StructurizrPreLexerScanResult {
    var markers: [StructurizrRecoveryMarker] = []
    var elementDeclarations: [StructurizrPreLexerScanResult.ElementDeclaration] = []
    var groupDeclarations: [StructurizrPreLexerScanResult.GroupDeclaration] = []
    let tagPrefix = "diagramkit:tag="
    let boundaryParentPrefix = "diagramkit:boundary-parent="
    var lineNumber = 0
    for rawLine in source.components(separatedBy: "\n") {
        lineNumber += 1
        var trimmed = rawLine
        while let first = trimmed.first, first == " " || first == "\t" {
            trimmed.removeFirst()
        }
        if trimmed.first == "#" {
            trimmed.removeFirst()
            while let first = trimmed.first, first == " " || first == "\t" {
                trimmed.removeFirst()
            }
            if trimmed.hasPrefix(tagPrefix) {
                var value = String(trimmed.dropFirst(tagPrefix.count))
                while let last = value.last, last == " " || last == "\t" || last == "\r" {
                    value.removeLast()
                }
                markers.append(StructurizrRecoveryMarker(
                    lineNumber: lineNumber,
                    kind: .elementTag(value: value)
                ))
            } else if trimmed.hasPrefix(boundaryParentPrefix) {
                var value = String(trimmed.dropFirst(boundaryParentPrefix.count))
                while let last = value.last, last == " " || last == "\t" || last == "\r" {
                    value.removeLast()
                }
                markers.append(StructurizrRecoveryMarker(
                    lineNumber: lineNumber,
                    kind: .boundaryParent(id: value)
                ))
            }
            continue
        }
        if let alias = parseElementDeclarationAlias(trimmed) {
            elementDeclarations.append(.init(alias: alias, line: lineNumber))
        } else if let label = parseGroupDeclarationLabel(trimmed) {
            groupDeclarations.append(.init(label: label, line: lineNumber))
        }
    }
    return StructurizrPreLexerScanResult(
        markers: markers,
        elementDeclarations: elementDeclarations,
        groupDeclarations: groupDeclarations
    )
}

private func parseElementDeclarationAlias(_ line: String) -> String? {
    var stripped = line
    if let slashes = stripped.range(of: "//") {
        stripped = String(stripped[..<slashes.lowerBound])
    }
    while let last = stripped.last, last == " " || last == "\t" || last == "\r" {
        stripped.removeLast()
    }
    guard let eqIdx = stripped.firstIndex(of: "=") else { return nil }
    let aliasPart = stripped[..<eqIdx]
    var alias = String(aliasPart)
    while let first = alias.first, first == " " || first == "\t" {
        alias.removeFirst()
    }
    while let last = alias.last, last == " " || last == "\t" {
        alias.removeLast()
    }
    guard !alias.isEmpty else { return nil }
    for c in alias {
        if !(c.isLetter || c.isNumber || c == "_" || c == "." || c == "/" || c == ":" || c == "-") {
            return nil
        }
    }
    guard let firstChar = alias.first, firstChar.isLetter || firstChar == "_" else {
        return nil
    }
    let rest = stripped[stripped.index(after: eqIdx)...]
    var restTrim = String(rest)
    while let first = restTrim.first, first == " " || first == "\t" {
        restTrim.removeFirst()
    }
    let kinds = ["person", "softwareSystem", "container", "component", "deploymentNode"]
    for kind in kinds {
        if restTrim.hasPrefix(kind) {
            let after = restTrim.index(restTrim.startIndex, offsetBy: kind.count)
            if after == restTrim.endIndex { return alias }
            let next = restTrim[after]
            if next == " " || next == "\t" || next == "\"" {
                return alias
            }
        }
    }
    return nil
}

private func parseGroupDeclarationLabel(_ line: String) -> String? {
    var stripped = line
    while let first = stripped.first, first == " " || first == "\t" {
        stripped.removeFirst()
    }
    guard stripped.hasPrefix("group") else { return nil }
    let afterGroup = stripped.index(stripped.startIndex, offsetBy: 5)
    guard afterGroup < stripped.endIndex else { return nil }
    let nextChar = stripped[afterGroup]
    guard nextChar == " " || nextChar == "\t" else { return nil }
    var rest = String(stripped[afterGroup...])
    while let first = rest.first, first == " " || first == "\t" {
        rest.removeFirst()
    }
    guard rest.first == "\"" else { return nil }
    rest.removeFirst()
    var label = ""
    var escaped = false
    for c in rest {
        if escaped {
            label.append(c)
            escaped = false
            continue
        }
        if c == "\\" {
            escaped = true
            continue
        }
        if c == "\"" {
            return label
        }
        label.append(c)
    }
    return nil
}

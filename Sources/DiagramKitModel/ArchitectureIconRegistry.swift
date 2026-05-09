import Foundation
import DiagramKitCommon

public typealias ArchitectureIconBody = String

public struct ArchitectureIconEntry: Sendable, Equatable {
    public var body: ArchitectureIconBody
    public var width: Int
    public var height: Int

    public init(body: ArchitectureIconBody, width: Int = 80, height: Int = 80) {
        self.body = body
        self.width = width
        self.height = height
    }
}

public struct ArchitectureIconPack: Sendable, Equatable {
    public var prefix: String
    public var icons: [String: ArchitectureIconEntry]

    public init(prefix: String, icons: [String: ArchitectureIconEntry]) {
        self.prefix = prefix
        self.icons = icons
    }
}

public final class ArchitectureIconRegistry: @unchecked Sendable {
    public static let shared = ArchitectureIconRegistry()

    private var packs: [String: ArchitectureIconPack] = [:]
    private let lock = NSLock()

    public func register(pack: ArchitectureIconPack) {
        lock.lock()
        defer { lock.unlock() }
        packs[pack.prefix] = pack
    }

    public func register(packs: [ArchitectureIconPack]) {
        for pack in packs {
            register(pack: pack)
        }
    }

    public func iconSVG(for iconName: String, fallbackPrefix: String = "mermaid-architecture") -> String? {
        let normalized = iconName.trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return nil }

        let (prefix, name): (String?, String)
        if normalized.contains(":") {
            let parts = normalized.split(separator: ":", maxSplits: 1)
            prefix = String(parts[0])
            name = String(parts[1])
        } else {
            prefix = nil
            name = normalized
        }

        let effectivePrefix = prefix ?? fallbackPrefix

        lock.lock()
        let pack = packs[effectivePrefix]
        lock.unlock()

        guard let pack = pack, let entry = pack.icons[name] else {
            if let bundled = _bundledExternalIconBody(forPrefix: effectivePrefix, name: name) {
                return bundled
            }
            return nil
        }

        let svgContent = entry.body
        guard _validateExternalIconSVG(svgContent) else {
            return nil
        }

        return svgContent
    }

    public func isAvailable(_ iconName: String) -> Bool {
        return iconSVG(for: iconName) != nil
    }

    public func hasBuiltInIcon(_ iconName: String) -> Bool {
        let name = iconName.trimmingCharacters(in: .whitespaces).lowercased()
        return _builtInIconNames.contains(name) || name == "unknown" || name == "blank"
    }

    public func builtInBody(for iconName: String) -> String? {
        let name = iconName.trimmingCharacters(in: .whitespaces).lowercased()
        switch name {
        case "cloud": return _cloudIconBody
        case "database": return _databaseIconBody
        case "disk": return _diskIconBody
        case "internet": return _internetIconBody
        case "server": return _serverIconBody
        case "unknown", "blank": return nil
        default: return nil
        }
    }

    public func resolveIconName(_ iconName: String, fallbackPrefix: String = "mermaid-architecture") -> (prefix: String, name: String) {
        let normalized = iconName.trimmingCharacters(in: .whitespaces)
        if normalized.contains(":") {
            let parts = normalized.split(separator: ":", maxSplits: 1)
            return (String(parts[0]), String(parts[1]))
        }
        return (fallbackPrefix, normalized)
    }

    public func isExternalIcon(_ iconName: String, fallbackPrefix: String = "mermaid-architecture") -> Bool {
        let (prefix, _) = resolveIconName(iconName, fallbackPrefix: fallbackPrefix)
        return prefix != fallbackPrefix
    }

    private func _validateExternalIconSVG(_ svg: String) -> Bool {
        let lower = svg.lowercased()
        let dangerous: [String] = [
            "<script", "onerror=", "onload=", "javascript:", "data:text/html",
            "<iframe", "<object", "<embed", "xlink:href=\"data:"
        ]
        for pattern in dangerous {
            if lower.contains(pattern) {
                return false
            }
        }
        return true
    }
}

private func _bundledExternalIconBody(forPrefix prefix: String, name: String) -> String? {
    switch (prefix.lowercased(), name.lowercased()) {
    case ("logos", "aws-s3"):
        return _awsS3IconBody
    default:
        return nil
    }
}

public func _sanitizeIconText(_ text: String?) -> String? {
    guard let text else { return nil }
    return SVG.escapeAttribute(text)
}

private var _builtInIconNames: Set<String> {
    ["cloud", "database", "disk", "internet", "server"]
}

private let _cloudIconBody = "<path d=\"M65 47.5c0 2.76-2.24 5-5 5H20c-2.76 0-5-2.24-5-5 0-1.87 1.03-3.51 2.56-4.36-.04-.21-.06-.42-.06-.64 0-2.6 2.48-4.74 5.65-4.97 1.65-4.51 6.34-7.76 11.85-7.76.86 0 1.69.08 2.5.23 2.09-1.57 4.69-2.5 7.5-2.5 6.1 0 11.19 4.38 12.28 10.17 2.14.56 3.72 2.51 3.72 4.83 0 .03 0 .07-.01.1 2.29.46 4.01 2.48 4.01 4.9Z\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/>"

private let _databaseIconBody = "<path d=\"M20 57.86c0 3.94 8.95 7.14 20 7.14s20-3.2 20-7.14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><path d=\"M20 45.95c0 3.94 8.95 7.14 20 7.14s20-3.2 20-7.14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><path d=\"M20 34.05c0 3.94 8.95 7.14 20 7.14s20-3.2 20-7.14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><ellipse cx=\"40\" cy=\"22.14\" rx=\"20\" ry=\"7.14\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><line x1=\"20\" y1=\"57.86\" x2=\"20\" y2=\"22.14\" stroke=\"currentColor\" stroke-width=\"2\"/><line x1=\"60\" y1=\"57.86\" x2=\"60\" y2=\"22.14\" stroke=\"currentColor\" stroke-width=\"2\"/>"

private let _diskIconBody = "<rect x=\"20\" y=\"15\" width=\"40\" height=\"50\" rx=\"1\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><ellipse cx=\"40\" cy=\"33.75\" rx=\"14\" ry=\"14.58\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><ellipse cx=\"40\" cy=\"33.75\" rx=\"4\" ry=\"4.17\" fill=\"currentColor\" stroke=\"currentColor\" stroke-width=\"2\"/>"

private let _internetIconBody = "<circle cx=\"40\" cy=\"40\" r=\"22.5\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><line x1=\"40\" y1=\"17.5\" x2=\"40\" y2=\"62.5\" stroke=\"currentColor\" stroke-width=\"2\"/><line x1=\"17.5\" y1=\"40\" x2=\"62.5\" y2=\"40\" stroke=\"currentColor\" stroke-width=\"2\"/><path d=\"M39.99 17.51c-15.28 11.1-15.28 33.88 0 44.98\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><path d=\"M40.01 17.51c15.28 11.1 15.28 33.88 0 44.98\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/>"

private let _serverIconBody = "<rect x=\"17.5\" y=\"17.5\" width=\"45\" height=\"45\" rx=\"2\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><line x1=\"17.5\" y1=\"32.5\" x2=\"62.5\" y2=\"32.5\" stroke=\"currentColor\" stroke-width=\"2\"/><line x1=\"17.5\" y1=\"47.5\" x2=\"62.5\" y2=\"47.5\" stroke=\"currentColor\" stroke-width=\"2\"/><circle cx=\"22.5\" cy=\"25\" r=\".75\" fill=\"currentColor\"/><circle cx=\"27.5\" cy=\"25\" r=\".75\" fill=\"currentColor\"/><circle cx=\"32.5\" cy=\"25\" r=\".75\" fill=\"currentColor\"/><circle cx=\"22.5\" cy=\"40\" r=\".75\" fill=\"currentColor\"/><circle cx=\"27.5\" cy=\"40\" r=\".75\" fill=\"currentColor\"/><circle cx=\"32.5\" cy=\"40\" r=\".75\" fill=\"currentColor\"/><circle cx=\"22.5\" cy=\"55\" r=\".75\" fill=\"currentColor\"/><circle cx=\"27.5\" cy=\"55\" r=\".75\" fill=\"currentColor\"/><circle cx=\"32.5\" cy=\"55\" r=\".75\" fill=\"currentColor\"/>"

private let _awsS3IconBody = "<g class=\"architecture-icon-aws-s3\"><path d=\"M20 24c0-5.52 8.95-10 20-10s20 4.48 20 10v32c0 5.52-8.95 10-20 10s-20-4.48-20-10V24Z\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><path d=\"M20 24c0 5.52 8.95 10 20 10s20-4.48 20-10\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><path d=\"M20 40c0 5.52 8.95 10 20 10s20-4.48 20-10\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><path d=\"M20 56c0 5.52 8.95 10 20 10s20-4.48 20-10\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/><path d=\"M29 20l11-6 11 6-11 6-11-6Z\" fill=\"currentColor\" opacity=\"0.18\"/></g>"

// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "BeautifulMermaidSwift",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .macCatalyst(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(name: "BeautifulMermaid", targets: ["BeautifulMermaid"]),
        .executable(name: "MermaidPlayground", targets: ["MermaidPlayground"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "BeautifulMermaid",
            dependencies: [
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            path: "Sources/BeautifulMermaidSwift"
        ),
        .executableTarget(
            name: "MermaidPlayground",
            dependencies: [
                "BeautifulMermaid",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            path: "Examples/MermaidPlayground",
            exclude: [
                "Info.plist",
                "Scripts"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "BeautifulMermaidSwiftTests",
            dependencies: [
                "BeautifulMermaid",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

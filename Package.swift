// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "BeautifulMermaidSwift",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "BeautifulMermaid", targets: ["BeautifulMermaid"]),
        .executable(name: "MermaidPlayground", targets: ["MermaidPlayground"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.18.0")
    ],
    targets: [
        .target(
            name: "BeautifulMermaid",
            dependencies: [
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            path: "Sources/BeautifulMermaidSwift",
            resources: [
                .process("Resources")
            ]
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
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: ["__Snapshots__"]
        )
    ],
    swiftLanguageModes: [.v6]
)

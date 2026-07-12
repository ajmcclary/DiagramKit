// swift-tools-version: 6.3
import PackageDescription

// `InferSendableFromCaptures` is already on by default in Swift 6 mode;
// re-enabling it via `.enableUpcomingFeature` emits a "feature is already
// enabled" warning per source file (one per compile job). We keep
// `StrictConcurrency` for documented intent and forward-compat against
// future toolchain shifts — it's silent under Swift 6.
let strictConcurrencySettings: [SwiftSetting] = [
    .enableUpcomingFeature("StrictConcurrency")
]

let package = Package(
    name: "DiagramKit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .library(name: "DiagramKit", targets: ["DiagramKit"]),
        .library(name: "DiagramKitImport", targets: ["DiagramKitImport"]),
        .library(name: "DiagramKitCommon", targets: ["DiagramKitCommon"]),
        .library(name: "DiagramKitModel", targets: ["DiagramKitModel"]),
        .library(name: "DiagramKitRenderingCG", targets: ["DiagramKitRenderingCG"]),
        .library(name: "DiagramKitViews", targets: ["DiagramKitViews"]),
        .library(name: "DiagramKitTestSupport", targets: ["DiagramKitTestSupport"]),
        .library(name: "DiagramKitD2", targets: ["DiagramKitD2"]),
        .library(name: "DiagramKitGraphviz", targets: ["DiagramKitGraphviz"]),
        .library(name: "DiagramKitStructurizr", targets: ["DiagramKitStructurizr"]),
        .library(name: "DiagramKitPlantUML", targets: ["DiagramKitPlantUML"]),
        .library(name: "DiagramKitExport", targets: ["DiagramKitExport"]),
        .library(name: "DiagramKitMermaid", targets: ["DiagramKitMermaid"]),
        .library(name: "DiagramKitInteractive", targets: ["DiagramKitInteractive"]),
        // Library products and the sample share the same macOS 26 / iOS 26 floor
        // declared above. The Xcode project that previously bundled the sample
        // (along with its UI test bundle and xcodegen project.yml) has been
        // removed in favor of pure SwiftPM (see commit history 2026-05-18).
        .executable(name: "DiagramKitSample", targets: ["DiagramKitSample"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
        // swift-crypto provides the CryptoKit API surface on Linux. On Apple
        // platforms `import CryptoKit` is preferred (zero-cost), but to keep
        // DiagramKitCommon Linux-portable for `StableID.derive(...)`, we
        // import `Crypto` from this package when CryptoKit is unavailable.
        .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
        // TEMP: pinned to the fork at `ajmcclary/swift-snapshot-testing` (branch
        // `fix-swift-6.3-attachable`), which carries pointfreeco/swift-snapshot-testing#1090
        // for the Swift 6.3 `Attachable` cross-import-overlay break. `Data: Attachable`
        // and `NSImage: AttachableAsImage` live in the `_Testing_Foundation` /
        // `_Testing_AppKit` overlays, which SwiftPM only enables for test targets — the
        // SnapshotTesting *library* target can't see those conformances on the
        // open-source `swift-6.3-RELEASE` toolchain. Once #1090 lands in a tagged
        // upstream release (likely 1.19.3+), switch back to:
        //   .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.x")
        .package(url: "https://github.com/ajmcclary/swift-snapshot-testing", branch: "fix-swift-6.3-attachable")
    ],
    targets: [
        .target(
            name: "DiagramKitCommon",
            dependencies: [
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitModel",
            dependencies: ["DiagramKitCommon"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitImport",
            dependencies: ["DiagramKitModel"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitD2",
            dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitGraphviz",
            dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitStructurizr",
            dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitPlantUML",
            dependencies: ["DiagramKitModel", "DiagramKitImport", "DiagramKitExport"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitExport",
            dependencies: ["DiagramKitCommon", "DiagramKitModel"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitMermaid",
            dependencies: ["DiagramKitCommon", "DiagramKitModel", "DiagramKitExport"],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitInteractive",
            dependencies: [
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitImport",
                "DiagramKitExport",
                "DiagramKitRenderingCG"
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitRenderingCG",
            dependencies: [
                "DiagramKitCommon",
                "DiagramKitModel"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitViews",
            dependencies: [
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitRenderingCG"
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKitTestSupport",
            dependencies: [
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitImport",
                "DiagramKitExport"
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .target(
            name: "DiagramKit",
            dependencies: [
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitImport",
                "DiagramKitExport",
                "DiagramKitMermaid",
                "DiagramKitInteractive",
                "DiagramKitD2",
                "DiagramKitGraphviz",
                "DiagramKitStructurizr",
                "DiagramKitPlantUML",
                "DiagramKitRenderingCG",
                "DiagramKitViews"
            ],
            swiftSettings: strictConcurrencySettings
        ),

        .target(
            name: "DiagramKitSampleDesignSystem",
            swiftSettings: strictConcurrencySettings
        ),

        .executableTarget(
            name: "DiagramKitSample",
            dependencies: [
                "DiagramKitSampleDesignSystem",
                "DiagramKit",
                "DiagramKitD2",
                "DiagramKitGraphviz",
                "DiagramKitStructurizr",
                "DiagramKitPlantUML",
                "DiagramKitInteractive",
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            // No `path:` — SwiftPM's default Sources/<TargetName>/ convention applies.
            resources: [
                .process("Resources")
            ],
            swiftSettings: strictConcurrencySettings + [
                // SwiftPM debug builds define DEBUG and expand SwiftUI
                // #Preview macros, but the preview macro plugin is only
                // available in the Xcode app-preview build path.
                .define("DIAGRAMKIT_SWIFTPM")
            ]
        ),
        .testTarget(
            name: "DiagramKitTests",
            dependencies: [
                "DiagramKit",
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitExport",
                "DiagramKitMermaid",
                "DiagramKitInteractive",
                "DiagramKitTestSupport",
                "DiagramKitSample",
                "DiagramKitSampleDesignSystem",
                "DiagramKitD2",
                "DiagramKitGraphviz",
                "DiagramKitStructurizr",
                "DiagramKitPlantUML",
                "DiagramKitRenderingCG",
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: [
                "__Snapshots__",
                "DesignSystem/__Snapshots__",
                // RoundTrip fixtures are loaded directly from the source tree
                // via `#filePath`, not from the test bundle. Excluding them
                // here avoids SwiftPM's "unhandled file" warnings for the
                // `.md` / `.puml` / `.d2` / `.dot` / `.dsl` corpus files.
                "RoundTrip/Resources"
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "DiagramKitLinuxTests",
            dependencies: [
                "DiagramKit",
                "DiagramKitCommon",
                "DiagramKitModel",
                "DiagramKitTestSupport",
            ],
            swiftSettings: strictConcurrencySettings
        )
    ],
    swiftLanguageModes: [.v6]
)

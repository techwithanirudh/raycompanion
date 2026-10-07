// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RayCompanion",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "RayCompanion", targets: ["RayCompanion"])],
    dependencies: [
        .package(url: "https://github.com/jaywcjlove/PermissionFlow", revision: "cb96db4bfd2342e8d8c56f2a7d51ca65b8aed6e2"),
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", revision: "a04ec1c363be3627734f6dad757d82f5d4fa8fcc")
    ],
    targets: [
        .target(name: "ChatCore"),
        .target(name: "TinycastKit", dependencies: ["PermissionFlow", .product(name: "Sparkle", package: "Sparkle")], exclude: [
            "Assets.xcassets", "Resources",
            "Features/Clipboard/Service/ClipboardTextExtractor.swift",
            "Features/Clipboard/Service/ClipboardTextHelper.swift"
        ], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])] ),
        .executableTarget(name: "RayCompanion", dependencies: ["TinycastKit", "ChatCore", "PermissionFlow", .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern")], path: "Sources/RayCompanion"),
        .executableTarget(name: "DictationHelper"),
        .executableTarget(name: "AIChatChecks", dependencies: ["TinycastKit"], path: "Checks/AIChatChecks"),
        .executableTarget(name: "AIProviderChecks", dependencies: ["TinycastKit"], path: "Checks/AIProviderChecks"),
        .executableTarget(name: "MarkdownChecks", dependencies: ["TinycastKit"], path: "Checks/MarkdownChecks"),
        .testTarget(name: "ChatCoreTests", dependencies: ["ChatCore"])
    ]
)

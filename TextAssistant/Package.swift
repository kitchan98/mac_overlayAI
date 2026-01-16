// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextAssistant",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "TextAssistant",
            dependencies: ["HotKey"],
            path: "TextAssistant"
        )
    ]
)

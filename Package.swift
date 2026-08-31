// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "term-code-open",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TermCodeOpenCore", targets: ["TermCodeOpenCore"]),
        .executable(name: "term-code-open", targets: ["TermCodeOpenApp"]),
    ],
    targets: [
        .target(name: "TermCodeOpenCore"),
        .executableTarget(
            name: "TermCodeOpenApp",
            dependencies: ["TermCodeOpenCore"]
        ),
        .testTarget(
            name: "TermCodeOpenCoreTests",
            dependencies: ["TermCodeOpenCore"]
        ),
    ]
)

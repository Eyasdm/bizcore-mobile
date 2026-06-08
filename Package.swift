// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BizCoreMobile",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "BizCoreMobile",
            targets: ["BizCoreMobile"]
        )
    ],
    targets: [
        .target(
            name: "BizCoreMobile",
            path: "Sources/BizCoreMobile",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
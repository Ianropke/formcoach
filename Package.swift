// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FormCoach",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "FormCoachCore",
            targets: ["FormCoachCore"]
        ),
        .library(
            name: "FormCoachUI",
            targets: ["FormCoachUI"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FormCoachCore",
            dependencies: [],
            path: "Sources/FormCoachCore"
        ),
        .target(
            name: "FormCoachUI",
            dependencies: ["FormCoachCore"],
            path: "Sources/FormCoachUI"
        ),
        .testTarget(
            name: "FormCoachTests",
            dependencies: ["FormCoachCore"],
            path: "Tests/FormCoachTests"
        )
    ]
)

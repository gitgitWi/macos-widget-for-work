// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WorkWidget",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    ],
    targets: [
        .executableTarget(
            name: "WorkWidget",
            dependencies: ["KeychainAccess"],
            path: "Sources",
            linkerSettings: [
                .linkedFramework("EventKit"),
            ]
        ),
    ]
)

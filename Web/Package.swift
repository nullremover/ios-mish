
 // swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MishWeb",
    products: [
        .executable(
            name: "MishWeb",
            targets: ["MishWeb"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftwasm/JavaScriptKit.git",
            from: "0.59.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "MishWeb",
            dependencies: [
                .product(
                    name: "JavaScriptKit",
                    package: "JavaScriptKit"
                )
            ]
        )
    ]
)

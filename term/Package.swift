// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "term",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "term",
            targets: ["term"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "term"),
        .testTarget(
            name: "termTests",
            dependencies: ["term"]
        ),
    ]
)

// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(name: "ModelPlanField", platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanField", targets: ["ModelPlanField"])],
    dependencies: [.package(name: "ModelPlanNative", path: "..")],
    targets: [
        .target(name: "ModelPlanField", dependencies: [
            .product(name: "ModelPlanCore", package: "ModelPlanNative")
        ], resources: [.copy("Web")]),
        .testTarget(name: "ModelPlanFieldTests", dependencies: ["ModelPlanField"]),
    ])

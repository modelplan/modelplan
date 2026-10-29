// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "ModelPlanEngineClient",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ModelPlanEngineClient", targets: ["ModelPlanEngineClient"])],
    dependencies: [.package(path: "../ModelPlanWire")],
    targets: [
        .target(
            name: "ModelPlanEngineClient",
            dependencies: [.product(name: "ModelPlanWire", package: "ModelPlanWire")]
        ),
        .testTarget(name: "ModelPlanEngineClientTests", dependencies: ["ModelPlanEngineClient", .product(name: "ModelPlanWire", package: "ModelPlanWire")])
    ]
)

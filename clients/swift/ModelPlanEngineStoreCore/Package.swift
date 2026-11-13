// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "ModelPlanEngineStoreCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ModelPlanEngineStoreCore", targets: ["ModelPlanEngineStoreCore"])],
    dependencies: [
        .package(path: "../ModelPlanEngineClient"),
        .package(path: "../ModelPlanWire")
    ],
    targets: [
        .target(name: "ModelPlanEngineStoreCore", dependencies: [
            .product(name: "ModelPlanEngineClient", package: "ModelPlanEngineClient"),
            .product(name: "ModelPlanWire", package: "ModelPlanWire")
        ]),
        .testTarget(name: "ModelPlanEngineStoreCoreTests", dependencies: [
            "ModelPlanEngineStoreCore",
            .product(name: "ModelPlanEngineClient", package: "ModelPlanEngineClient"),
            .product(name: "ModelPlanWire", package: "ModelPlanWire")
        ])
    ]
)

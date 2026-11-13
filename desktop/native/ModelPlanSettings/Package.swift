// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

// Lane-local entry point; shared app/manifest integration belongs to M0.
let package = Package(
    name: "ModelPlanSettings",
    platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanSettings", targets: ["ModelPlanSettings"])],
    dependencies: [
        .package(name: "ModelPlanNative", path: ".."),
        .package(path: "../../../clients/swift/ModelPlanWire"),
        .package(path: "../../../clients/swift/ModelPlanEngineClient"),
    ],
    targets: [
        .target(name: "ModelPlanSettings", dependencies: [
            .product(name: "ModelPlanDock", package: "ModelPlanNative"),
            .product(name: "ModelPlanWire", package: "ModelPlanWire"),
            .product(name: "ModelPlanEngineClient", package: "ModelPlanEngineClient"),
        ]),
        .testTarget(name: "ModelPlanSettingsTests", dependencies: ["ModelPlanSettings"]),
    ]
)

// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

// Composition lives above both packages: Settings already depends on the native Dock product.
let package = Package(
    name: "ModelPlanAppIntegration", platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanAppIntegration", targets: ["ModelPlanAppIntegration"])],
    dependencies: [
        .package(name: "ModelPlanNative", path: ".."),
        .package(name: "ModelPlanSettings", path: "../ModelPlanSettings"),
    ],
    targets: [
        .target(name: "ModelPlanAppIntegration", dependencies: [
            .product(name: "ModelPlanDock", package: "ModelPlanNative"),
            .product(name: "ModelPlanSettings", package: "ModelPlanSettings"),
        ]),
        .testTarget(name: "ModelPlanAppIntegrationTests", dependencies: ["ModelPlanAppIntegration"]),
    ]
)

// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

// Composition lives above both packages: Settings already depends on the native Dock product.
let package = Package(
    name: "ModelPlanAppIntegration", platforms: [.macOS(.v14)],
    products: [
        .library(name: "ModelPlanAppIntegration", targets: ["ModelPlanAppIntegration"]),
        .executable(name: "ModelPlanCommunityApp", targets: ["ModelPlanCommunityApp"]),
    ],
    dependencies: [
        .package(name: "ModelPlanNative", path: ".."),
        .package(name: "ModelPlanSettings", path: "../ModelPlanSettings"),
    ],
    targets: [
        .target(name: "ModelPlanAppIntegration", dependencies: [
            .product(name: "ModelPlanCore", package: "ModelPlanNative"),
            .product(name: "ModelPlanShell", package: "ModelPlanNative"),
            .product(name: "ModelPlanAssembly", package: "ModelPlanNative"),
            .product(name: "ModelPlanDock", package: "ModelPlanNative"),
            .product(name: "ModelPlanInstruments", package: "ModelPlanNative"),
            .product(name: "ModelPlanCockpitShell", package: "ModelPlanNative"),
            .product(name: "ModelPlanCommunityHost", package: "ModelPlanNative"),
            .product(name: "ModelPlanSettings", package: "ModelPlanSettings"),
        ], resources: [.copy("Resources")]),
        .executableTarget(name: "ModelPlanCommunityApp", dependencies: [
            "ModelPlanAppIntegration",
            .product(name: "ModelPlanCommunityHost", package: "ModelPlanNative"),
            .product(name: "ModelPlanShell", package: "ModelPlanNative"),
            .product(name: "ModelPlanSettings", package: "ModelPlanSettings"),
        ]),
        .testTarget(name: "ModelPlanAppIntegrationTests", dependencies: ["ModelPlanAppIntegration"], resources: [.process("Fixtures")]),
    ]
)

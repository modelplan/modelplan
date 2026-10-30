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
        .package(path: "../ModelPlanCockpitWeb"),
        .package(path: "../ModelPlanEngineStore"),
        .package(path: "../../../clients/swift/ModelPlanEngineClient"),
        .package(path: "../../../clients/swift/ModelPlanWire"),
    ],
    targets: [
        .target(name: "ModelPlanAppIntegration", dependencies: [
            .product(name: "ModelPlanCockpitWeb", package: "ModelPlanCockpitWeb"),
            .product(name: "ModelPlanEngineStore", package: "ModelPlanEngineStore"),
            .product(name: "ModelPlanEngineClient", package: "ModelPlanEngineClient"),
            .product(name: "ModelPlanWire", package: "ModelPlanWire"),
            .product(name: "ModelPlanCore", package: "ModelPlanNative"),
            .product(name: "ModelPlanShell", package: "ModelPlanNative"),
            .product(name: "ModelPlanAssembly", package: "ModelPlanNative"),
            .product(name: "ModelPlanDock", package: "ModelPlanNative"),
            .product(name: "ModelPlanInstruments", package: "ModelPlanNative"),
            .product(name: "ModelPlanCockpitShell", package: "ModelPlanNative"),
            .product(name: "ModelPlanField", package: "ModelPlanNative"),
            .product(name: "ModelPlanCommunityHost", package: "ModelPlanNative"),
            .product(name: "ModelPlanSettings", package: "ModelPlanSettings"),
        ], resources: [.copy("Resources")]),
        .executableTarget(name: "ModelPlanCommunityApp", dependencies: [
            .product(name: "ModelPlanCockpitWeb", package: "ModelPlanCockpitWeb"),
            .product(name: "ModelPlanEngineClient", package: "ModelPlanEngineClient"),
            .product(name: "ModelPlanWire", package: "ModelPlanWire"),
            "ModelPlanAppIntegration",
            .product(name: "ModelPlanCommunityHost", package: "ModelPlanNative"),
            .product(name: "ModelPlanShell", package: "ModelPlanNative"),
            .product(name: "ModelPlanSettings", package: "ModelPlanSettings"),
        ]),
        .testTarget(name: "ModelPlanAppCLIConsentContractTests", dependencies: [
            "ModelPlanAppIntegration",
            .product(name: "ModelPlanCore", package: "ModelPlanNative"),
            .product(name: "ModelPlanSettings", package: "ModelPlanSettings"),
        ], path: "AppCLIContractTests"),
        .testTarget(name: "ModelPlanAppIntegrationTests", dependencies: ["ModelPlanAppIntegration", .product(name: "ModelPlanEngineStore", package: "ModelPlanEngineStore")], resources: [.process("Fixtures")]),
    ]
)

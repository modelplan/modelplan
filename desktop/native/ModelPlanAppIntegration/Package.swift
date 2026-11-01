// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

// Composition lives above both packages: Settings already depends on the native Dock product.
let package = Package(
    name: "ModelPlanAppIntegration", platforms: [.macOS(.v14)],
    products: [
        .library(name: "ModelPlanAppIntegration", targets: ["ModelPlanAppIntegration"]),
        .executable(name: "ModelPlanCommunityApp", targets: ["ModelPlanCommunityApp"]),
        .executable(name: "S1Gallery", targets: ["S1Gallery"]),
    ],
    dependencies: [
        .package(name: "ModelPlanNative", path: ".."),
        .package(name: "ModelPlanSettings", path: "../ModelPlanSettings"),
        .package(path: "../ModelPlanCockpitWeb"),
        .package(path: "../ModelPlanEngineStore"),
        .package(path: "../../../clients/swift/ModelPlanEngineClient"),
        .package(path: "../../../clients/swift/ModelPlanWire"),
        .package(path: "../../official-visuals/dock"),
        .package(path: "../../third-party/dock-resources"),
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
            .product(name: "ModelPlanPrimitives", package: "ModelPlanNative"),
            .product(name: "ModelPlanInstruments", package: "ModelPlanNative"),
            .product(name: "ModelPlanCockpitShell", package: "ModelPlanNative"),
            .product(name: "ModelPlanField", package: "ModelPlanNative"),
            .product(name: "ModelPlanCommunityHost", package: "ModelPlanNative"),
            .product(name: "ModelPlanSettings", package: "ModelPlanSettings"),
            .product(name: "ModelPlanOfficialDock", package: "dock"),
            .product(name: "ModelPlanDockResources", package: "dock-resources"),
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
        .target(name: "S1GalleryCore", dependencies: ["ModelPlanAppIntegration",
            .product(name: "ModelPlanDock", package: "ModelPlanNative"),
            .product(name: "ModelPlanPrimitives", package: "ModelPlanNative"),
            .product(name: "ModelPlanOfficialDock", package: "dock"),
            .product(name: "ModelPlanSettings", package: "ModelPlanSettings"),
            .product(name: "ModelPlanDockResources", package: "dock-resources")]),
        .executableTarget(name: "S1Gallery", dependencies: ["S1GalleryCore"]),
        .testTarget(name: "ModelPlanAppCLIConsentContractTests", dependencies: [
            "ModelPlanAppIntegration",
            .product(name: "ModelPlanCore", package: "ModelPlanNative"),
            .product(name: "ModelPlanSettings", package: "ModelPlanSettings"),
        ], path: "AppCLIContractTests"),
        .testTarget(name: "ModelPlanAppIntegrationTests", dependencies: ["ModelPlanAppIntegration", "S1GalleryCore",
            .product(name: "ModelPlanEngineStore", package: "ModelPlanEngineStore"),
            .product(name: "ModelPlanDock", package: "ModelPlanNative"),
            .product(name: "ModelPlanPrimitives", package: "ModelPlanNative"),
            .product(name: "ModelPlanOfficialDock", package: "dock"),
            .product(name: "ModelPlanDockResources", package: "dock-resources")], resources: [.process("Fixtures")]),
    ]
)

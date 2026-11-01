// swift-tools-version: 6.0
// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import PackageDescription

let package = Package(name: "ModelPlanOfficialDock", platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanOfficialDock", targets: ["ModelPlanOfficialDock"])],
    dependencies: [.package(name: "ModelPlanNative", path: "../../native")],
    targets: [
        .target(name: "ModelPlanOfficialDock", dependencies: [.product(name: "ModelPlanDock", package: "ModelPlanNative"), .product(name: "ModelPlanPrimitives", package: "ModelPlanNative")], path: ".", exclude: ["Tests", "manifest.json", "README.md", "SOURCES.md", "T2ImpactJet.swift", "RegressionBaselines"],
                sources: ["T2EdgeCoordinates.swift", "T2Geometry.swift", "T2Grain.swift", "T2FaceMaterial.swift", "T2BundledArtwork.swift", "T2FlameFrameProvider.swift", "T2DockSkin.swift"],
                resources: [.copy("Resources")]),
        .testTarget(name: "ModelPlanOfficialDockTests", dependencies: ["ModelPlanOfficialDock", .product(name: "ModelPlanPrimitives", package: "ModelPlanNative")], path: "Tests", exclude: ["T2ImpactJetTests.swift"],
                    resources: [.copy("geometry-oracle.json")])
    ])

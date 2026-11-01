// swift-tools-version: 6.0
// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import PackageDescription

let package = Package(name: "ModelPlanOfficialDock", platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanOfficialDock", targets: ["ModelPlanOfficialDock"])],
    dependencies: [.package(name: "ModelPlanNative", path: "../../native")],
    targets: [
        .target(name: "ModelPlanOfficialDock", dependencies: [.product(name: "ModelPlanDock", package: "ModelPlanNative")], path: ".", exclude: ["Tests", "manifest.json", "README.md"],
                sources: ["T2EdgeCoordinates.swift", "T2Geometry.swift", "T2Grain.swift", "T2FaceMaterial.swift", "T2BundledArtwork.swift", "T2ResetEventDots.swift", "T2DockSkin.swift"],
                resources: [.copy("Resources")]),
        .testTarget(name: "ModelPlanOfficialDockTests", dependencies: ["ModelPlanOfficialDock"], path: "Tests",
                    resources: [.copy("geometry-oracle.json")])
    ])

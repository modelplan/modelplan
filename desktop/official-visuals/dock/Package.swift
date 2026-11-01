// swift-tools-version: 6.0
// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import PackageDescription

let package = Package(name: "ModelPlanOfficialDock", platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanOfficialDock", targets: ["ModelPlanOfficialDock"])],
    targets: [
        .target(name: "ModelPlanOfficialDock", path: ".", exclude: ["Tests", "manifest.json", "README.md"],
                sources: ["T2EdgeCoordinates.swift", "T2Geometry.swift", "T2Grain.swift", "T2FaceMaterial.swift", "T2BundledArtwork.swift", "T2ResetEventDots.swift"],
                resources: [.copy("Resources")]),
        .testTarget(name: "ModelPlanOfficialDockTests", dependencies: ["ModelPlanOfficialDock"], path: "Tests",
                    resources: [.copy("geometry-oracle.json")])
    ])

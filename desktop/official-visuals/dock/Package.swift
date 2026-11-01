// swift-tools-version: 6.0
// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import PackageDescription

let package = Package(name: "ModelPlanOfficialDock", platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanOfficialDock", targets: ["ModelPlanOfficialDock"])],
    targets: [
        .target(name: "ModelPlanOfficialDock", path: ".", exclude: ["Tests", "manifest.json"],
                sources: ["T2EdgeCoordinates.swift", "T2Geometry.swift"]),
        .testTarget(name: "ModelPlanOfficialDockTests", dependencies: ["ModelPlanOfficialDock"], path: "Tests")
    ])

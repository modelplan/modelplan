// swift-tools-version: 6.0
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(name: "ModelPlanDockResources", platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanDockResources", targets: ["ModelPlanDockResources"])],
    dependencies: [.package(name: "ModelPlanNative", path: "../../native")],
    targets: [
        .target(name: "ModelPlanDockResources", path: ".", exclude: ["Tests", "README.md"],
                sources: ["DockResources.swift"], resources: [.copy("Resources")]),
        .testTarget(name: "ModelPlanDockResourcesTests", dependencies: ["ModelPlanDockResources",
            .product(name: "ModelPlanDock", package: "ModelPlanNative")], path: "Tests")
    ])

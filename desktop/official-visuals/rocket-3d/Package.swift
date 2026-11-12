// swift-tools-version: 5.9
// SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0
import PackageDescription

let package = Package(name: "ModelPlanOfficialRocket", platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanOfficialRocket", targets: ["ModelPlanOfficialRocket"])],
    dependencies: [.package(name: "ModelPlanNative", path: "../../native")],
    targets: [
        .target(name: "ModelPlanOfficialRocket", dependencies: [.product(name: "ModelPlanEntrance", package: "ModelPlanNative")],
                path: ".", exclude: ["Tests", "manifest.json", "README.md", "SOURCES.md"],
                sources: ["OfficialRocket.swift"], resources: [.copy("Resources")]),
        .testTarget(name: "ModelPlanOfficialRocketTests", dependencies: ["ModelPlanOfficialRocket", .product(name: "ModelPlanEntrance", package: "ModelPlanNative"),
                                                                 .product(name: "ModelPlanEntranceScene", package: "ModelPlanNative")], path: "Tests/ModelPlanOfficialRocketTests",
                    resources: [.copy("c01-aperture-890.json")]),
    ])

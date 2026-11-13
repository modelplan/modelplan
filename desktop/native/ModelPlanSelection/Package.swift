// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(name: "ModelPlanSelection", platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanSelection", targets: ["ModelPlanSelection"])],
    targets: [.target(name: "ModelPlanSelection"),
              .testTarget(name: "ModelPlanSelectionTests", dependencies: ["ModelPlanSelection"])])

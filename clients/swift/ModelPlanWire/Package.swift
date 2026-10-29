// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "ModelPlanWire",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ModelPlanWire", targets: ["ModelPlanWire"])],
    targets: [
        .target(name: "ModelPlanWire"),
        .testTarget(name: "ModelPlanWireTests", dependencies: ["ModelPlanWire"])
    ]
)

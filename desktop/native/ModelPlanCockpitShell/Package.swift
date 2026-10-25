// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

// Lane-local entry point until M0 registers these targets in the shared manifest.
let package = Package(
    name: "ModelPlanCockpitShell",
    platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanCockpitShell", targets: ["ModelPlanCockpitShell"])],
    dependencies: [.package(name: "ModelPlanNative", path: "..")],
    targets: [
        .target(name: "ModelPlanCockpitShell", dependencies: [
            .product(name: "ModelPlanPrimitives", package: "ModelPlanNative"),
        ]),
        .testTarget(name: "ModelPlanCockpitShellTests", dependencies: ["ModelPlanCockpitShell"]),
    ]
)

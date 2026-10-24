// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(name: "ModelPlanNative", platforms: [.macOS(.v14)], products: [
    .library(name: "ModelPlanCore", targets: ["ModelPlanCore"]),
    .executable(name: "ModelPlanCommunity", targets: ["ModelPlanCommunity"]),
], targets: [
    .target(name: "ModelPlanCore"),
    .executableTarget(name: "ModelPlanCommunity", dependencies: ["ModelPlanCore"]),
    .executableTarget(name: "ModelPlanContractChecks", dependencies: ["ModelPlanCore"], path: "ContractChecks", resources: [.copy("Fixtures")]),
])

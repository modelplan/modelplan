// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(name: "ModelPlanNative", platforms: [.macOS(.v14)], products: [
    .library(name: "ModelPlanCore", targets: ["ModelPlanCore"]),
    .library(name: "ModelPlanShell", targets: ["ModelPlanShell"]),
    .library(name: "ModelPlanPrimitives", targets: ["ModelPlanPrimitives"]),
    .executable(name: "ModelPlanCommunity", targets: ["ModelPlanCommunity"]),
], targets: [
    .target(name: "ModelPlanCore"),
    .target(name: "ModelPlanShell", dependencies: ["ModelPlanCore"]),
    .executableTarget(name: "ModelPlanFieldProbe", dependencies: ["ModelPlanCore", "ModelPlanShell"], path: "FieldProbe"),
    .target(name: "ModelPlanPrimitives", dependencies: ["ModelPlanCore"]),
    .executableTarget(name: "ModelPlanPrimitiveProbe", dependencies: ["ModelPlanCore", "ModelPlanPrimitives"], path: "PrimitiveProbe"),
    .executableTarget(name: "ModelPlanPrimitiveChecks", dependencies: ["ModelPlanCore", "ModelPlanPrimitives"], path: "PrimitiveChecks"),
    .executableTarget(name: "ModelPlanCommunity", dependencies: ["ModelPlanCore", "ModelPlanShell"]),
    .executableTarget(name: "ModelPlanRunLoopChecks", dependencies: ["ModelPlanCore"], path: "RunLoopChecks"),
    .executableTarget(name: "ModelPlanShellChecks", dependencies: ["ModelPlanCore", "ModelPlanShell"], path: "ShellChecks"),
    .executableTarget(name: "ModelPlanContractChecks", dependencies: ["ModelPlanCore"], path: "ContractChecks", resources: [.copy("Fixtures")]),
])

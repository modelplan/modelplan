// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(name: "ModelPlanNative", platforms: [.macOS(.v14)], products: [
    .library(name: "ModelPlanCore", targets: ["ModelPlanCore"]),
    .library(name: "ModelPlanShell", targets: ["ModelPlanShell"]),
    .library(name: "ModelPlanPrimitives", targets: ["ModelPlanPrimitives"]),
    .library(name: "ModelPlanDock", targets: ["ModelPlanDock"]),
    .library(name: "ModelPlanInstruments", targets: ["ModelPlanInstruments"]),
    .library(name: "ModelPlanCockpitShell", targets: ["ModelPlanCockpitShell"]),
    .executable(name: "ModelPlanWindowProbe", targets: ["ModelPlanWindowProbe"]),
    .executable(name: "ModelPlanCommunity", targets: ["ModelPlanCommunity"]),
], targets: [
    .target(name: "ModelPlanCore"),
    .target(name: "ModelPlanShell", dependencies: ["ModelPlanCore"]),
    .executableTarget(name: "ModelPlanFieldProbe", dependencies: ["ModelPlanCore", "ModelPlanShell"], path: "FieldProbe"),
    .target(name: "ModelPlanPrimitives", dependencies: ["ModelPlanCore"]),
    .executableTarget(name: "ModelPlanPrimitiveProbe", dependencies: ["ModelPlanCore", "ModelPlanPrimitives"], path: "PrimitiveProbe"),
    .executableTarget(name: "ModelPlanPrimitiveChecks", dependencies: ["ModelPlanCore", "ModelPlanPrimitives"], path: "PrimitiveChecks"),
    .target(name: "ModelPlanDock", path: "ModelPlanDock/Logic"),
    .executableTarget(name: "ModelPlanDockLogicChecks", dependencies: ["ModelPlanDock"], path: "ModelPlanDock/LogicChecks"),
    .target(name: "ModelPlanInstruments", path: "ModelPlanInstruments/Sources/ModelPlanInstruments"),
    .testTarget(name: "ModelPlanInstrumentsTests", dependencies: ["ModelPlanInstruments"],
                path: "ModelPlanInstruments/Tests/ModelPlanInstrumentsTests"),
    .target(name: "ModelPlanCockpitShell", dependencies: ["ModelPlanPrimitives"],
            path: "ModelPlanCockpitShell/Sources/ModelPlanCockpitShell"),
    .testTarget(name: "ModelPlanCockpitShellTests", dependencies: ["ModelPlanCockpitShell"],
                path: "ModelPlanCockpitShell/Tests/ModelPlanCockpitShellTests"),
    .executableTarget(name: "ModelPlanWindowProbe", path: "ModelPlanDock/WindowInputProof",
                      exclude: ["README.md", "build.sh", "run-pair.py", "sample-owned.py"],
                      sources: ["Geometry.swift", "main.swift"]),
    .executableTarget(name: "ModelPlanCommunity", dependencies: ["ModelPlanCore", "ModelPlanShell"]),
    .executableTarget(name: "ModelPlanRunLoopChecks", dependencies: ["ModelPlanCore"], path: "RunLoopChecks"),
    .executableTarget(name: "ModelPlanShellChecks", dependencies: ["ModelPlanCore", "ModelPlanShell"], path: "ShellChecks"),
    .executableTarget(name: "ModelPlanContractV1Checks", dependencies: ["ModelPlanCore"], path: "ContractV1Checks"),
    .executableTarget(name: "ModelPlanContractChecks", dependencies: ["ModelPlanCore"], path: "ContractChecks", resources: [.copy("Fixtures")]),
])

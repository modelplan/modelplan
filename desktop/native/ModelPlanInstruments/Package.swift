// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

// Isolated lane package until the assembly owner registers this target in desktop/native.
let package = Package(
    name: "ModelPlanInstruments",
    platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanInstruments", targets: ["ModelPlanInstruments"])],
    targets: [
        .target(name: "ModelPlanInstruments"),
        .testTarget(name: "ModelPlanInstrumentsTests", dependencies: ["ModelPlanInstruments"]),
    ]
)

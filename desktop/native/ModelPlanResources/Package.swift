// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

// The resource plugin's native side (owner D324, D327): ResourceSampler (system calls only, never a child process),
// its cadence state machine, the 10-minute in-memory history, the widget readout rules and the hover-card rows.
let package = Package(name: "ModelPlanResources", platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanResources", targets: ["ModelPlanResources"])],
    targets: [.target(name: "ModelPlanResources"),
              .testTarget(name: "ModelPlanResourcesTests", dependencies: ["ModelPlanResources"])])

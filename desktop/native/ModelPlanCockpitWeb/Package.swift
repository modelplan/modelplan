// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
  name: "ModelPlanCockpitWeb", platforms: [.macOS(.v14)],
  products: [.library(name: "ModelPlanCockpitWeb", targets: ["ModelPlanCockpitWeb"])],
  dependencies: [
    .package(path: "../../../clients/swift/ModelPlanWire"),
    .package(path: "../../../clients/swift/ModelPlanEngineClient"),
  ],
  targets: [
    .target(
      name: "ModelPlanCockpitWeb",
      dependencies: [
        .product(name: "ModelPlanWire", package: "ModelPlanWire"),
        .product(name: "ModelPlanEngineClient", package: "ModelPlanEngineClient"),
      ]),
    .testTarget(
      name: "ModelPlanCockpitWebTests", dependencies: ["ModelPlanCockpitWeb"],
      resources: [.copy("Fixtures")]),
  ]
)

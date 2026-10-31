// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
  name: "ModelPlanMenuVerification", platforms: [.macOS(.v14)],
  products: [.library(name: "ModelPlanMenuVerification", targets: ["ModelPlanMenuVerification"])],
  targets: [
    .target(name: "ModelPlanMenuVerification"),
    .testTarget(
      name: "ModelPlanMenuVerificationTests", dependencies: ["ModelPlanMenuVerification"]),
  ])

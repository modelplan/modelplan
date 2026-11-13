// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription
let package = Package(name: "ModelPlanCredentialAgent", platforms: [.macOS(.v13)], products: [.library(name: "ModelPlanCredentialAgent", targets: ["ModelPlanCredentialAgent"])], dependencies: [.package(path: "../../../clients/swift/ModelPlanEngineClient"), .package(path: "../../../clients/swift/ModelPlanWire")], targets: [.target(name: "ModelPlanCredentialAgent", dependencies: ["ModelPlanEngineClient", "ModelPlanWire"]), .testTarget(name: "ModelPlanCredentialAgentTests", dependencies: ["ModelPlanCredentialAgent", "ModelPlanEngineClient", "ModelPlanWire"])])

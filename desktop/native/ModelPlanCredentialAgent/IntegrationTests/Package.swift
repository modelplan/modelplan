// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription
let package = Package(name: "U7ConnectionTests", platforms: [.macOS(.v14)], dependencies: [
    .package(path: "../../ModelPlanEngineStore"),
    .package(path: ".."),
    .package(path: "../../../../clients/swift/ModelPlanEngineClient"),
    .package(path: "../../../../clients/swift/ModelPlanWire")
], targets: [.testTarget(name: "U7ConnectionTests", dependencies: [
    "ModelPlanEngineStore", "ModelPlanCredentialAgent", "ModelPlanEngineClient", "ModelPlanWire"
], resources: [.copy("Fixtures")])])

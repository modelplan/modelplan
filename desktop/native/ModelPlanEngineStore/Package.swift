// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
    name: "ModelPlanEngineStore", platforms: [.macOS(.v14)],
    products: [.library(name: "ModelPlanEngineStore", targets: ["ModelPlanEngineStore"])],
    dependencies: [
        .package(path: "../../../clients/swift/ModelPlanEngineClient"),
        .package(path: "../../../clients/swift/ModelPlanWire")
    ],
    targets: [
        .target(name: "ModelPlanEngineStore", dependencies: [
            .product(name: "ModelPlanEngineClient", package: "ModelPlanEngineClient"),
            .product(name: "ModelPlanWire", package: "ModelPlanWire")
        ]),
        .testTarget(name: "ModelPlanEngineStoreTests", dependencies: [
            "ModelPlanEngineStore",
            .product(name: "ModelPlanEngineClient", package: "ModelPlanEngineClient"),
            .product(name: "ModelPlanWire", package: "ModelPlanWire")
        ])
    ]
)

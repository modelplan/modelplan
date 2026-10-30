// swift-tools-version: 5.9
// SPDX-License-Identifier: MIT
import PackageDescription

let package = Package(
  name: "U11WiredVerification", platforms: [.macOS(.v14)],
  products: [.executable(name: "U11WiredHost", targets: ["U11WiredHost"])],
  dependencies: [.package(path: "../ModelPlanCockpitWeb")],
  targets: [
    .executableTarget(
      name: "U11WiredHost",
      dependencies: [.product(name: "ModelPlanCockpitWeb", package: "ModelPlanCockpitWeb")],
      path: ".",
      exclude: [
        "bin", "tests", "fixtures", "results", "__pycache__", "SKILL.md", "feature-map.md",
        "ObservationSelfTests.swift", "test_observation.py", "test-animation-observer.mjs",
        "test-stable-layer.mjs", "animation-observer.js", "stable-layer.js",
      ], sources: ["Observation.swift", "U11aHost.swift", "U11WiredAdapter.swift"],
      swiftSettings: [.define("MODELPLAN_TEST_ONLY_SPI"), .define("MODELPLAN_U11_WIRED")])
  ])

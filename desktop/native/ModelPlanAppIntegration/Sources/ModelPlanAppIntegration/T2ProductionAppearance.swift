// SPDX-License-Identifier: MIT
import CoreGraphics
import Foundation
import ModelPlanDock
import ModelPlanOfficialDock
import ModelPlanDockResources
import ModelPlanSettings

/// Connects verified artwork and the registered T2 geometry to the production host.
@MainActor enum T2ProductionAppearance {
    static func apply(_ view: DockInstrumentView, _ rows: [DockInstrumentReading], _ preferences: SettingsPreferences) throws -> StaticDockGeometry {
        guard let screen = view.appearanceDisplaySize, screen.width > 0, screen.height > 0 else { throw T2Geometry.InputError.invalidGeometry }
        let edge: T2Edge
        switch preferences.dockEdge {
        case .left: edge = .left
        case .right: edge = .right
        case .bottom: edge = .bottom
        }
        let coords = T2EdgeCoordinates(edge: edge, width: screen.width, height: screen.height, menuBarExclusion: view.appearanceMenuBarExclusion)
        let input = T2GeometryInput(coordinates: coords, diameter: preferences.size.nozzleDiameter, showsPercentages: preferences.showPercentages, along: preferences.dockAlongFraction)
        let subscriptions = rows.map { T2Subscription(id: $0.subscriptionID, alias: $0.alias ?? "") }
        let geometry = try T2Geometry.make(subscriptions: subscriptions, input: input)
        let skin = try T2DockSkin.make(geometry: geometry, rows: rows, showsPercentages: preferences.showPercentages)
        let artwork = try T2BundledArtwork.records().mapValues { DockResourceFile(path: $0.path, sha256: $0.sha256, bytes: $0.bytes) }
        let official = try DockArtworkStore(root: T2BundledArtwork.rootURL(), manifest: .init(files: artwork))
        let vendorManifest = try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(allowBetaMarks: false))
        let vendor = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: vendorManifest)
        let material = T2FaceMaterial()
        let renderer = DockInstrumentRenderer(resources: official, supplementalResources: vendor) { supplied, scale in
            try material.render(geometry: geometry, viewport: supplied.bounds, scale: scale)
        }
        try view.applyOfficial(skin: skin, rows: rows, renderer: renderer, scale: 1, locale: preferences.language.rawValue)
        let button = try geometry.consoleButtonRect(in: skin.bounds)
        var result = StaticDockGeometry(hoverRects: [view.bounds], consoleButton: button,
                                        dragRegions: view.registeredDragRegions(excluding: [button]))
        if let hull = view.registeredHullBounds {
            try result.registerSliver(hullBounds: hull, expandedSize: view.bounds.size, edge: preferences.dockEdge,
                                      scale: preferences.size.nozzleDiameter / 44)
        }
        return result
    }
}

// SPDX-License-Identifier: MIT
import CoreGraphics
import Foundation
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanOfficialDock
import ModelPlanDockResources
import ModelPlanSettings

/// Connects verified artwork and the registered T2 geometry to the production host.
@MainActor enum T2ProductionAppearance {
    enum Failure: Error { case missingDisplay }
    static func apply(_ view: DockInstrumentView, _ rows: [DockInstrumentReading], _ preferences: SettingsPreferences) throws -> StaticDockGeometry {
        guard let screen = view.appearanceDisplaySize, screen.width > 0, screen.height > 0 else { throw Failure.missingDisplay }
        let edge: T2Edge
        switch preferences.dockEdge {
        case .left: edge = .left
        case .right: edge = .right
        case .bottom: edge = .bottom
        }
        let subscriptions = rows.map { T2Subscription(id: $0.subscriptionID, alias: $0.alias ?? "", hasEvent: view.appearanceNotices[$0.subscriptionID] != nil) }
        let vertical = edge != .bottom
        let nativeEdge: DockEdge = edge == .left ? .left : edge == .right ? .right : .bottom
        let room = PulseRestingPlacement.frameRoom(CGRect(origin: .zero, size: screen), edge: nativeEdge)
        var budget = screen
        var fit: (T2Geometry, DockInstrumentSkin)?
        // T2 measures its curved span before raster bounds union the ignition.
        // Feed any measured excess back into the overflow budget before drawing.
        for _ in 0..<8 {
            // Preserve the study's top-left origin for artwork and control registration.
            // The top reservation is added to the coordinate extent and excluded from
            // the along-edge budget, so fit still uses only the available rectangle.
            let top = view.appearanceMenuBarExclusion
            let coords = T2EdgeCoordinates(edge: edge, width: budget.width, height: budget.height + top,
                                           menuBarExclusion: top)
            let input = T2GeometryInput(coordinates: coords, diameter: preferences.size.nozzleDiameter,
                showsPercentages: preferences.showPercentages, along: preferences.dockAlongFraction)
            let geometry = try T2Geometry.make(subscriptions: subscriptions, input: input)
            let skin = try T2DockSkin.make(geometry: geometry, rows: rows, showsPercentages: preferences.showPercentages,
                                          zaiMarkEnabled: view.zaiMarkEnabled)
            guard vertical ? skin.bounds.width <= room.width : skin.bounds.height <= room.height else { break }
            let excess = vertical ? skin.bounds.height - room.height : skin.bounds.width - room.width
            if excess <= 0 { fit = (geometry, skin); break }
            if vertical { budget.height -= ceil(excess) }
            else { budget.width -= ceil(excess) }
        }
        guard let (geometry, skin) = fit else { throw DockEdgeError.invalidGeometry }
        let artwork = try T2BundledArtwork.records().mapValues { DockResourceFile(path: $0.path, sha256: $0.sha256, bytes: $0.bytes) }
        let official = try DockArtworkStore(root: T2BundledArtwork.rootURL(), manifest: .init(files: artwork))
        let vendorManifest = try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(zaiMarkEnabled: view.zaiMarkEnabled))
        let vendor = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: vendorManifest)
        let material = T2FaceMaterial()
        let renderer = DockInstrumentRenderer(resources: official, supplementalResources: vendor) { supplied, scale in
            try material.render(geometry: geometry, viewport: supplied.bounds, scale: scale)
        }
        var notices = view.appearanceNotices
        if let notice = geometry.overflow.compactMap({ notices[$0.id] }).min(by: { $0.rank < $1.rank }) {
            notices["__t2_overflow_notice__"] = notice
        }
        try view.applyOfficial(skin: skin, rows: rows, notices: notices, renderer: renderer, scale: 1, locale: preferences.language.rawValue)
        let button = try geometry.consoleButtonRect(in: skin.bounds)
        var result = StaticDockGeometry(hoverRects: [view.bounds], consoleButton: button,
                                        dragRegions: view.registeredDragRegions(excluding: [button]))
        let horizontal = edge == .bottom || edge == .top
        for station in geometry.stations {
            let position = horizontal ? station.centre.x : station.centre.y
            let fraction = max(0, min(1, (position - (geometry.placementCentre - geometry.span / 2)) / geometry.span))
            if let id = station.subscription?.id {
                result.noticeStationBySubscription[id] = id
                result.noticeStationPositions[id] = fraction
            } else if station.isOverflow {
                let key = "__t2_overflow_station__"
                result.noticeStationPositions[key] = fraction
                for member in geometry.overflow { result.noticeStationBySubscription[member.id] = key }
            }
        }
        result.noticeUnit = geometry.input.diameter / 52
        if let hull = view.registeredHullBounds {
            try result.registerSliver(hullBounds: hull, expandedSize: view.bounds.size, edge: preferences.dockEdge,
                                      scale: preferences.size.nozzleDiameter / 44)
        }
        return result
    }
}

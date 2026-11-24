// SPDX-License-Identifier: MIT
import AppKit
import CoreGraphics
import Foundation
@_spi(DockResourceChecks) import ModelPlanDock
import ModelPlanOfficialDock
import ModelPlanDockResources
import ModelPlanSettings

/// D-6: the ignition cap's art, loaded once from the verified store for its hover and press poses.
@MainActor final class T2IgnitionArt {
    let idle: CGImage, pressed: CGImage, inner: CGImage, guardRing: CGImage
    private init?() {
        guard let records = try? T2BundledArtwork.records().mapValues({ DockResourceFile(path: $0.path, sha256: $0.sha256, bytes: $0.bytes) }),
              let root = try? T2BundledArtwork.rootURL(), let store = try? DockArtworkStore(root: root, manifest: .init(files: records)),
              let idle = try? store.image("a5-cap-night-idle-44x44@3x.png", maximumPixelSize: 256),
              let pressed = try? store.image("a5-cap-night-pressed-44x44@3x.png", maximumPixelSize: 256),
              let inner = try? store.image("a5-inner-contact-shadow-52x52@3x.png", maximumPixelSize: 256),
              let guardRing = try? store.image("a5-recessed-guard-52x52@3x.png", maximumPixelSize: 256) else { return nil }
        self.idle = idle; self.pressed = pressed; self.inner = inner; self.guardRing = guardRing
    }
    static let shared = T2IgnitionArt()
}

/// Connects verified artwork and the registered T2 geometry to the production host.
@MainActor final class T2ProductionAppearance {
    /// G3-136: the status item's own rocket template (tray.png / tray@2x.png), at its 2x pixels, for the empty ring.
    private static var loadedEmptyMark: CGImage??
    static var emptyMark: CGImage? {
        if let loaded = loadedEmptyMark { return loaded }
        var rect = CGRect(x: 0, y: 0, width: 32, height: 32)
        let mark = CommunityMenuBarResources.templateImage()?.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        loadedEmptyMark = .some(mark)
        return mark
    }
    private struct Station: Equatable {
        let id: String
        let alias: String
        let hasEvent: Bool
    }
    private struct Layout: Equatable {
        let stations: [Station]
        let screen: CGSize
        let menuBarExclusion: CGFloat
        let edge: SettingsDockEdge
        let size: SettingsSize
        let showsPercentages: Bool
        let zaiMarkEnabled: Bool
    }
    private final class Prepared {
        let layout: Layout
        let geometry: T2Geometry
        let skin: DockInstrumentSkin
        let viewport: CGRect
        let renderer: DockInstrumentRenderer

        init(layout: Layout, geometry: T2Geometry, skin: DockInstrumentSkin, viewport: CGRect, renderer: DockInstrumentRenderer) {
            self.layout = layout; self.geometry = geometry; self.skin = skin; self.viewport = viewport; self.renderer = renderer
        }
    }
    private let preparedViews = NSMapTable<DockInstrumentView, Prepared>.weakToStrongObjects()
    #if DEBUG
    private(set) var preparationsForChecks = 0
    private(set) var materialRendersForChecks = 0
    /// Process-wide totals, for normal-entry checks that cannot reach the factory's instance.
    static var preparationsTotalForChecks = 0
    static var materialRendersTotalForChecks = 0
    static var preparedEvictionsTotalForChecks = 0
    #endif

    enum Failure: Error { case missingDisplay }

    func apply(_ view: DockInstrumentView, _ rows: [DockInstrumentReading], _ preferences: SettingsPreferences) throws -> StaticDockGeometry {
        guard let screen = view.appearanceDisplaySize, screen.width > 0, screen.height > 0 else { throw Failure.missingDisplay }
        let layout = Layout(stations: rows.map {
            Station(id: $0.subscriptionID, alias: $0.alias ?? "", hasEvent: view.appearanceNotices[$0.subscriptionID] != nil)
        }, screen: screen, menuBarExclusion: view.appearanceMenuBarExclusion, edge: preferences.dockEdge,
           size: preferences.size, showsPercentages: preferences.showPercentages, zaiMarkEnabled: view.zaiMarkEnabled)
        let prepared: Prepared
        if let previous = preparedViews.object(forKey: view), previous.layout == layout {
            prepared = previous
        } else {
            prepared = try prepare(layout, rows)
            preparedViews.setObject(prepared, forKey: view)
            view.discardPreparedAppearance = { [weak self, weak view] in
                guard let view, let self, self.preparedViews.object(forKey: view) != nil else { return }
                self.preparedViews.removeObject(forKey: view)
                #if DEBUG
                Self.preparedEvictionsTotalForChecks += 1
                #endif
            }
        }
        return try apply(prepared, to: view, rows: rows, language: preferences.language.rawValue)
    }

    private func prepare(_ layout: Layout, _ rows: [DockInstrumentReading]) throws -> Prepared {
        #if DEBUG
        preparationsForChecks += 1; Self.preparationsTotalForChecks += 1
        #endif
        let edge: T2Edge
        switch layout.edge {
        case .left: edge = .left
        case .right: edge = .right
        case .bottom: edge = .bottom
        case .top: edge = .top
        }
        let subscriptions = layout.stations.map { T2Subscription(id: $0.id, alias: $0.alias, hasEvent: $0.hasEvent) }
        let screen = layout.screen
        let vertical = edge == .left || edge == .right
        let nativeEdge: DockEdge = edge == .left ? .left : edge == .right ? .right : edge == .top ? .top : .bottom
        let room = PulseRestingPlacement.frameRoom(CGRect(origin: .zero, size: screen), edge: nativeEdge)
        let hoverRoom = ceil(layout.size.nozzleDiameter / 2)
        var budget = screen
        var fit: (T2Geometry, DockInstrumentSkin)?
        // T2 measures its curved span before raster bounds union the ignition.
        // Feed any measured excess back into the overflow budget before drawing.
        for _ in 0..<8 {
            // Preserve the study's top-left origin for artwork and control registration.
            // The top reservation is added to the coordinate extent and excluded from
            // the along-edge budget, so fit still uses only the available rectangle.
            let top = layout.menuBarExclusion
            let coords = T2EdgeCoordinates(edge: edge, width: budget.width, height: budget.height + top,
                                           menuBarExclusion: top)
            // Use one raster origin for a given display and edge. Pulse places
            // the resulting local geometry at the saved anchor.
            // The top edge mirrors the bottom-edge layout (A-1106-4): the ignition sits at the same end.
            let input = T2GeometryInput(coordinates: coords, diameter: layout.size.nozzleDiameter,
                showsPercentages: layout.showsPercentages, ignitionAtEnd: !vertical)
            let geometry = try T2Geometry.make(subscriptions: subscriptions, input: input)
            let skin = try T2DockSkin.make(geometry: geometry, rows: rows, showsPercentages: layout.showsPercentages,
                                          zaiMarkEnabled: layout.zaiMarkEnabled)
            guard vertical ? skin.bounds.width + hoverRoom <= room.width : skin.bounds.height + hoverRoom <= room.height else { break }
            let excess = vertical ? skin.bounds.height - room.height : skin.bounds.width - room.width
            if excess <= 0 { fit = (geometry, skin); break }
            if vertical { budget.height -= ceil(excess) }
            else { budget.width -= ceil(excess) }
        }
        guard let (geometry, skin) = fit else { throw DockEdgeError.invalidGeometry }
        // Reserve transparent inward canvas for strong hover. Keep the attached edge and the
        // along-edge extent fixed so a mode change never moves the resting hull.
        var hoverViewport = skin.bounds
        switch edge {
        case .left: hoverViewport.size.width += hoverRoom
        case .right: hoverViewport.origin.x -= hoverRoom; hoverViewport.size.width += hoverRoom
        case .bottom: hoverViewport.origin.y -= hoverRoom; hoverViewport.size.height += hoverRoom
        case .top: hoverViewport.size.height += hoverRoom
        }
        let artwork = try T2BundledArtwork.records().mapValues { DockResourceFile(path: $0.path, sha256: $0.sha256, bytes: $0.bytes) }
        let official = try DockArtworkStore(root: T2BundledArtwork.rootURL(), manifest: .init(files: artwork))
        let vendorManifest = try JSONDecoder().decode(DockResourceManifest.self, from: DockThirdPartyResources.manifestData(zaiMarkEnabled: layout.zaiMarkEnabled))
        let vendor = try DockArtworkStore(root: DockThirdPartyResources.rootURL(), manifest: vendorManifest)
        let material = T2FaceMaterial()
        let renderer = DockInstrumentRenderer(resources: official, supplementalResources: vendor) { [weak self] supplied, scale in
            #if DEBUG
            self?.materialRendersForChecks += 1; T2ProductionAppearance.materialRendersTotalForChecks += 1
            #endif
            return try material.render(geometry: geometry, viewport: supplied.bounds, scale: scale)
        }
        renderer.emptyMark = Self.emptyMark
        return Prepared(layout: layout, geometry: geometry, skin: skin, viewport: hoverViewport, renderer: renderer)
    }

    private func apply(_ prepared: Prepared, to view: DockInstrumentView, rows: [DockInstrumentReading],
                       language: String) throws -> StaticDockGeometry {
        let geometry = prepared.geometry, skin = prepared.skin, hoverViewport = prepared.viewport
        let layout = prepared.layout
        let horizontal = layout.edge == .bottom || layout.edge == .top
        var notices = view.appearanceNotices
        if let notice = geometry.overflow.compactMap({ notices[$0.id] }).min(by: { $0.rank < $1.rank }) {
            notices["__t2_overflow_notice__"] = notice
        }
        try view.applyOfficial(skin: skin, rows: rows, notices: notices, renderer: prepared.renderer, scale: 1, locale: language,
                               hoverViewport: hoverViewport, reusesPreparedMaterial: true)
        let button = try geometry.consoleButtonRect(in: hoverViewport)
        let restingFrame = skin.bounds.offsetBy(dx: -hoverViewport.minX, dy: -hoverViewport.minY)
        let grip = CGPoint(x: geometry.grip.x - hoverViewport.minX, y: geometry.grip.y - hoverViewport.minY)
        let unit = geometry.input.diameter / 52
        let scale = view.appliedGeometryScale
        // R64 D-5: the grip's hit target is the prototype's .dk-cap box, 44 x 30 on a side edge and
        // 34 x 44 on a horizontal edge (scaled with the dock), clipped to the widget; the outline hugs
        // the painted 10 x 22 / 22 x 10 art and its 1-unit stroke.
        // Prototype: design-handoffs/opus-r7/src/rocket-r1/rocket.css:44-50, dock.css:33.
        let hitSize = !horizontal ? CGSize(width: 44 * unit, height: 30 * unit) : CGSize(width: 34 * unit, height: 44 * unit)
        let artSize = !horizontal ? CGSize(width: 12 * unit, height: 24 * unit) : CGSize(width: 24 * unit, height: 12 * unit)
        func centred(_ size: CGSize) -> CGRect {
            CGRect(x: (grip.x - size.width / 2) * scale, y: (grip.y - size.height / 2) * scale, width: size.width * scale, height: size.height * scale)
        }
        let hit = centred(hitSize).intersection(CGRect(origin: .zero, size: view.bounds.size))
        view.registerGripRects([hit], art: [centred(artSize)])
        var result = StaticDockGeometry(hoverRects: [restingFrame], consoleButton: button,
                                        dragRegions: view.registeredDragRegions(excluding: [button]))
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
        for station in geometry.stations {
            guard let id = station.subscription?.id else { continue }
            result.hoverStations[id] = .init(inward: station.inwardNormal, pitch: station.pitch)
        }
        if let hull = view.registeredHullBounds {
            try result.registerSliver(hullBounds: hull, expandedSize: view.bounds.size, edge: layout.edge,
                                      scale: layout.size.nozzleDiameter / 44)
            let start = horizontal ? hull.minX:hull.minY, length = horizontal ? hull.width:hull.height
            for station in geometry.stations {
                let centre = horizontal ? station.centre.x-skin.bounds.minX : station.centre.y-skin.bounds.minY
                let lower = Double((centre-station.pitch/2-start)/length), upper = Double((centre+station.pitch/2-start)/length)
                let from = max(0,min(1,lower)), through = max(0,min(1,upper))
                guard from < through else { continue }
                let members = station.subscription.map { [$0.id] } ?? (station.isOverflow ? geometry.overflow.map(\.id):[])
                for id in members { result.quotaPitchRanges[id]=from...through; result.quotaPitchSpans[id]=lower...upper }
            }
        }
        return result
    }
}

// SPDX-License-Identifier: MIT
#if DEBUG
  import AppKit
  import QuartzCore
  import CryptoKit
  import ModelPlanPrimitives
  import ModelPlanCockpitWeb
  @_spi(DockResourceChecks) import ModelPlanDock

  // Migration table: queued one-off names -> the single renderedSnapshotForChecks() tree.
  // This maps observation coverage, not complete requirement/device/visual acceptance.
  // | Queued seam | Generic location / evidence |
  // | T2FaceMaterial.renderedMaterialForChecks | dock.face attributes + gradient-stop children |
  // | T2FaceMaterial.renderedLayerRolesForChecks | dock.face.layerRoles (completed material passes) |
  // | StaticDockPreviewHost.overflowPanelForChecks | dock.overflow (absent panel explicitly unavailable) |
  // | T2ProductionAppearance.geometrySourceIdentityForChecks | dock.attributes.geometrySourceIdentity |
  // | DockRenderedFaceInspection face identity | dock.face.assetSource |
  // | Ignition hover/press/disabled | dock.ignition.interaction; native transparent-control facts |
  // | Rendered logo colour/treatment | dock.logo.<id>.ink/assetSource + colourTreatment |
  // | Verified session-activity input | G1InspectionControls.setVerifiedSessionActivity; dock.nozzle.<id>.workingInput |
  // | renderedFixedLayerFramesForChecks | dock.resource.*.frame + fixed-resource layer role |
  // | CockpitShellSurface quick-open transition | cockpit.animationPhase + native window alpha target |
  // | A5 downstream filters | dock.resource.*.filters + dock.ignition/veil.filters |
  // | Logo/flame spacing and contrast | dock.logo.<id>/dock.effect.<id>.frame; multicolour contrast unavailable |
  // | Settings snap-toggle presence | settings native child tree, for the actually selected pane |
  // | selectedScope/day-boundary persistence | cockpit.attributes.selectedScope (actual coordinator state) |
  // | Factory synthetic-client normal composition | EngineRowsEntry.makeForG1Checks; real owner/page/fanout |
  // | Settings surface/text colour | settings native paints, text.ink, background, contrastAgainstParent |
  // | Dock card/LCD colour | card paints + native text/bar children; absent dedicated LCD stays absent |
  // | Cockpit LCD/porthole colour | cockpit.dom actual computed styles; no native-layout proxy for web paint |
  // | Face/readout/alias backings and transforms | dock.face/readout/alias attributes + completed draw records |
  // | T2 gap/curvature/grip | dock.attributes.gap/radius + dock.grip registered geometry facts |
  // | Nozzle material and resource filters | dock.nozzle.<id> + dock.resource.* |
  // | Clock dots | dock.clock.<id> attributes + actual painted-dot children |
  // | Working frame bounds/index/lifecycle/cadence/rotation | dock.effect.<id> frame/phase/attributes |
  // | WINDOW ledger isolation | app.attributes.notificationLedgerIdentity (path hash; no path export) |
  // | Displayed percentage and threshold ink | dock.readout.<id>.text/ink + displayedPercent/quotaRole |
  // Nil or unavailable is never a positive receipt. Native state and web observations carry
  // separate evidence/timestamps. The getter never advances inputs, lays out, draws or executes JS.

  /// Native frames use points; web frames use CSS pixels. coordinateSpace and parentIsFlipped
  /// identify their actual basis; screen-space area roots are explicit. `visible` means onscreen;
  /// `mounted` and `evidence` attributes distinguish offscreen draws from window acceptance.
  /// Missing observations are explicit, never model-derived defaults or synthetic success receipts.
  public struct G1RenderedColor: Equatable, Sendable {
    public let r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
      self.r = r
      self.g = g
      self.b = b
      self.a = a
    }
    public var hex: String {
      "#"
        + [r, g, b, a].map { String(format: "%02X", Int((max(0, min(1, $0)) * 255).rounded())) }
        .joined()
    }
    static func fromHex(_ raw: String) -> Self? {
      guard raw.count == 9, raw.first == "#", let bits = UInt32(raw.dropFirst(), radix: 16) else {
        return nil
      }
      let red: Double = Double((bits >> 24) & UInt32(255)) / 255.0
      let green: Double = Double((bits >> 16) & UInt32(255)) / 255.0
      let blue: Double = Double((bits >> 8) & UInt32(255)) / 255.0
      let alpha: Double = Double(bits & UInt32(255)) / 255.0
      return G1RenderedColor(red, green, blue, alpha)
    }
    static func color(_ ink: DockInk) -> Self { .init(ink.r, ink.g, ink.b, ink.a) }
    static func color(_ color: NSColor?, in view: NSView) -> Self? {
      var result: Self?
      view.effectiveAppearance.performAsCurrentDrawingAppearance {
        if let c = color?.usingColorSpace(.sRGB) {
          result = .init(c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent)
        }
      }
      return result
    }
    public func composited(over background: Self?) -> Self? {
      if a == 1 { return self }
      guard let background else { return nil }
      let alpha = a + background.a * (1 - a)
      guard alpha > 0 else { return .init(0, 0, 0, 0) }
      return .init(
        (r * a + background.r * background.a * (1 - a)) / alpha,
        (g * a + background.g * background.a * (1 - a)) / alpha,
        (b * a + background.b * background.a * (1 - a)) / alpha, alpha)
    }
    public func contrast(against background: Self) -> Double? {
      guard
        [r, g, b, a, background.r, background.g, background.b, background.a].allSatisfy({
          $0.isFinite && (0...1).contains($0)
        }),
        background.a == 1, let foreground = composited(over: background), foreground.a == 1
      else { return nil }
      func luminance(_ c: Self) -> Double {
        func channel(_ v: Double) -> Double {
          v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
      }
      let x = luminance(foreground)
      let y = luminance(background)
      return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
  }
  public struct G1RenderedInteraction: Sendable {
    public var hover: Bool?, press: Bool?, disabled: Bool?
    public init(hover: Bool? = nil, press: Bool? = nil, disabled: Bool? = nil) {
      self.hover = hover
      self.press = press
      self.disabled = disabled
    }
  }
  public struct G1RenderedElement: Sendable {
    public var identifier: String, role: String
    public var coordinateSpace = "parent-local"
    public var frame: CGRect?, visible: Bool?, text: String?
    /// Observed native screen coordinates; absent for offscreen or unmapped web geometry.
    public var screenFrame: CGRect?
    public var ink: G1RenderedColor?, fill: G1RenderedColor?, background: G1RenderedColor?,
      contrastAgainstParent: Double?
    public var assetSource: String?, layerRoles: [String] = [], zOrder: Double?
    public var interaction = G1RenderedInteraction(), filters: [String] = [],
      effects: [String] = [], animationPhase: String?
    public var attributes: [String: String] = [:], unavailable: [String: String] = [:],
      children: [Self] = []
    public init(_ identifier: String, role: String) {
      self.identifier = identifier
      self.role = role
    }
    public var elements: [Self] { [self] + children.flatMap(\.elements) }
    public func element(_ id: String) -> Self? {
      if identifier == id { return self }
      for child in children { if let found = child.element(id) { return found } }
      return nil
    }
  }
  public struct G1RenderedSnapshot: Sendable {
    public let schemaVersion = 1
    public let root: G1RenderedElement
    public let deliveryRevision: UInt64?
    public let capturedAt: Date
    public func element(_ id: String) -> G1RenderedElement? { root.element(id) }
    // Rev-2 facade; the detailed composition tree remains available for evidence metadata.
    public var dock: G1Element { G1ContractAdapter.element(element("dock") ?? .init("dock", role: "quota-widget")) }
    public var card: G1Element? {
      guard let node = element("card"), node.attributes["hidden"] == "false" else { return nil }
      return G1ContractAdapter.element(node)
    }
    public var settings: G1Element? {
      guard let node = element("settings"), node.visible == true else { return nil }
      return G1ContractAdapter.element(node)
    }
    public var cockpit: G1Element? {
      guard let node = element("cockpit"), node.visible == true else { return nil }
      return G1ContractAdapter.element(node)
    }
    // Not wired yet: absence is not an assertion that no product notices exist.
    public var menu: G1Element? { nil }
    public var statusItem: G1Element? { nil }
    public var notices: [G1Notice] { [] }
    private var contractRoots: [G1Element] { [dock] + [card, settings, cockpit, menu, statusItem].compactMap { $0 } }
    public func find(_ id: String) -> G1Element? { contractRoots.lazy.compactMap { $0.find(id) }.first }
    public func all(role: G1Role) -> [G1Element] { contractRoots.flatMap { $0.all(role: role) } }
  }

  @MainActor enum G1SnapshotReader {
    static func screenRect(_ rect: CGRect?, in view: NSView) -> CGRect? {
      guard let rect, !rect.isEmpty, let window = view.window, window.isVisible,
        !view.isHiddenOrHasHiddenAncestor, view.alphaValue > 0 else { return nil }
      return window.convertToScreen(view.convert(rect, to: nil))
    }
    /// These generated raster children use the instrument view's completed drawing coordinates.
    static func screenMapped(_ node: G1RenderedElement, in view: NSView) -> G1RenderedElement {
      var result = node
      result.screenFrame = screenRect(node.frame, in: view)
      result.children = node.children.map { screenMapped($0, in: view) }
      return result
    }
    static func paintBackdrop(
      _ rect: CGRect, earlier: ArraySlice<G1NativePaint>, over background: G1RenderedColor?,
      in view: NSView
    ) -> G1RenderedColor? {
      var result = background
      for paint in earlier where !paint.frame.isEmpty && paint.frame.intersects(rect) {
        if paint.frame.contains(rect) {
          result = G1RenderedColor.color(paint.color, in: view)?.composited(over: result)
        } else {
          result = nil
        }
      }
      return result
    }
    static func native(
      _ view: NSView, id: String, background: G1RenderedColor? = nil, order: Int = 0, depth: Int = 0
    ) -> G1RenderedElement {
      let observedIdentifier: String? = view.accessibilityIdentifier()
      let identifier = observedIdentifier.flatMap { $0.isEmpty ? nil : $0 } ?? id
      var node = G1RenderedElement(
        identifier, role: view.accessibilityRole()?.rawValue ?? String(describing: type(of: view)))
      node.frame = view.frame
      node.screenFrame = screenRect(view.bounds, in: view)
      node.visible =
        !view.isHiddenOrHasHiddenAncestor && view.window?.isVisible == true
        && !view.visibleRect.isEmpty && view.alphaValue > 0
      node.zOrder = Double(order)
      if let source = (view as? NSImageView)?.image?.name(), !source.hasPrefix("/"),
        !source.contains("://")
      {
        node.assetSource = source
      }
      node.attributes = [
        "renderer": String(describing: type(of: view)), "mounted": String(view.superview != nil),
        "hidden": String(view.isHiddenOrHasHiddenAncestor), "isFlipped": String(view.isFlipped),
        "parentIsFlipped": String(view.superview?.isFlipped ?? view.isFlipped),
        "evidence": "retained-native-view",
      ]
      node.background = background
      if let layer = view.layer {
        node.fill = layer.backgroundColor.flatMap {
          G1RenderedColor.color(NSColor(cgColor: $0), in: view)
        }
        node.filters = (layer.filters ?? []).map { String(describing: type(of: $0)) }
        node.effects = (layer.backgroundFilters ?? []).map { String(describing: type(of: $0)) }
        if layer.shadowOpacity > 0 {
          node.effects.append("shadow:opacity=\(layer.shadowOpacity),radius=\(layer.shadowRadius)")
        }
        let animations = layer.animationKeys() ?? []
        node.animationPhase = animations.isEmpty ? "idle" : "active"
        node.effects += animations.map { "animation:" + $0 }
        for key in animations {
          if let animation = layer.animation(forKey: key) {
            node.attributes["animation." + key] =
              "duration=\(animation.duration),offset=\(animation.timeOffset),speed=\(animation.speed)"
          }
        }
        node.attributes["opacity"] = String(layer.opacity)
        node.attributes["layerZPosition"] = String(Double(layer.zPosition))
      }
      if let painted = view as? any G1NativePaintObserving, !painted.g1DrawnPaints.isEmpty {
        node.attributes["paintEvidence"] = "completed-native-draw"
        node.layerRoles = painted.g1DrawnPaints.map(\.role)
        for (index, paint) in painted.g1DrawnPaints.enumerated() {
          let color = G1RenderedColor.color(paint.color, in: view)
          if paint.frame.contains(view.bounds) { node.fill = color }
          var region = G1RenderedElement(identifier + "/paint\(index)", role: paint.role)
          region.frame = paint.frame
          region.screenFrame = screenRect(paint.frame, in: view)
          region.fill = color
          region.background = paintBackdrop(
            paint.frame, earlier: painted.g1DrawnPaints[..<index], over: background, in: view)
          region.visible = (node.visible == true && !paint.frame.isEmpty && color?.a != 0)
          region.zOrder = Double(index)
          region.contrastAgainstParent = color.flatMap { ink in
            region.background.flatMap { ink.contrast(against: $0) }
          }
          node.children.append(region)
        }
      }
      if let effect = view as? NSVisualEffectView {
        node.effects.append(
          "visual-effect:material=\(effect.material.rawValue),blend=\(effect.blendingMode.rawValue)"
        )
        node.unavailable["background"] = "Composited visual-effect backdrop is not a solid colour"
      }
      if let text = view as? NSTextField {
        let sensitive =
          text is NSSecureTextField
          || (text.isEditable
            && ["password", "secret", "token", "apikey"].contains(
              where: identifier.lowercased().contains))
        if sensitive {
          node.unavailable["text"] = "Secure control content withheld"
        } else {
          node.text = text.stringValue
          node.ink = G1RenderedColor.color(text.textColor, in: view)
        }
        if text.drawsBackground {
          node.fill = G1RenderedColor.color(text.backgroundColor, in: view)
        }
        node.interaction.disabled = !text.isEnabled
        if text.cell?.isHighlighted == true {
          node.ink = nil
          node.unavailable["ink"] =
            "Native highlighted text palette is not an explicit paint receipt"
        }
      } else if let button = view as? NSButton {
        node.text = button.title
        node.interaction.disabled = !button.isEnabled
        node.interaction.press = button.isHighlighted
        if button.attributedTitle.length > 0,
          let color = button.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil)
            as? NSColor
        {
          node.ink = G1RenderedColor.color(color, in: view)
        }
        node.attributes["controlState"] = String(button.state.rawValue)
      } else if let control = view as? NSControl {
        node.interaction.disabled = !control.isEnabled
      }
      let effectiveBackground =
        node.fill.flatMap { $0.composited(over: node.background) } ?? node.background
      node.contrastAgainstParent = node.ink.flatMap { ink in
        effectiveBackground.flatMap { ink.contrast(against: $0) }
      }
      if node.ink != nil && node.contrastAgainstParent == nil {
        node.unavailable["contrastAgainstParent"] = "No observed opaque backdrop"
      }
      node.unavailable["hover"] = "No native hover receipt supplied"
      if node.text?.isEmpty == false && node.ink == nil && node.unavailable["text"] == nil {
        node.unavailable["ink"] = "No explicit native text ink observation"
      }
      if depth < 32 {
        node.children += view.subviews.enumerated().map {
          native(
            $0.element, id: identifier + "/\($0.offset)",
            background: (view is NSVisualEffectView
              || view.subviews.contains(where: { $0 is NSVisualEffectView }))
              ? nil : effectiveBackground, order: $0.offset, depth: depth + 1)
        }
      } else {
        node.unavailable["children"] = "Inspection depth limit"
      }
      return node
    }
    static func rasterRect(
      _ rect: CGRect, transform: CGAffineTransform, scale: Double, pixelHeight: Double
    ) -> CGRect? {
      guard scale.isFinite, scale > 0, pixelHeight.isFinite else { return nil }
      let pixels = rect.applying(transform)
      guard [pixels.minX, pixels.minY, pixels.width, pixels.height].allSatisfy(\.isFinite) else {
        return nil
      }
      return .init(
        x: pixels.minX / scale, y: (pixelHeight - pixels.maxY) / scale, width: pixels.width / scale,
        height: pixels.height / scale)
    }
    static func dock(_ host: StaticDockPreviewHost) -> G1RenderedElement {
      let view = host.g1SnapshotInstrumentView
      var root = native(view, id: "dock")
      let nativeChildCount = root.children.count
      root.role = "quota-widget"
      root.identifier = "dock"
      func drawn(_ rect: CGRect, _ transform: CGAffineTransform) -> CGRect? {
        guard let observation = view.g1RenderObservation,
          let pixels = view.renderedFaceMaterialForChecks?.pixelSize
        else { return nil }
        return rasterRect(
          rect, transform: transform, scale: Double(observation.scale),
          pixelHeight: Double(pixels.height))
      }
      if let face = view.renderedFaceMaterialForChecks {
        var node = G1RenderedElement("dock.face", role: "material")
        node.frame = view.bounds
        node.visible = root.visible
        node.assetSource = face.materialSourceIdentity
        node.layerRoles = face.materialLayerRoles
        node.zOrder = 0
        node.attributes = [
          "evidence": "completed-raster-pass", "pixelWidth": String(Double(face.pixelSize.width)),
          "pixelHeight": String(Double(face.pixelSize.height)),
        ]
        node.unavailable["fill"] = "Non-uniform supplied material; no invented solid colour"
        if let material = T2ProductionAppearance.materialObservationForSnapshot(view) {
          node.attributes["scale"] = String(material.scale)
          node.attributes["grainOpacity"] = String(material.grainOpacity)
          node.attributes["gradientLocations"] = material.gradientLocations.map {
            String(Double($0))
          }.joined(separator: ",")
          for (index, rgb) in material.gradientRGB.enumerated() where rgb.count == 3 {
            var stop = G1RenderedElement("dock.face.gradient.\(index)", role: "gradient-stop")
            stop.fill = .init(Double(rgb[0]) / 255, Double(rgb[1]) / 255, Double(rgb[2]) / 255)
            if material.gradientLocations.indices.contains(index) {
              stop.attributes["location"] = String(Double(material.gradientLocations[index]))
            }
            stop.unavailable["frame"] =
              "Gradient stop is a paint parameter, not a standalone region"
            node.children.append(stop)
          }
        }
        root.children.append(node)
      }
      for (index, layer) in view.renderedLayerRolesForChecks.enumerated() {
        var node = G1RenderedElement("dock.layer.\(index)", role: layer.role)
        node.assetSource = layer.resource
        node.zOrder = Double(index)
        node.visible = root.visible
        if let id = layer.subscriptionID { node.attributes["subscriptionID"] = id }
        root.children.append(node)
      }
      for (index, resource) in view.renderedResourceFiltersForChecks.enumerated() {
        var node = G1RenderedElement("dock.resource.\(index)", role: "image")
        node.frame = drawn(resource.target, resource.drawingTransform)
        node.assetSource = resource.resource
        node.visible = root.visible
        node.filters = ["interpolation:\(resource.interpolationQuality.rawValue)"]
        node.attributes = [
          "preservesSourcePixels": String(resource.preservesSourcePixels),
          "fitsVisibleGlyph": String(resource.fitsVisibleGlyph),
        ]
        node.attributes["assetDigest"] = resource.sourceIdentity
        if let id = resource.subscriptionID { node.attributes["subscriptionID"] = id }
        let fixed =
          view.presentedSkinForChecks?.fixedLayers.filter { $0.resource == resource.resource } ?? []
        if resource.subscriptionID == nil, fixed.count == 1 {
          node.layerRoles = ["fixed-resource"]
          node.attributes["layerOpacity"] = String(fixed[0].opacity ?? 1)
        }
        root.children.append(node)
      }
      for id in view.renderedWidgetValuesForChecks.keys.sorted() {
        guard let value = view.renderedWidgetValuesForChecks[id],
          let layout = view.renderedReadoutBackingForChecks[id]
        else { continue }
        var node = G1RenderedElement("dock.readout." + id, role: "text")
        node.frame = drawn(layout.frame, layout.frameTransform)
        node.text = value.text
        node.ink = .color(value.ink)
        node.visible = root.visible
        node.attributes = [
          "subscriptionID": id,
          "remainingPercent": value.remainingPercent.map { String($0) } ?? "unknown",
          "quotaRole": value.quotaRole.rawValue, "colorRole": value.colorRole,
          "displayedPercent": value.displayedPercent.map { String($0) } ?? "unknown",
          "selectedWindowID": value.selectedWindowID ?? "unknown", "opacity": String(value.opacity),
          "evidence": "completed-text-pass",
        ]
        let t = layout.glyphTransform
        node.attributes["glyphTransform"] = [t.a, t.b, t.c, t.d, t.tx, t.ty].map {
          String(Double($0))
        }.joined(separator: ",")
        node.attributes["hasDedicatedBacking"] = String(layout.hasDedicatedBacking)
        node.unavailable["background"] =
          "Text is drawn on the textured face, with no dedicated backing"
        root.children.append(node)
      }
      for (id, alias) in view.renderedAliasBackingForChecks.sorted(by: { $0.key < $1.key }) {
        var node = G1RenderedElement("dock.alias." + id, role: "text")
        node.frame = drawn(alias.frame, alias.frameTransform)
        node.text = alias.text
        node.ink = .color(alias.ink)
        node.visible = root.visible
        node.attributes["subscriptionID"] = id
        let t = alias.glyphTransform
        node.attributes["glyphTransform"] = [t.a, t.b, t.c, t.d, t.tx, t.ty].map {
          String(Double($0))
        }.joined(separator: ",")
        node.attributes["hasDedicatedBacking"] = String(alias.hasDedicatedBacking)
        root.children.append(node)
      }
      for (id, logo) in view.renderedLogosForChecks.sorted(by: { $0.key < $1.key }) {
        var node = G1RenderedElement("dock.logo." + id, role: "image")
        node.frame = view.renderedNozzleMaterialForChecks[id].flatMap {
          drawn(logo.frame, $0.surfaceTransform)
        }
        node.assetSource = logo.resource
        node.text = logo.fallbackText
        node.ink = logo.tint.map(G1RenderedColor.color)
        node.visible = root.visible
        node.attributes = [
          "subscriptionID": id, "colourTreatment": logo.colourTreatment.rawValue,
          "opacity": String(logo.opacity),
        ]
        node.attributes["assetDigest"] =
          view.renderedResourceFiltersForChecks.first {
            $0.subscriptionID == id && $0.resource == logo.resource
          }?.sourceIdentity
        if logo.colourTreatment == .sourceRGBA {
          node.unavailable["contrastAgainstParent"] =
            "Original multicolour asset has no single solid ink"
        }
        root.children.append(node)
      }
      if let geometry = host.resolvedT2CurvatureForChecks {
        root.attributes["geometrySourceIdentity"] = host.geometrySourceIdentityForChecks
        root.attributes["gap"] = String(Double(geometry.gap))
        root.attributes["radius"] = String(Double(geometry.radius))
      }
      for (id, nozzle) in view.renderedNozzleMaterialForChecks.sorted(by: { $0.key < $1.key }) {
        var node = G1RenderedElement("dock.nozzle." + id, role: "nozzle")
        node.frame = drawn(nozzle.frame, nozzle.surfaceTransform)
        node.visible = root.visible
        node.attributes = [
          "subscriptionID": id, "resources": nozzle.resources.joined(separator: ","),
        ]
        let t = nozzle.surfaceTransform
        node.attributes["surfaceTransform"] = [t.a, t.b, t.c, t.d, t.tx, t.ty].map {
          String(Double($0))
        }.joined(separator: ",")
        node.assetSource = nozzle.replacementResource
        node.ink = nozzle.caseInk.map(G1RenderedColor.color)
        if let reading = view.presentedReadingsForChecks[id] {
          node.attributes["workingInput"] = String(reading.isWorking)
          node.attributes["jetEligibleInput"] = String(reading.jetEligible)
        }
        if let radial = nozzle.radialOverlay {
          node.effects = ["radial-overlay"]
          node.attributes["radialOverlayRadius"] = String(Double(radial.radius))
        }
        root.children.append(node)
      }
      for (id, clock) in view.renderedClockDotsForChecks.sorted(by: { $0.key < $1.key }) {
        var node = G1RenderedElement("dock.clock." + id, role: "clock-dots")
        node.ink = .color(clock.ink)
        node.background = .color(clock.backingInk)
        node.attributes = [
          "positions": String(clock.positions), "litCount": String(clock.litCentres.count),
          "radius": String(Double(clock.radius)), "dotRadius": String(Double(clock.dotRadius)),
          "backingWidth": String(Double(clock.backingWidth)),
        ]
        for (index, point) in clock.litCentres.enumerated() {
          var dot = G1RenderedElement("dock.clock." + id + "/\(index)", role: "dot")
          dot.fill = node.ink
          dot.frame = view.renderedNozzleMaterialForChecks[id].flatMap {
            drawn(
              CGRect(
                x: point.x - clock.dotRadius, y: point.y - clock.dotRadius,
                width: 2 * clock.dotRadius, height: 2 * clock.dotRadius), $0.surfaceTransform)
          }
          node.children.append(dot)
        }
        root.children.append(node)
      }
      for index in nativeChildCount..<root.children.count {
        root.children[index] = screenMapped(root.children[index], in: view)
      }
      host.g1AppendHostObservations(to: &root)
      return root
    }
    private static func webColor(_ value: Any?) -> G1RenderedColor? {
      guard let d = value as? [String: Any], let r = d["r"] as? Double, let g = d["g"] as? Double,
        let b = d["b"] as? Double, let a = d["a"] as? Double,
        [r, g, b, a].allSatisfy({ $0.isFinite && (0...1).contains($0) })
      else { return nil }
      return .init(r, g, b, a)
    }
    private static func webNode(_ d: [String: Any], background: G1RenderedColor?, depth: Int = 0)
      -> G1RenderedElement?
    {
      guard depth <= 32, let id = d["identifier"] as? String, let role = d["role"] as? String else {
        return nil
      }
      var node = G1RenderedElement(id, role: role)
      node.coordinateSpace = "web-viewport-css-px-top-left"
      if let f = d["frame"] as? [[Double]], f.count == 2, f.allSatisfy({ $0.count == 2 }),
        f.flatMap({ $0 }).allSatisfy(\.isFinite)
      {
        node.frame = CGRect(x: f[0][0], y: f[0][1], width: f[1][0], height: f[1][1])
      }
      node.visible = d["visible"] as? Bool
      node.text = d["text"] as? String
      node.ink = webColor(d["ink"])
      node.fill = webColor(d["fill"])
      node.background = background
      node.assetSource = d["assetSource"] as? String
      node.layerRoles = d["layerRoles"] as? [String] ?? []
      node.zOrder = d["zOrder"] as? Double
      if let state = d["interaction"] as? [String: Any] {
        node.interaction = .init(
          hover: state["hover"] as? Bool, press: state["press"] as? Bool,
          disabled: state["disabled"] as? Bool)
      }
      node.filters = d["filters"] as? [String] ?? []
      node.effects = d["effects"] as? [String] ?? []
      node.animationPhase = d["animationPhase"] as? String
      node.attributes = d["attributes"] as? [String: String] ?? [:]
      node.unavailable = d["unavailable"] as? [String: String] ?? [:]
      let nonuniform =
        node.effects.contains { $0.hasPrefix("background-image:") } || !node.filters.isEmpty
      let effective =
        nonuniform ? nil : (node.fill.flatMap { $0.composited(over: background) } ?? background)
      node.contrastAgainstParent = node.ink.flatMap { ink in
        effective.flatMap { ink.contrast(against: $0) }
      }
      if node.ink != nil && node.contrastAgainstParent == nil {
        node.unavailable["contrastAgainstParent"] = "No observed opaque web backdrop"
      }
      node.children = (d["children"] as? [[String: Any]] ?? []).compactMap {
        webNode($0, background: node.filters.isEmpty ? effective : nil, depth: depth + 1)
      }
      return node
    }
    static func cockpit(_ page: CockpitWindowController?, scope: String?) -> G1RenderedElement {
      var node = G1RenderedElement("cockpit", role: "cockpit-shell")
      node.attributes["selectedScope"] = scope
      guard let page else {
        node.unavailable["surface"] = "No cockpit page is composed"
        return node
      }
      let state = page.stateForChecks
      node.attributes = [
        "openRequested": String(state.openRequested), "hasWindow": String(state.hasWindow),
        "hasWebView": String(state.hasWebView), "blocked": String(state.blocked),
        "disposed": String(state.disposed),
        "captureGeneration": String(page.g1DOMCaptureGenerationForChecks),
      ]
      node.attributes["selectedScope"] = scope
      node.attributes.merge(page.g1ShellMetadataForChecks, uniquingKeysWith: { _, new in new })
      node.animationPhase = page.g1ShellMetadataForChecks["transitionPhase"]
      node.assetSource = page.g1BundleIdentityForChecks.map { "manifest:" + $0 }
      if state.hasWindow, let window = page.window {
        node.frame = window.frame
        node.coordinateSpace = "screen"
        node.visible = window.isVisible
        node.attributes["windowAlpha"] = String(Double(window.alphaValue))
        if let root = window.contentView {
          node.children.append(
            native(
              root, id: "cockpit.native",
              background: G1RenderedColor.color(window.backgroundColor, in: root)))
        }
      } else {
        node.visible = false
        node.unavailable["frame"] = "No native cockpit window"
      }
      if let data = page.g1RenderedDOMForChecks,
        let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
        let tree = value["tree"] as? [String: Any], var dom = webNode(tree, background: nil)
      {
        dom.attributes["sourceIdentifier"] = dom.identifier
        dom.identifier = "cockpit.dom"
        node.children.append(dom)
        if let at = value["capturedAt"] as? Double {
          node.attributes["webCapturedAtMilliseconds"] = String(at)
        }
        if value["truncated"] as? Bool == true {
          node.unavailable["webTreeCompleteness"] = "Web observation exceeded its element bound"
        }
        for key in ["devicePixelRatio", "viewportWidth", "viewportHeight"] {
          if let v = value[key] as? Double { node.attributes[key] = String(v) }
        }
      } else {
        node.unavailable["webTree"] = "No completed current WebKit layout observation"
      }
      return node
    }

  }

  extension EngineDockMenuApplication {
    /// App adapter behind the sole composition inspection entry. Does not lay out, draw, show or query a service.
    func g1ReadRenderedSnapshotForChecks() -> G1RenderedSnapshot {
      var root = G1RenderedElement("app", role: "application")
      root.attributes["consistency"] = "Native current read; WebKit last completed current layout"
      if let ledger = composition.nativeNotificationLedgerForChecks {
        root.attributes["notificationLedgerIdentity"] = SHA256.hash(
          data: Data(ledger.standardizedFileURL.path.utf8)
        ).map { String(format: "%02x", $0) }.joined()
      } else {
        root.unavailable["notificationLedgerIdentity"] = "No reset notifier is installed"
      }
      root.children = [G1SnapshotReader.dock(composition.dock)]
      let cardView = composition.dock.card
      let cardFill = cardView.g1DrawnPaints.first.flatMap {
        G1RenderedColor.color($0.color, in: cardView)
      }
      var card = G1SnapshotReader.native(cardView, id: "card", background: cardFill)
      card.identifier = "card"
      card.role = "card"
      var fragments = G1RenderedElement("card.fragments", role: "text-layout")
      fragments.frame = cardView.bounds
      fragments.screenFrame = G1SnapshotReader.screenRect(cardView.bounds, in: cardView)
      for (id, rects) in cardView.renderedLineFragmentsForChecks.sorted(by: { $0.key < $1.key }) {
        for (index, rect) in rects.enumerated() {
          var line = G1RenderedElement("card.fragment." + id + ".\(index)", role: "text-fragment")
          line.frame = rect
          line.screenFrame = G1SnapshotReader.screenRect(rect, in: cardView)
          line.attributes["textIdentifier"] = id
          fragments.children.append(line)
        }
      }
      card.children.append(fragments)
      root.children.append(card)
      if let view = settingsHost.renderedRootForG1Checks {
        var settings = G1SnapshotReader.native(view, id: "settings")
        settings.identifier = "settings"
        settings.role = "settings"
        settings.attributes["selectedPane"] = settingsHost.renderedPaneForG1Checks
        root.children.append(settings)
      } else {
        var settings = G1RenderedElement("settings", role: "settings")
        settings.unavailable["surface"] = "Native Settings has not been prepared"
        root.children.append(settings)
      }
      if let source = g1CockpitSnapshotSource {
        root.children.append(source())
      } else {
        var cockpit = G1RenderedElement("cockpit", role: "cockpit")
        cockpit.unavailable["surface"] = "Cockpit has not been composed"
        root.children.append(cockpit)
      }
      return .init(
        root: root, deliveryRevision: composition.store.snapshot.delivery?.revision,
        capturedAt: composition.currentDate())
    }
  }
#endif

#if DEBUG
  extension EngineDockMenuComposition {
    /// Canonical G1 inspection interface. Returns observations only; never draws, lays out or presents UI.
    public func renderedSnapshotForChecks() -> G1RenderedSnapshot {
      if let snapshot = g1SnapshotReader?() { return snapshot }
      var root = G1RenderedElement("app", role: "application")
      root.children = [G1SnapshotReader.dock(dock)]
      root.unavailable["appSurfaces"] = "Normal-entry app facade is not attached"
      return .init(
        root: root, deliveryRevision: store.snapshot.delivery?.revision, capturedAt: currentDate())
    }
  }
#endif

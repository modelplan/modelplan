// SPDX-License-Identifier: MIT
#if DEBUG
  import AppKit
  import ModelPlanDock
  import ModelPlanSettings
  import ModelPlanEngineClient
  import ModelPlanCockpitWeb

  public enum G1InspectionInputError: Error {
    case invalidClock, invalidPointer, alreadyBound, notBound, missingIsolatedLedger,
      systemDeliveryNotEnabled, invalidMember
  }
  @MainActor private final class G1InspectionTimer: DockEdgeScheduling {
    var deadline: TimeInterval?, action: (@MainActor () -> Void)?
    func arm(at deadline: TimeInterval, _ action: @escaping @MainActor () -> Void) {
      self.deadline = deadline
      self.action = action
    }
    func cancel() {
      deadline = nil
      action = nil
    }
    func fire(at now: TimeInterval) {
      for _ in 0..<32 {
        guard let deadline, deadline <= now else { return }
        let saved = action
        cancel()
        saved?()
      }
    }
  }
  /// Explicit synthetic inputs, separate from the read-only snapshot. One instance per composition.
  /// No desktop pointer is moved, no engine permission is granted, and activity still passes admission.
  @MainActor public final class G1InspectionControls {
    public private(set) var now: Date, elapsed: TimeInterval
    public private(set) var pointer: CGPoint?
    public let displays: [DockDisplayArea]
    public let notificationLedgerURL: URL?
    private weak var app: EngineDockMenuApplication?
    private var activityDelivery: EngineDeliveryContext?
    private var activitySignals: [String: DockWorkingSignal] = [:]
    private var cockpitTimers: [UUID: (TimeInterval, @MainActor () -> Void)] = [:]
    var unixMilliseconds: UInt64 {
      UInt64(max(0, min(now.timeIntervalSince1970 * 1000, 8_640_000_000_000_000)).rounded(.down))
    }
    func armCockpit(_ milliseconds: UInt64, _ action: @escaping @MainActor () -> Void) -> () -> Void
    {
      let token = UUID()
      cockpitTimers[token] = (elapsed + Double(milliseconds) / 1000, action)
      return { [weak self] in self?.cockpitTimers.removeValue(forKey: token) }
    }
    fileprivate let timer = G1InspectionTimer()
    public init(
      now: Date, elapsed: TimeInterval = 0, pointer: CGPoint? = nil, displays: [DockDisplayArea],
      notificationLedgerURL: URL? = nil
    ) {
      self.now = now
      self.elapsed = elapsed
      self.pointer = pointer
      self.displays = displays
      self.notificationLedgerURL = notificationLedgerURL
    }
    fileprivate var isUnbound: Bool { app == nil }
    fileprivate func bind(_ app: EngineDockMenuApplication) {
      timer.cancel()
      self.app = app
      app.g1InspectionControls = self
    }
    fileprivate func environment() -> DockEdgeEnvironment {
      .init(displays: displays, layouts: [], primaryDisplayID: displays.first?.id, pointer: pointer)
    }
    public func advance(by seconds: TimeInterval) throws {
      guard let app else { throw G1InspectionInputError.notBound }
      let nextElapsed = elapsed + seconds
      let nextDate = now.addingTimeInterval(seconds)
      guard seconds.isFinite, seconds >= 0, nextElapsed.isFinite, nextElapsed >= 0,
        nextDate.timeIntervalSince1970.isFinite
      else { throw G1InspectionInputError.invalidClock }
      elapsed = nextElapsed
      now = nextDate
      timer.fire(at: elapsed)
      for _ in 0..<64 {
        guard
          let due = cockpitTimers.filter({ $0.value.0 <= elapsed }).min(by: {
            $0.value.0 < $1.value.0
          })
        else { break }
        cockpitTimers.removeValue(forKey: due.key)
        due.value.1()
      }
      app.composition.dock.refreshPresence()
      app.composition.dock.interactionControllerForChecks?.refresh()
      app.composition.dock.seekWorkingEffectsForChecks(elapsed)
      app.g1RefreshObservationSources?()
    }
    public func setWallDate(_ date: Date) throws {
      guard app != nil else { throw G1InspectionInputError.notBound }
      guard date.timeIntervalSince1970.isFinite else { throw G1InspectionInputError.invalidClock }
      now = date
      timer.fire(at: elapsed)
      app?.composition.dock.refreshDockContent()
      app?.g1InspectionClockDidChange?()
      app?.g1RefreshObservationSources?()
    }
    public func setPointer(_ point: CGPoint?) throws {
      guard point.map({ $0.x.isFinite && $0.y.isFinite }) ?? true else {
        throw G1InspectionInputError.invalidPointer
      }
      guard let app else { throw G1InspectionInputError.notBound }
      pointer = point
      let host = app.composition.dock
      host.refreshPresence()
      guard let place = host.edgePresentation?.placement else { return }
      let view = host.g1SnapshotInstrumentView
      let local = point.map { point in
        if let window = view.window { return view.convert(window.convertPoint(fromScreen: point), from: nil) }
        return CGPoint(x: point.x - place.frame.minX + view.bounds.minX,
          y: place.frame.maxY - point.y + view.bounds.minY)
      }
      if let local, view.bounds.contains(local) {
        let location = view.convert(local, to: nil)
        if let event = NSEvent.mouseEvent(
          with: .mouseMoved, location: location, modifierFlags: [], timestamp: elapsed,
          windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0,
          clickCount: 0, pressure: 0)
        {
          view.mouseMoved(with: event)
        }
      } else {
        view.nozzleEventDelegate?.hoverNozzle(nil)
      }
      host.interactionControllerForChecks?.refresh()
      app.g1RefreshObservationSources?()
    }
    public func setVerifiedSessionActivity(
      _ values: [DockWorkingSignal], delivery: EngineDeliveryContext
    ) throws {
      guard let app else { throw G1InspectionInputError.notBound }
      try app.composition.applySessionActivityForChecks(values, delivery: delivery)
      activityDelivery = delivery
      activitySignals = Dictionary(uniqueKeysWithValues: values.compactMap { signal in
        signal.subscriptionID.map { ($0, signal) }
      })
    }
    /// A tool is the canonical row ID; a member must name exactly one admitted bound account.
    public func setVerifiedSessionActivity(tool: String, member: String, active: Bool) throws {
      guard let app else { throw G1InspectionInputError.notBound }
      let composition = app.composition
      guard let delivery = composition.store.snapshot.delivery,
        composition.accountMembers.members.contains(where: {
          $0.rowID == tool && $0.id == member && $0.isStable && $0.subscriptionRef == member
        }) else { throw G1InspectionInputError.invalidMember }
      let freshBoundIDs = Set(composition.accountMembers.members.filter { candidate in
        candidate.isStable && candidate.subscriptionRef == candidate.id &&
          composition.presentedContent.snapshot.inputs.contains { $0.id == candidate.id && $0.dataState == .fresh }
      }.map(\.id))
      var signals = activityDelivery == delivery ? activitySignals.filter { freshBoundIDs.contains($0.key) } : [:]
      if active {
        signals[member] = .init(subscriptionID: member, bindingVerified: true, fresh: true, observedOutput: true)
      } else { signals.removeValue(forKey: member) }
      try setVerifiedSessionActivity(signals.keys.sorted().compactMap { signals[$0] }, delivery: delivery)
    }
  }

  extension EngineRowsEntry {
    /// Swaps only synthetic external inputs while retaining the real owner, page and fanout.
    public static func makeForG1Checks(
      configuration: EngineClientConfiguration, settingsStore: SettingsStore,
      controls: G1InspectionControls, bundleURL: URL, cockpitBundle: VerifiedCockpitBundle? = nil,
      nativeDock: Bool = false, nativeCockpit: Bool = false, cockpitEntryEnabled: Bool = true,
      makeEngineClient:
        @escaping @MainActor (EngineClientConfiguration, any EngineClientEventConsumer) ->
        any EngineClient
    ) throws -> EngineDockMenuApplication {
      guard controls.elapsed.isFinite, controls.elapsed >= 0,
        controls.now.timeIntervalSince1970.isFinite
      else { throw G1InspectionInputError.invalidClock }
      guard controls.isUnbound else { throw G1InspectionInputError.alreadyBound }
      let ledger = controls.notificationLedgerURL ?? isolatedNativeNotificationLedgerForChecks
      guard !nativeDock || ledger != nil else { throw G1InspectionInputError.missingIsolatedLedger }
      let app = CommunityCockpitApplicationFactory.makeForChecks(
        configuration: configuration, settingsStore: settingsStore,
        bundleURL: bundleURL, createsNativePanels: nativeDock,
        cockpitEntryEnabled: cockpitEntryEnabled, verifiedBundleForChecks: cockpitBundle,
        dockEnvironment: { controls.environment() }, deadlineNow: { controls.now },
        deadlineElapsed: { controls.elapsed }, deadlineScheduling: controls.timer,
        makeEngineClient: makeEngineClient)
      app.composition.installResetEvents(
        settings: settingsStore, live: nativeDock, isolatedLedger: ledger)
      app.composition.setResetNotificationDelivery { _ in
        throw G1InspectionInputError.systemDeliveryNotEnabled
      }
      app.g1ConfigureNativeCockpit?(nativeCockpit)
      app.g1BindInspectionControls?(controls)
      controls.bind(app)
      return app
    }
  }
#endif

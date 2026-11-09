// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanWire

@MainActor public protocol CockpitPageSurface: AnyObject {
  var queryTicket: CockpitQueryTicket? { get }
  var onReady: (() -> Void)? { get set }
  var onIntent: ((CockpitIntent) -> Void)? { get set }
  var onClosed: (() -> Void)? { get set }
  /// CKP-SHELL-20: once per open, when the page is first confirmed visible.
  var onShown: (() -> Void)? { get set }
  /// CKP-SHELL-20: build and load the page without showing it or taking focus.
  func prewarm()
  func open()
  func requestClose()
  func updateAppearance(_ appearance: CockpitAppearance)
  func updateScope(_ key:String)
  /// G3-56: the acknowledged caution identities to restore; applied before the page loads.
  func setAckedCautions(_ ids:[String])
  func display(_ data: WireCockpitData, ticket: CockpitQueryTicket)
  func clearPrivateViews(adopting: CockpitEngineContext?) async
  func discard()
}
public extension CockpitPageSurface {
  var onShown: (() -> Void)? { get { nil } set {} }
  func prewarm() {}
  func requestClose() { discard() }
  func updateAppearance(_ appearance: CockpitAppearance) {}
  func updateScope(_ key:String) {}
  func setAckedCautions(_ ids:[String]) {}
}
extension CockpitWindowController: CockpitPageSurface {}

/// D64: where the app keeps the cockpit scope and the local day it was chosen, so it outlives a restart that day.
@MainActor public protocol CockpitScopeMemory: AnyObject {
  func load() -> (key: String, day: String)?
  func save(_ value: (key: String, day: String)?)
}

/// G3-56: where the app keeps the caution identities the owner acknowledged, so the lamp stays steady after a restart.
@MainActor public protocol CockpitCautionMemory: AnyObject {
  func load() -> [String]
  func save(_ ids: [String])
}

private final class WeakCockpitConsumer: EngineClientEventConsumer, @unchecked Sendable {
  @MainActor weak var owner: EngineCockpitCoordinator?
  @MainActor init(_ owner: EngineCockpitCoordinator) { self.owner = owner }
  func consume(_ event: EngineClientEvent) async { await owner?.consume(event) }
}

/// The App retains this consumer and calls open() from its cockpit action.
/// This is the sole cockpit/query requester on its client. Other feature events
/// continue through the existing consumer, with clear acknowledged last.
@MainActor public final class EngineCockpitCoordinator: EngineClientEventConsumer {
  public typealias PageFactory = (CockpitEngineContext) throws -> any CockpitPageSurface
  private let makePage: PageFactory
  private let downstream: (any EngineClientEventConsumer)?
  private var ownedClient: (any EngineClient)?
  private weak var borrowedClient: (any EngineClient)?
  private var client: (any EngineClient)? { ownedClient ?? borrowedClient }
  private var delivery: EngineDeliveryContext?
  private var page: (any CockpitPageSurface)?
  private var pageGeneration: UUID?
  public private(set) var selectedScope = "all"
  /// The calendar day the scope was chosen.
  private var scopeDay: DateComponents?
  /// The clock that decides that day. The app sets its own clock here, so the day follows the clock its
  /// other deadlines use.
  public var currentDate: @MainActor () -> Date = { Date() }
  /// D64: set after `currentDate`. A saved scope from today is restored; any other day is ignored. A numbered
  /// (positional) fallback is never kept, and a restored scope is still checked against each reply.
  public var scopeMemory: (any CockpitScopeMemory)? {
    didSet {
      guard let saved = scopeMemory?.load(), Self.persistable(saved.key), saved.day == dayKey(currentDate()) else { return }
      selectedScope = saved.key; scopeDay = calendarDay(currentDate())
    }
  }
  /// G3-56: the acknowledged caution identities. Restored at load, replaced whenever the page reports a press.
  public private(set) var ackedCautions: [String] = []
  public var cautionMemory: (any CockpitCautionMemory)? {
    didSet { let ids = cautionMemory?.load() ?? []; ackedCautions = CockpitCautionIdentities.valid(ids) ? ids : [] }
  }
  private static func persistable(_ key: String) -> Bool {
    key != "all" && CockpitMemberScopes.isValidKey(key) && !CockpitMemberScopes.isIndexedFallback(key)
  }
  private func dayKey(_ date: Date) -> String {
    let d = calendarDay(date); return String(format: "%04d-%02d-%02d", d.year ?? 0, d.month ?? 0, d.day ?? 0)
  }
  private var scopeMembers = Set<String>()
  private var request: Task<Void, Never>?
  private var requestToken: UUID?
  private var requestTicket: CockpitQueryTicket?
  private var refreshAgain = false
  /// True from open() until the shown page closes. A prewarmed page is not presented.
  public private(set) var presented = false
  /// The last accepted cockpit reply, kept only for the exact delivery it was answered for. It is shown
  /// at the next open before the fresh query returns, and dropped with every private-view clear,
  /// delivery change, feature failure and shutdown. The page applies the same freshness rules to it as
  /// to any data, against the clock at display time.
  private var lastReply: (delivery: EngineDeliveryContext, data: WireCockpitData)?
  /// CKP-SHELL-20 (owner D50): keep one loaded, hidden, empty page ready so a click does not wait for a
  /// WebKit cold start. Off by default; the app turns it on when the cockpit entry is enabled.
  public var prewarmEnabled = false {
    didSet {
      guard prewarmEnabled != oldValue else { return }
      if prewarmEnabled { watchMemoryPressure(); schedulePrewarm() }
      else { stopWatchingMemoryPressure(); releaseWarmPage() }
    }
  }
  public var prewarmDelay: Duration = .milliseconds(500)
  private var prewarmTask: Task<Void, Never>?
  /// Hidden pages that ended on their own (a failure, not a release or a clear) since the last open.
  /// Three stop prewarming until the next open, so a page that cannot load is not rebuilt in a loop.
  private var warmFailures = 0
  /// G3-66: an open that found no engine context yet. The first context completes it, so a click during the
  /// engine start is not lost and needs no second click.
  private var pendingOpen = false
  /// Which engine-side inputs exist, for the failure log. Counters and flags only, never engine data.
  public var diagnosticState: String {
    "client=\(client != nil) delivery=\(delivery != nil) page=\(page != nil) presented=\(presented) pendingOpen=\(pendingOpen) warmFailures=\(warmFailures)"
  }
  private var memoryPressured = false
  private var releasingWarmPage = false
  private var memorySource: (any DispatchSourceMemoryPressure)?
  /// G3-42 timing lines: hidden pages built this launch, when the current one was built, and whether the
  /// fresh reply of the current open has been logged.
  private var warmBuilds = 0
  private var warmBuiltAt: TimeInterval?
  private var freshLogged = true
  #if MODELPLAN_TEST_ONLY_SPI
  /// Names each step of a prewarm and an open, in order, for timing tests. Never engine data.
  public var verificationTrace: ((String) -> Void)?
  #endif
  private func trace(_ step: String) {
    #if MODELPLAN_TEST_ONLY_SPI
    verificationTrace?(step)
    #endif
  }
  public var onIntent: ((CockpitIntent) -> Void)?
  public var onUnavailable: ((CockpitUnavailableReason) -> Void)?
  public var onClosed: (() -> Void)?
  public var onOpened: (() -> Void)?

  public init(downstream: (any EngineClientEventConsumer)? = nil, makePage: @escaping PageFactory) {
    self.downstream = downstream
    self.makePage = makePage
  }
  public convenience init(
    bundle: VerifiedCockpitBundle, appearance: CockpitAppearance,
    downstream: (any EngineClientEventConsumer)? = nil
  ) {
    self.init(downstream: downstream) {
      CockpitWindowController(bundle: bundle, context: $0, appearance: appearance)
    }
  }
  /// Builds the actual production protocol client; no second DTO return path.
  /// The consumer proxy is weak so the client/consumer graph has no retain cycle.
  @discardableResult public func makeClient(
    configuration: EngineClientConfiguration, credentialAgent: (any CredentialAgent)? = nil
  ) -> ProcessEngineClient {
    precondition(client == nil)
    let value = ProcessEngineClient(
      configuration: configuration, credentialAgent: credentialAgent,
      consumer: WeakCockpitConsumer(self))
    ownedClient = value
    return value
  }
  /// Injection seam for an already-constructed client whose consumer routes to
  /// consume(). Never construct a second client to display one cockpit.
  public func bind(client: any EngineClient) {
    precondition(self.client == nil)
    self.borrowedClient = client
  }
  public static func bridgeContext(_ context: EngineDeliveryContext) throws -> CockpitEngineContext
  {
    // ProcessEngineClient uses s-<UUID>. Preserve that exact UUID identity;
    // never invent a session when an unsupported identity reaches the seam.
    let raw =
      context.sessionID.hasPrefix("s-") ? String(context.sessionID.dropFirst(2)) : context.sessionID
    guard let session = UUID(uuidString: raw) else { throw CockpitBridgeError.invalidContext }
    return try CockpitEngineContext(
      sessionID: session, storeEpoch: context.floor.storeEpoch, generation: context.floor.generation
    )
  }
  public func start() async throws {
    guard let client else { throw CockpitBridgeError.unavailable }
    _ = try await client.start()
  }
  public func open() {
    guard client != nil else { onUnavailable?(.noClient); return }
    guard let delivery else { pendingOpen = true; onUnavailable?(.noDelivery); return }
    guard let context = try? Self.bridgeContext(delivery) else { onUnavailable?(.invalidContext); return }
    prewarmTask?.cancel(); prewarmTask = nil
    warmFailures = 0
    if let page {
      if !presented {
        // The prewarmed page: the click only shows it. Its scope starts as a new page's does.
        presented = true
        freshLogged = false
        CockpitTimingLog.record("open page=\(page.queryTicket == nil ? "warm-loading" : "warm-ready") clickMs=\(CockpitTimingLog.sinceClick())")
        trace("open.warm")
        retireScopeFromAnotherDay()
        page.updateScope(selectedScope)
      }
      page.open()
      if self.page === page { onOpened?() }
      return
    }
    let newPage: any CockpitPageSurface
    do { newPage = try makeWiredPage(context) } catch {
      onUnavailable?(.pageCreation(CockpitFailureLog.errorName(error))); return
    }
    presented = true
    freshLogged = false
    CockpitTimingLog.record("open page=cold clickMs=\(CockpitTimingLog.sinceClick())")
    trace("open.cold")
    page = newPage
    retireScopeFromAnotherDay()
    newPage.updateScope(selectedScope)
    newPage.open()
    if page === newPage { onOpened?() }
  }
  /// One page and its callbacks; the same for a prewarmed page and one made by a click.
  private func makeWiredPage(_ context: CockpitEngineContext) throws -> any CockpitPageSurface {
    let newPage = try makePage(context)
    newPage.setAckedCautions(ackedCautions)
    let generation = UUID()
    pageGeneration = generation
    newPage.onReady = { [weak self] in
      guard let self, self.pageGeneration == generation else { return }
      if !self.presented { CockpitTimingLog.record("prewarm ready buildMs=\(self.warmBuiltAt.map { CockpitTimingLog.ms(since: $0) } ?? -1)") }
      else { CockpitTimingLog.record("open ready clickMs=\(CockpitTimingLog.sinceClick())") }
      self.trace(self.presented ? "page.ready" : "warm.ready")
      self.refresh()
    }
    newPage.onShown = { [weak self] in
      guard let self, self.pageGeneration == generation, self.presented else { return }
      CockpitTimingLog.record("open shown clickMs=\(CockpitTimingLog.sinceClick())")
      self.trace("page.shown")
      self.showLastReply()
      // A query already running was asked after this page loaded; its reply is fresh.
      if self.request == nil { self.refresh() }
    }
    newPage.onIntent = { [weak self] intent in
      guard self?.pageGeneration == generation else { return }; self?.receiveIntent(intent)
    }
    newPage.onClosed = { [weak self] in
      guard let self, self.pageGeneration == generation else { return }
      self.pageGeneration = nil
      self.scopeMembers.removeAll()
      self.cancelQuery()
      self.page = nil
      let wasPresented = self.presented
      self.presented = false
      if wasPresented { self.onClosed?() }
      else if !self.releasingWarmPage {
        self.warmFailures += 1
        CockpitTimingLog.record("prewarm ended failures=\(self.warmFailures)")
      }
      self.schedulePrewarm()
    }
    return newPage
  }
  /// The last reply for this exact delivery, on a page confirmed visible. Never retagged to a newer context.
  private func showLastReply() {
    guard let page, let ticket = page.queryTicket, let delivery, let last = lastReply, last.delivery == delivery,
      let context = try? Self.bridgeContext(delivery), ticket.context == context else { return }
    scopeMembers = CockpitMemberScopes.keys(last.data)
    if CockpitMemberScopes.isIndexedFallback(selectedScope) || !scopeMembers.contains(selectedScope) { selectedScope = "all" }
    CockpitTimingLog.record("open display=last clickMs=\(CockpitTimingLog.sinceClick())")
    trace("display.last")
    page.display(last.data, ticket: ticket)
    page.updateScope(selectedScope)
  }
  private func schedulePrewarm() {
    guard prewarmEnabled, !memoryPressured, warmFailures < 3, page == nil, prewarmTask == nil,
      client != nil, delivery != nil else { return }
    let delay = prewarmDelay
    prewarmTask = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: delay) } catch { return }
      guard let self, !Task.isCancelled else { return }
      self.prewarmTask = nil
      self.prewarmNow()
    }
  }
  private func prewarmNow() {
    guard prewarmEnabled, !memoryPressured, warmFailures < 3, page == nil, client != nil,
      let delivery, let context = try? Self.bridgeContext(delivery) else { return }
    do {
      let warm = try makeWiredPage(context)
      page = warm
      warmBuilds += 1; warmBuiltAt = CockpitTimingLog.now
      CockpitTimingLog.record("prewarm build n=\(warmBuilds)")
      trace("warm.start")
      warm.prewarm()
    } catch {
      // Nothing is shown for a page nobody asked for; a click reports its own failure.
      warmFailures = 3
      CockpitFailureLog.record("prewarm-unavailable error=\(CockpitFailureLog.errorName(error))")
    }
  }
  /// A hidden page that a clear discards before it loaded was not a failure; build the next one as usual.
  private func clearKeepingWarmCount(_ page: any CockpitPageSurface, adopting context: CockpitEngineContext?) async {
    let hidden = !presented
    if hidden { releasingWarmPage = true }
    await page.clearPrivateViews(adopting: context)
    if hidden { releasingWarmPage = false }
  }
  /// Discards the hidden page, never a shown one. A released page is not counted as a failure.
  public func releaseWarmPage() {
    prewarmTask?.cancel(); prewarmTask = nil
    guard let warm = page, !presented else { return }
    cancelQuery()
    page = nil; pageGeneration = nil; scopeMembers.removeAll()
    warm.discard()
    CockpitTimingLog.record("prewarm released")
    trace("warm.released")
  }
  /// Under memory pressure the hidden page goes; it comes back once the system reports normal again.
  func memoryPressureChanged(pressured: Bool) {
    memoryPressured = pressured
    if pressured { releaseWarmPage() } else { schedulePrewarm() }
  }
  private func watchMemoryPressure() {
    guard memorySource == nil else { return }
    let source = DispatchSource.makeMemoryPressureSource(eventMask: [.normal, .warning, .critical], queue: .main)
    source.setEventHandler { [weak self] in
      MainActor.assumeIsolated {
        guard let self, let event = self.memorySource?.data else { return }
        self.memoryPressureChanged(pressured: !event.contains(.normal))
      }
    }
    source.resume()
    memorySource = source
  }
  private func stopWatchingMemoryPressure() { memorySource?.cancel(); memorySource = nil }
  private func receiveIntent(_ intent:CockpitIntent) {
    if case .cautionAck(let ids)=intent {
      guard CockpitCautionIdentities.valid(ids) else { return }
      ackedCautions=ids; cautionMemory?.save(ids); return
    }
    if case .scopeSelect(let key)=intent {
      guard delivery != nil,scopeMembers.contains(key) else { return }
      selectedScope=key; scopeDay=calendarDay(currentDate()); page?.updateScope(key)
      scopeMemory?.save(Self.persistable(key) ? (key, dayKey(currentDate())) : nil); return
    }
    onIntent?(intent)
  }
  private func calendarDay(_ date:Date) -> DateComponents { Calendar.current.dateComponents([.era,.year,.month,.day],from:date) }
  /// CKP-ENTRY-04: a scope lasts for the day it was chosen; the first open on a later day starts at All.
  private func retireScopeFromAnotherDay() {
    if selectedScope != "all", scopeDay != calendarDay(currentDate()) { selectedScope="all" }
  }
  public func updateAppearance(_ appearance: CockpitAppearance) { page?.updateAppearance(appearance) }
  /// User close retains the page until its normal transition completes.
  /// Privacy/shutdown continue to use close() for immediate disposal.
  public func requestClose() {
    guard presented else { return }
    cancelQuery(); page?.requestClose()
  }
  public func close() {
    pendingOpen = false
    cancelQuery()
    prewarmTask?.cancel(); prewarmTask = nil
    let previous = page, wasPresented = presented
    page = nil; pageGeneration = nil; scopeMembers.removeAll(); presented = false
    previous?.discard()
    if previous != nil, wasPresented { onClosed?() }
    schedulePrewarm()
  }
  private func cancelQuery() {
    request?.cancel()
    request = nil
    requestToken = nil
    requestTicket = nil
    refreshAgain = false
  }
  public func refresh() {
    guard let client, let ticket = page?.queryTicket, let delivery else { return }
    // A hidden page asks only to fill an empty last reply; while it stays hidden, row changes wait for the open.
    guard presented || lastReply?.delivery != delivery else { return }
    guard request == nil else {
      refreshAgain = true
      return
    }
    let token = UUID()
    requestToken = token
    requestTicket = ticket
    trace("query.start")
    request = Task { @MainActor [weak self] in
      do { _ = try await client.cockpit(timeout: .seconds(10)) }
      catch EngineClientError.featureDecode(.cockpit) {
        // ProcessEngineClient pairs this completion with the ordered feature
        // event. That event alone owns the notice, in either scheduling order.
      } catch {
        // A query for a hidden page that fails shows nothing; the open asks again.
        if self?.requestToken == token, self?.presented == true { self?.onUnavailable?(.query(CockpitFailureLog.errorName(error))) }
      }
      guard let self, self.requestToken == token else { return }
      self.request = nil
      self.requestToken = nil
      self.requestTicket = nil
      if self.refreshAgain {
        self.refreshAgain = false
        self.refresh()
      }
    }
  }
  #if DEBUG
  // A completion-only join lets verification force the inverse event order;
  // no response value or publication path is exposed.
  func joinCurrentQueryForVerification() async { await request?.value }
  #endif
  private func adopt(_ next: EngineDeliveryContext) async {
    guard delivery != next else { return }
    cancelQuery()
    lastReply = nil
    // A restored scope (D64) waits for the first context; a change of session or floor after that returns to All.
    if let previous = delivery, previous.sessionID != next.sessionID || previous.floor != next.floor { selectedScope="all" }
    scopeMembers.removeAll()
    delivery = next
    do {
      let context = try Self.bridgeContext(next)
      if let page { await clearKeepingWarmCount(page, adopting: context); page.updateScope(selectedScope) }
      refresh()
      if pendingOpen { pendingOpen = false; open() }
      schedulePrewarm()
    } catch {
      delivery = nil
      close()
      onUnavailable?(.contextRejected)
    }
  }
  public func consume(_ event: EngineClientEvent) async {
    switch event {
    case .clearPrivateViews(let invalidation):
      cancelQuery()
      lastReply = nil
      // The engine's first floor arrives as a clear with no previous session; nothing private was shown yet, so a scope
      // restored for today (D64) stays, and is still checked against the first reply. After a session, a consent or
      // store change forgets the saved scope; an engine stop (the app quitting) keeps it for today.
      if invalidation.previous == nil {
        delivery = nil; scopeMembers.removeAll()
        // A prewarmed page cleared here is not a failure of that page (CKP-SHELL-20).
        if let page { await clearKeepingWarmCount(page, adopting: nil); page.updateScope(selectedScope) }
        break
      }
      if invalidation.reason == .generationAdvanced || invalidation.reason == .epochChanged { scopeMemory?.save(nil); cautionMemory?.save([]); ackedCautions = [] }
      delivery = nil; selectedScope="all"; scopeMembers.removeAll()
      // Do not adopt a guessed session from nextFloor. The subsequent
      // admitted context event supplies the complete authoritative identity.
      if let page { await clearKeepingWarmCount(page, adopting: nil); page.updateScope("all") }
    case .context(let context), .connection(.ready(let context)):
      await adopt(context)
    case .response(_, .cockpit(let reply)):
      if let ticket = requestTicket, let delivery, reply.delivery == delivery,
        ticket == page?.queryTicket,
        reply.envelope.sessionId == delivery.sessionID,
        reply.envelope.storeEpoch == delivery.floor.storeEpoch,
        reply.envelope.consentGeneration == delivery.floor.generation
      {
        lastReply = (delivery, reply.envelope.data)
        trace(presented ? "query.reply" : "warm.reply")
        if !presented { CockpitTimingLog.record("prewarm last-reply buildMs=\(warmBuiltAt.map { CockpitTimingLog.ms(since: $0) } ?? -1)") }
        else if !freshLogged { freshLogged = true; CockpitTimingLog.record("open display=fresh clickMs=\(CockpitTimingLog.sinceClick())") }
        if presented {
          scopeMembers=CockpitMemberScopes.keys(reply.envelope.data)
          if CockpitMemberScopes.isIndexedFallback(selectedScope) || !scopeMembers.contains(selectedScope) { selectedScope="all" }
          page?.display(reply.envelope.data, ticket: ticket)
          page?.updateScope(selectedScope)
        }
      }
    case .rowsChanged: refresh()
    case .featureFailure(.cockpit, _):
      cancelQuery()
      lastReply = nil
      // Do not rebuild a page that the engine cannot fill; the next open tries again.
      warmFailures = 3
      // Capture the foreground recovery intent before onClosed retires it.
      onUnavailable?(.featureFailure)
      close()
    default: break
    }
    await downstream?.consume(event)
  }
  /// Owner calls outside the delivery turn; stop itself emits a clear event.
  public func shutdown() async {
    prewarmEnabled = false
    close()
    delivery = nil; selectedScope="all"; scopeMembers.removeAll(); lastReply = nil
    let current = ownedClient
    ownedClient = nil; borrowedClient = nil
    await current?.stop()
  }
}

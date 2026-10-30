// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineClient
import ModelPlanWire

@MainActor public protocol CockpitPageSurface: AnyObject {
  var queryTicket: CockpitQueryTicket? { get }
  var onReady: (() -> Void)? { get set }
  var onIntent: ((CockpitIntent) -> Void)? { get set }
  var onClosed: (() -> Void)? { get set }
  func open()
  func display(_ data: WireCockpitData, ticket: CockpitQueryTicket)
  func clearPrivateViews(adopting: CockpitEngineContext?) async
  func discard()
}
extension CockpitWindowController: CockpitPageSurface {}

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
  private var request: Task<Void, Never>?
  private var requestToken: UUID?
  private var requestTicket: CockpitQueryTicket?
  private var refreshAgain = false
  public var onIntent: ((CockpitIntent) -> Void)?
  public var onUnavailable: (() -> Void)?
  public var onClosed: (() -> Void)?

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
    guard let delivery, client != nil, let context = try? Self.bridgeContext(delivery) else {
      onUnavailable?()
      return
    }
    if let page {
      page.open()
      return
    }
    let newPage: any CockpitPageSurface
    do { newPage = try makePage(context) } catch { onUnavailable?(); return }
    newPage.onReady = { [weak self] in self?.refresh() }
    newPage.onIntent = { [weak self] in self?.onIntent?($0) }
    newPage.onClosed = { [weak self] in
      self?.cancelQuery()
      self?.page = nil
      self?.onClosed?()
    }
    page = newPage
    newPage.open()
  }
  public func close() {
    cancelQuery()
    page?.discard()
    page = nil
  }
  private func cancelQuery() {
    request?.cancel()
    request = nil
    requestToken = nil
    requestTicket = nil
    refreshAgain = false
  }
  public func refresh() {
    guard let client, let ticket = page?.queryTicket, delivery != nil else { return }
    guard request == nil else {
      refreshAgain = true
      return
    }
    let token = UUID()
    requestToken = token
    requestTicket = ticket
    request = Task { @MainActor [weak self] in
      do { _ = try await client.cockpit(timeout: .seconds(10)) }
      catch EngineClientError.featureDecode(.cockpit) {
        // ProcessEngineClient pairs this completion with the ordered feature
        // event. That event alone owns the notice, in either scheduling order.
      } catch {
        if self?.requestToken == token { self?.onUnavailable?() }
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
    delivery = next
    do {
      let context = try Self.bridgeContext(next)
      if let page { await page.clearPrivateViews(adopting: context) }
      refresh()
    } catch {
      delivery = nil
      close()
      onUnavailable?()
    }
  }
  public func consume(_ event: EngineClientEvent) async {
    switch event {
    case .clearPrivateViews:
      cancelQuery()
      delivery = nil
      // Do not adopt a guessed session from nextFloor. The subsequent
      // admitted context event supplies the complete authoritative identity.
      if let page { await page.clearPrivateViews(adopting: nil) }
    case .context(let context), .connection(.ready(let context)):
      await adopt(context)
    case .response(_, .cockpit(let reply)):
      if let ticket = requestTicket, let delivery, reply.delivery == delivery,
        ticket == page?.queryTicket,
        reply.envelope.sessionId == delivery.sessionID,
        reply.envelope.storeEpoch == delivery.floor.storeEpoch,
        reply.envelope.consentGeneration == delivery.floor.generation
      {
        page?.display(reply.envelope.data, ticket: ticket)
      }
    case .rowsChanged: refresh()
    case .featureFailure(.cockpit, _):
      cancelQuery()
      // Capture the foreground recovery intent before onClosed retires it.
      onUnavailable?()
      close()
    default: break
    }
    await downstream?.consume(event)
  }
  /// Owner calls outside the delivery turn; stop itself emits a clear event.
  public func shutdown() async {
    close()
    delivery = nil
    let current = ownedClient
    ownedClient = nil; borrowedClient = nil
    await current?.stop()
  }
}

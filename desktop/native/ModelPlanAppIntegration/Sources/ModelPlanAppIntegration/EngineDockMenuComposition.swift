// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
import ModelPlanCommunityHost

/// Normal-entry composition. Construction creates no engine child or native panel when requested.
public struct EngineMenuRefreshResult {
    public let engineRequestID:WireRequestID
    public let scheduled:[WireRefreshScheduled]
}
@MainActor public final class EngineDockMenuComposition {
    public let store: EngineStore
    public let client: any EngineClient
    public let provider: EngineDockMenuProvider
    public let dock: StaticDockPreviewHost
    private let adapter: EngineDockContentProvider
    public var menuDidChange: (() -> Void)?
    public init(configuration: EngineClientConfiguration, createsNativePanels: Bool = true,
                makeClient: (@MainActor (EngineClientConfiguration, EngineStore) -> any EngineClient)? = nil) {
        let store: EngineStore
        if let makeClient {
            store = EngineStore(); client = makeClient(configuration, store)
        } else {
            let connection = EngineStoreConnection(configuration: configuration)
            store = connection.store; client = connection.client
        }
        self.store = store
        let provider = EngineDockMenuProvider(store: store)
        self.provider = provider
        adapter = EngineDockContentProvider(source: provider)
        dock = ProductionDockFactory.community(createsNativePanels: createsNativePanels)
        adapter.bindDockMenuTracking(dock)
        dock.setDockContentProvider(adapter)
        provider.dockContentDidChange = { [weak self] in
            self?.adapter.scrubInvalidatedMenus()
            self?.dock.refreshDockContent(); self?.menuDidChange?()
        }
    }
    public var presentedContent: DockContent { adapter.makeContent(.init(snapshot: nil, diagnostics: .init(), now: Date())) }
    public var menuPresentation: CommunityMenuBarPresentation {
        let content = presentedContent
        return .init(title: "", detail: (content.menuStatusLines ?? []).joined(separator: " · "))
    }
    public func start() async {
        do { _ = try await client.start(); _ = try await client.subscribeRows(timeout: nil) }
        catch { /* Accepted client events own errors and current data, never the Task completion. */ }
    }
    public func refresh(onResult: (@MainActor (Result<EngineMenuRefreshResult, Error>) -> Void)? = nil) async {
        var replies:[(WireRequestID,[WireRefreshScheduled])]=[]
        let token=onResult == nil ? nil : store.observeRefreshReplies { replies.append(($0,$1)) }
        defer { if let token { store.removeRefreshReplyObserver(token) } }
        do {
            let completion=try await client.refresh(try .init(), timeout:nil)
            if let onResult {
                let own=replies.filter { $0.0==completion.requestID }
                guard own.count==1 else { throw EngineClientError.protocolViolation }
                onResult(.success(.init(engineRequestID:completion.requestID,scheduled:own[0].1)))
            }
        }
        catch { onResult?(.failure(error)) /* No automatic retry or optimistic value. */ }
    }
    public func stop() async { dock.close(); await client.stop() }
}

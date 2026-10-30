// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanEngineStore
import ModelPlanEngineClient
import ModelPlanWire
import ModelPlanCommunityHost

/// Normal-entry composition. Construction creates no engine child or native panel when requested.
@MainActor public final class EngineDockMenuComposition {
    public let store: EngineStore
    public let client: any EngineClient
    public let provider: EngineDockMenuProvider
    public let dock: StaticDockPreviewHost
    private let adapter: EngineDockContentProvider
    public var menuDidChange: (() -> Void)?
    public init(configuration: EngineClientConfiguration, createsNativePanels: Bool = true,
                makeClient: (@MainActor (EngineClientConfiguration, EngineStore) -> any EngineClient)? = nil) {
        let store = EngineStore()
        self.store = store
        client = makeClient?(configuration, store) ?? ProcessEngineClient(configuration: configuration, consumer: store)
        let provider = EngineDockMenuProvider(store: store)
        self.provider = provider
        adapter = EngineDockContentProvider(source: provider)
        dock = ProductionDockFactory.community(createsNativePanels: createsNativePanels)
        dock.setDockContentProvider(adapter)
        provider.dockContentDidChange = { [weak self] in
            self?.dock.refreshDockContent(); self?.menuDidChange?()
        }
    }
    public var menuPresentation: CommunityMenuBarPresentation {
        let content = adapter.makeContent(.init(snapshot: nil, diagnostics: .init(), now: Date()))
        return .init(title: "", detail: (content.menuStatusLines ?? []).joined(separator: " · "))
    }
    public func start() async {
        do { _ = try await client.start(); _ = try await client.subscribeRows(timeout: nil) }
        catch { /* Accepted client events own errors and current data, never the Task completion. */ }
    }
    public func refresh() async {
        do { _ = try await client.refresh(try .init(), timeout: nil) }
        catch { /* No automatic retry or optimistic value. */ }
    }
    public func stop() async { dock.close(); await client.stop() }
}

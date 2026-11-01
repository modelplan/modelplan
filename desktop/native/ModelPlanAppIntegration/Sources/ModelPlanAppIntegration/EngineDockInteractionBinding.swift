// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanDock
import ModelPlanSettings

@MainActor public final class EngineDockInteractionBinding {
    private weak var host: (any DockInteractionHostPort)?
    private let application: SettingsApplicationCoordinator
    private let controller: DockInteractionController
    private var active = false
    private var installed = false
    private var generation: UInt64 = 0

    public init(host: any DockInteractionHostPort, application: SettingsApplicationCoordinator,
                scheduler: any DockEdgeScheduling, clock: @escaping () -> TimeInterval) {
        self.host = host; self.application = application
        controller = DockInteractionController(clock: clock, scheduler: scheduler) { [weak host] in
            host?.interactionEnvironment() ?? .init(catalogue: [], preferences: .init(), targets: [], active: false)
        }
    }

    public func install() {
        guard !installed, let host else { return }
        installed = true
        controller.onOrderRequest = { [weak self] request in self?.submit(request) }
        host.installInteraction(controller)
    }

    public func start() {
        guard !active else { return }
        install()
        guard installed else { return }
        active = true; generation &+= 1
        controller.start()
    }

    public func stop() {
        guard installed else { return }
        active = false; installed = false; generation &+= 1
        controller.onOrderRequest = nil
        controller.stop(preservingPin: false)
        host?.uninstallInteraction(controller)
    }

    private func submit(_ request: DockOrderRequest) {
        let token = generation
        Task { [weak self] in
            guard let self, self.active, self.generation == token else { return }
            let editor = self.application.editor
            guard let snapshot = editor.snapshot,
                  snapshot.preferences.subscriptions == request.expected,
                  editor.context.subscriptions.map(\.id) == request.catalogue,
                  let expectedOrder = try? request.expected.orderedIDs(in: request.catalogue) else {
                self.controller.orderRejected(request.id); return
            }
            do {
                let committed = try await editor.commit(.moveSubscription(request.movedID, to: request.position, expectedOrder: expectedOrder))
                guard self.active, self.generation == token else { return }
                guard editor.context.subscriptions.map(\.id) == request.catalogue,
                      committed.preferences.subscriptions == request.proposed else {
                    self.controller.orderRejected(request.id); return
                }
                self.controller.orderAccepted(request.id, preferences: committed.preferences.subscriptions, catalogue: request.catalogue)
            } catch {
                guard self.active, self.generation == token else { return }
                self.controller.orderRejected(request.id)
            }
        }
    }
}

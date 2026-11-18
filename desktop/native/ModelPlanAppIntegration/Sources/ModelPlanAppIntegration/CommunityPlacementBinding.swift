// SPDX-License-Identifier: MIT
import ModelPlanDock
import ModelPlanSettings

/// The Dock owns geometry; Settings consumes observations and saves explicit placement choices.
@MainActor public protocol CommunityPlacementProducing: AnyObject {
    var onPlacementObserved: ((DockEdgePlacement?, Bool) -> Void)? { get set }
}
/// Existing Dock return ports; all writes still go through the shared Settings editor.
@MainActor public protocol CommunityDockSettingsRouting: CommunityPlacementProducing {
    var commitDisplayPlacement: ((String, SettingsDockEdge, Double) -> Void)? { get set }
    var displayChoicesChanged: (([SettingsDisplayChoice]) -> Void)? { get set }
    var catalogueChanged: (([SettingsSubscription]) -> Void)? { get set }
}
extension StaticDockPreviewHost: CommunityDockSettingsRouting {}

@MainActor public enum CommunityPlacementBinding {
    public static func install(on producer: any CommunityPlacementProducing, application: SettingsApplicationCoordinator) {
        if let dock = producer as? any CommunityDockSettingsRouting {
            let saver = CommunityPlacementSaver(application: application)
            dock.commitDisplayPlacement = { id, edge, fraction in saver.save(displayID: id, edge: edge, alongFraction: fraction) }
            dock.displayChoicesChanged = { [weak application] displays in
                guard let application else { return }
                var context = application.editor.context; context.displays = displays
                application.update(context: context)
            }
            dock.catalogueChanged = { [weak application] rows in
                guard let application else { return }
                var context = application.editor.context; context.subscriptions = rows
                application.update(context: context)
            }
        }
        producer.onPlacementObserved = { [weak application] placement, recovering in
            guard let application else { return }
            // Inputs come from the same resolver/producer; invalid facts become unknown, never preferences.
            do { try CommunityDockPlacementFacts.apply(placement, recovering: recovering, application: application) }
            catch { try? CommunityDockPlacementFacts.apply(nil, recovering: false, application: application) }
        }
    }
}

/// Saves a dropped widget placement through the shared Settings editor without losing it to another writer.
/// The help-hint host writes the same store directly, and an edge-changing carry retires the help surface's
/// anchors as the drop is presented, so its hint write can land just before the drop's commit: that commit then
/// failed as a stale revision (or overlapped an in-flight save) and was dropped by a bare `try?`, leaving the
/// widget shown on the new edge but never saved. A failed save is retried against the reloaded revision, and a
/// newer drop supersedes an older one that has not been saved yet.
@MainActor final class CommunityPlacementSaver {
    struct Placement: Equatable { let displayID: String, edge: SettingsDockEdge, alongFraction: Double }
    static let attemptLimit = 4
    static let busyWait: Duration = .seconds(3)
    private weak var application: SettingsApplicationCoordinator?
    private var latest: Placement?
    private var draining = false
    init(application: SettingsApplicationCoordinator) { self.application = application }

    func save(displayID: String, edge: SettingsDockEdge, alongFraction: Double) {
        latest = .init(displayID: displayID, edge: edge, alongFraction: alongFraction)
        guard !draining else { return }
        draining = true
        Task { @MainActor [weak self] in await self?.drain() }
    }
    private func drain() async {
        defer { draining = false }
        while let next = latest {
            latest = nil
            await commit(next)
        }
    }
    private func commit(_ placement: Placement) async {
        var failures = 0
        let busyUntil = ContinuousClock.now + Self.busyWait
        while failures < Self.attemptLimit {
            // A newer drop replaces this one; the drain saves it next.
            guard latest == nil, let application, application.editor.snapshot != nil else { return }
            if application.editor.isSaving {
                guard ContinuousClock.now < busyUntil else { return }
                try? await Task.sleep(for: .milliseconds(50)); continue
            }
            do {
                _ = try await application.editor.commit(.dockPlacement(displayID: placement.displayID, edge: placement.edge,
                                                                       alongFraction: placement.alongFraction))
                return
            } catch SettingsEditorError.editInProgress {
                guard ContinuousClock.now < busyUntil else { return }
                try? await Task.sleep(for: .milliseconds(50))
            } catch {
                // The editor has already reloaded the store's current revision (another writer advanced it).
                failures += 1
                await application.editor.reload()
            }
        }
    }
}

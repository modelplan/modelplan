// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCockpitWeb
import ModelPlanSettings

/// Samples the plugins the cockpit page runs (D124: only while the cockpit is open and the column is on the shown
/// page). A plugin that needs host readings registers a reader; one that derives everything from `display` (calendar)
/// registers none. Each running, enabled, registered plugin is read at once and then every `intervalSeconds` (its
/// setting, else 10 s); it stops the moment it leaves the running set or is turned off.
@MainActor public final class CockpitPluginSampler {
    public typealias Reader = @MainActor () -> [String: Any]?
    /// Runs `fire` once after the delay; the returned closure cancels it.
    public typealias Schedule = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> @MainActor () -> Void
    public static let defaultInterval = 10
    public var send: ((String, [String: Any]) -> Void)?
    private let schedule: Schedule
    private var readers: [String: Reader] = [:]
    private var timers: [String: (interval: Int, cancel: @MainActor () -> Void)] = [:]
    private var running: [String] = []
    private var preferences = CockpitPluginPreferences()
    private var catalogue = CockpitPluginCatalogue.builtIn
    public init(schedule: Schedule? = nil) {
        if let schedule { self.schedule = schedule; return }
        self.schedule = { delay, fire in
            let task = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(Int(delay * 1000))) } catch { return }
                fire()
            }
            return { task.cancel() }
        }
    }
    public func register(_ id: String, reader: @escaping Reader) { readers[id] = reader; reconcile() }
    public func unregister(_ id: String) { readers[id] = nil; reconcile() }
    public func setRunning(_ ids: [String]) { running = ids; reconcile() }
    public func apply(_ preferences: CockpitPluginPreferences, catalogue: [CockpitPluginDefinition] = CockpitPluginCatalogue.builtIn) {
        self.preferences = preferences; self.catalogue = catalogue; reconcile()
    }
    /// The ids being sampled now (tests and diagnostics).
    public var sampling: [String] { timers.keys.sorted() }
    private func reconcile() {
        let enabled = Set(preferences.enabledIDs(catalogue))
        let wanted = running.filter { enabled.contains($0) && readers[$0] != nil }
        for (id, timer) in timers where !wanted.contains(id) { timer.cancel(); timers[id] = nil }
        for id in wanted {
            let interval = max(1, preferences.value(id, "intervalSeconds", catalogue) ?? Self.defaultInterval)
            if timers[id]?.interval == interval { continue }
            timers[id]?.cancel(); timers[id] = nil
            sample(id, interval: interval)
        }
    }
    private func sample(_ id: String, interval: Int) {
        if let reading = readers[id]?() { send?(id, reading) }
        // The reader may have changed the running set or the choices; only a still-wanted plugin is scheduled again.
        guard running.contains(id), readers[id] != nil, preferences.enabledIDs(catalogue).contains(id) else { return }
        let cancel = schedule(TimeInterval(interval)) { [weak self] in
            guard let self, self.timers[id]?.interval == interval else { return }
            self.sample(id, interval: interval)
        }
        timers[id] = (interval, cancel)
    }
}

/// macrevc-844-1: the app's side of the cockpit plugin columns. One `CockpitPluginSettingsModel`, persisted by
/// `CockpitPluginStore` beside the settings file, is the durable copy. Every committed change (Settings or a page edit)
/// goes to the coordinator, which hands it to every page; the page's edits are saved here; the page's running plugins
/// drive the sampler.
@MainActor public final class CockpitPluginBridge {
    public let model: CockpitPluginSettingsModel
    public let sampler: CockpitPluginSampler
    private weak var coordinator: EngineCockpitCoordinator?
    /// `sampler` nil makes the app's own (macrevb-1104-1: a default argument cannot call the main-actor initializer).
    public init(model: CockpitPluginSettingsModel, coordinator: EngineCockpitCoordinator?, sampler: CockpitPluginSampler? = nil) {
        let sampler = sampler ?? CockpitPluginSampler()
        self.model = model; self.coordinator = coordinator; self.sampler = sampler
        sampler.send = { [weak coordinator] id, data in coordinator?.sendPluginData(id: id, data: data) }
        // The coordinator and model have one callback each; the bridge owns both and fans out to every observer.
        coordinator?.onPluginsRunning = { [weak self] ids in
            guard let self else { return }
            self.sampler.setRunning(ids)
            for observer in self.runningObservers { observer(ids) }
        }
        // D293 (macrevb-1104-3): the page shows its edit at once. When the edit cannot be saved (bad body, unwritable
        // store), the committed choice is sent again, so the open page and the sampler return to what reopen will show.
        coordinator?.onPluginsEdit = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                var saved = false
                if let object = try? JSONSerialization.jsonObject(with: state) { saved = await self.model.acceptPageEdit(object) }
                if !saved { self.publish(self.model.preferences) }
            }
        }
        model.onChange = { [weak self] preferences in self?.publish(preferences) }
        publish(model.preferences)
    }
    /// Loads the saved choices (`<settings directory>/cockpit-plugins.json`) and attaches them to the coordinator.
    public static func load(directory: URL, coordinator: EngineCockpitCoordinator?) async -> CockpitPluginBridge {
        CockpitPluginBridge(model: await CockpitPluginSettingsModel.load(from: CockpitPluginStore(directory: directory)), coordinator: coordinator)
    }
    private var runningObservers: [([String]) -> Void] = []
    private var choiceObservers: [(CockpitPluginPreferences) -> Void] = []
    /// The page's running plugins ([] without a shown page), now and on every change. Plugin hosts (the resource
    /// plugin's) observe here; nothing else may replace `EngineCockpitCoordinator.onPluginsRunning`.
    public func observeRunning(_ observer: @escaping ([String]) -> Void) {
        runningObservers.append(observer); observer(coordinator?.pluginsRunning ?? [])
    }
    /// The committed plugin choices, now and after every change (Settings or a page edit); never replace `model.onChange`.
    public func observeChoices(_ observer: @escaping (CockpitPluginPreferences) -> Void) {
        choiceObservers.append(observer); observer(model.preferences)
    }
    /// Shows the cockpit (the app's own open path); set by the factory.
    public var showCockpit: (() -> Void)?
    /// #1096 card action: open this plugin's big screen in the cockpit, showing the cockpit first if needed.
    public func openScreen(_ id: String) {
        coordinator?.openPluginScreen(id)
        showCockpit?()
    }
    private func publish(_ preferences: CockpitPluginPreferences) {
        sampler.apply(preferences, catalogue: model.catalogue)
        if let json = try? preferences.bridgeJSON() { coordinator?.pluginsJSON = json }
        for observer in choiceObservers { observer(preferences) }
    }
}

// SPDX-License-Identifier: MIT
import Foundation

public enum FieldPickerConnectionError: Error, Equatable { case disconnected }
public struct FieldPickerHostInput: Sendable {
    public let catalogue: FieldPickerCatalogue
    public let savedValue: Data?
    public init(catalogue: FieldPickerCatalogue, savedValue: Data?) { self.catalogue = catalogue; self.savedValue = savedValue }
}

/// Required upper-owner ports. Implement using the existing selector/store/FieldCoordinator and
/// M2 scope sprite provider. No no-op defaults: unavailable focus/still wiring must throw.
@MainActor public protocol FieldPickerProductionHost: AnyObject {
    func fieldPickerInput() throws -> FieldPickerHostInput
    func applyEnlargedField(_ projection: FieldPublicProjection, focusedPublicID: String?) throws
    func setFieldPickerExpanded(_ expanded: Bool) throws
    func saveFieldPickerValue(_ value: Data) throws
    func closeEnlargedFieldAndRestoreCurrentScopeStill() throws
}

/// Production caller adapter, with no renderer, store, field timer or normal-still cache of its own.
@MainActor public final class FieldPickerProductionBinding {
    public let view: FieldFleetPickerView
    public private(set) var lastError: Error?
    public var onFailure: ((Error) -> Void)?
    private weak var host: (any FieldPickerProductionHost)?
    private var locale: FieldLocale
    private var disposed = false
    public init(view: FieldFleetPickerView, host: (any FieldPickerProductionHost)?, locale: FieldLocale) {
        self.view = view; self.host = host; self.locale = locale
        view.onChange = { [weak self] change in self?.apply(change) }
    }
    /// Explicit enlarge route only. A disconnected production path never exposes working-looking controls.
    public func open() throws {
        guard !disposed else { throw FieldPickerConnectionError.disconnected }
        guard let host else { let error = FieldPickerConnectionError.disconnected; fail(error); throw error }
        do {
            let input = try host.fieldPickerInput()
            guard !disposed else { return }
            let state = FieldFleetPicker(catalogue: input.catalogue, savedValue: input.savedValue)
            try host.setFieldPickerExpanded(state.expanded)
            guard !disposed else { return }
            try host.applyEnlargedField(input.catalogue.projection.selecting(publicIDs: state.selectedIDs(in: input.catalogue)),
                                       focusedPublicID: state.effectiveFocus(in: input.catalogue))
            guard !disposed else { return }
            view.update(catalogue: input.catalogue, locale: locale, restoring: state)
            view.setPresentationAllowed(true); lastError = nil
        } catch { fail(error); throw error }
    }
    private func apply(_ change: FieldPickerChange) {
        guard !disposed, view.isPresented else { return }
        guard let host else { fail(FieldPickerConnectionError.disconnected); return }
        do {
            if change.kind == .presentation { try host.setFieldPickerExpanded(change.expanded) }
            else {
                try host.applyEnlargedField(change.projection, focusedPublicID: change.focusedPublicID)
            }
            guard !disposed else { return }
            if let saved = change.savedValue { try host.saveFieldPickerValue(saved) }
            lastError = nil
        } catch { fail(error) }
    }
    public func close() throws {
        view.setPresentationAllowed(false)
        guard !disposed else { throw FieldPickerConnectionError.disconnected }
        guard let host else { let error = FieldPickerConnectionError.disconnected; fail(error); throw error }
        do { try host.closeEnlargedFieldAndRestoreCurrentScopeStill(); lastError = nil }
        catch { fail(error); throw error }
    }
    private func fail(_ error: Error) { lastError = error; view.setPresentationAllowed(false); onFailure?(error) }
    public func dispose() {
        guard !disposed else { return }; disposed = true
        view.dispose(); host = nil; onFailure = nil
    }
}

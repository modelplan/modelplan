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
    public private(set) var recoveryError: Error?
    public var onFailure: ((Error) -> Void)?
    private weak var host: (any FieldPickerProductionHost)?
    private var locale: FieldLocale
    private var disposed = false
    public private(set) var isProcessing = false
    public init(view: FieldFleetPickerView, host: (any FieldPickerProductionHost)?, locale: FieldLocale) {
        self.view = view; self.host = host; self.locale = locale
        view.onChange = { [weak self] change in self?.apply(change) }
    }
    public func setLocale(_ locale: FieldLocale) { self.locale = locale }
    /// Explicit enlarge only. Host failures are compensated; failed compensation retains retry controls.
    public func open() throws {
        guard !isProcessing else { throw FieldPickerConnectionError.disconnected }
        isProcessing = true; defer { isProcessing = false }
        guard !disposed else { throw FieldPickerConnectionError.disconnected }
        guard let host else { let error = FieldPickerConnectionError.disconnected; fail(error); throw error }
        do {
            view.setPresentationAllowed(false)
            let input = try host.fieldPickerInput()
            guard !disposed else { return }
            let state = FieldFleetPicker(catalogue: input.catalogue, savedValue: input.savedValue)
            // Prepare retryable controls, but do not expose them before the host accepts the open.
            view.update(catalogue: input.catalogue, locale: locale, restoring: state)
            try host.setFieldPickerExpanded(state.expanded)
            guard !disposed else { return }
            try host.applyEnlargedField(input.catalogue.projection.selecting(publicIDs: state.selectedIDs(in: input.catalogue)),
                                       focusedPublicID: state.effectiveFocus(in: input.catalogue))
            guard !disposed else { return }
            view.setPresentationAllowed(true); lastError = nil; recoveryError = nil
        } catch { fail(error); throw error }
    }
    private func apply(_ change: FieldPickerChange) {
        guard !isProcessing else { return }
        isProcessing = true; defer { isProcessing = false }
        guard !disposed, view.isPresented else { return }
        guard let host else { fail(FieldPickerConnectionError.disconnected); return }
        do {
            if change.kind == .presentation { try host.setFieldPickerExpanded(change.expanded) }
            else {
                try host.applyEnlargedField(change.projection, focusedPublicID: change.focusedPublicID)
            }
            guard !disposed else { return }
            if let saved = change.savedValue { try host.saveFieldPickerValue(saved) }
            lastError = nil; recoveryError = nil
        } catch { fail(error) }
    }
    public func close() throws {
        guard !isProcessing else { throw FieldPickerConnectionError.disconnected }
        isProcessing = true; defer { isProcessing = false }
        guard !disposed else { throw FieldPickerConnectionError.disconnected }
        guard let host else { let error = FieldPickerConnectionError.disconnected; fail(error); throw error }
        do {
            try host.closeEnlargedFieldAndRestoreCurrentScopeStill()
            guard !disposed else { return }
            try host.setFieldPickerExpanded(false)
            guard !disposed else { return }
            view.setPresentationAllowed(false); lastError = nil; recoveryError = nil
        } catch {
            // A failed close is not a successful abandonment: leave controls available for retry.
            lastError = error; recoveryError = error; onFailure?(error); throw error
        }
    }
    private func fail(_ error: Error) {
        guard !disposed else { return }
        lastError = error; recoveryError = nil
        if let host {
            do {
                try host.closeEnlargedFieldAndRestoreCurrentScopeStill()
                guard !disposed else { return }
                try host.setFieldPickerExpanded(false)
                guard !disposed else { return }
                view.setPresentationAllowed(false)
            } catch {
                recoveryError = error
                // Hiding only the controls would strand a partially active host session.
                if !disposed { view.setPresentationAllowed(true) }
            }
        } else { view.setPresentationAllowed(false) }
        if !disposed { onFailure?(error) }
    }
    public func dispose() {
        guard !disposed else { return }; disposed = true
        view.dispose(); host = nil; onFailure = nil
    }
}

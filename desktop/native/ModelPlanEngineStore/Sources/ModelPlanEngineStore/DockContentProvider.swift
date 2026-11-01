// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire
import ModelPlanEngineClient

public enum DockContentStatus: Sendable, Equatable { case loading, ready, empty, failed, cleared }
public struct DockContentSnapshot: Sendable {
    public let status: DockContentStatus
    public let dockRows: [RowsRow]
    public let menuRows: [RowsRow]
    public let summary: RowsRowsSummary?
}
/// Presentation fanout over the native store's already-admitted rows, never a protocol reducer.
@MainActor public final class EngineDockMenuProvider: EngineStoreSink {
    public private(set) var dockContent = DockContentSnapshot(status: .loading, dockRows: [], menuRows: [], summary: nil)
    public var dockContentDidChange: (() -> Void)?
    #if MODELPLAN_U6_DRIVE
    public var verificationWillClear: ((EngineInvalidation) -> Void)?
    #endif
    private let store: EngineStore
    private var attachment: UUID?
    public init(store: EngineStore) { self.store = store; attachment = store.attach(self) }
    public func clearPrivateViews(_ invalidation: EngineInvalidation) {
        #if MODELPLAN_U6_DRIVE
        verificationWillClear?(invalidation)
        #endif
        dockContent = .init(status: .cleared, dockRows: [], menuRows: [], summary: nil)
        dockContentDidChange?()
    }
    public func apply(_ snapshot: EngineStoreSnapshot) {
        let rows = snapshot.rows?.projection
        let failed: Bool
        switch snapshot.connection {
        case .stopped, .restarting: failed = true
        default: failed = snapshot.failures.contains { $0.feature == .rows }
        }
        let status: DockContentStatus
        if failed { status = .failed }
        else if let rows { status = rows.rows.isEmpty ? .empty : .ready }
        else {
            switch snapshot.connection {
            case .starting: status = .loading
            default: status = dockContent.status == .cleared ? .cleared : .loading
            }
        }
        dockContent = .init(status: status,
                            dockRows: rows?.rows.filter { $0.surfaces.contains(.dock) } ?? [],
                            menuRows: rows?.rows.filter { $0.surfaces.contains(.menu) } ?? [],
                            summary: rows?.rowsSummary)
        dockContentDidChange?()
    }
}

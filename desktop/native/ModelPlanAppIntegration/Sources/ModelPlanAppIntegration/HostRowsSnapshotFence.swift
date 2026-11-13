// SPDX-License-Identifier: MIT
import CryptoKit
import Foundation
import ModelPlanEngineClient
import ModelPlanEngineStore
import ModelPlanWire

/// An in-memory identity for one admitted rows delivery, including reset events.
/// Neither the fingerprint nor the source rows is emitted to logs or disk.
@MainActor enum HostRowsSnapshotFence {
    struct Capture {
        let delivery: EngineDeliveryContext
        let sequence: UInt64
        let generation: UInt64
        let fingerprint: SHA256.Digest
        let resetEvents: EngineRowsEventState
    }

    enum Failure: Error { case notAdmitted, inconsistentProjection, changed }

    static func capture(snapshot: EngineStoreSnapshot, projection: DockContentSnapshot,
                        generation: UInt64, isCurrent: (EngineDeliveryContext) -> Bool) throws -> Capture {
        guard case .ready(let context) = snapshot.connection,
              snapshot.delivery == context, isCurrent(context),
              let rows = snapshot.rows,
              !snapshot.failures.contains(where: { $0.feature == .rows }),
              projection.status == (rows.projection.rows.isEmpty ? .empty : .ready) else {
            throw Failure.notAdmitted
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard try encoder.encode(projection.dockRows) == encoder.encode(rows.projection.rows.filter { $0.surfaces.contains(.dock) }),
              try encoder.encode(projection.menuRows) == encoder.encode(rows.projection.rows.filter { $0.surfaces.contains(.menu) }),
              try encoder.encode(projection.summary) == encoder.encode(Optional(rows.projection.rowsSummary)) else {
            throw Failure.inconsistentProjection
        }
        let bytes = try encoder.encode(rows)
        guard isCurrent(context) else { throw Failure.changed }
        return Capture(delivery: context, sequence: rows.sequence, generation: generation,
                       fingerprint: SHA256.hash(data: bytes), resetEvents: EngineRowsEventDecoder.decode(rows))
    }

    static func check(_ original: Capture, snapshot: EngineStoreSnapshot, projection: DockContentSnapshot,
                      generation: UInt64, isCurrent: (EngineDeliveryContext) -> Bool) throws {
        let current = try capture(snapshot: snapshot, projection: projection, generation: generation, isCurrent: isCurrent)
        guard current.delivery == original.delivery, current.sequence == original.sequence,
              current.generation == original.generation, current.fingerprint == original.fingerprint,
              current.resetEvents == original.resetEvents else { throw Failure.changed }
    }
}

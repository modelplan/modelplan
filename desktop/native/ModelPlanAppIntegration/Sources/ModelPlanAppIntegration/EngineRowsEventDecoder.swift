// SPDX-License-Identifier: MIT
import ModelPlanWire

public enum EngineRowsEventState:Equatable,Sendable {
    /// Current public Rows schema has no announced-reset field. No inferred event,
    /// account fetch, popup, dot or notification can be produced from quota changes.
    case absentFromSchema
}

/// Replace this boundary only against the published CLI/wire draft. Unknown JSON
/// fields are not an event contract and the existing typed decoder ignores them.
public enum EngineRowsEventDecoder {
    public static func decode(_ rows:WireRowsSnapshot?) -> EngineRowsEventState { .absentFromSchema }
}

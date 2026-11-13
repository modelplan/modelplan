// SPDX-License-Identifier: MIT
#if MODELPLAN_U6_DRIVE
import Foundation

/// The App and offline fixture capture use the same envelope serializer. Fixture
/// callers supply clocks and IDs; this type never observes a window or posts input.
enum U6NativeReceiptSerializer {
    static func encode(event: String, fields: [String:Any], runID: String, epoch: String,
                       pid: Int32, seq: UInt64, mono: Double, at: Double) throws -> Data {
        let base: [String:Any] = ["runID":runID,"epoch":epoch,"pid":pid,"seq":seq,"mono":mono,"at":at]
        let object: [String:Any] = event == "refresh"
            ? fields.merging(base) { _, bound in bound }
            : base.merging(["event":event,"timestamp":at,"checks":fields]) { _, added in added }
        return try JSONSerialization.data(withJSONObject:object,options:[.sortedKeys]) + Data([10])
    }
}
#endif

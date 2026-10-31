// SPDX-License-Identifier: MIT
#if MODELPLAN_U6_DRIVE
import Foundation
import CryptoKit
import ModelPlanWire

enum U6ReadingFingerprint {
    enum Failure: Error { case accountCount, invalidTimestamp }
    static func sha256(_ accounts: [RowsAccount]) throws -> String {
        guard accounts.count == 1, let account=accounts.first else { throw Failure.accountCount }
        let windows: [[String:Any]] = try account.windows.sorted { $0.id < $1.id }.map { window in
            var reset: Any = NSNull()
            if let value=window.resetsAt {
                let plain=ISO8601DateFormatter()
                let fractional=ISO8601DateFormatter();fractional.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
                guard let date=plain.date(from:value.rawValue) ?? fractional.date(from:value.rawValue) else { throw Failure.invalidTimestamp }
                reset=Int64(date.timeIntervalSince1970)
            }
            return ["id":window.id,"limitKey":window.limitKey,"poolKey":window.poolKey,
                    "remainingBp":window.remainingPercent.map { Int64(($0*100).rounded()) } as Any? ?? NSNull(),"resetsAt":reset]
        }
        let value: [String:Any] = ["route":account.route.rawValue,"plan":account.plan.id,"windows":windows]
        let data=try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys,.withoutEscapingSlashes])
        return SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()
    }
}
#endif

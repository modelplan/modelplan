// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanWire
import ModelPlanSettings

/// The App identity unit shared by Dock and Settings. Keys are never display copy.
public struct EngineAccountMember:Sendable {
    public let id:String
    public let rowID:String
    public let source:String
    public let subscriptionRef:String?
    public let duplicateTag:Int?
    public let row:RowsRow
    public let account:RowsAccount
    func name(english:Bool) -> String {
        let base=english ? row.name.en:row.name.zh
        guard let duplicateTag else { return base }
        return base + (english ? " · Account ":" · 账户 ") + String(duplicateTag)
    }
}

public struct EngineAccountMemberCatalogue:Sendable {
    public let members:[EngineAccountMember]
    /// A collision cannot acquire an ordinal/hash identity or duplicate a source total.
    public let ambiguousKeys:Set<String>
    public let memberKeysByRow:[String:[String]]
    public init(rows:[RowsRow]) {
        let candidates=rows.flatMap { row in row.accounts.enumerated().map { index,account in
            EngineAccountMember(id:account.subscriptionRef ?? row.id+"#"+account.route.rawValue,
                rowID:row.id,source:account.route.rawValue,subscriptionRef:account.subscriptionRef,
                duplicateTag:row.accounts.count > 1 ? index+1:nil,row:row,account:account)
        } }
        let grouped=Dictionary(grouping:candidates,by:\.id)
        memberKeysByRow=Dictionary(grouping:candidates,by:\.rowID).mapValues{$0.map(\.id)}
        ambiguousKeys=Set(grouped.filter{$0.value.count != 1}.keys)
        members=candidates.filter{grouped[$0.id]?.count == 1}
    }
    /// Pure migration for the one shared Settings writer to commit. Explicit member choices win.
    /// Ambiguous row choices are dropped rather than copied to every member.
    public func migratingRowPreferences(_ preferences:SettingsPreferences) -> SettingsPreferences {
        var result=preferences
        for (row,keys) in memberKeysByRow where !keys.contains(row) {
            let target=keys.count == 1 && !ambiguousKeys.contains(keys[0]) ? keys[0]:nil
            if let old=result.subscriptionSettings.removeValue(forKey:row),let target,result.subscriptionSettings[target] == nil {
                result.subscriptionSettings[target]=old
            }
            let hidden=result.subscriptions.hiddenIDs.remove(row) != nil
            if hidden,let target { result.subscriptions.hiddenIDs.insert(target) }
            let order=result.subscriptions.order.compactMap { $0 == row ? target:$0 }
            var seen=Set<String>()
            result.subscriptions = .init(order:order.filter{seen.insert($0).inserted},hiddenIDs:result.subscriptions.hiddenIDs)
        }
        return result
    }
}

// SPDX-License-Identifier: MIT
import Foundation

/// Host-supplied membership knowledge, independent of reading freshness, consent and model eligibility.
/// Neither an empty collection nor a populated collection supplies this verdict implicitly.
public enum InstrumentMembershipKnowledge: Equatable, Sendable {
    case unknown, unavailable, reported

    func emptyLabel(language: InstrumentLanguage) -> String {
        let label: String
        switch (self, language) {
        case (.unknown, .chinese): label = "订阅数据尚未加载"
        case (.unknown, .english): label = "Subscription data not loaded"
        case (.unavailable, .chinese): label = "订阅数据不可用"
        case (.unavailable, .english): label = "Subscription data unavailable"
        case (.reported, .chinese): label = "已报告的订阅绑定为空"
        case (.reported, .english): label = "No reported subscription bindings"
        }
        return label + " · modelplan doctor"
    }
}

// SPDX-License-Identifier: MIT
import ModelPlanInstruments

/// Which explanation a hovered or focused Quota Widget element shows (G3-10, S-07).
/// The copy comes from the shared Help catalogue; nothing here invents facts.
enum DockHoverExplanation {
    static func explanation(anchorID: String, language: InstrumentLanguage, refreshAvailable: Bool) -> HelpExplanation? {
        let catalog = HelpCatalog(language)
        let topic: HelpTopic
        if anchorID.hasPrefix("dock.rings.") { topic = .ring }
        else if anchorID.hasPrefix("dock.nozzle.") {
            guard refreshAvailable else {
                // Only promise a refresh click when the engine negotiated member refresh.
                let base = catalog.explanation(.nozzle)
                return HelpExplanation(title: base.title, body: language == .chinese
                    ? "悬停查看额度卡片，拖动喷口可移动整个额度挂件；也可用 ⌥ 加方向键移动一位。"
                    : "Hover for the quota card or drag to move the whole Quota Widget; Option arrows move one place.")
            }
            topic = .nozzle
        }
        else if anchorID.hasPrefix("dock.number.") { topic = .dockQuota }
        else if anchorID.hasPrefix("dock.notice.") { topic = .event }
        else if anchorID.hasPrefix("dock.grip.") || anchorID == "dock.move" { topic = .dockMove }
        else if anchorID == "dock.ignition" { topic = .ignition }
        else { return nil }
        return catalog.explanation(topic)
    }
}

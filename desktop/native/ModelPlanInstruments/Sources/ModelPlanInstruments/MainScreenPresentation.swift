// SPDX-License-Identifier: MIT
import Foundation

public enum MainScreenFooterDisplay: Equatable, Sendable {
    case blank
    case option(MainScreenFooterOption)
    case back(String)
    case fast(modelID: String, title: String, off: String, on: String, selected: Bool, help: HelpExplanation)
}
public struct MainScreenPageKeyDisplay: Equatable, Sendable {
    public let page: MainScreenPage, title: String
    public let lit: Bool
}
public struct MainScreenPresentation: Equatable, Sendable {
    public let language: InstrumentLanguage
    public let compact: Bool
    public let pageKeys: [MainScreenPageKeyDisplay]
    public let displayedPage: MainScreenPage
    public let titleVariants: [String]
    public let lines: [String]
    public let backLine: String?
    public let footer: [MainScreenFooterDisplay]
    public let comparison: ComparisonPresentation?
    public let source: MainScreenSource?
    public let sourceModelID: String?
    public let pageHelp: HelpExplanation
    public let returnHelp: HelpExplanation
    public init(controller: MainScreenController, language: InstrumentLanguage, compact: Bool) {
        self.language = language; self.compact = compact
        let nav = controller.navigation, chinese = language == .chinese
        source = nav.sourced?.source; sourceModelID = controller.sourceModelID
        displayedPage = nav.location.page
        pageKeys = MainScreenPage.allCases.map { .init(page: $0, title: $0.title(language), lit: nav.highlightedPage == $0) }
        pageHelp = HelpCatalog(language).explanation(.screen)
        let returnPage = nav.sourced?.returnTo.page ?? nav.location.page
        let back = (chinese ? "‹ 返回 " : "‹ ") + returnPage.title(language)
        returnHelp = HelpCatalog(language).explanation(.screen, context: .init(fact: chinese ? "返回" + returnPage.title(language) + "（Esc）" : "Back to " + returnPage.title(language) + " (Esc)"))
        if let trial = controller.trial, let input = controller.input(trial.modelID) {
            let compare = ComparisonPresentation(model: input.model, nameVariants: input.nameVariants,
                trial: trial.configuration, publicationUsable: controller.publicationUsable, language: language)
            comparison = compare; titleVariants = compare.titleVariants; lines = compare.notes; backLine = nil
            footer = [.back(back), compare.fastAvailable
                ? .fast(modelID: input.model.id, title: chinese ? "快速" : "Fast", off: chinese ? "关" : "off", on: chinese ? "开" : "on",
                        selected: compare.trialFast, help: HelpCatalog(language).explanation(.comparison, context: .init(fact: compare.notes.joined(separator: " · "))))
                : .blank]
        } else {
            comparison = nil
            let payload = nav.sourced.flatMap { view in controller.sourcedBodies.first { $0.content == view.content } }
            let page = controller.pages.first { $0.page == nav.location.page }
            if let payload {
                titleVariants = payload.titleVariants; lines = payload.lines
            } else if let content = nav.sourced?.content {
                switch content {
                case .session: titleVariants = [chinese ? "会话" : "Session"]
                case .alerts: titleVariants = [chinese ? "提醒" : "Alerts"]
                case .page: titleVariants = [nav.location.page.title(language)]
                case .comparison: titleVariants = [chinese ? "比较" : "Compare"]
                }
                if case .page = content { lines = page?.lines ?? [] } else { lines = [] }
            } else {
                titleVariants = [nav.location.page.title(language)]; lines = page?.lines ?? []
            }
            backLine = nav.sourced == nil ? nil : back
            var slots: [MainScreenFooterDisplay] = []
            let pageOptionsAllowed: Bool
            if let content = nav.sourced?.content {
                if case .page = content { pageOptionsAllowed = true } else { pageOptionsAllowed = false }
            } else { pageOptionsAllowed = true }
            for i in 0..<3 {
                if pageOptionsAllowed, let option = page?.options, i < option.count, let value = option[i] {
                    slots.append(.option(controller.option(value, page: nav.location.page)))
                } else { slots.append(.blank) }
            }
            footer = slots
        }
    }
}

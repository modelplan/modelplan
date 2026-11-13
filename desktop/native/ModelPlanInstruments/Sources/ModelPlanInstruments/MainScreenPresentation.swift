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
    public var websiteLinks:[InstrumentWebsiteLink] {comparison?.websiteLinks ?? effort?.links ?? []}
    public let language: InstrumentLanguage
    public let compact: Bool
    public let pageKeys: [MainScreenPageKeyDisplay]
    public let displayedPage: MainScreenPage
    public let titleVariants: [String]
    public let lines: [String]
    public let backLine: String?
    public let footer: [MainScreenFooterDisplay]
    public let effort:EffortPageSnapshot?,destinations:DestinationsPageDisplay?,session:DestinationSessionDisplay?
    public let history:SubscriptionHistoryDisplay?
    public let subscription: SubscriptionNowDisplay?
    public let overview: OverviewPageDisplay?
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
            effort=nil;destinations=nil;session=nil;history=nil; subscription = nil; overview = nil; comparison = compare; titleVariants = compare.titleVariants; lines = compare.notes; backLine = nil
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
                if pageOptionsAllowed,page?.subscription.map({$0.language == language}) ?? true, let option = page?.options, i < option.count, let value = option[i] {
                    slots.append(.option(controller.option(value, page: nav.location.page)))
                } else { slots.append(.blank) }
            }
            if pageOptionsAllowed, payload == nil, nav.location.page == .overview, let snapshot = page?.overview {
                func selected(_ id: String) -> String? {
                    page?.options.compactMap { $0 }.first { $0.id == id }.flatMap { controller.option($0, page: .overview).selectedValue }
                }
                overview = snapshot.display(rangeKey: selected("overview.range"), modeKey: selected("overview.mode"), language: language,visualizationKey:selected("overview.chart"))
                if overview?.visualization == .heatmap { slots[1] = .blank; slots[2] = .blank }
            } else { overview = nil }
            if pageOptionsAllowed,payload == nil,nav.location.page == .subscriptions,let snapshot=page?.subscription,snapshot.language == language {
                func selected(_ id:String)->String? {page?.options.compactMap{$0}.first{$0.id == id}.flatMap{controller.option($0,page:.subscriptions).selectedValue}}
                if selected("subscription.tab") == "history",let data=page?.history,data.language == language {
                    history=data.display(windowKey:selected("subscription.cycle"));subscription=nil
                    slots[1]=data.cycleOption().map{.option(controller.option($0,page:.subscriptions))} ?? .blank
                } else {
                    history=nil;subscription=snapshot.display(daysKey:selected("subscription.usage"))
                }
                slots[2] = .blank
            } else {subscription=nil;history=nil}
            if pageOptionsAllowed,payload == nil,nav.location.page == .effort,let data=page?.effort,data.language == language,
               data.matches(controller.selection,publication:controller.publication,usable:controller.publicationUsable) {effort=data.selecting(nav.selectedModelID)} else{effort=nil}
            if pageOptionsAllowed,payload == nil,nav.location.page == .destinations,let data=page?.destinations,data.language == language {
                destinations=data.display(location:nav.location)
                func option(_ id:String,_ selected:String)->MainScreenFooterDisplay {
                    guard let o=page?.options.compactMap({$0}).first(where:{$0.id==id}) else{return .blank}
                    return .option(.init(id:o.id,choices:o.choices,selectedValue:selected,help:o.help))
                }
                slots[0]=option("destinations.mode",nav.location.destinationsMode == .projects ? "proj":"time")
                slots[1]=nav.location.destinationsMode == .projects ? option("destinations.days",nav.location.projectPeriod == .days7 ? "7":"30"):
                    option("destinations.time",nav.location.timelineRange == .today ? "today":"7d")
                slots[2] = .blank
            } else{destinations=nil}
            if payload == nil,let content=nav.sourced?.content,case .session(let id)=content,let data=controller.pages.first(where:{$0.page == .destinations})?.destinations,
               data.scope==nav.scope,data.language==language {
                let matches=data.details.filter{$0.id==id};session=matches.count==1 ? matches[0]:nil
            } else{session=nil}
            footer = slots
        }
    }
}

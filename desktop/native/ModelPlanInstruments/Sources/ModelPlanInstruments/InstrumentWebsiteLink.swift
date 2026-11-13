// SPDX-License-Identifier: MIT
import Foundation

/// User-activated public links. The host owns opening; no personal query data or network work is owned here.
public struct InstrumentWebsiteLink:Equatable,Sendable {
    public let title:String,url:String
    public let target:String,rel:String
    private init(title:String,url:String) {self.title=title;self.url=url;target="_blank";rel="noopener noreferrer"}
    public static func compare(publicModelID:String,language:InstrumentLanguage)->Self {
        let safe=CharacterSet(charactersIn:"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789*-._")
        let encoded=publicModelID.utf8.map { byte -> String in
            if byte==32{return "+"}
            let scalar=UnicodeScalar(Int(byte))!
            return safe.contains(scalar) ? String(scalar):String(format:"%%%02X",byte)
        }.joined()
        return .init(title:(language == .chinese ? "在网站上对比":"Compare on the website")+" ↗",url:"https://modelplan.ai/effort?model="+encoded)
    }
    public static func methodology(comparison:Bool,language:InstrumentLanguage)->Self {
        .init(title:(language == .chinese ? "怎么算的":"How it's worked out")+" ↗",url:"https://modelplan.ai/methodology#"+(comparison ? "cost-basis":"effort-ladder"))
    }
    public static func sourceAbout(language:InstrumentLanguage)->Self {
        .init(title:(language == .chinese ? "说明":"About")+" ↗",url:"https://modelplan.ai/methodology#cost-basis")
    }
    public static func dataSource(language:InstrumentLanguage)->Self {
        .init(title:(language == .chinese ? "数据怎么来的":"Where the data comes from")+" ↗",url:"https://modelplan.ai/methodology")
    }
}
/// Inject this into the host-owned Option source corner; it consumes no chart height.
public struct InstrumentPublicationSource:Equatable,Sendable {
    public let publishedAt:Date?
    public let age:String
    public let links:[InstrumentWebsiteLink]
    public init(publishedAt:Date?,now:Date,language:InstrumentLanguage) {
        let value=publishedAt.flatMap{$0.timeIntervalSinceReferenceDate.isFinite ? $0:nil}
        self.publishedAt=value;age=InstrumentFormat(language).age(value,now:now)
        links=[.sourceAbout(language:language),.dataSource(language:language)]
    }
}

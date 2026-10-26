// SPDX-License-Identifier: MIT
import AppKit

public enum RecordStripDensity: Sendable { case full, compact }
public struct RecordStripAppearance: Sendable {
    public let dark: Bool, scale: Int, language: InstrumentLanguage, reduceMotion: Bool
    public init(dark:Bool = true,scale:Int = 2,language:InstrumentLanguage = .english,reduceMotion:Bool = false) {
        self.dark = dark;self.scale = scale;self.language = language;self.reduceMotion = reduceMotion
    }
}
/// Display labels/brand ink only; eligibility, attribution, rates and privacy remain P03/Core owned.
public struct RecordStripIdentity: Sendable {
    public let fullToolName: String?, shortModelName: String?, fullModelName: String?
    public let vendorInk: EngineInk?
    public init(fullToolName:String? = nil,shortModelName:String? = nil,fullModelName:String? = nil,vendorInk:EngineInk? = nil) {
        self.fullToolName = fullToolName;self.shortModelName = shortModelName;self.fullModelName = fullModelName;self.vendorInk = vendorInk
    }
}
/// No cadence is invented here. A later exact cursor handoff can replace this narrow input.
public struct RecordStripCursor: Sendable {
    public let recordID: String, rect: CGRect, visible: Bool
    public init(recordID:String,rect:CGRect,visible:Bool) { self.recordID = recordID;self.rect = rect;self.visible = visible }
}
public struct RecordStripViewInput: Sendable {
    public let presentation: RecordStripPresentation, density: RecordStripDensity, appearance: RecordStripAppearance
    public let identities: [String:RecordStripIdentity]
    public let selectedID: String?, overflowSelected: Bool, cursor: RecordStripCursor?
    public init(presentation:RecordStripPresentation,density:RecordStripDensity,appearance:RecordStripAppearance,
                identities:[String:RecordStripIdentity] = [:],selectedID:String? = nil,overflowSelected:Bool = false,cursor:RecordStripCursor? = nil) {
        self.presentation = presentation;self.density = density;self.appearance = appearance;self.identities = identities
        self.selectedID = selectedID;self.overflowSelected = overflowSelected;self.cursor = cursor
    }
}
public enum RecordStripField: String, CaseIterable, Sendable { case chip, tool, model, effort, project, speed, age }
public struct RecordStripRowLayout: Sendable {
    public let id: String?, frame: CGRect, fields: [RecordStripField:CGRect]
    public init(id:String?,frame:CGRect,fields:[RecordStripField:CGRect]) { self.id = id;self.frame = frame;self.fields = fields }
}
public struct RecordStripRecipe: Sendable {
    public let drawing: EngineTableRecipe, rows: [RecordStripRowLayout], more: CGRect?, cursorInk: EngineInk
    public init(drawing:EngineTableRecipe,rows:[RecordStripRowLayout],more:CGRect?,cursorInk:EngineInk = .init(1,1,1)) {
        self.drawing = drawing;self.rows = rows;self.more = more;self.cursorInk = cursorInk
    }
    public func validate() throws {
        try drawing.validate()
        let root = CGRect(origin:.zero,size:drawing.size)
        guard rows.count<=5,cursorInk.valid,Set(rows.compactMap(\.id)).count==rows.compactMap(\.id).count else { throw EngineTableError.invalidRecipe }
        for row in rows {
            guard !row.frame.isNull,!row.frame.isInfinite,row.frame.width>0,row.frame.height>0,root.contains(row.frame),
                  Set(row.fields.keys)==Set(RecordStripField.allCases) else { throw EngineTableError.invalidRecipe }
            for rect in row.fields.values {
                guard !rect.isNull,!rect.isInfinite,rect.width>0,rect.height>0,row.frame.contains(rect) else { throw EngineTableError.invalidRecipe }
            }
        }
        if let more { guard !more.isNull,!more.isInfinite,more.width>0,more.height>0,root.contains(more) else { throw EngineTableError.invalidRecipe } }
    }
}
@MainActor public protocol RecordStripRecipeProvider: InstrumentDrawingResources {
    func preferredSize(for density:RecordStripDensity)->CGSize
    func recipe(for input:RecordStripViewInput,size:CGSize,hoveredID:String?) throws -> RecordStripRecipe
}
public struct RecordStripRowText: Sendable {
    public let tool:String,model:String,effort:String,project:String,speed:String,age:String,accessibility:String
    public init(line:RecordLine,identity:RecordStripIdentity?,language:InstrumentLanguage) {
        let zh = language == .chinese
        tool = line.tool;model = identity?.shortModelName ?? line.model;effort = line.effort ?? "--"
        project = line.projectName ?? "--";age = line.age ?? ""
        speed = line.working ? (line.speed60s.map { String(format:"%.0f",locale:Locale(identifier:"en_US_POSIX"),$0) } ?? "--")+" t/s":""
        let activity:String
        switch line.activity { case .working: activity = zh ? "运行中":"Working";case .completed:activity = zh ? "已结束":"Completed";case .unknown:activity = zh ? "状态未知":"Status unknown" }
        let actualEffort = line.effort ?? (zh ? "档位未报告":"Effort not reported")
        let fast = line.fast ? (zh ? "；快速":"; Fast"):""
        let projectText = line.projectName.map { (zh ? "项目 ":"Project ")+$0 } ?? (zh ? "项目不可用":"Project unavailable")
        let speedText = line.working ? (zh ? "近 60 秒生成速度 ":"Last 60 seconds generation speed ")+speed:""
        accessibility = [activity,identity?.fullToolName ?? line.tool,identity?.fullModelName ?? line.model,actualEffort+fast,projectText,speedText,age].filter{!$0.isEmpty}.joined(separator:"; ")
    }
}
public struct RecordStripHelpTarget: Sendable {
    public let id:String,anchor:CGRect,text:String
    public init(id:String,anchor:CGRect,text:String) { self.id = id;self.anchor = anchor;self.text = text }
}

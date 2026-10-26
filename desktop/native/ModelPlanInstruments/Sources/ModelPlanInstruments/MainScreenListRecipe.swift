// SPDX-License-Identifier: MIT
import AppKit

public struct MainScreenListRowRecipe: Equatable, Sendable {
    public let height: Double
    public let commands: [EngineDrawingCommand]
    /// Row-local coordinates; the native scroll document supplies the vertical position.
    public let region: MainScreenHitRegion
    public init(height:Double,commands:[EngineDrawingCommand],region:MainScreenHitRegion) {
        self.height=height;self.commands=commands;self.region=region
    }
}
public struct MainScreenListRecipe: Equatable, Sendable {
    public let identity:String
    public let viewport:CGRect
    public let rows:[MainScreenListRowRecipe]
    public init(identity:String,viewport:CGRect,rows:[MainScreenListRowRecipe]) {self.identity=identity;self.viewport=viewport;self.rows=rows}
    public var contentHeight:Double {rows.reduce(0){$0+$1.height}}
    public var positionedRegions:[MainScreenHitRegion] {
        var y=0.0
        return rows.map { row in
            defer{y+=row.height};let r=row.region
            return .init(id:r.id,rect:r.rect.offsetBy(dx:0,dy:y),action:r.action,label:r.label,help:r.help,role:r.role,
                enabled:r.enabled,tabStop:r.tabStop,value:r.value,focusGroup:r.focusGroup,gridPosition:r.gridPosition)
        }
    }
    func validate(in size:CGSize)throws {
        guard !identity.isEmpty,identity.utf8.count<=1024,rows.count<=256,
            [viewport.minX,viewport.minY,viewport.width,viewport.height].allSatisfy(\.isFinite),viewport.minX>=0,viewport.minY>=0,
            viewport.width>0,viewport.height>0,viewport.maxX<=size.width,viewport.maxY<=size.height,
            Set(rows.map{ $0.region.id }).count==rows.count else{throw EngineTableError.invalidRecipe}
        for row in rows {
            let r=row.region
            guard row.height.isFinite,(16...256).contains(row.height),!r.id.isEmpty,r.label.utf8.count<=8192,
                [r.rect.minX,r.rect.minY,r.rect.width,r.rect.height].allSatisfy(\.isFinite),r.rect.minX>=0,r.rect.minY>=0,
                r.rect.width>0,r.rect.height>0,r.rect.maxX<=viewport.width,r.rect.maxY<=row.height else{throw EngineTableError.invalidRecipe}
            try EngineTableRecipe(size:CGSize(width:viewport.width,height:row.height),commands:row.commands,regions:[]).validate()
        }
    }
}
@MainActor final class MainScreenListDocument:NSView {
    weak var owner:MainScreenView?
    var list:MainScreenListRecipe?
    override var isFlipped:Bool {true}
    init(owner:MainScreenView) {self.owner=owner;super.init(frame:.zero);setAccessibilityElement(false)}
    required init?(coder:NSCoder) {fatalError("init(coder:) is unsupported")}
    override func draw(_ dirtyRect:NSRect) {
        guard let list,let context=NSGraphicsContext.current?.cgContext,let owner else{return}
        do {try drawRows(list,in:context,offset:0,visible:dirtyRect,provider:owner.recipeProvider)}
        catch {owner.listDrawingFailed(error)}
    }
    func drawRows(_ list:MainScreenListRecipe,in context:CGContext,offset:Double,visible:CGRect,provider:any InstrumentDrawingResources)throws {
        var y=0.0
        for row in list.rows {
            let bounds=CGRect(x:0,y:y,width:list.viewport.width,height:row.height)
            if bounds.intersects(visible) {
                context.saveGState();context.translateBy(x:0,y:y-offset)
                defer{context.restoreGState()}
                try EngineRecipeDrawing.draw(.init(size:CGSize(width:list.viewport.width,height:row.height),commands:row.commands,regions:[]),in:context,provider:provider)
            }
            y+=row.height
        }
    }
}

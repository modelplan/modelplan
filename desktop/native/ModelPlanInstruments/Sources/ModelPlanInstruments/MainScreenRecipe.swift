// SPDX-License-Identifier: MIT
import AppKit

public enum MainScreenAction: Equatable, Sendable {
    case inspectEffort(modelID:String,key:String),session(String)
    case website(InstrumentWebsiteLink)
    case subscriptionScope(String)
    case overviewAlerts, overviewInformation(String)
    case page(MainScreenPage), back
    case option(page: MainScreenPage, id: String, value: String?)
    case effort(modelID: String, key: String)
    case fast(modelID: String)
}
public enum MainScreenRegionRole: Sendable { case button, readout, choice }
/// Traversable text/data alternatives; these never add painted layout or actions.
public struct MainScreenAccessibilityDetail: Equatable, Sendable {
    public let id:String,label:String,value:String
    public init(id:String,label:String,value:String) {self.id=id;self.label=label;self.value=value}
}
public struct MainScreenGridPosition: Equatable, Sendable {
    public let column: Int, row: Int
    public init(column: Int, row: Int) { self.column=column; self.row=row }
}
public struct MainScreenHitRegion: Equatable, Sendable {
    public let id: String, label: String
    public let rect: CGRect
    public let action: MainScreenAction?
    public let help: HelpExplanation
    public let role: MainScreenRegionRole
    public let enabled: Bool, tabStop: Bool
    public let gridPosition: MainScreenGridPosition?
    public let focusGroup: String?
    public let value: String?
    public let accessibilityDetails:[MainScreenAccessibilityDetail]
    var validAccessibilityDetails:Bool {
        accessibilityDetails.count<=512 && Set(accessibilityDetails.map(\.id)).count==accessibilityDetails.count &&
        accessibilityDetails.allSatisfy{!$0.id.isEmpty && $0.id.utf8.count<=1024 && $0.label.utf8.count<=16_384 && $0.value.utf8.count<=16_384}
    }
    public init(id: String, rect: CGRect, action: MainScreenAction? = nil, label: String, help: HelpExplanation,
                role: MainScreenRegionRole = .button, enabled: Bool = true, tabStop: Bool = true, value: String? = nil, focusGroup: String? = nil, gridPosition: MainScreenGridPosition? = nil, accessibilityDetails:[MainScreenAccessibilityDetail] = []) {
        self.id = id; self.rect = rect; self.action = action; self.label = label; self.help = help
        self.role = role; self.enabled = enabled; self.tabStop = tabStop; self.value = value; self.focusGroup = focusGroup; self.gridPosition = gridPosition
        self.accessibilityDetails=accessibilityDetails
    }
}
public struct MainScreenRecipe: Equatable, Sendable {
    public let size: CGSize
    public let commands: [EngineDrawingCommand]
    public let regions: [MainScreenHitRegion]
    public let chart: ComparisonChartGeometry?
    public let list: MainScreenListRecipe?
    public let focusInk: EngineInk?
    public init(size: CGSize, commands: [EngineDrawingCommand], regions: [MainScreenHitRegion],
                chart: ComparisonChartGeometry? = nil, focusInk: EngineInk? = nil, list: MainScreenListRecipe? = nil) {
        self.size = size; self.commands = commands; self.regions = regions; self.chart = chart; self.focusInk = focusInk; self.list = list
    }
    public func validate() throws {
        try EngineTableRecipe(size: size, commands: commands, regions: [], focusInk: focusInk).validate()
        guard regions.count <= 512, Set(regions.map(\.id)).count == regions.count else { throw EngineTableError.invalidRecipe }
        guard (list?.rows.count ?? 0)<=256,
              regions.reduce(0,{$0+$1.accessibilityDetails.count})+(list?.rows.reduce(0,{$0+$1.region.accessibilityDetails.count}) ?? 0)<=512 else {throw EngineTableError.invalidRecipe}
        for r in regions {
            guard r.validAccessibilityDetails else {throw EngineTableError.invalidRecipe}
            if let position=r.gridPosition {
                guard r.focusGroup != nil,(0...4096).contains(position.column),(0...4096).contains(position.row) else {throw EngineTableError.invalidRecipe}
            }
            guard !r.id.isEmpty, r.label.utf8.count <= 4096,
                  [r.rect.minX, r.rect.minY, r.rect.width, r.rect.height].allSatisfy(\.isFinite),
                  r.rect.minX >= 0, r.rect.minY >= 0, r.rect.width > 0, r.rect.height > 0,
                  r.rect.maxX <= size.width + 0.5, r.rect.maxY <= size.height + 0.5 else { throw EngineTableError.invalidRecipe }
        }
        if let list {
            try list.validate(in:size)
            guard regions.count+list.rows.count<=512, Set(regions.map(\.id)).isDisjoint(with:list.rows.map{$0.region.id}) else{throw EngineTableError.invalidRecipe}
        }
        if let chart {
            guard chart.axis.maximum.isFinite, chart.axis.maximum >= 1, chart.axis.ticks.contains(1),
                  chart.profiles.flatMap(\.points).compactMap({ $0 }).allSatisfy({
                    $0.point.x.isFinite && $0.point.y.isFinite && $0.ratio.isFinite && $0.ratio >= 0
                  }) else { throw EngineTableError.invalidRecipe }
        }
    }
}
@MainActor public protocol MainScreenRecipeProvider: InstrumentDrawingResources {
    func minimumSize(for presentation: MainScreenPresentation) -> CGSize
    func recipe(for presentation: MainScreenPresentation, size: CGSize) throws -> MainScreenRecipe
}

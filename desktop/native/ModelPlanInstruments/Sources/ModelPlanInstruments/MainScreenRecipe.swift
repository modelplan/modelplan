// SPDX-License-Identifier: MIT
import AppKit

public enum MainScreenAction: Equatable, Sendable {
    case overviewAlerts, overviewInformation(String)
    case page(MainScreenPage), back
    case option(page: MainScreenPage, id: String, value: String?)
    case effort(modelID: String, key: String)
    case fast(modelID: String)
}
public enum MainScreenRegionRole: Sendable { case button, readout, choice }
public struct MainScreenHitRegion: Equatable, Sendable {
    public let id: String, label: String
    public let rect: CGRect
    public let action: MainScreenAction?
    public let help: HelpExplanation
    public let role: MainScreenRegionRole
    public let enabled: Bool, tabStop: Bool
    public let focusGroup: String?
    public let value: String?
    public init(id: String, rect: CGRect, action: MainScreenAction? = nil, label: String, help: HelpExplanation,
                role: MainScreenRegionRole = .button, enabled: Bool = true, tabStop: Bool = true, value: String? = nil, focusGroup: String? = nil) {
        self.id = id; self.rect = rect; self.action = action; self.label = label; self.help = help
        self.role = role; self.enabled = enabled; self.tabStop = tabStop; self.value = value; self.focusGroup = focusGroup
    }
}
public struct MainScreenRecipe: Equatable, Sendable {
    public let size: CGSize
    public let commands: [EngineDrawingCommand]
    public let regions: [MainScreenHitRegion]
    public let chart: ComparisonChartGeometry?
    public let focusInk: EngineInk?
    public init(size: CGSize, commands: [EngineDrawingCommand], regions: [MainScreenHitRegion],
                chart: ComparisonChartGeometry? = nil, focusInk: EngineInk? = nil) {
        self.size = size; self.commands = commands; self.regions = regions; self.chart = chart; self.focusInk = focusInk
    }
    public func validate() throws {
        try EngineTableRecipe(size: size, commands: commands, regions: [], focusInk: focusInk).validate()
        guard regions.count <= 512, Set(regions.map(\.id)).count == regions.count else { throw EngineTableError.invalidRecipe }
        for r in regions {
            guard !r.id.isEmpty, r.label.utf8.count <= 4096,
                  [r.rect.minX, r.rect.minY, r.rect.width, r.rect.height].allSatisfy(\.isFinite),
                  r.rect.minX >= 0, r.rect.minY >= 0, r.rect.width > 0, r.rect.height > 0,
                  r.rect.maxX <= size.width + 0.5, r.rect.maxY <= size.height + 0.5 else { throw EngineTableError.invalidRecipe }
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

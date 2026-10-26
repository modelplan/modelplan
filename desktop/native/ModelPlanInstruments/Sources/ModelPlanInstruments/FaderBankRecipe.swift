// SPDX-License-Identifier: MIT
import AppKit

public enum FaderRegionAction: Equatable, Sendable {
    case lcd(String), travel(String), effort(String, String), bank(Int)
}
public enum FaderRegionRole: Sendable { case button, slider, readout }
public struct FaderDetent: Equatable, Sendable {
    public let key: String
    public let position: Double
    public init(key: String, position: Double) { self.key = key; self.position = position }
}
/// A trusted injected provider may declare an approved denser native tick floor.
/// This does not approve a label arrangement or change the ordinary 20 pt default.
public enum FaderNativeTickPolicy: Equatable, Sendable {
    case standard
    case approvedDense(minimumSpacing: Double)
    fileprivate func minimumSpacing() throws -> Double {
        switch self {
        case .standard: return 20
        case .approvedDense(let minimum):
            guard minimum.isFinite, (12...20).contains(minimum) else { throw EngineTableError.invalidRecipe }
            return minimum
        }
    }
}
public struct FaderHitRegion: Equatable, Sendable {
    public let id: String
    public let rect: CGRect
    public let role: FaderRegionRole
    public let action: FaderRegionAction?
    public let label: String
    public let help: HelpExplanation
    public let tabStop: Bool
    public let enabled: Bool
    public let modelID: String?
    public let levelCount: Int
    public let shownIndex: Int?
    /// Pointer-normalization anchors inside a slider's parent-coordinate frame.
    public let top: Double?, bottom: Double?
    public let detents: [FaderDetent]
    public let nativeTickPolicy: FaderNativeTickPolicy
    /// Nil means every native detent is labelled; an explicit list declares a subset.
    /// Labelled positions retain their independent 20 pt minimum.
    public let labelledDetentKeys: [String]?
    public init(id: String, rect: CGRect, role: FaderRegionRole = .button, action: FaderRegionAction? = nil,
                label: String, help: HelpExplanation, tabStop: Bool = true, enabled: Bool = true,
                modelID: String? = nil, levelCount: Int = 0, shownIndex: Int? = nil, top: Double? = nil, bottom: Double? = nil,
                detents: [FaderDetent] = [], nativeTickPolicy: FaderNativeTickPolicy = .standard,
                labelledDetentKeys: [String]? = nil) {
        self.id = id; self.rect = rect; self.role = role; self.action = action; self.label = label; self.help = help
        self.tabStop = tabStop; self.enabled = enabled; self.modelID = modelID; self.levelCount = levelCount
        self.shownIndex = shownIndex; self.top = top; self.bottom = bottom
        self.detents = detents; self.nativeTickPolicy = nativeTickPolicy; self.labelledDetentKeys = labelledDetentKeys
    }
}
public enum FaderCapKind: Sendable { case real, ghost, preview }
public struct FaderCapSurface: Equatable, Sendable {
    /// Stable slot identity permits motorized movement when a different model occupies a slot.
    public let id: String
    public let modelID: String
    public let kind: FaderCapKind
    public let frame: CGRect
    public let commands: [EngineDrawingCommand]
    public let opacity: Float
    public let pointerOwned: Bool
    public let timingCurve: [Float]?
    public init(id: String, modelID: String, kind: FaderCapKind, frame: CGRect, commands: [EngineDrawingCommand],
                opacity: Float = 1, pointerOwned: Bool = false, timingCurve: [Float]? = nil) {
        self.id = id; self.modelID = modelID; self.kind = kind; self.frame = frame; self.commands = commands
        self.opacity = opacity; self.pointerOwned = pointerOwned; self.timingCurve = timingCurve
    }
}
public struct FaderBankRecipe: Equatable, Sendable {
    public let size: CGSize
    public let commands: [EngineDrawingCommand]
    public let regions: [FaderHitRegion]
    public let caps: [FaderCapSurface]
    public let focusInk: EngineInk?
    public init(size: CGSize, commands: [EngineDrawingCommand], regions: [FaderHitRegion], caps: [FaderCapSurface], focusInk: EngineInk? = nil) {
        self.size = size; self.commands = commands; self.regions = regions; self.caps = caps; self.focusInk = focusInk
    }
    public func validate() throws {
        try EngineTableRecipe(size: size, commands: commands, regions: [], focusInk: focusInk).validate()
        guard regions.count <= 512, caps.count <= 16, Set(regions.map(\.id)).count == regions.count,
              Set(caps.map(\.id)).count == caps.count else { throw EngineTableError.invalidRecipe }
        for region in regions {
            guard !region.id.isEmpty, region.label.utf8.count <= 4096, region.rect.width > 0, region.rect.height > 0,
                  [region.rect.minX, region.rect.minY, region.rect.maxX, region.rect.maxY].allSatisfy(\.isFinite),
                  region.rect.minX >= 0, region.rect.minY >= 0, region.rect.maxX <= size.width + 0.5, region.rect.maxY <= size.height + 0.5,
                  region.levelCount >= 0, region.shownIndex.map({ $0 >= 0 && $0 < region.levelCount }) ?? true else { throw EngineTableError.invalidRecipe }
            if region.role == .slider {
                guard let top = region.top, let bottom = region.bottom, top.isFinite, bottom.isFinite,
                      top >= region.rect.minY, bottom <= region.rect.maxY, bottom >= top,
                      region.detents.count == region.levelCount, Set(region.detents.map(\.key)).count == region.detents.count,
                      region.detents.allSatisfy({ $0.position.isFinite && (0...1).contains($0.position) }) else { throw EngineTableError.invalidRecipe }
                let positions = region.detents.map { top + $0.position * (bottom - top) }.sorted()
                let minimum = try region.nativeTickPolicy.minimumSpacing()
                for i in positions.indices.dropFirst() where positions[i] - positions[i - 1] < minimum - 0.01 { throw EngineTableError.invalidRecipe }
                let labelled = region.labelledDetentKeys ?? region.detents.map(\.key)
                let nativeKeys = Set(region.detents.map(\.key)), labelKeys = Set(labelled)
                guard labelKeys.count == labelled.count, labelKeys.isSubset(of: nativeKeys) else { throw EngineTableError.invalidRecipe }
                let labels = region.detents.filter { labelKeys.contains($0.key) }.map { top + $0.position * (bottom - top) }.sorted()
                for i in labels.indices.dropFirst() where labels[i] - labels[i - 1] < 20 - 0.01 { throw EngineTableError.invalidRecipe }
            }
        }
        for cap in caps {
            guard !cap.id.isEmpty, cap.opacity.isFinite, (0...1).contains(cap.opacity),
                  [cap.frame.minX, cap.frame.minY, cap.frame.width, cap.frame.height].allSatisfy(\.isFinite),
                  cap.frame.width > 0, cap.frame.height > 0,
                  cap.timingCurve.map({ $0.count == 4 && $0.allSatisfy { $0.isFinite && (0...1).contains($0) } }) ?? true else { throw EngineTableError.invalidRecipe }
            try EngineTableRecipe(size: cap.frame.size, commands: cap.commands, regions: []).validate()
        }
    }
}
@MainActor public protocol FaderBankRecipeProvider: InstrumentDrawingResources {
    func recipe(for presentation: FaderBankPresentation, size: CGSize) throws -> FaderBankRecipe
    func minimumSize(for presentation: FaderBankPresentation) -> CGSize
}

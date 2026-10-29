// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanShell
import ModelPlanCore
import ModelPlanAssembly
import ModelPlanInstruments

/// Optional upper-app consumer. Root Shell/Instruments never import Settings or AppIntegration.
@MainActor public protocol CommunityInstrumentSurface: NativeOverviewSurface {
    var instrumentLanguage: InstrumentLanguage { get }
    var selectedModelID: String? { get }
    var requestedInstrumentScope: InstrumentScope { get }
    var isPresented: Bool { get }
    var preferredContentSize: CGSize { get }
    var requestFreshSelection: (() -> Void)? { get set }
    var contentSizeChanged: (() -> Void)? { get set }
    func render(selection: AssembledModelSelection, publishedAt: Date?, now: Date)
    func resumePresentation()
    func suspendPresentation()
    func closePresentation()
}

/// Existing consumers remain All until they explicitly expose a requested subscription.
public extension CommunityInstrumentSurface {
    var requestedInstrumentScope: InstrumentScope { .all }
}

/// Public-only feed supplied from the same store observation, even without a personal join.
@MainActor public protocol CommunityPublicCatalogueConsumer: AnyObject {
    func render(publication: PublicPublication?)
}

/// The host binds this only to its existing retained Settings integration.
@MainActor public protocol CommunityInstrumentSettingsRouting: AnyObject {
    var requestSubscriptionsSettings: (() async -> Void)? { get set }
}

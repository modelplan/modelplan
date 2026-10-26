// SPDX-License-Identifier: MIT
import AppKit
import ModelPlanShell
import ModelPlanAssembly
import ModelPlanInstruments

/// Optional upper-app consumer. Root Shell/Instruments never import Settings or AppIntegration.
@MainActor public protocol CommunityInstrumentSurface: NativeOverviewSurface {
    var instrumentLanguage: InstrumentLanguage { get }
    var selectedModelID: String? { get }
    var isPresented: Bool { get }
    var preferredContentSize: CGSize { get }
    var requestFreshSelection: (() -> Void)? { get set }
    var contentSizeChanged: (() -> Void)? { get set }
    func render(selection: AssembledModelSelection, publishedAt: Date?, now: Date)
    func resumePresentation()
    func suspendPresentation()
    func closePresentation()
}

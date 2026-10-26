// SPDX-License-Identifier: MIT
import AppKit

@MainActor public protocol HelpUIRecipeProvider: AnyObject {
    func presentation(for input: HelpUIRenderInput) -> HelpUIPresentation
    func measure(_ text: String, width: CGFloat, role: HelpUITextRole) -> CGSize
    func font(for role: HelpUITextRole) -> NSFont
    var primaryInk: NSColor { get }
    var secondaryInk: NSColor { get }
    var panelColor: NSColor { get }
    var borderColor: NSColor { get }
}

/// Independent community rendering; approved private geometry/material/copy can be injected above it.
@MainActor public final class NeutralHelpUIRecipeProvider: HelpUIRecipeProvider {
    public init() {}
    public var primaryInk: NSColor { .labelColor }
    public var secondaryInk: NSColor { .secondaryLabelColor }
    public var panelColor: NSColor { .controlBackgroundColor }
    public var borderColor: NSColor { .separatorColor }
    public func font(for role: HelpUITextRole) -> NSFont {
        .systemFont(ofSize: role == .button ? 10:11,weight:role == .contextTitle || role == .header ? .semibold:.regular)
    }
    public func measure(_ text: String, width: CGFloat, role: HelpUITextRole) -> CGSize {
        guard width.isFinite,width>0 else { return .zero }
        let paragraph=NSMutableParagraphStyle();paragraph.minimumLineHeight=15;paragraph.maximumLineHeight=15
        let rect=(text as NSString).boundingRect(with:.init(width:width,height:10_000),
            options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:[.font:font(for:role),.paragraphStyle:paragraph])
        return .init(width:ceil(rect.width),height:ceil(rect.height))
    }
    public func presentation(for input: HelpUIRenderInput) -> HelpUIPresentation {
        HelpUILayout.make(input) { [self] text,width,role in measure(text,width:width,role:role) }
    }
}

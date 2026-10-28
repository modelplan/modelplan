// SPDX-License-Identifier: MIT
import AppKit

/// Only explicit Copy Diagnostics uses this port. Tests inject a fake and never touch the system clipboard.
@MainActor public protocol SettingsDiagnosticClipboard: AnyObject {
    func writeDiagnostics(_ text: String) -> Bool
}
@MainActor public enum SettingsDiagnosticCopy {
    /// Projection is applied at the final port boundary, even if the caller supplied unsafe versions.
    @discardableResult public static func copy(_ about: SettingsAbout, to clipboard: SettingsDiagnosticClipboard) -> Bool {
        clipboard.writeDiagnostics(about.diagnosticText)
    }
}
@MainActor public final class SystemDiagnosticClipboard: SettingsDiagnosticClipboard {
    public init() {}
    public func writeDiagnostics(_ text: String) -> Bool {
        let board = NSPasteboard.general
        _ = board.clearContents()
        return board.setString(text, forType: .string)
    }
}

enum SettingsSurfaceAction {
    case copyDiagnostics, request(SettingsB22Action)
}

@MainActor final class SettingsLicenseView: NSScrollView {
    private let text = NSTextView()
    override init(frame: NSRect) {
        super.init(frame: frame)
        hasVerticalScroller = true; borderType = .bezelBorder
        text.isEditable = false; text.isSelectable = true; text.isRichText = false
        text.isAutomaticLinkDetectionEnabled = false
        text.font = .systemFont(ofSize: 12); text.textContainerInset = .init(width: 8, height: 8)
        text.isHorizontallyResizable = false; text.isVerticallyResizable = true
        text.minSize = .init(width: 0, height: 180)
        text.maxSize = .init(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.frame = .init(x: 0, y: 0, width: 230, height: 180)
        text.autoresizingMask = [.width]; text.textContainer?.widthTracksTextView = true
        documentView = text
        widthAnchor.constraint(equalToConstant: 230).isActive = true
        heightAnchor.constraint(equalToConstant: 180).isActive = true
        setAccessibilityIdentifier("settings.licenses.text")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    func apply(_ notices: [SettingsLicenseNotice], language: SettingsLanguage) {
        let licenses = notices.isEmpty
            ? SettingsWords.text("Bundled notices are not available in this build.", "此版本尚未提供随包许可声明。", language)
            : notices.map { $0.component + " — " + $0.license + "\n" + $0.text }.joined(separator: "\n\n")
        let value = licenses + "\n\n" + SettingsAbout.trademarkNotice.value(language)
        if text.string != value { text.string = value }
        text.setAccessibilityLabel(SettingsWords.text("Third-party license notices", "第三方许可声明", language))
    }
}

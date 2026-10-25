// SPDX-License-Identifier: MIT
import AppKit
import CoreText

public struct EngineInk: Equatable, Sendable {
    public var red: Double, green: Double, blue: Double, alpha: Double
    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }
    public var valid: Bool { [red, green, blue, alpha].allSatisfy { $0.isFinite && (0...1).contains($0) } }
    var cgColor: CGColor { CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [red, green, blue, alpha])! }
    @MainActor public init(_ color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? .black
        self.init(c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent)
    }
}
public enum EngineTextAlignment: Sendable { case left, center, right }
public struct EngineFontRequest: Equatable, Sendable {
    public var resourceID: String?
    public var size: Double
    public var weight: Double
    public var monospaced: Bool
    public init(resourceID: String? = nil, size: Double, weight: Double = 400, monospaced: Bool = true) {
        self.resourceID = resourceID; self.size = size; self.weight = weight; self.monospaced = monospaced
    }
}
public struct EngineTextCommand: Equatable, Sendable {
    public var id: String, variants: [String]
    public var rect: CGRect, baseline: Double?
    public var font: EngineFontRequest, ink: EngineInk
    public var alignment: EngineTextAlignment
    public var transitionDuration: Double
    public var shadow: EngineTextShadow?
    public init(id: String, variants: [String], rect: CGRect, baseline: Double? = nil, font: EngineFontRequest,
                ink: EngineInk, alignment: EngineTextAlignment = .left, transitionDuration: Double = 0, shadow: EngineTextShadow? = nil) {
        self.id = id; self.variants = variants; self.rect = rect; self.baseline = baseline
        self.font = font; self.ink = ink; self.alignment = alignment; self.transitionDuration = transitionDuration
        self.shadow = shadow
    }
}
public struct EngineTextShadow: Equatable, Sendable {
    public let offset: CGSize
    public let blur: Double
    public let ink: EngineInk
    public init(offset: CGSize, blur: Double, ink: EngineInk) { self.offset = offset; self.blur = blur; self.ink = ink }
    var valid: Bool { offset.width.isFinite && offset.height.isFinite && abs(offset.width) <= 128 && abs(offset.height) <= 128 && blur.isFinite && (0...128).contains(blur) && ink.valid }
}
public struct EngineFocusStyle: Equatable, Sendable {
    public let ink: EngineInk
    public let width: Double, outset: Double, radius: Double
    public init(ink: EngineInk, width: Double, outset: Double, radius: Double) { self.ink = ink; self.width = width; self.outset = outset; self.radius = radius }
    var valid: Bool { ink.valid && width.isFinite && width > 0 && width <= 16 && outset.isFinite && abs(outset) <= 64 && radius.isFinite && (0...128).contains(radius) }
}
/// General drawing operations. There are no official silhouettes, coordinates or font names in this schema.
public enum EngineDrawingCommand: Equatable, Sendable {
    case fill(rect: CGRect, radius: Double, ink: EngineInk, alignToPixels: Bool = false)
    case stroke(rect: CGRect, radius: Double, width: Double, ink: EngineInk)
    case ellipse(rect: CGRect, ink: EngineInk, alignToPixels: Bool = false)
    case image(resourceID: String, rect: CGRect, opacity: Double)
    case text(EngineTextCommand)
    case shadowedFill(rect: CGRect, radius: Double, ink: EngineInk, offset: CGSize, blur: Double, shadow: EngineInk, alignToPixels: Bool = false)
    indirect case group(opacity: Double, commands: [EngineDrawingCommand])
    indirect case clipped(rect: CGRect, radius: Double, commands: [EngineDrawingCommand])
}
public enum EngineAccessibilityRole: Sendable { case button, readout, image }
public struct EngineHitRegion: Equatable, Sendable {
    public let id: String
    public let rect: CGRect
    public let label: String
    public let help: HelpExplanation
    public let role: EngineAccessibilityRole
    public let intent: EngineTableIntent?
    public let tabStop: Bool, enabled: Bool, selected: Bool
    public let focus: EngineFocusStyle?
    public init(id: String, rect: CGRect, label: String, help: HelpExplanation, role: EngineAccessibilityRole = .button,
                intent: EngineTableIntent? = nil, tabStop: Bool = true, enabled: Bool = true, selected: Bool = false, focus: EngineFocusStyle? = nil) {
        self.id = id; self.rect = rect; self.label = label; self.help = help; self.role = role
        self.intent = intent; self.tabStop = tabStop; self.enabled = enabled; self.selected = selected
        self.focus = focus
    }
}
public struct EngineTableRecipe: Equatable, Sendable {
    public let size: CGSize
    public var commands: [EngineDrawingCommand]
    public var regions: [EngineHitRegion]
    public var focusInk: EngineInk?
    public init(size: CGSize, commands: [EngineDrawingCommand], regions: [EngineHitRegion], focusInk: EngineInk? = nil) {
        self.size = size; self.commands = commands; self.regions = regions; self.focusInk = focusInk
    }
    public func validate() throws {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
              size.width <= 4096, size.height <= 4096, commands.count <= 8192, regions.count <= 512,
              Set(regions.map(\.id)).count == regions.count, focusInk?.valid != false else { throw EngineTableError.invalidRecipe }
        func rect(_ r: CGRect) -> Bool {
            [r.origin.x, r.origin.y, r.width, r.height].allSatisfy(\.isFinite)
                && r.width > 0 && r.height > 0 && r.width <= 8192 && r.height <= 8192
                && abs(r.origin.x) <= 8192 && abs(r.origin.y) <= 8192
        }
        var count = 0
        func check(_ commands: [EngineDrawingCommand], depth: Int) throws {
        guard depth <= 16 else { throw EngineTableError.invalidRecipe }
        count += commands.count
        guard count <= 8192 else { throw EngineTableError.invalidRecipe }
        for command in commands {
            let valid: Bool
            switch command {
            case .fill(let r, let radius, let ink, _), .stroke(let r, let radius, _, let ink):
                valid = rect(r) && radius.isFinite && radius >= 0 && radius <= min(r.width, r.height) / 2 && ink.valid
            case .ellipse(let r, let ink, _): valid = rect(r) && ink.valid
            case .image(let id, let r, let opacity): valid = !id.isEmpty && rect(r) && opacity.isFinite && (0...1).contains(opacity)
            case .text(let t):
                valid = !t.id.isEmpty && rect(t.rect) && !t.variants.isEmpty && t.variants.count <= 8
                    && t.variants.allSatisfy { $0.utf8.count <= 4096 } && t.font.size.isFinite && (1...128).contains(t.font.size)
                    && t.font.weight.isFinite && (1...1000).contains(t.font.weight) && t.ink.valid
                    && (t.baseline.map { $0.isFinite && abs($0) <= 8192 } ?? true)
                    && t.transitionDuration.isFinite && (0...0.25).contains(t.transitionDuration)
                    && (depth == 0 || t.transitionDuration == 0)
                    && (t.shadow?.valid ?? true)
            case .shadowedFill(let r, let radius, let ink, let offset, let blur, let shadow, _):
                valid = rect(r) && radius.isFinite && radius >= 0 && radius <= min(r.width, r.height) / 2 && ink.valid && shadow.valid
                    && offset.width.isFinite && offset.height.isFinite && abs(offset.width) <= 128 && abs(offset.height) <= 128
                    && blur.isFinite && (0...128).contains(blur)
            case .group(let opacity, let children):
                valid = opacity.isFinite && (0...1).contains(opacity)
                try check(children, depth: depth + 1)
            case .clipped(let r, let radius, let children):
                valid = rect(r) && radius.isFinite && radius >= 0 && radius <= min(r.width, r.height) / 2
                try check(children, depth: depth + 1)
            }
            if !valid { throw EngineTableError.invalidRecipe }
            if case .stroke(_, _, let width, _) = command, !width.isFinite || width <= 0 || width > 128 { throw EngineTableError.invalidRecipe }
        }
        }
        try check(commands, depth: 0)
        for region in regions {
            guard rect(region.rect), !region.id.isEmpty, region.label.utf8.count <= 4096,
                  region.rect.minX >= 0, region.rect.minY >= 0, region.rect.maxX <= size.width + 0.5,
                  region.rect.maxY <= size.height + 0.5, region.focus?.valid != false else { throw EngineTableError.invalidRecipe }
        }
    }
}
public enum EngineTableError: Error { case invalidRecipe, missingResource(String), resourceBudget, invalidScale }

/// Trusted assembly injects official recipes/resources explicitly. The neutral implementation needs no files.
@MainActor public protocol EngineTableRecipeProvider: AnyObject {
    func recipe(for presentation: EngineTablePresentation, size: CGSize) throws -> EngineTableRecipe
    func font(_ request: EngineFontRequest) throws -> CTFont
    func image(_ resourceID: String) throws -> CGImage
}

public struct EngineGlyphMetric: Sendable {
    public let id: String, text: String, fontName: String
    public let rect: CGRect, baseline: Double, advance: Double
    public let drawOrigin: CGPoint
    public let clipped: Bool
}
@MainActor public enum EngineRecipeDrawing {
    public static func alignedToDevicePixels(_ rect: CGRect, in context: CGContext) -> CGRect {
        let a = context.convertToDeviceSpace(rect.origin)
        let b = context.convertToDeviceSpace(CGPoint(x: rect.maxX, y: rect.maxY))
        func snap(_ value: CGFloat, flipped: Bool) -> CGFloat { flipped ? ceil(value - 0.5) : floor(value + 0.5) }
        let x0 = snap(a.x, flipped: context.ctm.a < 0), x1 = snap(b.x, flipped: context.ctm.a < 0)
        let y0 = snap(a.y, flipped: context.ctm.d < 0), y1 = snap(b.y, flipped: context.ctm.d < 0)
        let device = CGRect(x: min(x0, x1), y: min(y0, y1), width: abs(x1-x0), height: abs(y1-y0))
        return context.convertToUserSpace(device)
    }
    public static func choose(_ command: EngineTextCommand, font: CTFont) -> (String, CTLine, Double) {
        var result: (String, CTLine, Double)!
        for text in command.variants {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): command.ink.cgColor,
            ]))
            let width = CTLineGetTypographicBounds(line, nil, nil, nil)
            result = (text, line, width)
            if width <= command.rect.width + 0.2 { break }
        }
        return result
    }
    @discardableResult public static func draw(_ recipe: EngineTableRecipe, in context: CGContext,
                                               provider: any EngineTableRecipeProvider, includeTransitionText: Bool = true) throws -> [EngineGlyphMetric] {
        try recipe.validate()
        var metrics: [EngineGlyphMetric] = []
        var resources: Set<String> = [], bytes = 0
        for command in recipe.commands {
            context.saveGState()
            defer { context.restoreGState() }
            switch command {
            case .fill(let original, let radius, let ink, let align):
                let r = align ? alignedToDevicePixels(original, in: context) : original
                context.setFillColor(ink.cgColor); context.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)); context.fillPath()
            case .stroke(let r, let radius, let width, let ink):
                context.setStrokeColor(ink.cgColor); context.setLineWidth(width)
                context.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)); context.strokePath()
            case .ellipse(let original, let ink, let align):
                let r = align ? alignedToDevicePixels(original, in: context) : original
                context.setFillColor(ink.cgColor); context.fillEllipse(in: r)
            case .image(let id, let r, let opacity):
                let image = try provider.image(id)
                if resources.insert(id).inserted {
                    let amount = image.bytesPerRow.multipliedReportingOverflow(by: image.height)
                    guard !amount.overflow, amount.partialValue <= 16_000_000 - bytes else { throw EngineTableError.resourceBudget }
                    bytes += amount.partialValue
                }
                context.setAlpha(opacity); context.translateBy(x: r.minX, y: r.maxY); context.scaleBy(x: 1, y: -1)
                context.draw(image, in: CGRect(origin: .zero, size: r.size))
            case .text(let t):
                if !includeTransitionText && t.transitionDuration > 0 { continue }
                let font = try provider.font(t.font)
                let (text, line, advance) = choose(t, font: font)
                let alignment = t.alignment == .center ? (t.rect.width - advance) / 2 : t.alignment == .right ? t.rect.width - advance : 0
                var ascent: CGFloat = 0, descent: CGFloat = 0
                _ = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
                let baseline = t.baseline ?? (t.rect.midY + (ascent - descent) / 2)
                metrics.append(EngineGlyphMetric(id: t.id, text: text, fontName: CTFontCopyPostScriptName(font) as String,
                                                rect: t.rect, baseline: baseline, advance: advance, drawOrigin: CGPoint(x: t.rect.minX + alignment, y: baseline), clipped: advance > t.rect.width + 0.2))
                if let shadow = t.shadow { context.setShadow(offset: shadow.offset, blur: shadow.blur, color: shadow.ink.cgColor) }
                context.clip(to: t.rect); context.translateBy(x: t.rect.minX + alignment, y: baseline); context.scaleBy(x: 1, y: -1)
                context.textMatrix = .identity; context.textPosition = .zero; CTLineDraw(line, context)
            case .shadowedFill(let original, let radius, let ink, let offset, let blur, let shadow, let align):
                let r = align ? alignedToDevicePixels(original, in: context) : original
                context.setShadow(offset: offset, blur: blur, color: shadow.cgColor)
                context.setFillColor(ink.cgColor); context.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)); context.fillPath()
            case .group(let opacity, let commands):
                context.setAlpha(opacity); context.beginTransparencyLayer(auxiliaryInfo: nil)
                let nested = EngineTableRecipe(size: recipe.size, commands: commands, regions: [])
                do {
                    metrics += try draw(nested, in: context, provider: provider, includeTransitionText: includeTransitionText)
                    context.endTransparencyLayer()
                } catch { context.endTransparencyLayer(); throw error }
            case .clipped(let rect, let radius, let commands):
                context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); context.clip()
                metrics += try draw(EngineTableRecipe(size: recipe.size, commands: commands, regions: []), in: context,
                                    provider: provider, includeTransitionText: includeTransitionText)
            }
        }
        return metrics
    }
    public static func raster(_ recipe: EngineTableRecipe, provider: any EngineTableRecipeProvider, scale: Int) throws -> (CGImage, [EngineGlyphMetric]) {
        try recipe.validate()
        guard (1...2).contains(scale) else { throw EngineTableError.invalidScale }
        let w = ceil(recipe.size.width * Double(scale)), h = ceil(recipe.size.height * Double(scale))
        guard w > 0, h > 0, w <= 8192, h <= 8192, w * h <= 16_777_216 else { throw EngineTableError.invalidRecipe }
        guard let c = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw EngineTableError.resourceBudget }
        c.translateBy(x: 0, y: h); c.scaleBy(x: Double(scale), y: -Double(scale))
        let metrics = try draw(recipe, in: c, provider: provider)
        guard let image = c.makeImage() else { throw EngineTableError.resourceBudget }
        return (image, metrics)
    }
}

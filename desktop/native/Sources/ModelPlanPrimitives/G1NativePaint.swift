// SPDX-License-Identifier: MIT
#if DEBUG
  import AppKit
  /// Completed custom drawing operations, shared with the generic inspection adapter.
  @MainActor public struct G1NativePaint {
    public let role: String, frame: CGRect, color: NSColor
    public init(role: String, frame: CGRect, color: NSColor) {
      self.role = role
      self.frame = frame
      self.color = color
    }
  }
  @MainActor public protocol G1NativePaintObserving: AnyObject {
    var g1DrawnPaints: [G1NativePaint] { get }
  }
#endif

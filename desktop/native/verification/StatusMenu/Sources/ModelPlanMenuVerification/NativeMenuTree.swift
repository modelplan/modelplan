// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI || MODELPLAN_U6_DRIVE
  import ApplicationServices
  import Foundation

  public struct NativeMenuElement: Hashable {
    let value: AXUIElement
    init(_ value: AXUIElement) {
      self.value = value
      _ = AXUIElementSetMessagingTimeout(value, 0.25)
    }
    public static func == (a: Self, b: Self) -> Bool { CFEqual(a.value, b.value) }
    public func hash(into hasher: inout Hasher) { hasher.combine(CFHash(value)) }
  }
  public struct NativeStatusMenuTree: StatusMenuTree {
    public init() {}
    public func extras(subjectPID: Int32) throws -> NativeMenuElement {
      guard subjectPID > 0 else { throw StatusMenuError.outsideOwnedMenu }
      let app = AXUIElementCreateApplication(subjectPID)
      _ = AXUIElementSetMessagingTimeout(app, 0.25)
      guard let result = try attribute(app, kAXExtrasMenuBarAttribute as CFString),
        CFGetTypeID(result) == AXUIElementGetTypeID()
      else { throw StatusMenuError.unsupported }
      return NativeMenuElement(unsafeBitCast(result, to: AXUIElement.self))
    }
    private func attribute(_ element: AXUIElement, _ name: CFString) throws -> CFTypeRef? {
      var value: CFTypeRef?
      let result = AXUIElementCopyAttributeValue(element, name, &value)
      if result == .noValue || result == .attributeUnsupported { return nil }
      guard result == .success else { throw StatusMenuError.unsupported }
      return value
    }
    public func pid(_ e: NativeMenuElement) throws -> Int32 {
      var p: pid_t = 0
      guard AXUIElementGetPid(e.value, &p) == .success else { throw StatusMenuError.unsupported }
      return p
    }
    public func role(_ e: NativeMenuElement) throws -> String {
      try attribute(e.value, kAXRoleAttribute as CFString) as? String ?? ""
    }
    public func identifier(_ e: NativeMenuElement) throws -> String? {
      try attribute(e.value, kAXIdentifierAttribute as CFString) as? String
    }
    public func title(_ e: NativeMenuElement) throws -> String? {
      try attribute(e.value, kAXTitleAttribute as CFString) as? String
    }
    public func enabled(_ e: NativeMenuElement) throws -> Bool {
      try attribute(e.value, kAXEnabledAttribute as CFString) as? Bool == true
    }
    public func children(_ e: NativeMenuElement) throws -> [NativeMenuElement] {
      var count: CFIndex = 0
      let result = AXUIElementGetAttributeValueCount(
        e.value, kAXChildrenAttribute as CFString, &count)
      if result == .noValue || result == .attributeUnsupported { return [] }
      guard result == .success, count <= 256 else { throw StatusMenuError.limit }
      guard count > 0 else { return [] }
      var values: CFArray?
      guard
        AXUIElementCopyAttributeValues(e.value, kAXChildrenAttribute as CFString, 0, count, &values)
          == .success, let values
      else { throw StatusMenuError.unsupported }
      return try (0..<CFArrayGetCount(values)).map { index in
        guard let pointer = CFArrayGetValueAtIndex(values, index) else {
          throw StatusMenuError.outsideOwnedMenu
        }
        let value = Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
          throw StatusMenuError.outsideOwnedMenu
        }
        return NativeMenuElement(unsafeBitCast(value, to: AXUIElement.self))
      }
    }
    /// Accepted and unconfirmed transport returns both still require a native
    /// arrival receipt. A timeout return is never relabelled as arrival.
    public func press(_ e: NativeMenuElement) throws -> Bool {
      var names: CFArray?
      guard AXUIElementCopyActionNames(e.value, &names) == .success, let names else {
        throw StatusMenuError.unsupported
      }
      let supportsPress = (0..<CFArrayGetCount(names)).contains { index in
        guard let pointer = CFArrayGetValueAtIndex(names, index) else { return false }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? String
          == kAXPressAction as String
      }
      guard supportsPress else { throw StatusMenuError.unsupported }
      let result = AXUIElementPerformAction(e.value, kAXPressAction as CFString)
      guard result == .success || result == .cannotComplete else {
        throw StatusMenuError.unsupported
      }
      return result == .success
    }
  }
#endif

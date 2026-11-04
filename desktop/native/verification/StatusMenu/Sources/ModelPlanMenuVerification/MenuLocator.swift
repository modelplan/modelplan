// SPDX-License-Identifier: MIT
#if MODELPLAN_TEST_ONLY_SPI || MODELPLAN_U6_DRIVE
  import Foundation

  /// Testable scoped tree seam. The native adapter starts only at AXExtrasMenuBar
  /// for the supplied application PID; no system-wide/window fallback exists.
  public protocol StatusMenuTree {
    associatedtype Element: Hashable
    func pid(_ element: Element) throws -> Int32
    func role(_ element: Element) throws -> String
    func identifier(_ element: Element) throws -> String?
    func title(_ element: Element) throws -> String?
    func enabled(_ element: Element) throws -> Bool
    func children(_ element: Element) throws -> [Element]
  }
  public enum StatusMenuLocator {
    public static func statusItem<T: StatusMenuTree>(
      tree: T, extras: T.Element, subjectPID: Int32, identifier: String?
    ) throws -> T.Element {
      guard subjectPID > 0, try tree.pid(extras) == subjectPID, try tree.role(extras) == "AXMenuBar"
      else { throw StatusMenuError.outsideOwnedMenu }
      let children = try tree.children(extras)
      guard children.count <= 32 else { throw StatusMenuError.limit }
      var matches: [T.Element] = []
      for child in children {
        guard try tree.pid(child) == subjectPID else { throw StatusMenuError.outsideOwnedMenu }
        guard try tree.role(child) == "AXMenuBarItem" else { continue }
        if let identifier, try tree.identifier(child) != identifier { continue }
        matches.append(child)
      }
      guard matches.count == 1 else {
        throw matches.isEmpty ? StatusMenuError.notFound : StatusMenuError.ambiguous
      }
      return matches[0]
    }
    public static func item<T: StatusMenuTree>(
      tree: T, statusItem: T.Element, subjectPID: Int32, name: String
    ) throws -> T.Element {
      guard !name.isEmpty, name.utf16.count <= 128,
        !name.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
        try tree.pid(statusItem) == subjectPID, try tree.role(statusItem) == "AXMenuBarItem"
      else { throw StatusMenuError.outsideOwnedMenu }
      var queue = try tree.children(statusItem).map { ($0, 1) }
      var visited = Set<T.Element>()
      var matches: [T.Element] = []
      while !queue.isEmpty {
        guard visited.count < 256 else { throw StatusMenuError.limit }
        let (node, depth) = queue.removeFirst()
        guard depth <= 8 else { throw StatusMenuError.limit }
        guard visited.insert(node).inserted else { continue }
        guard try tree.pid(node) == subjectPID else { throw StatusMenuError.outsideOwnedMenu }
        let role = try tree.role(node)
        guard ["AXMenu", "AXMenuItem", "AXScrollArea"].contains(role) else {
          throw StatusMenuError.outsideOwnedMenu
        }
        if role == "AXMenuItem", try tree.title(node) == name { matches.append(node) }
        let children = try tree.children(node)
        guard children.count <= 256, queue.count + children.count <= 256 else {
          throw StatusMenuError.limit
        }
        queue += children.map { ($0, depth + 1) }
      }
      guard matches.count == 1 else {
        throw matches.isEmpty ? StatusMenuError.notFound : StatusMenuError.ambiguous
      }
      guard try tree.enabled(matches[0]) else { throw StatusMenuError.disabled }
      return matches[0]
    }
  }
#endif

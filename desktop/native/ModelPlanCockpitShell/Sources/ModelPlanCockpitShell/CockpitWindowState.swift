// SPDX-License-Identifier: MIT

/// User intent survives a temporary forced closure on a smaller display.
public struct CockpitWindowState: Equatable, Sendable {
    public private(set) var userClosed: Bool

    public init(userClosed: Bool = false) { self.userClosed = userClosed }

    public func isClosed(forcedClosed: Bool) -> Bool { userClosed || forcedClosed }
    public func switchEnabled(forcedClosed: Bool) -> Bool { !forcedClosed }

    /// A disabled slider cannot mutate the saved user preference.
    @discardableResult
    public mutating func setClosed(_ closed: Bool, forcedClosed: Bool) -> Bool {
        guard !forcedClosed, closed != userClosed else { return false }
        userClosed = closed
        return true
    }

    @discardableResult
    public mutating func toggle(forcedClosed: Bool) -> Bool {
        setClosed(!userClosed, forcedClosed: forcedClosed)
    }
}

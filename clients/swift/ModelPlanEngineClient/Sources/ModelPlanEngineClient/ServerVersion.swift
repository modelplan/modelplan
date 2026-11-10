// SPDX-License-Identifier: MIT
import Foundation

// Semantic Version 2.0.0 precedence. A prerelease ranks below its own release but above every
// earlier release, so a 0.5.58-rc.1 candidate meets a 0.5.52 floor and 0.5.52-dev does not.
// Malformed versions fail closed; build metadata does not change version precedence.
func meetsMinimumServerVersion(_ actual: String, minimum: String) -> Bool {
    guard let have = ServerVersion(actual), let required = ServerVersion(minimum) else { return false }
    return !have.precedes(required)
}

private struct ServerVersion {
    let core: [UInt64]
    let prerelease: [Substring]

    init?(_ value: String) {
        let sections = value.split(separator: "+", omittingEmptySubsequences: false)
        guard !sections.isEmpty, sections.count <= 2 else { return nil }
        if sections.count == 2 { guard Self.identifiers(sections[1]) != nil else { return nil } }
        let parts = sections[0].split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2 {
            guard let identifiers = Self.identifiers(parts[1]),
                  identifiers.allSatisfy({ !Self.isNumeric($0) || !($0.count > 1 && $0.first == "0") }) else { return nil }
            prerelease = identifiers
        } else {
            prerelease = []
        }
        let components = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3 else { return nil }
        var numbers: [UInt64] = []
        for component in components {
            guard Self.isNumeric(component), !(component.count > 1 && component.first == "0"),
                  let number = UInt64(component) else { return nil }
            numbers.append(number)
        }
        core = numbers
    }

    func precedes(_ other: ServerVersion) -> Bool {
        if core != other.core { return core.lexicographicallyPrecedes(other.core) }
        if prerelease.isEmpty || other.prerelease.isEmpty { return !prerelease.isEmpty && other.prerelease.isEmpty }
        for (left, right) in zip(prerelease, other.prerelease) where left != right {
            switch (Self.isNumeric(left), Self.isNumeric(right)) {
            case (true, true):  // no leading zeros, so the shorter number is the smaller one
                return left.count != right.count ? left.count < right.count : left.utf8.lexicographicallyPrecedes(right.utf8)
            case (true, false): return true
            case (false, true): return false
            case (false, false): return left.utf8.lexicographicallyPrecedes(right.utf8)
            }
        }
        return prerelease.count < other.prerelease.count
    }

    private static func identifiers(_ text: Substring) -> [Substring]? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy(isIdentifierByte) }) else { return nil }
        return parts
    }

    private static func isIdentifierByte(_ byte: UInt8) -> Bool {
        (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte) || byte == 45
    }

    private static func isNumeric(_ text: Substring) -> Bool {
        !text.isEmpty && text.utf8.allSatisfy { (48...57).contains($0) }
    }
}

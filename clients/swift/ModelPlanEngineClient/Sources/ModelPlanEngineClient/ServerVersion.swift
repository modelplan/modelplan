// SPDX-License-Identifier: MIT
import Foundation

// Released CLI versions use three numeric components. Prereleases and malformed
// versions fail closed; build metadata does not change version precedence.
func meetsMinimumServerVersion(_ actual: String, minimum: String) -> Bool {
    func parse(_ value: String) -> [UInt64]? {
        let sections = value.split(separator: "+", omittingEmptySubsequences: false)
        guard !sections.isEmpty, sections.count <= 2 else { return nil }
        if sections.count == 2 {
            let metadata = sections[1]
            guard !metadata.isEmpty, metadata.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 46 }) else { return nil }
        }
        let components = sections[0].split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3 else { return nil }
        var numbers: [UInt64] = []
        for component in components {
            guard !component.isEmpty, !(component.count > 1 && component.first == "0"),
                  component.utf8.allSatisfy({ (48...57).contains($0) }), let number = UInt64(component) else { return nil }
            numbers.append(number)
        }
        return numbers
    }
    guard let have = parse(actual), let required = parse(minimum) else { return false }
    return !have.lexicographicallyPrecedes(required)
}

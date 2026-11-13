// SPDX-License-Identifier: MIT
import Foundation

/// CLI-supplied labels, never network destinations, navigation targets or reader admission.
public enum SettingsProviderHostText {
    public static let maximumUTF8Length = 253
    public static func isValid(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespaces).isEmpty && value.utf8.count <= maximumUTF8Length
            && !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }
    public static func normalized(_ value: String) -> String? {
        guard isValid(value) else { return nil }
        let text = value.trimmingCharacters(in: .whitespaces)
        var endpoint = text, note = ""
        if text.hasSuffix(")"), let split = text.range(of: " (") {
            endpoint = String(text[..<split.lowerBound]); note = String(text[split.lowerBound...])
        }
        if let url = URLComponents(string: endpoint), url.scheme?.lowercased() == "https",
           let host = url.host, !host.isEmpty {
            let label = host + note
            return isValid(label) ? label : nil
        }
        return text
    }
}

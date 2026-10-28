// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanSettings

public enum CommunityConsentAccessClass: String, Sendable { case standard, browserSession = "browser-session", notRead = "not-read", unknown }
public typealias CommunityConsentKeychain = SettingsRecordedKeychain
public enum CommunityConsentKeychainDecision: String, Encodable, Sendable { case allow, deny }
/// Core's verified decoder supplies these exact preview fields. No credential/sign-in claim is derived.
public struct CommunityConsentToolFacts: Sendable {
    public let id: String, displayName: String, accessClass: CommunityConsentAccessClass
    public let detected: Bool, allowed: Bool
    public let backend: String, readerId: String
    public let keychain: CommunityConsentKeychain
    public let hosts: [String]
    public init(id: String, displayName: String, accessClass: CommunityConsentAccessClass,
                detected: Bool, allowed: Bool, backend: String, readerId: String, keychain: CommunityConsentKeychain,
                hosts: [String] = []) {
        self.id = id; self.displayName = displayName; self.accessClass = accessClass
        self.detected = detected; self.allowed = allowed; self.backend = backend; self.readerId = readerId; self.keychain = keychain
        self.hosts = hosts
    }
    var tool: SettingsConnectionTool? {
        Self.knownTool(id)
    }
    private static func knownTool(_ id: String) -> SettingsConnectionTool? {
        let value: String
        switch id { case "claude-code": value = "claude"; case "zcode": value = "zai"; case "opencode": value = "opencodego"; default: value = id }
        return SettingsConnectionTool(rawValue: value)
    }
    var eligible: Bool {
        guard let tool, accessClass == .standard, detected,
              ["native", "codexbar", "codexbar-compat"].contains(backend) else { return false }
        let parts = readerId.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, ["native", "codexbar"].contains(String(parts[0])) else { return false }
        return Self.knownTool(String(parts[1])) == tool
    }
    var mayDeny: Bool { tool != nil && accessClass == .standard && detected }
}
/// Values decoded by M0 from `consent --json`; exact text is supplied, not reconstructed or translated.
public struct CommunityConsentPreviewFacts: Sendable {
    public let generation: UInt64, consentTextVersion: Int
    public let mode: SettingsReadingMode
    public let tools: [CommunityConsentToolFacts]
    public let consentText: SettingsText
    public init(generation: UInt64, consentTextVersion: Int, mode: SettingsReadingMode,
                tools: [CommunityConsentToolFacts], consentText: SettingsText) throws {
        let normalized = tools.compactMap(\.tool)
        guard tools.count <= 512, Set(tools.map(\.id)).count == tools.count, Set(normalized).count == normalized.count,
              tools.allSatisfy({ $0.id.range(of: #"^[a-z][a-z0-9-]{0,47}$"#, options: .regularExpression) != nil
                  && !$0.displayName.isEmpty && $0.displayName.utf8.count <= 96
                  && !$0.displayName.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
                  && $0.hosts.count <= 32 && $0.hosts.allSatisfy(SettingsConnectionSnapshot.validHost) }),
              consentTextVersion > 0, consentTextVersion <= 1_000_000,
              [consentText.english, consentText.chinese].allSatisfy({ !$0.isEmpty && $0.utf8.count <= 8192 })
        else { throw SettingsConnectionFailure.invalidResponse }
        self.generation = generation; self.consentTextVersion = consentTextVersion; self.mode = mode; self.tools = tools; self.consentText = consentText
    }
    /// Detection/consent preview cannot invent quota or membership. Preserve verified reading facts.
    public func projecting(over previous: SettingsConnectionSnapshot? = nil) throws -> SettingsConnectionSnapshot {
        let present = Set(tools.compactMap(\.tool))
        var rows = (previous?.tools ?? []).map { prior in
            var row = prior
            if !present.contains(row.tool) { row.presence = .unknown; row.authorization = .unknown; row.consentEligible = false }
            return row
        }
        var unknown = previous?.unrecognizedTools ?? []
        for value in tools {
            guard let tool = value.tool else {
                unknown.removeAll { $0.id == value.id }
                unknown.append(.init(id: value.id, title: value.displayName, presence: value.detected ? .detected : .notDetected,
                                     access: value.accessClass == .browserSession ? .browserSession : .standard))
                continue
            }
            var row = rows.first { $0.tool == tool } ?? .init(tool: tool)
            row.presence = value.detected ? .detected : .notDetected
            row.authorization = value.allowed ? .allowed : .noConsent
            row.access = value.accessClass == .browserSession ? .browserSession : .standard
            row.consentEligible = value.eligible
            row.keychain = value.keychain; row.providerHosts = value.hosts
            if mode == .off { row.connection = .off }
            rows.removeAll { $0.tool == tool }; rows.append(row)
        }
        let eligible = Set(tools.filter(\.eligible).compactMap(\.tool))
        return try .init(consentGeneration: generation, tools: rows, subscriptions: previous?.subscriptions ?? [],
            unrecognizedTools: unknown, consentPreview: .init(textVersion: consentTextVersion, notice: consentText, standardTools: eligible), mode: mode)
    }
}
/// Only the final structured `consent grant --json` stdin shape. This type never launches a command.
public struct CommunityConsentGrantPayload: Encodable, Sendable {
    public let requestId: String
    public let expectGeneration: UInt64
    public let consentTextVersion: Int
    public let allow: [String], deny: [String]
    /// No Keychain opt-in is collected by this slice. Empty is deliberate, never inferred from presence.
    public let keychain: [String: CommunityConsentKeychainDecision] = [:]
    public init(preview: CommunityConsentPreviewFacts, allow: [SettingsConnectionTool], deny: [SettingsConnectionTool],
                request: SettingsConnectionRequestContext) throws {
        let selected = allow + deny
        guard request.expectedConsentGeneration == preview.generation, request.consentTextVersion == preview.consentTextVersion,
              !selected.isEmpty, Set(selected).count == selected.count,
              allow.isEmpty || preview.mode == .automatic || preview.mode == .passive else { throw SettingsConnectionFailure.stale }
        var ids: [SettingsConnectionTool: String] = [:]
        for tool in selected {
            guard let value = preview.tools.first(where: { $0.tool == tool }),
                  allow.contains(tool) ? value.eligible : value.mayDeny else { throw SettingsConnectionFailure.unavailable }
            ids[tool] = value.id
        }
        self.requestId = request.id.uuidString; self.expectGeneration = preview.generation; self.consentTextVersion = preview.consentTextVersion
        self.allow = allow.compactMap { ids[$0] }; self.deny = deny.compactMap { ids[$0] }
    }
}

// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore

public enum FieldContractError: Error { case invalidProjection, invalidViewport, invalidMessage, oversized }
public enum FieldTheme: String, Codable, Sendable { case day, night }
public enum FieldProfile: String, Codable, Sendable { case tall, short }
public enum FieldLocale: String, Codable, Sendable { case english = "en", chinese = "zh-CN" }
public struct FieldAppearance: Codable, Equatable, Sendable {
    public let theme: FieldTheme
    public let locale: FieldLocale
    public init(theme: FieldTheme, locale: FieldLocale) { self.theme = theme; self.locale = locale }
}
public struct FieldViewport: Codable, Equatable, Sendable {
    public let width: Int, height: Int
    public let scale: Double
    public let profile: FieldProfile
    public init(width: Int, height: Int, scale: Double, profile: FieldProfile) throws {
        guard (1...4096).contains(width), (1...4096).contains(height),
              scale.isFinite, (0.1...4).contains(scale) else { throw FieldContractError.invalidViewport }
        self.width = width; self.height = height; self.scale = scale; self.profile = profile
    }
}
public struct FieldPublicEffort: Codable, Equatable, Sendable {
    public let effort: String, label: String?
    public let ability: Double?, cost: Double?, time: Double?
    public let available: Bool?
    public init(effort: String, label: String?, ability: Double?, cost: Double?, time: Double?, available: Bool? = nil) {
        self.effort = effort; self.label = label; self.ability = ability; self.cost = cost; self.time = time; self.available = available
    }
}
public struct FieldPublicModel: Codable, Equatable, Sendable {
    public let id: String, name: String?, developerId: String?, recommended: String?
    public let efforts: [FieldPublicEffort]
}
/// Allowlist projection of the public publication, with no JoinedSnapshot or personal-state entry point.
/// Published order and nullable values are preserved; this module never scores/ranks models.
public struct FieldPublicProjection: Codable, Equatable, Sendable {
    public let revision: String
    public let models: [FieldPublicModel]
    private init(revision: String, models: [FieldPublicModel]) { self.revision = revision; self.models = models }
    /// Copy only already chosen, known public IDs; this is not an eligibility/ranking selector.
    public func selecting(publicIDs: [String]) throws -> FieldPublicProjection {
        let byID = Dictionary(grouping: models, by: \.id)
        guard publicIDs.count <= 10, Set(publicIDs).count == publicIDs.count,
              publicIDs.allSatisfy({ byID[$0]?.count == 1 }) else { throw FieldContractError.invalidProjection }
        return .init(revision: revision, models: publicIDs.compactMap { byID[$0]?.first })
    }
    public init(publication: PublicPublication) throws {
        func text(_ value: String?, limit: Int = 256) -> Bool { value.map { !$0.isEmpty && $0.utf8.count <= limit } ?? true }
        func number(_ value: Double?) -> Bool { value.map { $0.isFinite && $0 >= 0 } ?? true }
        guard publication.supportedUnits, text(publication.publicationId, limit: 128),
              publication.models.count <= 256, Set(publication.models.map(\.id)).count == publication.models.count else {
            throw FieldContractError.invalidProjection
        }
        var result: [FieldPublicModel] = []
        for m in publication.models {
            let efforts = m.efforts ?? []
            guard text(m.id, limit: 128), text(m.name), text(m.developerId, limit: 128), text(m.recommended, limit: 128),
                  efforts.count <= 16, Set(efforts.map(\.effort)).count == efforts.count else { throw FieldContractError.invalidProjection }
            for e in efforts {
                guard text(e.effort, limit: 128), text(e.label), number(e.ability), number(e.cost), number(e.time) else {
                    throw FieldContractError.invalidProjection
                }
            }
            result.append(FieldPublicModel(id: m.id, name: m.name, developerId: m.developerId,
                recommended: m.recommended, efforts: efforts.map {
                    FieldPublicEffort(effort: $0.effort, label: $0.label, ability: $0.ability, cost: $0.cost, time: $0.time, available: $0.available)
                }))
        }
        revision = publication.publicationId; models = result
        guard try JSONEncoder().encode(self).count <= 512 * 1024 else { throw FieldContractError.oversized }
    }
}
public struct FieldConfiguration: Codable, Equatable, Sendable {
    public let appearance: FieldAppearance
    public let viewport: FieldViewport
    public let projection: FieldPublicProjection
    public init(appearance: FieldAppearance, viewport: FieldViewport, projection: FieldPublicProjection) {
        self.appearance = appearance; self.viewport = viewport; self.projection = projection
    }
}
public struct FieldCaptureKey: Codable, Equatable, Sendable {
    public let generation: UUID, requestId: UUID, configurationId: UUID
    public let appearance: FieldAppearance
    public let viewport: FieldViewport
    public let projectionRevision: String
    public var slot: String { appearance.theme.rawValue + "-" + viewport.profile.rawValue }
}
public enum FieldCommandKind: String, Codable, Sendable {
    case configure, setPublicProjection, setAppearance, capture, dispose
}
public struct FieldCommand: Codable, Equatable, Sendable {
    public let version: Int
    public let generation: UUID, requestId: UUID
    public let type: FieldCommandKind
    public let configuration: FieldConfiguration?
    public let paused: Bool?
    public let captureKey: FieldCaptureKey?
    init(generation: UUID, requestId: UUID = UUID(), type: FieldCommandKind,
         configuration: FieldConfiguration? = nil, paused: Bool? = nil, captureKey: FieldCaptureKey? = nil) {
        version = 1; self.generation = generation; self.requestId = requestId; self.type = type
        self.configuration = configuration; self.paused = paused; self.captureKey = captureKey
    }
    public func structuredObject() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard data.count <= 1024 * 1024,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw FieldContractError.oversized }
        return object
    }
}
public enum FieldEventKind: String, Codable, Sendable { case ready, settled, interaction, captureResult, disposed, error }
public enum FieldInteraction: String, Codable, Sendable { case pointer, drag, keyboard, camera }
public enum FieldWebError: String, Codable, Sendable { case initialization, render, capture }
public struct FieldWebMessage: Codable, Equatable, Sendable {
    public let version: Int
    public let generation: UUID
    public let type: FieldEventKind
    public let requestId: UUID?
    public let captureKey: FieldCaptureKey?
    public let interaction: FieldInteraction?
    public let code: FieldWebError?
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= 64 * 1024 else { throw FieldContractError.oversized }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw FieldContractError.invalidMessage }
        let result = try JSONDecoder().decode(Self.self, from: data)
        var keys: Set<String> = ["version", "generation", "type"]
        switch result.type {
        case .ready: break
        case .settled, .disposed:
            keys.insert("requestId")
            guard result.requestId != nil else { throw FieldContractError.invalidMessage }
        case .captureResult:
            keys.formUnion(["requestId", "captureKey"])
            guard let key = result.captureKey, key.generation == result.generation, key.requestId == result.requestId else {
                throw FieldContractError.invalidMessage
            }
            // Reject hidden/private fields at every level of an echoed capture identity.
            guard let keyObject = object["captureKey"] as? [String: Any],
                  Set(keyObject.keys) == ["generation", "requestId", "configurationId", "appearance", "viewport", "projectionRevision"],
                  let appearance = keyObject["appearance"] as? [String: Any], Set(appearance.keys) == ["theme", "locale"],
                  let viewport = keyObject["viewport"] as? [String: Any], Set(viewport.keys) == ["width", "height", "scale", "profile"] else {
                throw FieldContractError.invalidMessage
            }
        case .interaction:
            keys.insert("interaction")
            guard result.interaction != nil else { throw FieldContractError.invalidMessage }
        case .error:
            keys.insert("code")
            guard result.code != nil else { throw FieldContractError.invalidMessage }
        }
        guard result.version == 1, Set(object.keys) == keys else { throw FieldContractError.invalidMessage }
        return result
    }
}

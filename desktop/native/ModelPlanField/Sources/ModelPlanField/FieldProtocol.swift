// SPDX-License-Identifier: MIT
import Foundation
import ModelPlanCore

public enum FieldContractError: Error { case invalidProjection, invalidViewport, oversized }
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
